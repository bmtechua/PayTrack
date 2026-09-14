//
//  EngineeringView.swift
//  PayTrack
//
//  Created by bmtech on 12.09.2026.
//

import SwiftUI
import LinkKit
import Supabase

struct EngineeringView: View {

@State private var showLogs = false

@StateObject private var plaidManager =
    PlaidLinkManager()

@State private var showPlaid = false
@State private var showFullSyncAlert = false
@State private var showSyncPlaidAlert = false

@State private var showRemoveDuplicatesAlert = false
@State private var showDeleteLocalAlert = false
@State private var showDeleteRemoteAlert = false
@State private var showStatisticsAlert = false
@State private var statisticsText = ""
@State private var showConnectionsAlert = false
@State private var connectionsText = ""
@State private var showRealtimeAlert = false
@State private var realtimeText = ""
@State private var showResetSyncAlert = false

var body: some View {

    NavigationStack {

        List {

            // MARK: - Full Sync

            Button {

                AppLogger.shared.info(
                    "Full Sync requested",
                    category: .engineering
                )

                showFullSyncAlert = true

            } label: {

                Label(
                    "engineering_full_sync",
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }

            // MARK: - Sync Plaid

            Button {

                AppLogger.shared.info(
                    "Sync Plaid requested",
                    category: .engineering
                )

                showSyncPlaidAlert = true

            } label: {

                Label(
                    "engineering_sync_plaid",
                    systemImage: "building.columns"
                )
            }

            // MARK: - Remove duplicate Plaid expenses

            Button {

                AppLogger.shared.info(
                    "Remove duplicate Plaid expenses requested",
                    category: .engineering
                )

                showRemoveDuplicatesAlert = true

            } label: {

                Label(
                    "engineering_remove_duplicates",
                    systemImage: "doc.on.doc"
                )
            }

            // MARK: - Delete local Plaid expenses

            Button {

                AppLogger.shared.info(
                    "Delete local Plaid expenses requested",
                    category: .engineering
                )

                showDeleteLocalAlert = true

            } label: {

                Label(
                    "engineering_delete_local",
                    systemImage: "trash"
                )
            }

            // MARK: - Delete remote Plaid expenses

            Button(role: .destructive) {

                AppLogger.shared.info(
                    "Delete remote Plaid expenses requested",
                    category: .engineering
                )

                showDeleteRemoteAlert = true

            } label: {

                Label(
                    "engineering_delete_remote",
                    systemImage: "trash.fill"
                )
            }

            // MARK: - Sync statistics

            Button {

                AppLogger.shared.info(
                    "Sync statistics requested",
                    category: .engineering
                )

                Task {

                    statisticsText =
                        await SyncService.shared.syncStatisticsText()

                    showStatisticsAlert = true
                }

            } label: {

                Label(
                    "engineering_sync_statistics",
                    systemImage: "chart.bar"
                )
            }

            // MARK: - Plaid connections

            Button {

                AppLogger.shared.info(
                    "Plaid connections requested",
                    category: .engineering
                )

                print("🔗 Plaid connections button tapped")

                Task {

                    let text =
                        await SyncService.shared.plaidConnectionsText()

                    print("🔗 Plaid connections result:")
                    print(text)

                    connectionsText = text
                    showConnectionsAlert = true
                }

            } label: {

                Label(
                    "engineering_plaid_connections",
                    systemImage: "link.circle"
                )
            }

            // MARK: - Realtime test

            Button {

                AppLogger.shared.info(
                    "Realtime test requested",
                    category: .engineering
                )

                Task {

                    realtimeText =
                        await SyncService.shared.testRealtime()

                    showRealtimeAlert = true
                }

            } label: {

                Label(
                    "engineering_realtime_test",
                    systemImage: "antenna.radiowaves.left.and.right"
                )
            }

            // MARK: - Logs

            Button {

                AppLogger.shared.info(
                    "Logs opened",
                    category: .engineering
                )

                showLogs = true

            } label: {

                Label(
                    "engineering_logs",
                    systemImage: "doc.text"
                )
            }

            // MARK: - Reset sync state

            Button {

                AppLogger.shared.info(
                    "Reset sync state requested",
                    category: .engineering
                )

                showResetSyncAlert = true

            } label: {

                Label(
                    "engineering_reset_sync",
                    systemImage: "arrow.counterclockwise"
                )
            }
        }

        .navigationTitle("engineering")

        .navigationDestination(isPresented: $showLogs) {
            LogView()
        }
    }

    // MARK: - Plaid Link

    .sheet(isPresented: $showPlaid) {

        if let session = plaidManager.linkSession {
            session.sheet()
        }
    }

    // MARK: - Full Sync alert

    .alert(
        "engineering_run_full_sync",
        isPresented: $showFullSyncAlert
    ) {

        Button("cancel", role: .cancel) {

            AppLogger.shared.info(
                "Full Sync cancelled",
                category: .engineering
            )
        }

        Button("run") {

            AppLogger.shared.info(
                "Full Sync confirmed",
                category: .engineering
            )

            Task {
                await SyncService.shared.syncAll()
            }
        }

    } message: {

        Text("engineering_full_sync_message")
    }

    // MARK: - Sync Plaid alert

    .alert(
        "engineering_sync_plaid_question",
        isPresented: $showSyncPlaidAlert
    ) {

        Button("cancel", role: .cancel) {

            AppLogger.shared.info(
                "Sync Plaid cancelled",
                category: .engineering
            )
        }

        Button("sync") {

            AppLogger.shared.info(
                "Sync Plaid confirmed",
                category: .engineering
            )

            Task {
                await SyncService.shared.syncPlaid()
            }
        }

    } message: {

        Text("engineering_sync_plaid_message")
    }

    // MARK: - Remove duplicates alert

    .alert(
        "engineering_remove_duplicates_question",
        isPresented: $showRemoveDuplicatesAlert
    ) {

        Button("cancel", role: .cancel) {

            AppLogger.shared.info(
                "Remove duplicate Plaid expenses cancelled",
                category: .engineering
            )
        }

        Button("remove", role: .destructive) {

            AppLogger.shared.info(
                "Remove duplicate Plaid expenses confirmed",
                category: .engineering
            )

            Task {

                await SyncService.shared
                    .removeDuplicatePlaidExpensesFromSupabase()
            }
        }

    } message: {

        Text("engineering_remove_duplicates_message")
    }

    // MARK: - Delete local alert

    .alert(
        "engineering_delete_local_question",
        isPresented: $showDeleteLocalAlert
    ) {

        Button("cancel", role: .cancel) {

            AppLogger.shared.info(
                "Delete local Plaid expenses cancelled",
                category: .engineering
            )
        }

        Button("delete", role: .destructive) {

            AppLogger.shared.info(
                "Delete local Plaid expenses confirmed",
                category: .engineering
            )

            SyncService.shared.deleteLocalPlaidExpenses()
        }

    } message: {

        Text("engineering_delete_local_message")
    }

    // MARK: - Delete remote Plaid alert

    .alert(
        "engineering_delete_remote_question",
        isPresented: $showDeleteRemoteAlert
    ) {

        Button("cancel", role: .cancel) {

            AppLogger.shared.info(
                "Delete remote Plaid expenses cancelled",
                category: .engineering
            )
        }

        Button("delete", role: .destructive) {

            AppLogger.shared.info(
                "Delete remote Plaid expenses confirmed",
                category: .engineering
            )

            Task {

                await SyncService.shared
                    .deleteRemotePlaidExpenses()
            }
        }

    } message: {

        Text("engineering_delete_remote_message")
    }

    // MARK: - Sync statistics alert

    .alert(
        "engineering_sync_statistics",
        isPresented: $showStatisticsAlert
    ) {

        Button("ok", role: .cancel) {}

    } message: {

        Text(statisticsText)
    }

    // MARK: - Plaid connections alert

    .alert(
        "engineering_plaid_connections",
        isPresented: $showConnectionsAlert
    ) {

        Button("ok", role: .cancel) {}

    } message: {

        Text(connectionsText)
    }

    // MARK: - Realtime alert

    .alert(
        "engineering_realtime_test",
        isPresented: $showRealtimeAlert
    ) {

        Button("ok", role: .cancel) {}

    } message: {

        Text(realtimeText)
    }

    // MARK: - Reset sync alert

    .alert(
        "engineering_reset_sync_question",
        isPresented: $showResetSyncAlert
    ) {

        Button("cancel", role: .cancel) {

            AppLogger.shared.info(
                "Reset sync state cancelled",
                category: .engineering
            )
        }

        Button("reset", role: .destructive) {

            AppLogger.shared.info(
                "Reset sync state confirmed",
                category: .engineering
            )

            SyncService.shared.cancelFullSync()
        }

    } message: {

        Text("engineering_reset_sync_message")
    }
}

// MARK: - Get Plaid Link token

private func getLinkToken() {

    AppLogger.shared.info(
        "Requesting Plaid Link token",
        category: .engineering
    )

    Task {

        do {

            let user =
                try await SupabaseManager.shared.client
                    .auth
                    .session
                    .user

            guard let url = URL(
                string:
                    "http://127.0.0.1:8000/api/plaid/create-link-token/"
            ) else {

                AppLogger.shared.error(
                    "Plaid Link token URL is invalid",
                    category: .engineering
                )

                return
            }

            var request =
                URLRequest(url: url)

            request.httpMethod = "POST"

            request.setValue(
                "application/json",
                forHTTPHeaderField: "Content-Type"
            )

            let body: [String: Any] = [
                "user_id": user.id.uuidString
            ]

            request.httpBody =
                try JSONSerialization.data(
                    withJSONObject: body
                )

            let (data, response) =
                try await URLSession.shared.data(
                    for: request
                )

            guard let httpResponse =
                    response as? HTTPURLResponse
            else {

                AppLogger.shared.error(
                    "Invalid Django response",
                    category: .engineering
                )

                print(
                    "❌ Invalid Django response"
                )

                return
            }

            guard (200...299).contains(
                httpResponse.statusCode
            ) else {

                AppLogger.shared.error(
                    "Django HTTP error: \(httpResponse.statusCode)",
                    category: .engineering
                )

                print(
                    "❌ Django HTTP error: \(httpResponse.statusCode)"
                )

                print(
                    String(
                        data: data,
                        encoding: .utf8
                    ) ?? ""
                )

                return
            }

            let result =
                try JSONSerialization.jsonObject(
                    with: data
                ) as? [String: Any]

            guard let linkToken =
                    result?["link_token"] as? String
            else {

                AppLogger.shared.error(
                    "link_token not found in Django response",
                    category: .engineering
                )

                print(
                    "❌ link_token not found"
                )

                return
            }

            AppLogger.shared.info(
                "Plaid Link token received",
                category: .engineering
            )

            print(
                "✅ Link token received"
            )

            plaidManager.prepare(
                linkToken: linkToken,
                userID: user.id
            )

            showPlaid = true

        } catch {

            AppLogger.shared.error(
                "Django error: \(error)",
                category: .engineering
            )

            print(
                "❌ Django error: \(error)"
            )
        }
    }
}

}

#Preview {
EngineeringView()
}
