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

    struct BankConnection: Decodable, Identifiable {

        let id: UUID
        let institutionName: String?
        let status: String
        let createdAt: Date

        var institutionDisplayName: String {
            institutionName ?? NSLocalizedString(
                "unknown",
                comment: ""
            )
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

    @State
    private var connectionToDelete: BankConnection?

    @State
    private var showDeleteConfirmation = false

    @State
    private var deleteError: String?

    @State
    private var selectedCountryCode = "CA"

    // MARK: - Plaid countries

    private let plaidCountries: [
        (code: String, nameKey: LocalizedStringKey)
    ] = [
        ("CA", "country_canada"),
        ("US", "country_united_states"),
        ("GB", "country_united_kingdom"),
        ("FR", "country_france"),
        ("DE", "country_germany"),
        ("ES", "country_spain"),
        ("PT", "country_portugal"),
        ("IT", "country_italy"),
        ("NL", "country_netherlands"),
        ("BE", "country_belgium"),
        ("AT", "country_austria"),
        ("IE", "country_ireland"),
        ("PL", "country_poland"),
        ("DK", "country_denmark"),
        ("NO", "country_norway"),
        ("SE", "country_sweden"),
        ("FI", "country_finland"),
        ("EE", "country_estonia"),
        ("LT", "country_lithuania"),
        ("LV", "country_latvia")
    ]

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

                        NavigationLink {

                            BankAccountsView(
                                connection: connection
                            )

                        } label: {

                            VStack(
                                alignment: .leading,
                                spacing: 6
                            ) {

                                // Bank name
                                Text(
                                    connection.institutionDisplayName
                                )
                                .font(.headline)

                                HStack {

                                    // Localized status
                                    Text(
                                        connectionStatusText(
                                            connection.status
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundStyle(
                                        connection.status
                                            .lowercased() == "active"
                                        ? .green
                                        : .secondary
                                    )

                                    Spacer()

                                    // Account count
                                    let accountCount =
                                        SyncService.shared.bankAccounts
                                            .filter {
                                                $0.connectionID == connection.id
                                            }
                                            .count

                                    if accountCount > 0 {

                                        Text(
                                            accountCountText(
                                                accountCount
                                            )
                                        )
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }

                                    // Connection date
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

                        // MARK: - Delete bank

                        .swipeActions(
                            edge: .trailing,
                            allowsFullSwipe: false
                        ) {

                            Button(role: .destructive) {

                                connectionToDelete = connection
                                showDeleteConfirmation = true

                            } label: {

                                Label(
                                    "delete",
                                    systemImage: "trash"
                                )
                            }
                        }
                    }
                }
            }

            // MARK: - Add bank

            Section("bank_connection_country") {

                Picker(
                    "bank_connection_country",
                    selection: $selectedCountryCode
                ) {

                    ForEach(
                        plaidCountries,
                        id: \.code
                    ) { country in

                        Text(country.nameKey)
                            .tag(country.code)
                    }
                }

                Button {

                    AppLogger.shared.info(
                        "Bank connection requested: country=\(selectedCountryCode)"
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

        // MARK: - Delete confirmation

        .alert(
            "bank_connection_delete_title",
            isPresented: $showDeleteConfirmation
        ) {

            Button(
                "cancel",
                role: .cancel
            ) {

                connectionToDelete = nil
            }

            Button(
                "delete",
                role: .destructive
            ) {

                guard let connection = connectionToDelete else {
                    return
                }

                Task {
                    await deleteConnection(connection)
                }
            }

        } message: {

            Text(
                "bank_connection_delete_message"
            )
        }

        // MARK: - Delete error

        .alert(
            "error",
            isPresented: Binding(
                get: {
                    deleteError != nil
                },
                set: { isPresented in

                    if !isPresented {
                        deleteError = nil
                    }
                }
            )
        ) {

            Button(
                NSLocalizedString(
                    "ok",
                    comment: ""
                )
            ) {

                deleteError = nil
            }

        } message: {

            Text(
                deleteError ?? ""
            )
        }

        // MARK: - Plaid error

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

            Button(
                NSLocalizedString(
                    "ok",
                    comment: ""
                )
            ) {

                plaidManager.connectionError = nil
            }

        } message: {

            Text(
                plaidManager.connectionError ?? ""
            )
        }
    }

    // MARK: - Localized bank status

    private func connectionStatusText(
        _ status: String
    ) -> String {

        switch status.lowercased() {

        case "active":

            return NSLocalizedString(
                "bank_connection_status_active",
                comment: ""
            )

        case "inactive":

            return NSLocalizedString(
                "bank_connection_status_inactive",
                comment: ""
            )

        default:

            return NSLocalizedString(
                "bank_connection_status_unknown",
                comment: ""
            )
        }
    }

    // MARK: - Localized account count

    private func accountCountText(
        _ count: Int
    ) -> String {

        let key: String

        if count == 1 {

            key = "bank_connection_account_one"

        } else {

            key = "bank_connection_accounts_many"
        }

        return String(
            format: NSLocalizedString(
                key,
                comment: ""
            ),
            count
        )
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

    // MARK: - Delete connection

    private func deleteConnection(
        _ connection: BankConnection
    ) async {

        do {

            let client = SupabaseManager.shared.client

            // 1. Delete bank accounts
            //    belonging to this connection

            try await client
                .from("bank_accounts")
                .delete()
                .eq(
                    "connection_id",
                    value: connection.id.uuidString
                )
                .execute()

            // 2. Delete bank connection

            try await client
                .from("bank_connections")
                .delete()
                .eq(
                    "id",
                    value: connection.id.uuidString
                )
                .execute()

            // 3. Remove from current UI

            connections.removeAll {
                $0.id == connection.id
            }

            AppLogger.shared.info(
                "Bank connection deleted: \(connection.institutionDisplayName)"
            )

            connectionToDelete = nil

        } catch {

            AppLogger.shared.error(
                "Failed to delete bank connection: \(error.localizedDescription)"
            )

            deleteError = error.localizedDescription
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

                    "user_id":
                        user.id.uuidString,

                    "country_code":
                        selectedCountryCode
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

// MARK: - Preview

#Preview {

    NavigationStack {

        BankConnectionView()
    }
}
