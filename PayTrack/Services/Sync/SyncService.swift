//
//  SyncService.swift
//  PayTrack
//
//  Created by bmtech on 26.08.2026.
//

import Foundation
import CoreData
import Supabase
import Combine

@MainActor
final class SyncService: ObservableObject {

    static let shared = SyncService()

    let client = SupabaseManager.shared.client

    let context =
        PersistenceController.shared.container.viewContext

    var categoriesChannel: RealtimeChannelV2?

    var expensesChannel: RealtimeChannelV2?

    var profileChannel: RealtimeChannelV2?
    
    var bankAccountsChannel: RealtimeChannelV2?
    private var isReloadingBankAccountsFromRealtime = false

    var fullSyncTask: Task<Void, Never>?
    
    @Published var bankAccounts: [BankAccount] = []

    // MARK: - Cancel full sync

    func cancelFullSync() {

        fullSyncTask?.cancel()

        fullSyncTask = nil
        

        AppLogger.shared.info(
            "Full sync cancelled",
            category: .sync
        )
    }

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
                "Sync test: user \(user.id), local expenses: \(expenses.count)",
                category: .sync
            )

            if let expense = expenses.first {

                AppLogger.shared.info(
                    "Sync test expense: \(expense.title ?? "No title"), amount: \(expense.amount)",
                    category: .sync
                )
            }

        } catch {

            AppLogger.shared.error(
                "Sync test failed: \(error.localizedDescription)",
                category: .sync
            )
        }
    }
    
    // MARK: - syncPlaidConnection
    
    func syncPlaidConnection(_ connectionID: String) async {
        do {
            let expenses = try await PlaidExpenseService.shared.fetchExpenses(
                connectionID: connectionID
            )

            AppLogger.shared.info(
                "Plaid expenses received after Link: \(expenses.count)",
                category: .sync
            )

            await importPlaidExpenses(expenses)

        } catch {
            AppLogger.shared.error(
                "Plaid connection sync failed: \(error.localizedDescription)",
                category: .sync
            )
        }
    }
}
