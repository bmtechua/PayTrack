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

        // 1. Отримуємо тільки активні Plaid connections
        let connectionsResponse = try await client
            .from("bank_connections")
            .select("id, institution_name")
            .eq("user_id", value: userID.uuidString)
            .eq("status", value: "active")
            .execute()

        struct ActiveConnection: Decodable {
            let id: UUID
            let institutionName: String?

            enum CodingKeys: String, CodingKey {
                case id
                case institutionName = "institution_name"
            }
        }

        let activeConnections = try JSONDecoder().decode(
            [ActiveConnection].self,
            from: connectionsResponse.data
        )

        let activeConnectionIDs = activeConnections.map { $0.id.uuidString }

        AppLogger.shared.info(
            "[ACCOUNTS] Active connections: \(activeConnections.count)",
            category: .sync
        )

        // Якщо активних connections немає — повертаємо порожній список
        guard !activeConnectionIDs.isEmpty else {
            AppLogger.shared.info(
                "[ACCOUNTS] No active Plaid connections",
                category: .sync
            )
            return []
        }

        // 2. Завантажуємо рахунки тільки цих active connections
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
            .eq("user_id", value: userID.uuidString)
            .in("connection_id", values: activeConnectionIDs)
            .order("name", ascending: true)
            .execute()

        let decoder = JSONDecoder()

        let accounts = try decoder.decode(
            [BankAccount].self,
            from: response.data
        )

        // 3. Перевіряємо унікальність Plaid account ID
        let plaidAccountIDs = accounts.map { $0.plaidAccountID }
        let uniquePlaidAccountIDs = Set(plaidAccountIDs)

        AppLogger.shared.info(
            "[ACCOUNTS] Active connections: \(activeConnections.count)",
            category: .sync
        )

        AppLogger.shared.info(
            "[ACCOUNTS] Accounts loaded: \(accounts.count)",
            category: .sync
        )

        AppLogger.shared.info(
            "[ACCOUNTS] Unique plaid_account_id: \(uniquePlaidAccountIDs.count)",
            category: .sync
        )

        if accounts.count != uniquePlaidAccountIDs.count {
            AppLogger.shared.warning(
                "[ACCOUNTS] DUPLICATE plaid_account_id detected!",
                category: .sync
            )
        }

        // 4. Детальний контроль по connections
        for connection in activeConnections {
            let connectionAccounts = accounts.filter {
                $0.connectionID == connection.id
            }

            AppLogger.shared.info(
                "[ACCOUNTS] \(connection.institutionName ?? "Unknown"): \(connectionAccounts.count) accounts",
                category: .sync
            )
        }

        return accounts
    }
    
    // MARK: - update bank accounts
    
    func updateBankAccount(
        id: UUID,
        isEnabled: Bool
    ) async throws {
        
        AppLogger.shared.info(
                "UPDATE bank_accounts called: id=\(id), isEnabled=\(isEnabled)",
                category: .sync
            )

        try await client
            .from("bank_accounts")
            .update([
                "is_enabled": isEnabled
            ])
            .eq("id", value: id.uuidString)
            .execute()

        if let index = bankAccounts.firstIndex(where: { $0.id == id }) {
            var updatedBankAccounts = bankAccounts
                updatedBankAccounts[index].isEnabled = isEnabled
                bankAccounts = updatedBankAccounts
        }

        AppLogger.shared.info(
            "Bank account \(id) enabled: \(isEnabled)",
            category: .sync
        )
    }
}
