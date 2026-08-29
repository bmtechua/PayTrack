//
//  SyncService.swift
//  PayTrack
//
//  Created by bmtech on 26.08.2026.
//

import Foundation
import CoreData
import Supabase

@MainActor
final class SyncService {

    static let shared = SyncService()

    let client = SupabaseManager.shared.client
    let context = PersistenceController.shared.container.viewContext
    
    private var categoriesChannel: RealtimeChannelV2?
    private var expensesChannel: RealtimeChannelV2?

    private init() {
    }
    
    // MARK: - Realtime categories

    func startCategoriesRealtime() async {

        guard categoriesChannel == nil else {
            return
        }

        do {

            let user = try await client.auth.session.user

            AppLogger.shared.info(
                "Realtime user ID: \(user.id.uuidString)"
            )

            let channel = client.channel(
                "categories-realtime-\(user.id.uuidString)"
            )

            let changes = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "categories"
            )

            categoriesChannel = channel

            Task { @MainActor in

                for await change in changes {

                    switch change {

                    case .insert(let action):

                        self.applyRealtimeCategoryInsert(
                            action.record
                        )

                        AppLogger.shared.info(
                            "Realtime category INSERT received"
                        )

                    case .update(let action):

                        self.applyRealtimeCategoryUpdate(
                            action.record
                        )

                        AppLogger.shared.info(
                            "Realtime category UPDATE received"
                        )

                    case .delete(let action):

                        self.applyRealtimeCategoryDelete(
                            action.oldRecord
                        )

                        AppLogger.shared.info(
                            "Realtime category DELETE received"
                        )
                    }
                }
            }

            try await channel.subscribeWithError()

            AppLogger.shared.info(
                "Categories Realtime subscribed"
            )

        } catch {

            AppLogger.shared.error(
                "Categories Realtime failed: \(error.localizedDescription)"
            )
        }
    }
    

    

    

    
    // MARK: - Stop Realtime categories

    func stopCategoriesRealtime() async {

        guard let channel = categoriesChannel else {
            return
        }

        await client.removeChannel(channel)

        categoriesChannel = nil

        AppLogger.shared.info(
            "Categories Realtime unsubscribed"
        )
    }

    // MARK: - Prepare local data for user

    func prepareForUser(_ userID: UUID) async {

        let key = "activeUserID"
        let currentUserID = UserDefaults.standard.string(forKey: key)

        if currentUserID == userID.uuidString {
            return
        }

        AppLogger.shared.info(
            "User changed. Clearing local data for previous user"
        )

        do {
            let categoryRequest: NSFetchRequest<Category> =
                Category.fetchRequest()

            let categories = try context.fetch(categoryRequest)

            for category in categories {
                context.delete(category)
            }

            let expenseRequest: NSFetchRequest<Expense> =
                Expense.fetchRequest()

            let expenses = try context.fetch(expenseRequest)

            for expense in expenses {
                context.delete(expense)
            }

            try context.save()

            UserDefaults.standard.set(
                userID.uuidString,
                forKey: key
            )

            AppLogger.shared.info(
                "Local data cleared for new user"
            )

        } catch {
            AppLogger.shared.error(
                "Failed to prepare local data: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Sync one expense

    func syncOneExpense(_ expense: Expense) async {

        do {
            let user = try await client.auth.session.user

            guard let expenseID = expense.id else {
                AppLogger.shared.error("Expense has no ID")
                return
            }

            let categoryID = expense.category?.id?.uuidString

            let data: [String: AnyJSON] = [

                "id": .string(expenseID.uuidString),

                "user_id": .string(user.id.uuidString),

                "title": .string(
                    expense.title ?? ""
                ),

                "amount": .double(
                    expense.amount
                ),

                "date": .string(
                    ISO8601DateFormatter().string(
                        from: expense.date ?? Date()
                    )
                ),

                "category_id": categoryID.map {
                    .string($0)
                } ?? .null,

                "merchant_name": expense.merchantName.map {
                    .string($0)
                } ?? .null,

                "source": expense.source.map {
                    .string($0)
                } ?? .null,

                "transaction_id": expense.transactionID.map {
                    .string($0)
                } ?? .null
            ]

            try await client
                .from("expenses")
                .upsert(data)
                .execute()

            AppLogger.shared.info(
                "Expense synced successfully: \(expense.title ?? "No title")"
            )

        } catch {
            AppLogger.shared.error(
                "Expense sync failed: \(error.localizedDescription)"
            )
        }
    }
    
    // MARK: - Realtime expenses

    func startExpensesRealtime() async {

        guard expensesChannel == nil else {
            return
        }

        do {

            let user = try await client.auth.session.user

            let channel = client.channel(
                "expenses-realtime-\(user.id.uuidString)"
            )

            let changes = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "expenses"
            )

            expensesChannel = channel

            Task { @MainActor in

                for await change in changes {

                    switch change {

                    case .insert(let action):

                        self.applyRealtimeExpenseInsert(
                            action.record
                        )

                        AppLogger.shared.info(
                            "Realtime expense INSERT received"
                        )

                    case .update(let action):

                        self.applyRealtimeExpenseUpdate(
                            action.record
                        )

                        AppLogger.shared.info(
                            "Realtime expense UPDATE received"
                        )

                    case .delete(let action):

                        self.applyRealtimeExpenseDelete(
                            action.oldRecord
                        )

                        AppLogger.shared.info(
                            "Realtime expense DELETE received"
                        )
                    }
                }
            }

            try await channel.subscribeWithError()

            AppLogger.shared.info(
                "Expenses Realtime subscribed"
            )

        } catch {

            AppLogger.shared.error(
                "Expenses Realtime failed: \(error.localizedDescription)"
            )
        }
    }
    
    // MARK: - Apply Realtime expense INSERT

    private func applyRealtimeExpenseInsert(
        _ record: [String: AnyJSON]
    ) {

        guard
            case let .string(idString) = record["id"],
            let expenseID = UUID(uuidString: idString)
        else {
            AppLogger.shared.error(
                "Realtime expense INSERT: invalid ID"
            )
            return
        }

        // Check by Expense ID
        let idRequest: NSFetchRequest<Expense> =
            Expense.fetchRequest()

        idRequest.fetchLimit = 1
        idRequest.predicate = NSPredicate(
            format: "id == %@",
            expenseID as CVarArg
        )

        do {

            if try context.fetch(idRequest).first != nil {

                AppLogger.shared.info(
                    "Realtime expense INSERT skipped: ID already exists"
                )

                return
            }

            // Check by bank transaction ID
            if case let .string(transactionID) = record["transaction_id"],
               !transactionID.isEmpty {

                let transactionRequest: NSFetchRequest<Expense> =
                    Expense.fetchRequest()

                transactionRequest.fetchLimit = 1
                transactionRequest.predicate = NSPredicate(
                    format: "transactionID == %@",
                    transactionID
                )

                if try context.fetch(transactionRequest).first != nil {

                    AppLogger.shared.info(
                        "Realtime expense INSERT skipped: transaction already exists"
                    )

                    return
                }
            }

            let expense = Expense(context: context)

            expense.id = expenseID

            if case let .string(value) = record["user_id"] {
                // Не використовуємо user_id для Core Data Expense,
                // якщо такого атрибута немає в моделі.
                _ = value
            }

            if case let .string(value) = record["title"] {
                expense.title = value
            }

            if case let .double(value) = record["amount"] {
                expense.amount = value
            }

            if case let .string(value) = record["date"] {

                let formatter = ISO8601DateFormatter()

                if let date = formatter.date(from: value) {
                    expense.date = date
                }
            }

            if case let .string(value) = record["merchant_name"] {
                expense.merchantName = value
            }

            if case let .string(value) = record["source"] {
                expense.source = value
            }

            if case let .string(value) = record["transaction_id"] {
                expense.transactionID = value
            }

            if case let .string(categoryIDString) = record["category_id"],
               let categoryID = UUID(uuidString: categoryIDString) {

                let categoryRequest: NSFetchRequest<Category> =
                    Category.fetchRequest()

                categoryRequest.fetchLimit = 1
                categoryRequest.predicate = NSPredicate(
                    format: "id == %@",
                    categoryID as CVarArg
                )

                expense.category =
                    try context.fetch(categoryRequest).first
            }

            try context.save()

            AppLogger.shared.info(
                "Realtime expense INSERT applied: \(expense.title ?? "No title")"
            )

        } catch {

            AppLogger.shared.error(
                "Realtime expense INSERT failed: \(error.localizedDescription)"
            )
        }
    }
    
    // MARK: - Apply Realtime expense UPDATE

    private func applyRealtimeExpenseUpdate(
        _ record: [String: AnyJSON]
    ) {

        guard
            case let .string(idString) = record["id"],
            let expenseID = UUID(uuidString: idString)
        else {
            AppLogger.shared.error(
                "Realtime expense UPDATE: invalid ID"
            )
            return
        }

        let request: NSFetchRequest<Expense> =
            Expense.fetchRequest()

        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "id == %@",
            expenseID as CVarArg
        )

        do {

            guard let expense = try context.fetch(request).first else {

                AppLogger.shared.info(
                    "Realtime expense UPDATE: local expense not found"
                )

                return
            }

            if case let .string(value) = record["title"] {
                expense.title = value
            }

            if case let .double(value) = record["amount"] {
                expense.amount = value
            }

            if case let .string(value) = record["date"] {

                let formatter = ISO8601DateFormatter()

                if let date = formatter.date(from: value) {
                    expense.date = date
                }
            }

            if case let .string(value) = record["merchant_name"] {
                expense.merchantName = value
            }

            if case let .string(value) = record["source"] {
                expense.source = value
            }

            if case let .string(value) = record["transaction_id"] {
                expense.transactionID = value
            }

            if case let .string(categoryIDString) = record["category_id"],
               let categoryID = UUID(uuidString: categoryIDString) {

                let categoryRequest: NSFetchRequest<Category> =
                    Category.fetchRequest()

                categoryRequest.fetchLimit = 1
                categoryRequest.predicate = NSPredicate(
                    format: "id == %@",
                    categoryID as CVarArg
                )

                expense.category =
                    try context.fetch(categoryRequest).first
            } else {
                expense.category = nil
            }

            try context.save()

            AppLogger.shared.info(
                "Realtime expense UPDATE applied: \(expense.title ?? "No title")"
            )

        } catch {

            AppLogger.shared.error(
                "Realtime expense UPDATE failed: \(error.localizedDescription)"
            )
        }
    }
    
    // MARK: - Apply Realtime expense DELETE

    private func applyRealtimeExpenseDelete(
        _ record: [String: AnyJSON]
    ) {

        guard
            case let .string(idString) = record["id"],
            let expenseID = UUID(uuidString: idString)
        else {
            AppLogger.shared.error(
                "Realtime expense DELETE: invalid ID"
            )
            return
        }

        let request: NSFetchRequest<Expense> =
            Expense.fetchRequest()

        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "id == %@",
            expenseID as CVarArg
        )

        do {

            guard let expense = try context.fetch(request).first else {

                AppLogger.shared.info(
                    "Realtime expense DELETE: local expense not found"
                )

                return
            }

            let title = expense.title ?? "No title"

            context.delete(expense)

            try context.save()

            AppLogger.shared.info(
                "Realtime expense DELETE applied: \(title)"
            )

        } catch {

            AppLogger.shared.error(
                "Realtime expense DELETE failed: \(error.localizedDescription)"
            )
        }
    }
    
    

    // MARK: - Delete expense

    func deleteExpense(id: UUID, title: String) async {

        do {
            let user = try await client.auth.session.user

            try await client
                .from("expenses")
                .delete()
                .eq("id", value: id.uuidString)
                .eq("user_id", value: user.id.uuidString)
                .execute()

            AppLogger.shared.info(
                "Expense deleted from Supabase: \(title)"
            )

        } catch {
            AppLogger.shared.error(
                "Expense delete sync failed: \(error.localizedDescription)"
            )
        }
    }







    // MARK: - Full sync

    // MARK: - Full sync

    func syncAll() async {

        do {

            let user = try await client.auth.session.user
            let userID = user.id

            // MARK: - Upload local categories

            let localCategoryRequest: NSFetchRequest<Category> =
                Category.fetchRequest()

            localCategoryRequest.predicate = NSPredicate(
                format: "userID == %@",
                userID as CVarArg
            )

            let localCategories =
                try context.fetch(localCategoryRequest)

            for category in localCategories {

                await syncOneCategory(category)

            }

            // MARK: - Upload local expenses

            let localExpenseRequest: NSFetchRequest<Expense> =
                Expense.fetchRequest()

            let localExpenses =
                try context.fetch(localExpenseRequest)

            for expense in localExpenses {

                await syncOneExpense(expense)

            }

            // MARK: - Categories from Supabase

            let remoteCategories: [[String: AnyJSON]] =
                try await client
                    .from("categories")
                    .select()
                    .eq(
                        "user_id",
                        value: userID.uuidString
                    )
                    .execute()
                    .value

            // Remove local categories ONLY for current user

            let categoriesToRemove =
                try context.fetch(localCategoryRequest)

            for category in categoriesToRemove {

                context.delete(category)

            }

            // Create categories from Supabase

            for remoteCategory in remoteCategories {

                guard
                    case let .string(idString) =
                        remoteCategory["id"],

                    let categoryID =
                        UUID(uuidString: idString)

                else {

                    continue

                }

                let category = Category(context: context)

                category.id = categoryID
                category.userID = userID

                if case let .string(value) =
                    remoteCategory["name"] {

                    category.name = value

                }

                if case let .string(value) =
                    remoteCategory["icon"] {

                    category.icon = value

                }

                if case let .bool(value) =
                    remoteCategory["is_default"] {

                    category.is_default = value

                }

            }

            try context.save()

            // MARK: - Expenses from Supabase

            let remoteExpenses: [[String: AnyJSON]] =
                try await client
                    .from("expenses")
                    .select()
                    .eq(
                        "user_id",
                        value: userID.uuidString
                    )
                    .execute()
                    .value

            // Remove local expenses

            let expensesToRemove =
                try context.fetch(localExpenseRequest)

            for expense in expensesToRemove {

                context.delete(expense)

            }

            // Get categories for relationships

            let categoryRequest: NSFetchRequest<Category> =
                Category.fetchRequest()

            categoryRequest.predicate = NSPredicate(
                format: "userID == %@",
                userID as CVarArg
            )

            let allCategories =
                try context.fetch(categoryRequest)

            var categoriesByID: [UUID: Category] = [:]

            for category in allCategories {

                if let id = category.id {

                    categoriesByID[id] = category

                }

            }

            let dateFormatter = ISO8601DateFormatter()

            // Create expenses from Supabase

            for remoteExpense in remoteExpenses {

                guard
                    case let .string(idString) =
                        remoteExpense["id"],

                    let expenseID =
                        UUID(uuidString: idString)

                else {

                    continue

                }

                let expense = Expense(context: context)

                expense.id = expenseID

                if case let .string(value) =
                    remoteExpense["title"] {

                    expense.title = value

                }

                if case let .double(value) =
                    remoteExpense["amount"] {

                    expense.amount = value

                }

                if case let .string(value) =
                    remoteExpense["date"],

                    let date =
                        dateFormatter.date(from: value) {

                    expense.date = date

                }

                if case let .string(value) =
                    remoteExpense["merchant_name"] {

                    expense.merchantName = value

                }

                if case let .string(value) =
                    remoteExpense["source"] {

                    expense.source = value

                }

                if case let .string(value) =
                    remoteExpense["transaction_id"] {

                    expense.transactionID = value

                }

                if case let .string(categoryIDString) =
                    remoteExpense["category_id"],

                    let categoryID =
                        UUID(uuidString: categoryIDString) {

                    expense.category =
                        categoriesByID[categoryID]

                }

            }

            try context.save()

            AppLogger.shared.info(
                "Full sync completed: \(allCategories.count) categories, \(remoteExpenses.count) expenses"
            )

        } catch {

            AppLogger.shared.error(
                "Full sync failed: \(error.localizedDescription)"
            )

        }

    }
    
    // MARK: - Clear Data after logout
    func clearLocalData() async {

        do {

            let categoryRequest: NSFetchRequest<Category> =
                Category.fetchRequest()

            let categories =
                try context.fetch(categoryRequest)

            for category in categories {
                context.delete(category)
            }

            let expenseRequest: NSFetchRequest<Expense> =
                Expense.fetchRequest()

            let expenses =
                try context.fetch(expenseRequest)

            for expense in expenses {
                context.delete(expense)
            }

            try context.save()

            UserDefaults.standard.removeObject(
                forKey: "activeUserID"
            )

            AppLogger.shared.info(
                "Local data cleared after logout"
            )

        } catch {

            AppLogger.shared.error(
                "Failed to clear local data after logout: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Test

    func testSyncData() async {

        do {

            let user =
                try await client.auth.session.user

            let request: NSFetchRequest<Expense> =
                Expense.fetchRequest()

            request.sortDescriptors = [
                NSSortDescriptor(
                    key: "date",
                    ascending: false
                )
            ]

            request.fetchLimit = 1

            let expenses =
                try context.fetch(request)

            AppLogger.shared.info(
                "Sync test: user \(user.id), local expenses: \(expenses.count)"
            )

            if let expense = expenses.first {

                AppLogger.shared.info(
                    "Sync test expense: \(expense.title ?? "No title"), amount: \(expense.amount)"
                )
            }

        } catch {

            AppLogger.shared.error(
                "Sync test failed: \(error.localizedDescription)"
            )
        }
    }
}
