//
//  BankAccount.swift
//  PayTrack
//
//  Created by bmtech on 15.09.2026.
//

import Foundation

struct BankAccount: Identifiable, Codable {
    let id: UUID
    let connectionID: UUID
    let plaidAccountID: String

    let name: String?
    let officialName: String?
    let mask: String?

    let type: String?
    let subtype: String?

    let currency: String?

    let currentBalance: Double?
    let availableBalance: Double?

    var isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case connectionID = "connection_id"
        case plaidAccountID = "plaid_account_id"
        case name
        case officialName = "official_name"
        case mask
        case type
        case subtype
        case currency
        case currentBalance = "current_balance"
        case availableBalance = "available_balance"
        case isEnabled = "is_enabled"
    }
}
