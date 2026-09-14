//
//  SettingsView.swift
//  PayTrack
//
//  Created by bmtech on 30.06.2026.
//

import SwiftUI
import Auth

struct SettingsView: View {

@ObservedObject
private var authService = AuthService.shared

private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        ?? "—"
}

private var appBuild: String {
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        ?? "—"
}

@AppStorage("monthlyBudget")
private var monthlyBudget: Double = 5000

@AppStorage("currency")
private var currency: String = "UAH"

@AppStorage("language")
private var language = "uk"

@AppStorage("theme")
private var theme: String = "system"

#if DEBUG
@AppStorage("engineeringEnabled")
private var engineeringEnabled = false
#endif

@State
private var budgetBeforeEditing: Double = 0

@State
private var versionTapCount = 0

@State
private var showEngineering = false

var body: some View {

    NavigationStack {

        Form {

            // MARK: - Account

            Section("account") {

                NavigationLink {

                    AccountView()

                } label: {

                    VStack(alignment: .leading, spacing: 4) {

                        Text("account")

                        if let email = authService.user?.email {

                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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

                            Task {
                                await SyncService.shared.syncProfileSettings()
                            }
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

                    Text("currency_cad")
                        .tag("CAD")

                    Text("currency_aud")
                        .tag("AUD")
                }
                .onChange(of: currency) {

                    Task {
                        await SyncService.shared.syncProfileSettings()
                    }
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
                .onChange(of: language) {

                    Task {
                        await SyncService.shared.syncProfileSettings()
                    }
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

            // MARK: - About

            Section("about") {

                HStack {

                    Text("app_name")

                    Spacer()

                    Text("PayTrack")
                        .foregroundStyle(.secondary)
                }

                HStack {

                    Text("version")

                    Spacer()

                    Text("\(appVersion) (\(appBuild))")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {

                    #if DEBUG

                    // Developer shortcut.
                    // When enabled, the hidden 10-tap gesture is bypassed.
                    if engineeringEnabled {
                        showEngineering = true
                        return
                    }

                    #endif

                    versionTapCount += 1

                    if versionTapCount >= 10 {
                        versionTapCount = 0
                        showEngineering = true
                    }
                }
            }

            #if DEBUG
            // MARK: - Engineering mode

            Section("engineering") {

                Toggle(
                    "engineering_enabled",
                    isOn: $engineeringEnabled
                )
            }
            #endif

            // MARK: - Report Problem

            Section {

                NavigationLink {

                    ReportProblemView()

                } label: {

                    Text("report_problem")
                }
            }
        }

        .navigationTitle("settings_title")

        .navigationDestination(isPresented: $showEngineering) {

            EngineeringView()
        }
    }
}

}

#Preview {
SettingsView()
}
