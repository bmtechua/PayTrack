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

    private let client = SupabaseManager.shared.client
    private let context = PersistenceController.shared.container.viewContext

    private init() {
    }

    func testSyncData() async {

        do {
            let user = try await client.auth.session.user

            let request: NSFetchRequest<Expense> = Expense.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "date", ascending: false)
            ]
            request.fetchLimit = 1

            let expenses = try context.fetch(request)

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
    
    func syncOneExpense() async {

        do {
            let user = try await client.auth.session.user

            let request: NSFetchRequest<Expense> = Expense.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "date", ascending: false)
            ]
            request.fetchLimit = 1

            let expenses = try context.fetch(request)

            guard let expense = expenses.first else {
                AppLogger.shared.info("No local expenses to sync")
                return
            }

            let data: [String: AnyJSON] = [
                "id": .string(expense.id?.uuidString ?? UUID().uuidString),
                "user_id": .string(user.id.uuidString),
                "title": .string(expense.title ?? ""),
                "amount": .double(expense.amount),
                "date": .string(
                    ISO8601DateFormatter().string(from: expense.date ?? Date())
                ),
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
    
    func syncOneCategory() async {

        do {
            let user = try await client.auth.session.user

            let request: NSFetchRequest<Category> = Category.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "name", ascending: true)
            ]
            request.fetchLimit = 1

            let categories = try context.fetch(request)

            guard let category = categories.first else {
                AppLogger.shared.info("No local categories to sync")
                return
            }

            guard let categoryID = category.id else {
                AppLogger.shared.error("Category has no ID")
                return
            }

            let data: [String: AnyJSON] = [
                "id": .string(categoryID.uuidString),
                "user_id": .string(user.id.uuidString),
                "name": .string(category.name ?? ""),
                "icon": category.icon.map {
                    .string($0)
                } ?? .null,
                "is_default": .bool(category.isDefault)
            ]

            try await client
                .from("categories")
                .upsert(data)
                .execute()

            AppLogger.shared.info(
                "Category synced successfully: \(category.name ?? "No name")"
            )

        } catch {
            AppLogger.shared.error(
                "Category sync failed: \(error.localizedDescription)"
            )
        }
    }
    
    func syncAll() async {

        do {
            let user = try await client.auth.session.user

            // MARK: - Categories

            let categoryRequest: NSFetchRequest<Category> =
                Category.fetchRequest()

            let categories = try context.fetch(categoryRequest)

            for category in categories {

                guard let categoryID = category.id else {
                    continue
                }

                let categoryData: [String: AnyJSON] = [
                    "id": .string(categoryID.uuidString),
                    "user_id": .string(user.id.uuidString),
                    "name": .string(category.name ?? ""),
                    "icon": category.icon.map {
                        .string($0)
                    } ?? .null,
                    "is_default": .bool(category.isDefault)
                ]

                try await client
                    .from("categories")
                    .upsert(categoryData)
                    .execute()
            }

            // MARK: - Expenses

            let expenseRequest: NSFetchRequest<Expense> =
                Expense.fetchRequest()

            let expenses = try context.fetch(expenseRequest)

            for expense in expenses {

                guard let expenseID = expense.id else {
                    continue
                }

                let categoryID = expense.category?.id?.uuidString

                let expenseData: [String: AnyJSON] = [
                    "id": .string(expenseID.uuidString),
                    "user_id": .string(user.id.uuidString),
                    "title": .string(expense.title ?? ""),
                    "amount": .double(expense.amount),
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
                    .upsert(expenseData)
                    .execute()
            }

            AppLogger.shared.info(
                "Full sync completed: \(categories.count) categories, \(expenses.count) expenses"
            )

        } catch {
            AppLogger.shared.error(
                "Full sync failed: \(error.localizedDescription)"
            )
        }
    }
}
