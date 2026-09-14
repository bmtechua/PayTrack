//
//  BankConnectionView.swift
//  PayTrack
//
//  Created by bmtech on 14.09.2026.
//

import SwiftUI
import LinkKit
import Supabase

struct BankConnectionView: View {

// MARK: - Bank connection model

private struct BankConnection: Decodable, Identifiable {

    let id: UUID
    let institutionName: String?
    let status: String
    let createdAt: Date

    var institutionDisplayName: String {
        institutionName ?? "Unknown"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case institutionName = "institution_name"
        case status
        case createdAt = "created_at"
    }
}

// MARK: - State

@StateObject
private var plaidManager = PlaidLinkManager()

@State
private var showPlaid = false

@State
private var connections: [BankConnection] = []

@State
private var isLoadingConnections = false

// MARK: - Body

var body: some View {

    List {

        // MARK: - Connected banks

        Section("bank_connection_connected") {

            if isLoadingConnections && connections.isEmpty {

                HStack {

                    Spacer()

                    ProgressView()

                    Spacer()
                }

            } else if connections.isEmpty {

                Text("bank_connection_none")
                    .foregroundStyle(.secondary)

            } else {

                ForEach(connections) { connection in

                    VStack(
                        alignment: .leading,
                        spacing: 6
                    ) {

                        Text(
                            connection.institutionDisplayName
                        )
                        .font(.headline)

                        HStack {

                            Text(
                                connection.status.capitalized
                            )
                            .font(.caption)
                            .foregroundStyle(
                                connection.status.lowercased()
                                    == "active"
                                ? .green
                                : .secondary
                            )

                            Spacer()

                            Text(
                                connection.createdAt,
                                format: .dateTime
                                    .year()
                                    .month(.twoDigits)
                                    .day(.twoDigits)
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }

        // MARK: - Add bank

        Section {

            Button {

                AppLogger.shared.info(
                    "Bank connection requested"
                )

                getLinkToken()

            } label: {

                Label(
                    "bank_connection_plaid",
                    systemImage: "building.columns"
                )
            }
        }
    }

    .navigationTitle("bank_connection")

    // MARK: - Load connections

    .task {

        await loadConnections()
    }

    // MARK: - Reload after Plaid

    .onChange(of: showPlaid) { _, isPresented in

        if !isPresented {

            Task {
                await loadConnections()
            }
        }
    }

    // MARK: - Plaid Link

    .sheet(isPresented: $showPlaid) {

        if let session = plaidManager.linkSession {

            session.sheet()
        }
    }
    
    .alert(
        "bank_connection",
        isPresented: Binding(
            get: {
                plaidManager.connectionError != nil
            },
            set: { isPresented in
                if !isPresented {
                    plaidManager.connectionError = nil
                }
            }
        )
    ) {
        Button("OK") {
            plaidManager.connectionError = nil
        }
    } message: {
        Text(
            plaidManager.connectionError
            ?? ""
        )
    }
}

// MARK: - Load connections

private func loadConnections() async {

    isLoadingConnections = true
    defer {
        isLoadingConnections = false
    }

    do {

        let user =
            try await SupabaseManager.shared.client
                .auth
                .session
                .user

        let response =
            try await SupabaseManager.shared.client
                .from("bank_connections")
                .select(
                    "id, institution_name, status, created_at"
                )
                .eq(
                    "user_id",
                    value: user.id.uuidString
                )
                .eq(
                    "status",
                    value: "active"
                )
                .order(
                    "created_at",
                    ascending: false
                )
                .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        connections =
            try decoder.decode(
                [BankConnection].self,
                from: response.data
            )

        AppLogger.shared.info(
            "Bank connections loaded: \(connections.count)"
        )

    } catch {

        AppLogger.shared.error(
            "Failed to load bank connections: \(error.localizedDescription)"
        )
    }
}

// MARK: - Get Plaid Link token

private func getLinkToken() {

    AppLogger.shared.info(
        "Requesting Plaid Link token"
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
                    "Plaid Link token URL is invalid"
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
                    "Invalid Django response"
                )

                return
            }

            guard (200...299).contains(
                httpResponse.statusCode
            ) else {

                AppLogger.shared.error(
                    "Django HTTP error: \(httpResponse.statusCode)"
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
                    "link_token not found in Django response"
                )

                return
            }

            AppLogger.shared.info(
                "Plaid Link token received"
            )

            plaidManager.prepare(
                linkToken: linkToken,
                userID: user.id
            )

            showPlaid = true

        } catch {

            AppLogger.shared.error(
                "Django error: \(error)"
            )
        }
    }
}

}

#Preview {
NavigationStack {
BankConnectionView()
}
}
