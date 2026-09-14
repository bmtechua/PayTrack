//
//  SyncService+PlaidHelp.swift
//  PayTrack
//
//  Created by bmtech on 12.09.2026.
//

import Foundation
import CoreData
import Supabase

extension SyncService {
    
    func deleteLocalPlaidExpenses() {
        let context = PersistenceController.shared.container.viewContext

        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "source == %@", "plaid")

        do {
            let expenses = try context.fetch(request)

            for expense in expenses {
                context.delete(expense)
            }

            try context.save()

            AppLogger.shared.info(
                "Local Plaid expenses deleted: \(expenses.count)",
                category: .sync
            )
        } catch {
            AppLogger.shared.error(
                "Failed to delete local Plaid expenses: \(error)",
                category: .sync
            )
        }
    }
    
    // MARK: - Remove duplicate Plaid expenses from Supabase

    func removeDuplicatePlaidExpensesFromSupabase() async {

        do {

            let user = try await client.auth.session.user

            let userID = user.id.uuidString

            // Отримуємо всі Plaid expenses поточного користувача
            let records: [[String: AnyJSON]] =
                try await client
                    .from("expenses")
                    .select()
                    .eq("user_id", value: userID)
                    .eq("source", value: "plaid")
                    .execute()
                    .value

            AppLogger.shared.info(
                "Supabase Plaid expenses found: \(records.count)",
                category: .sync
            )

            // Групуємо за transaction_id
            var grouped:
                [String: [[String: AnyJSON]]] = [:]

            for record in records {

                guard
                    case let .string(transactionID) =
                        record["transaction_id"],
                    !transactionID.isEmpty
                else {
                    continue
                }

                grouped[transactionID, default: []]
                    .append(record)
            }

            var removedCount = 0

            // Шукаємо transaction_id, які зустрічаються більше одного разу
            for (transactionID, duplicates) in grouped {

                guard duplicates.count > 1 else {
                    continue
                }

                AppLogger.shared.info(
                    """
                    Supabase duplicate transaction found:
                    transactionID=\(transactionID)
                    count=\(duplicates.count)
                    """,
                    category: .sync
                )

                // Сортуємо за UUID.
                // Перший залишаємо.
                let sorted =
                    duplicates.sorted { first, second in

                        let firstID: String

                        if case let .string(value) =
                            first["id"] {
                            firstID = value
                        } else {
                            firstID = ""
                        }

                        let secondID: String

                        if case let .string(value) =
                            second["id"] {
                            secondID = value
                        } else {
                            secondID = ""
                        }

                        return firstID < secondID
                    }

                // Перший залишаємо
                for duplicate in sorted.dropFirst() {

                    guard
                        case let .string(expenseID) =
                            duplicate["id"]
                    else {
                        continue
                    }

                    try await client
                        .from("expenses")
                        .delete()
                        .eq(
                            "id",
                            value: expenseID
                        )
                        .eq(
                            "user_id",
                            value: userID
                        )
                        .execute()

                    removedCount += 1

                    AppLogger.shared.info(
                        """
                        Supabase duplicate removed:
                        transactionID=\(transactionID)
                        id=\(expenseID)
                        """,
                        category: .sync
                    )
                }
            }

            AppLogger.shared.info(
                """
                Supabase Plaid duplicate cleanup completed.
                Removed: \(removedCount)
                """,
                category: .sync
            )

        } catch {

            AppLogger.shared.error(
                """
                Supabase Plaid duplicate cleanup failed:
                \(error.localizedDescription)
                """,
                category: .sync
            )
        }
    }
    
   
}
