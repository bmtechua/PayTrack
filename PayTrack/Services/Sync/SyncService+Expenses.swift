//
//  SyncService+Expenses.swift
//  PayTrack
//
//  Created by bmtech on 29.08.2026.
//

import Foundation
import CoreData
import Supabase

extension SyncService {

    // syncOneExpense
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

    // deleteExpense
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

    // applyRealtimeExpenseInsert
    // MARK: - Apply Realtime expense INSERT

    func applyRealtimeExpenseInsert(
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

    // applyRealtimeExpenseUpdate
    // MARK: - Apply Realtime expense UPDATE

    func applyRealtimeExpenseUpdate(
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
            
            if let amount = record["amount"] {
                switch amount {
                case .double(let value):
                    expense.amount = value

                case .integer(let value):
                    expense.amount = Double(value)

                default:
                    break
                }
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
    // applyRealtimeExpenseDelete
    // MARK: - Apply Realtime expense DELETE

    func applyRealtimeExpenseDelete(
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
}
