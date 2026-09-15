//
//  BankAccountsView.swift
//  PayTrack
//
//  Created by bmtech on 15.09.2026.
//
import SwiftUI

struct BankAccountsView: View {

    let connection: BankConnectionView.BankConnection

    @ObservedObject
    private var syncService = SyncService.shared

    private var accounts: [BankAccount] {
        syncService.bankAccounts.filter {
            $0.connectionID == connection.id
        }
    }
    
    private func localizedSubtype(_ subtype: String) -> LocalizedStringKey {
        switch subtype.lowercased() {
        case "checking":
            return "bank_account_checking"

        case "savings":
            return "bank_account_savings"

        case "money market":
            return "bank_account_money_market"

        case "cd":
            return "bank_account_cd"

        case "credit card":
            return "bank_account_credit_card"

        case "student":
            return "bank_account_student_loan"

        case "mortgage":
            return "bank_account_mortgage"

        case "auto":
            return "bank_account_auto_loan"

        case "home equity":
            return "bank_account_home_equity"

        case "hsa":
            return "bank_account_hsa"

        case "cash management":
            return "bank_account_cash_management"

        case "tfsa":
            return "bank_account_tfsa"

        case "rrsp":
            return "bank_account_rrsp"

        default:
            return LocalizedStringKey(subtype)
        }
    }
    
    private func localizedCurrency(_ currency: String) -> LocalizedStringKey {
        switch currency.uppercased() {
        case "CAD":
                return "currency_cad"

        case "USD":
                return "currency_usd"

        case "EUR":
                return "currency_eur"

        case "UAH":
                return "currency_uah"

        case "GBP":
                return "currency_gbp"

        case "AUD":
                return "currency_aud"

        case "NZD":
                return "currency_nzd"

        case "CHF":
                return "currency_chf"

        case "JPY":
                return "currency_jpy"

        case "PLN":
                return "currency_pln"

        default:
            return LocalizedStringKey(currency)
        }
    }

    var body: some View {
        List {

            Section("bank_accounts") {

                if accounts.isEmpty {
                    Text("bank_accounts_none")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(accounts) { account in

                        VStack(
                            alignment: .leading,
                            spacing: 6
                        ) {

                            HStack {
                                Text(
                                    account.name
                                    ?? "bank_account"
                                )
                                .font(.headline)

                                Spacer()

                                if let balance = account.currentBalance {
                                    Text(
                                        balance,
                                        format: .number
                                            .precision(
                                                .fractionLength(0...2)
                                            )
                                    )
                                }
                            }

                            HStack {

                                if let mask = account.mask {
                                    Text("••••\(mask)")
                                }

                                if let currency = account.currency {
                                    Text(localizedCurrency(currency))
                                }

                                Spacer()

                                if let subtype = account.subtype {
                                    Text(localizedSubtype(subtype))
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            
                            Toggle(
                                "account_enabled",
                                isOn: Binding(
                                    get: {
                                        account.isEnabled
                                    },
                                    set: { newValue in
                                        Task {
                                            do {
                                                try await syncService.updateBankAccount(
                                                    id: account.id,
                                                    isEnabled: newValue
                                                )
                                            } catch {
                                                AppLogger.shared.error(
                                                    "Failed to update bank account: \(error.localizedDescription)",
                                                    category: .sync
                                                )
                                            }
                                        }
                                    }
                                )
                            )
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(
            connection.institutionDisplayName
        )
    }
}
