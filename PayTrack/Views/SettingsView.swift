//
//  SettingsView.swift
//  PayTrack
//
//  Created by bmtech on 30.06.2026.
//
import SwiftUI

struct SettingsView: View {

    @AppStorage("monthlyBudget")
    private var monthlyBudget: Double = 5000

    @AppStorage("currency")
    private var currency: String = "UAH"

    @AppStorage("language")
    private var language = "uk"

    @AppStorage("theme")
    private var theme: String = "system"

    @State
    private var budgetBeforeEditing: Double = 0


    var body: some View {

        NavigationStack {

            Form {

                // MARK: - Account
                Section("account") {
                    NavigationLink {
                        AccountView()
                    } label: {
                        Text("account")
                    }
                }
                
                // MARK: - Budget

                Section("budget") {

                    BudgetTextField(
                        value: $monthlyBudget,
                        onEditingBegan: {
                            budgetBeforeEditing = monthlyBudget
                        },
                        onDone: {

                            if budgetBeforeEditing != monthlyBudget {

                                AppLogger.shared.info(
                                    "Budget changed: \(budgetBeforeEditing) → \(monthlyBudget)"
                                )
                            }
                        }
                    )
                    .frame(height: 36)
                }


                // MARK: - Currency

                Section("currency") {

                    Picker(
                        "currency",
                        selection: $currency
                    ) {

                        Text("currency_uah")
                            .tag("UAH")

                        Text("currency_eur")
                            .tag("EUR")

                        Text("currency_usd")
                            .tag("USD")
                    }
                }


                // MARK: - Language

                Section("language") {

                    Picker(
                        "language",
                        selection: $language
                    ) {

                        Text("Українська")
                            .tag("uk")

                        Text("English")
                            .tag("en")

                        Text("Français")
                            .tag("fr")
                    }
                }


                // MARK: - Theme

                Section("theme") {

                    Picker(
                        "theme",
                        selection: $theme
                    ) {

                        Text("theme_system")
                            .tag("system")

                        Text("theme_light")
                            .tag("light")

                        Text("theme_dark")
                            .tag("dark")
                    }
                }


                // MARK: - Log

                Section("app_log") {

                    NavigationLink {

                        LogView()

                    } label: {

                        Text("app_log")
                    }
                }
            }

            .navigationTitle("settings_title")
        }
    }
}
