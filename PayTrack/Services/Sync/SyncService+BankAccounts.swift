//
//  SyncService+BankAccounts.swift
//  PayTrack
//
//  Created by bmtech on 15.09.2026.
//

import Foundation
import Supabase

extension SyncService {

    // MARK: - Download bank accounts

    func downloadBankAccounts() async throws -> [BankAccount] {

        let userID = try await currentUserID()

        let response = try await client
            .from("bank_accounts")
            .select("""
                id,
                connection_id,
                plaid_account_id,
                name,
                official_name,
                mask,
                type,
                subtype,
                currency,
                current_balance,
                available_balance,
                is_enabled
            """)
            .eq(
                "user_id",
                value: userID.uuidString
            )
            .order(
                "name",
                ascending: true
            )
            .execute()

        let decoder = JSONDecoder()

        let accounts = try decoder.decode(
            [BankAccount].self,
            from: response.data
        )

        AppLogger.shared.info(
            "Bank accounts loaded: \(accounts.count)",
            category: .sync
        )

        return accounts
    }
    
    // MARK: - update bank accounts
    
    func updateBankAccount(
        id: UUID,
        isEnabled: Bool
    ) async throws {

        try await client
            .from("bank_accounts")
            .update([
                "is_enabled": isEnabled
            ])
            .eq("id", value: id.uuidString)
            .execute()

        if let index = bankAccounts.firstIndex(where: { $0.id == id }) {
            bankAccounts[index].isEnabled = isEnabled
        }

        AppLogger.shared.info(
            "Bank account \(id) enabled: \(isEnabled)",
            category: .sync
        )
    }
}
