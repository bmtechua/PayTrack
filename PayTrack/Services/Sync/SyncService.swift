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
    
    var categoriesChannel: RealtimeChannelV2?
    var expensesChannel: RealtimeChannelV2?

    private init() {
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
