//
//  ReportProblemView.swift
//  PayTrack
//

import SwiftUI
import UIKit
import Auth

struct ReportProblemView: View {

    @State private var problemDescription = ""
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "—"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            ?? "—"
    }

    private var systemVersion: String {
        UIDevice.current.systemName + " " + UIDevice.current.systemVersion
    }

    private var deviceModel: String {
        UIDevice.current.model
    }

    private var log: String {
        AppLogger.shared.readLog()
    }

    private var reportText: String {

        let email =
            AuthService.shared.user?.email ?? String(localized: "not_authenticated")

        let userID =
            AuthService.shared.user?.id.uuidString ?? String(localized: "not_authenticated")

        return """
        \(String(localized: "diagnostic_report_title"))

        \(String(localized: "problem")):

        \(problemDescription)

        --- \(String(localized: "technical_information")) ---

        \(String(localized: "app")): PayTrack
        \(String(localized: "version")): \(appVersion)
        \(String(localized: "build")): \(appBuild)
        \(String(localized: "device")): \(deviceModel)
        \(String(localized: "system")): \(systemVersion)
        \(String(localized: "date")): \(Date())

        \(String(localized: "user")):
        \(String(localized: "email")): \(email)
        \(String(localized: "id")): \(userID)

        --- \(String(localized: "log")) ---

        \(log)
        """
    }

    var body: some View {

        Form {

            Section {

                TextEditor(text: $problemDescription)
                    .frame(minHeight: 180)

            } header: {

                Text("problem_description")

            } footer: {

                Text("problem_description_hint")
            }

            Section {

                Button {

                    sendReport()

                } label: {

                    HStack {

                        Spacer()

                        if isSending {

                            ProgressView()

                        } else {

                            Text("send_report")
                        }

                        Spacer()
                    }
                }
                .disabled(
                    isSending ||
                    problemDescription
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .isEmpty
                )
            }
        }
        .navigationTitle("report_problem")
        .navigationBarTitleDisplayMode(.inline)
        .alert("report_sent", isPresented: $showSuccess) {

            Button("OK", role: .cancel) { }

        }
        .alert(
            "report_error",
            isPresented: Binding(
                get: {
                    errorMessage != nil
                },
                set: {
                    if !$0 {
                        errorMessage = nil
                    }
                }
            )
        ) {

            Button("OK", role: .cancel) { }

        } message: {

            Text(errorMessage ?? "")
        }
    }

    // MARK: - Send report

    private func sendReport() {

        let description =
            problemDescription.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let currentLog = log

        isSending = true

        AppLogger.shared.info(
            "Diagnostic report sending started",
            category: .app
        )

        Task {

            do {

                try await SyncService.shared.sendDiagnosticReport(
                    problemDescription: description,
                    appVersion: appVersion,
                    appBuild: appBuild,
                    deviceModel: deviceModel,
                    systemVersion: systemVersion,
                    log: currentLog
                )

                AppLogger.shared.info(
                    "Diagnostic report sending completed",
                    category: .app
                )

                await MainActor.run {

                    isSending = false
                    showSuccess = true
                    problemDescription = ""
                }

            } catch {

                AppLogger.shared.error(
                    "Diagnostic report sending failed: \(error.localizedDescription)",
                    category: .app
                )

                await MainActor.run {

                    isSending = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
