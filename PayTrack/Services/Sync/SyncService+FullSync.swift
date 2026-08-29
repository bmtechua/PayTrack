//
//  SyncService+FullSync.swift
//  PayTrack
//
//  Created by bmtech on 29.08.2026.
//

import Foundation
import CoreData
import Supabase

extension SyncService {
    
    private func currentUserID() async throws -> UUID {
            let user = try await client.auth.session.user
            return user.id
        }
    
    private func uploadLocalCategories(for userID: UUID) async throws {
        let request: NSFetchRequest<Category> = Category.fetchRequest()

        request.predicate = NSPredicate(
            format: "userID == %@",
            userID as CVarArg
        )

        let categories = try context.fetch(request)

        for category in categories {
            await syncOneCategory(category)
        }
    }
    
    private func removeLocalCategories(for userID: UUID) throws {
        let request: NSFetchRequest<Category> =
            Category.fetchRequest()

        request.predicate = NSPredicate(
            format: "userID == %@",
            userID as CVarArg
        )

        let categories = try context.fetch(request)

        for category in categories {
            context.delete(category)
        }
    }
    
    private func uploadLocalExpenses() async throws {
        let request: NSFetchRequest<Expense> =
            Expense.fetchRequest()

        let expenses = try context.fetch(request)

        for expense in expenses {
            await syncOneExpense(expense)
        }
    }
    
    private func removeLocalExpenses() throws {
        let request: NSFetchRequest<Expense> =
            Expense.fetchRequest()

        let expenses = try context.fetch(request)

        for expense in expenses {
            context.delete(expense)
        }
    }
    
    private func downloadRemoteCategories(
        for userID: UUID
    ) async throws -> [[String: AnyJSON]] {

        return try await client
            .from("categories")
            .select()
            .eq(
                "user_id",
                value: userID.uuidString
            )
            .execute()
            .value
    }
    
    private func saveRemoteCategories(
        _ remoteCategories: [[String: AnyJSON]],
        for userID: UUID
    ) throws {

        for remoteCategory in remoteCategories {

            guard
                case let .string(idString) = remoteCategory["id"],
                let categoryID = UUID(uuidString: idString)
            else {
                continue
            }

            let category = Category(context: context)

            category.id = categoryID
            category.userID = userID

            if case let .string(value) = remoteCategory["name"] {
                category.name = value
            }

            if case let .string(value) = remoteCategory["icon"] {
                category.icon = value
            }

            if case let .bool(value) = remoteCategory["is_default"] {
                category.is_default = value
            }
        }

        try context.save()
    }
    
    private func downloadRemoteExpenses(
        for userID: UUID
    ) async throws -> [[String: AnyJSON]] {

        return try await client
            .from("expenses")
            .select()
            .eq(
                "user_id",
                value: userID.uuidString
            )
            .execute()
            .value
    }
    
    private func localCategoriesByID(
        for userID: UUID
    ) throws -> [UUID: Category] {

        let request: NSFetchRequest<Category> =
            Category.fetchRequest()

        request.predicate = NSPredicate(
            format: "userID == %@",
            userID as CVarArg
        )

        let categories = try context.fetch(request)

        var categoriesByID: [UUID: Category] = [:]

        for category in categories {
            if let id = category.id {
                categoriesByID[id] = category
            }
        }

        return categoriesByID
    }

    func syncAll() async {

        do {

            let user = try await client.auth.session.user
            let userID = user.id

            // MARK: - Upload local categories

            try await uploadLocalCategories(for: userID)

            // MARK: - Upload local expenses

            try await uploadLocalExpenses()

            // MARK: - Categories from Supabase

            let remoteCategories =
                try await downloadRemoteCategories(for: userID)

            // Remove local categories ONLY for current user

            try removeLocalCategories(for: userID)

            // Create categories from Supabase

            try saveRemoteCategories(
                remoteCategories,
                for: userID
            )

            // MARK: - Expenses from Supabase

            let remoteExpenses =
                try await downloadRemoteExpenses(for: userID)

            // Remove local expenses
            
            try removeLocalExpenses()

            // Get categories for relationships

            let categoriesByID =
                try localCategoriesByID(for: userID)

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
                "Full sync completed: \(categoriesByID.count) categories, \(remoteExpenses.count) expenses"
            )

        } catch {

            AppLogger.shared.error(
                "Full sync failed: \(error.localizedDescription)"
            )

        }

    }

}
