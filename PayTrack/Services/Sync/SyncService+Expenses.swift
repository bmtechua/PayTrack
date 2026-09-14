//
//  SyncService+Expenses.swift
//  PayTrack
//

import Foundation
import CoreData
import Supabase

extension SyncService {

    // MARK: - Sync one expense

    func syncOneExpense(_ expense: Expense) async {

        do {

            let user = try await client.auth.session.user

            guard let expenseID = expense.id else {

                AppLogger.shared.error(
                    "Expense has no ID",
                    category: .sync
                )

                return
            }

            expense.userID = user.id
            var remoteID = expenseID.uuidString

            if expense.source == "plaid",
               let transactionID = expense.transactionID,
               !transactionID.isEmpty {

                struct ExistingExpense: Decodable {
                    let id: UUID
                }

                let response = try await client
                    .from("expenses")
                    .select("id")
                    .eq("user_id", value: user.id.uuidString)
                    .eq("source", value: "plaid")
                    .eq("transaction_id", value: transactionID)
                    .limit(1)
                    .execute()

                let existingExpenses = try JSONDecoder().decode(
                    [ExistingExpense].self,
                    from: response.data
                )

                if let existingExpense = existingExpenses.first {
                    remoteID = existingExpense.id.uuidString

                    if expense.id != existingExpense.id {
                        expense.id = existingExpense.id
                    }
                }
            }

            let categoryID = expense.category?.id?.uuidString

            let data: [String: AnyJSON] = [

                "id": .string(remoteID),

                "user_id": .string(
                    user.id.uuidString
                ),

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

            try context.save()

            AppLogger.shared.info(
                "Expense synced successfully: \(expense.title ?? "No title")",
                category: .sync
            )

        } catch {

            AppLogger.shared.error(
                "Expense sync failed: \(error.localizedDescription)",
                category: .sync
            )
        }
    }

    // MARK: - Import Plaid expenses

    func importPlaidExpenses(
        _ plaidExpenses: [PlaidExpense]
    ) async {

        do {

            let user = try await client.auth.session.user

            for plaidExpense in plaidExpenses {

                guard let transactionID = plaidExpense.transactionID,
                      !transactionID.isEmpty else {

                    AppLogger.shared.error(
                        "Plaid expense has no transaction ID",
                        category: .sync
                    )

                    continue
                }

                // MARK: 1. Find existing expense by Plaid transaction ID

                let transactionRequest: NSFetchRequest<Expense> =
                    Expense.fetchRequest()

                transactionRequest.fetchLimit = 1

                transactionRequest.predicate = NSPredicate(
                    format:
                        "transactionID == %@ AND userID == %@",
                    transactionID,
                    user.id as CVarArg
                )

                let existingExpense =
                    try context.fetch(transactionRequest).first

                // MARK: 2. Reuse existing or create new expense

                let expense: Expense

                if let existingExpense {

                    expense = existingExpense

                    AppLogger.shared.info(
                        "Plaid expense updated: \(transactionID)",
                        category: .sync
                    )

                } else {

                    expense = Expense(
                        context: context
                    )

                    expense.id = UUID()
                    expense.userID = user.id
                    expense.source = "plaid"

                    AppLogger.shared.info(
                        "Plaid expense created: \(transactionID)",
                        category: .sync
                    )
                }

                // MARK: 3. Update expense

                expense.userID = user.id
                expense.transactionID = transactionID
                expense.amount = plaidExpense.amount
                expense.title = plaidExpense.title
                expense.merchantName = plaidExpense.merchantName
                expense.source = "plaid"

                if let dateString = plaidExpense.date {

                    let formatter = DateFormatter()

                    formatter.dateFormat = "yyyy-MM-dd"

                    formatter.locale = Locale(
                        identifier: "en_US_POSIX"
                    )

                    formatter.timeZone = TimeZone(
                        secondsFromGMT: 0
                    )

                    expense.date = formatter.date(
                        from: dateString
                    )
                }

                // MARK: 4. Find category

                let categoryRequest: NSFetchRequest<Category> =
                    Category.fetchRequest()

                categoryRequest.fetchLimit = 1

                categoryRequest.predicate = NSPredicate(
                    format:
                        "name == %@ AND userID == %@",
                    plaidExpense.category,
                    user.id as CVarArg
                )

                if let category = try context.fetch(
                    categoryRequest
                ).first {

                    expense.category = category

                } else {

                    AppLogger.shared.info(
                        "Plaid category not found: \(plaidExpense.category)",
                        category: .sync
                    )

                    let otherRequest: NSFetchRequest<Category> =
                        Category.fetchRequest()

                    otherRequest.fetchLimit = 1

                    otherRequest.predicate = NSPredicate(
                        format:
                            "name == %@ AND userID == %@",
                        "Other",
                        user.id as CVarArg
                    )

                    expense.category = try context.fetch(
                        otherRequest
                    ).first
                }

                // MARK: 5. Save local expense

                try context.save()

                AppLogger.shared.info(
                    "Plaid expense imported: \(expense.title ?? "No title")",
                    category: .sync
                )

                // MARK: 6. Upload/update Supabase expense

                await syncOneExpense(
                    expense
                )
            }

        } catch {

            AppLogger.shared.error(
                "Plaid expenses import failed: \(error.localizedDescription)",
                category: .sync
            )
        }
    }

    // MARK: - Delete expense

    func deleteExpense(
        id: UUID,
        title: String
    ) async {

        do {

            let user =
                try await client.auth.session.user

            try await client
                .from("expenses")
                .delete()
                .eq(
                    "id",
                    value: id.uuidString
                )
                .eq(
                    "user_id",
                    value: user.id.uuidString
                )
                .execute()

            AppLogger.shared.info(
                "Expense deleted from Supabase: \(title)",
                category: .sync
            )

        } catch {

            AppLogger.shared.error(
                "Expense delete sync failed: \(error.localizedDescription)",
                category: .sync
            )
        }
    }

    // MARK: - Apply Realtime expense INSERT

    func applyRealtimeExpenseInsert(
        _ record: [String: AnyJSON]
    ) {

        guard
            case let .string(idString) = record["id"],
            let expenseID = UUID(uuidString: idString),
            case let .string(userIDString) =
                record["user_id"],
            let userID = UUID(
                uuidString: userIDString
            )
        else {

            AppLogger.shared.error(
                "Realtime expense INSERT: invalid ID or user_id",
                category: .realtime
            )

            return
        }

        guard UserDefaults.standard.string(
            forKey: "activeUserID"
        ) == userID.uuidString else {

            return
        }

        do {

            // MARK: Check local ID

            let idRequest:
                NSFetchRequest<Expense> =
                Expense.fetchRequest()

            idRequest.fetchLimit = 1

            idRequest.predicate = NSPredicate(
                format:
                    "id == %@ AND userID == %@",
                expenseID as CVarArg,
                userID as CVarArg
            )

            if try context.fetch(
                idRequest
            ).first != nil {

                AppLogger.shared.info(
                    "Realtime expense INSERT skipped: ID already exists",
                    category: .realtime
                )

                return
            }

            // MARK: Check transaction ID

            if case let .string(transactionID) =
                record["transaction_id"],
               !transactionID.isEmpty {

                let transactionRequest:
                    NSFetchRequest<Expense> =
                    Expense.fetchRequest()

                transactionRequest.fetchLimit = 1

                transactionRequest.predicate = NSPredicate(
                    format:
                        "transactionID == %@ AND userID == %@",
                    transactionID,
                    userID as CVarArg
                )

                if try context.fetch(
                    transactionRequest
                ).first != nil {

                    AppLogger.shared.info(
                        "Realtime expense INSERT skipped: transaction already exists",
                        category: .realtime
                    )

                    return
                }
            }

            // MARK: Create expense

            let expense = Expense(
                context: context
            )

            expense.id = expenseID
            expense.userID = userID

            if case let .string(value) =
                record["title"] {

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

            if case let .string(value) =
                record["date"] {

                let formatter =
                    ISO8601DateFormatter()

                if let date = formatter.date(
                    from: value
                ) {

                    expense.date = date
                }
            }

            if case let .string(value) =
                record["merchant_name"] {

                expense.merchantName = value
            }

            if case let .string(value) =
                record["source"] {

                expense.source = value
            }

            if case let .string(value) =
                record["transaction_id"] {

                expense.transactionID = value
            }

            if case let .string(categoryIDString) =
                record["category_id"],
               let categoryID = UUID(
                   uuidString: categoryIDString
               ) {

                let categoryRequest:
                    NSFetchRequest<Category> =
                    Category.fetchRequest()

                categoryRequest.fetchLimit = 1

                categoryRequest.predicate =
                    NSPredicate(
                        format:
                            "id == %@ AND userID == %@",
                        categoryID as CVarArg,
                        userID as CVarArg
                    )

                expense.category =
                    try context.fetch(
                        categoryRequest
                    ).first
            }

            try context.save()

            AppLogger.shared.info(
                "Realtime expense INSERT applied: \(expense.title ?? "No title")",
                category: .realtime
            )

        } catch {

            AppLogger.shared.error(
                "Realtime expense INSERT failed: \(error.localizedDescription)",
                category: .realtime
            )
        }
    }

    // MARK: - Apply Realtime expense UPDATE

    func applyRealtimeExpenseUpdate(
        _ record: [String: AnyJSON]
    ) {

        guard
            case let .string(idString) =
                record["id"],
            let expenseID = UUID(
                uuidString: idString
            ),
            case let .string(userIDString) =
                record["user_id"],
            let userID = UUID(
                uuidString: userIDString
            )
        else {

            AppLogger.shared.error(
                "Realtime expense UPDATE: invalid ID or user_id",
                category: .realtime
            )

            return
        }

        guard UserDefaults.standard.string(
            forKey: "activeUserID"
        ) == userID.uuidString else {

            return
        }

        let request:
            NSFetchRequest<Expense> =
            Expense.fetchRequest()

        request.fetchLimit = 1

        request.predicate = NSPredicate(
            format:
                "id == %@ AND userID == %@",
            expenseID as CVarArg,
            userID as CVarArg
        )

        do {

            var expense =
                try context.fetch(request).first

            // Plaid Realtime UPDATE can contain the
            // remote Supabase ID while the local Core Data
            // expense has another ID.
            //
            // In that case, use transaction_id to find
            // the local expense.

            if expense == nil,
               case let .string(transactionID) =
                    record["transaction_id"],
               !transactionID.isEmpty {

                let transactionRequest:
                    NSFetchRequest<Expense> =
                    Expense.fetchRequest()

                transactionRequest.fetchLimit = 1

                transactionRequest.predicate =
                    NSPredicate(
                        format:
                            "transactionID == %@ AND userID == %@",
                        transactionID,
                        userID as CVarArg
                    )

                expense =
                    try context.fetch(
                        transactionRequest
                    ).first
            }

            guard let expense else {

                AppLogger.shared.info(
                    "Realtime expense UPDATE: local expense not found",
                    category: .realtime
                )

                return
            }

            if case let .string(value) =
                record["title"] {

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

            if case let .string(value) =
                record["date"] {

                let formatter =
                    ISO8601DateFormatter()

                if let date = formatter.date(
                    from: value
                ) {

                    expense.date = date
                }
            }

            if case let .string(value) =
                record["merchant_name"] {

                expense.merchantName = value
            }

            if case let .string(value) =
                record["source"] {

                expense.source = value
            }

            if case let .string(value) =
                record["transaction_id"] {

                expense.transactionID = value
            }

            if case let .string(categoryIDString) =
                record["category_id"],
               let categoryID = UUID(
                   uuidString: categoryIDString
               ) {

                let categoryRequest:
                    NSFetchRequest<Category> =
                    Category.fetchRequest()

                categoryRequest.fetchLimit = 1

                categoryRequest.predicate =
                    NSPredicate(
                        format:
                            "id == %@ AND userID == %@",
                        categoryID as CVarArg,
                        userID as CVarArg
                    )

                expense.category =
                    try context.fetch(
                        categoryRequest
                    ).first

            } else {

                expense.category = nil
            }

            try context.save()

            AppLogger.shared.info(
                "Realtime expense UPDATE applied: \(expense.title ?? "No title")",
                category: .realtime
            )

        } catch {

            AppLogger.shared.error(
                "Realtime expense UPDATE failed: \(error.localizedDescription)",
                category: .realtime
            )
        }
    }

    // MARK: - Apply Realtime expense DELETE

    func applyRealtimeExpenseDelete(
        _ record: [String: AnyJSON]
    ) {

        guard
            case let .string(idString) =
                record["id"],
            let expenseID = UUID(
                uuidString: idString
            ),
            case let .string(userIDString) =
                record["user_id"],
            let userID = UUID(
                uuidString: userIDString
            )
        else {

            AppLogger.shared.error(
                "Realtime expense DELETE: invalid ID or user_id",
                category: .realtime
            )

            return
        }

        guard UserDefaults.standard.string(
            forKey: "activeUserID"
        ) == userID.uuidString else {

            return
        }

        let request:
            NSFetchRequest<Expense> =
            Expense.fetchRequest()

        request.fetchLimit = 1

        request.predicate = NSPredicate(
            format:
                "id == %@ AND userID == %@",
            expenseID as CVarArg,
            userID as CVarArg
        )

        do {

            guard let expense =
                    try context.fetch(
                        request
                    ).first else {

                AppLogger.shared.info(
                    "Realtime expense DELETE: local expense not found",
                    category: .realtime
                )

                return
            }

            let title =
                expense.title ?? "No title"

            context.delete(
                expense
            )

            try context.save()

            AppLogger.shared.info(
                "Realtime expense DELETE applied: \(title)",
                category: .realtime
            )

        } catch {

            AppLogger.shared.error(
                "Realtime expense DELETE failed: \(error.localizedDescription)",
                category: .realtime
            )
        }
    }
}
