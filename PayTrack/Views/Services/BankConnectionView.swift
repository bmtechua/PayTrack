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

    @State
    private var connectionsLoadTask: Task<Void, Never>?

    @ObservedObject
    private var syncService = SyncService.shared

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
            connectedBanksSection
            addBankSection
        }
        .navigationTitle("bank_connection")
        .task {
            startConnectionsLoading()
        }
        .onChange(of: showPlaid) { _, isPresented in
            handlePlaidPresentationChange(isPresented)
        }
        .sheet(isPresented: $showPlaid) {
            plaidSheet
        }
        .alert(
            "bank_connection_delete_title",
            isPresented: $showDeleteConfirmation
        ) {
            deleteConfirmationButtons
        } message: {
            Text("bank_connection_delete_message")
        }
        .alert(
            "error",
            isPresented: deleteErrorBinding
        ) {
            Button(
                localizedString(
                    "ok",
                    fallback: "OK"
                )
            ) {
                deleteError = nil
            }
        } message: {
            Text(deleteError ?? "")
        }
        .alert(
            "bank_connection",
            isPresented: plaidErrorBinding
        ) {
            Button(
                localizedString(
                    "ok",
                    fallback: "OK"
                )
            ) {
                plaidManager.connectionError = nil
            }
        } message: {
            Text(plaidManager.connectionError ?? "")
        }
    }

    // MARK: - Connected banks section

    private var connectedBanksSection: some View {
        Section("bank_connection_connected") {
            if isLoadingConnections && connections.isEmpty {
                loadingView
            } else if connections.isEmpty {
                emptyConnectionsView
            } else {
                ForEach(connections) { connection in
                    connectionRow(connection)
                }
            }
        }
    }

    // MARK: - Add bank section

    private var addBankSection: some View {
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
                requestPlaidLink()
            } label: {
                Label(
                    "bank_connection_plaid",
                    systemImage: "building.columns"
                )
            }
        }
    }

    // MARK: - Connection row

    private func connectionRow(
        _ connection: BankConnection
    ) -> some View {
        NavigationLink {
            BankAccountsView(
                connection: connection
            )
        } label: {
            VStack(
                alignment: .leading,
                spacing: 6
            ) {
                HStack(spacing: 10) {
                    Image(
                        systemName: "building.columns.fill"
                    )
                    .foregroundStyle(.secondary)

                    Text(
                        connection.institutionDisplayName
                    )
                    .font(.headline)

                    Spacer()
                }

                connectionDetails(
                    for: connection
                )
            }
            .padding(.vertical, 4)
        }
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

    // MARK: - Connection details

    private func connectionDetails(
        for connection: BankConnection
    ) -> some View {
        HStack {
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

            let accountCount = syncService.bankAccounts
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

    // MARK: - Loading / Empty

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    private var emptyConnectionsView: some View {
        Text("bank_connection_none")
            .foregroundStyle(.secondary)
    }

    // MARK: - Plaid sheet

    @ViewBuilder
    private var plaidSheet: some View {
        if let session = plaidManager.linkSession {
            session.sheet()
        }
    }

    // MARK: - Alerts

    @ViewBuilder
    private var deleteConfirmationButtons: some View {
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
                await deleteConnection(
                    connection
                )
            }
        }
    }

    private var deleteErrorBinding: Binding<Bool> {
        Binding(
            get: {
                deleteError != nil
            },
            set: { isPresented in
                if !isPresented {
                    deleteError = nil
                }
            }
        )
    }

    private var plaidErrorBinding: Binding<Bool> {
        Binding(
            get: {
                plaidManager.connectionError != nil
            },
            set: { isPresented in
                if !isPresented {
                    plaidManager.connectionError = nil
                }
            }
        )
    }

    // MARK: - Connection loading

    private func startConnectionsLoading() {
        connectionsLoadTask?.cancel()

        connectionsLoadTask = Task {
            await loadConnections()
        }
    }

    private func handlePlaidPresentationChange(
        _ isPresented: Bool
    ) {
        guard !isPresented else {
            return
        }

        connectionsLoadTask?.cancel()

        connectionsLoadTask = Task {
            // Give backend time to save
            // the new bank connection.
            try? await Task.sleep(
                for: .milliseconds(1000)
            )

            guard !Task.isCancelled else {
                return
            }

            await loadConnections()
        }
    }

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

            guard !Task.isCancelled else {
                return
            }

            let decoder = JSONDecoder()

            decoder.dateDecodingStrategy = .iso8601

            let decoded =
                try decoder.decode(
                    [BankConnection].self,
                    from: response.data
                )

            guard !Task.isCancelled else {
                return
            }

            connections = decoded

            AppLogger.shared.info(
                "Bank connections loaded: \(connections.count)"
            )

        } catch {
            guard !Task.isCancelled else {
                return
            }

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
            let client =
                SupabaseManager.shared.client

            // 1. Delete bank accounts

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

            connectionToDelete = nil

            AppLogger.shared.info(
                "Bank connection deleted: \(connection.institutionDisplayName)"
            )

        } catch {
            AppLogger.shared.error(
                "Failed to delete bank connection: \(error.localizedDescription)"
            )

            deleteError =
                error.localizedDescription
        }
    }

    // MARK: - Plaid Link

    private func requestPlaidLink() {
        AppLogger.shared.info(
            "Bank connection requested: country=\(selectedCountryCode)"
        )

        Task {
            do {
                let user =
                    try await SupabaseManager.shared.client
                        .auth
                        .session
                        .user

                #if targetEnvironment(simulator)
                let baseURL = "http://127.0.0.1:8000"
                #else
                let baseURL = "http://10.0.0.239:8000"
                #endif

                guard let url = URL(
                    string: "\(baseURL)/api/plaid/create-link-token/"
                ) else {
                    AppLogger.shared.error(
                        "Plaid Link token URL is invalid"
                    )
                    return
                }

                var request = URLRequest(
                    url: url
                )

                request.httpMethod = "POST"

                request.setValue(
                    "application/json",
                    forHTTPHeaderField: "Content-Type"
                )

                let body: [String: Any] = [
                    "user_id": user.id.uuidString,
                    "country_code": selectedCountryCode
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

    // MARK: - Localization

    private func localizedString(
        _ key: String,
        fallback: String
    ) -> String {
        let language =
            UserDefaults.standard.string(
                forKey: "language"
            ) ?? "uk"

        guard
            let path = Bundle.main.path(
                forResource: language,
                ofType: "lproj"
            ),
            let bundle = Bundle(path: path)
        else {
            AppLogger.shared.error(
                "Localization bundle not found: \(language).lproj"
            )

            return fallback
        }

        return NSLocalizedString(
            key,
            bundle: bundle,
            comment: ""
        )
    }

    // MARK: - Localized bank status

    private func connectionStatusText(
        _ status: String
    ) -> String {
        let key: String

        switch status.lowercased() {
        case "active":
            key = "bank_connection_status_active"

        case "inactive":
            key = "bank_connection_status_inactive"

        default:
            key = "bank_connection_status_unknown"
        }

        return localizedString(
            key,
            fallback: status
        )
    }

    // MARK: - Localized account count

    private func accountCountText(
        _ count: Int
    ) -> String {
        let language =
            UserDefaults.standard.string(
                forKey: "language"
            ) ?? "uk"

        let key: String

        if language == "uk" {
            let lastTwo = count % 100
            let lastOne = count % 10

            if lastTwo >= 11 && lastTwo <= 14 {
                key = "bank_connection_accounts_many"
            } else {
                switch lastOne {
                case 1:
                    key = "bank_connection_account_one"

                case 2, 3, 4:
                    key = "bank_connection_accounts_few"

                default:
                    key = "bank_connection_accounts_many"
                }
            }

        } else {
            key =
                count == 1
                ? "bank_connection_account_one"
                : "bank_connection_accounts_many"
        }

        let format = localizedString(
            key,
            fallback: "%d accounts"
        )

        return String(
            format: format,
            count
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BankConnectionView()
    }
}
