//
//  PlaidExpenseService.swift
//  PayTrack
//
//  Created by bmtech on 11.09.2026.
//
import Foundation

struct PlaidExpense: Codable {
    let transactionID: String?
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

struct PlaidExpensesResponse: Codable {
    let expenses: [PlaidExpense]
}

@MainActor
final class PlaidExpenseService {

    static let shared = PlaidExpenseService()

    private init() {}

    func fetchExpenses(
        connectionID: String
    ) async throws -> [PlaidExpense] {

        guard let url = URL(
            string: "http://127.0.0.1:8000/api/plaid/transactions/\(connectionID)/expenses/"
        ) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(
                data: data,
                encoding: .utf8
            ) ?? "Unknown server error"

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

        return result.expenses
    }
}
