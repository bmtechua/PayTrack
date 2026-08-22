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
    private var theme: String = "Система"


    var body: some View {

        NavigationStack {

            Form {

                // MARK: - Budget
                Section("budget") {

                    TextField(
                        "budget_limit",
                        value: $monthlyBudget,
                        format: .number
                    )
                    .keyboardType(.decimalPad)
                }

                // MARK: - Currency
                Section("currency") {

                    Picker("currency", selection: $currency) {

                        Text("₴ Гривня").tag("UAH")
                        Text("€ Євро").tag("EUR")
                        Text("$ Долар").tag("USD")
                    }
                }

                // MARK: - Language
                Section("language") {

                    Picker("language", selection: $language) {

                        Text("Українська").tag("uk")
                        Text("English").tag("en")
                        Text("Français").tag("fr")
                    }
                }

                // MARK: - Theme
                Section("theme") {

                    Picker("theme", selection: $theme) {
                        Text("theme_system").tag("system")
                        Text("theme_light").tag("light")
                        Text("theme_dark").tag("dark")
                    }
                }
            }
            .navigationTitle("settings_title")
        }
    }
}
