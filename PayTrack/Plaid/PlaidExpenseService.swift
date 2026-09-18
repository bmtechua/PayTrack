//
//  PlaidExpenseService.swift
//  PayTrack
//
//  Created by bmtech on 11.09.2026.
//

import Foundation

struct PlaidExpense: Codable {
    let transactionID: String?
    let accountID: String?
    let amount: Double
    let date: String?
    let title: String?
    let merchantName: String?
    let category: String
    let currency: String?
    let pending: Bool?
    let source: String

    enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
        case accountID = "account_id"
        case amount
        case date
        case title
        case merchantName = "merchant_name"
        case category
        case currency
        case pending
        case source
    }
}

// MARK: - Plaid removed transaction

struct PlaidRemovedExpense: Codable {
    let transactionID: String?
    let accountID: String?

    enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
        case accountID = "account_id"
    }
}

// MARK: - Plaid sync response

struct PlaidExpensesResponse: Codable {
    let added: [PlaidExpense]
    let modified: [PlaidExpense]
    let removed: [PlaidRemovedExpense]
    let hasMore: Bool
    let nextCursor: String

    enum CodingKeys: String, CodingKey {
        case added
        case modified
        case removed
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}

// MARK: - Plaid changes

struct PlaidExpenseChanges {
    let added: [PlaidExpense]
    let modified: [PlaidExpense]
    let removed: [PlaidRemovedExpense]
}

// MARK: - Service

@MainActor
final class PlaidExpenseService {

    static let shared = PlaidExpenseService()

    private init() {}

    // MARK: - Fetch Plaid changes

    func fetchChanges(
        connectionID: String
    ) async throws -> PlaidExpenseChanges {

        #if targetEnvironment(simulator)
        let baseURL = "http://127.0.0.1:8000"
        #else
        let baseURL = "http://10.0.0.239:8000"
        #endif

        guard let url = URL(
            string: "\(baseURL)/api/plaid/transactions/\(connectionID)/expenses/"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(
            url: url
        )

        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(
            httpResponse.statusCode
        ) else {

            let message =
                String(
                    data: data,
                    encoding: .utf8
                )
                ?? "Unknown server error"

            throw NSError(
                domain: "PlaidExpenseService",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: message
                ]
            )
        }

        let decoder = JSONDecoder()

        let result = try decoder.decode(
            PlaidExpensesResponse.self,
            from: data
        )

        AppLogger.shared.info(
            """
            [PLAID] Changes received: \
            added=\(result.added.count), \
            modified=\(result.modified.count), \
            removed=\(result.removed.count)
            """,
            category: .sync
        )

        return PlaidExpenseChanges(
            added: result.added,
            modified: result.modified,
            removed: result.removed
        )
    }

    // MARK: - Compatibility method

    func fetchExpenses(
        connectionID: String
    ) async throws -> [PlaidExpense] {

        let changes = try await fetchChanges(
            connectionID: connectionID
        )

        return changes.added
    }
}
