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

}
