//
//  PlaidLinkManager.swift
//  PayTrack
//
//  Created by bmtech on 11.09.2026.
//

import Foundation
import Combine
import LinkKit
import Supabase

@MainActor
final class PlaidLinkManager: ObservableObject {

    @Published var linkSession: PlaidLinkSession?
    @Published var connectionID: String?
    @Published var connectionError: String?

    func prepare(
        linkToken: String,
        userID: UUID
    ) {
        connectionError = nil

        let configuration = LinkTokenConfiguration(
            token: linkToken,

            onSuccess: { [weak self] success in
                
                print("✅ Plaid Link success")
                print("Public token received")

                guard let url = URL(
                    string:
                        "http://127.0.0.1:8000/api/plaid/exchange-public-token/"
                ) else {
                    print("❌ Invalid Django URL")
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"

                request.setValue(
                    "application/json",
                    forHTTPHeaderField: "Content-Type"
                )
                

                let accounts = success.metadata.accounts.map { account in
                    [
                        "id": account.id,
                        "name": account.name,
                        "mask": account.mask ?? "",
                        "subtype": String(describing: account.subtype)
                    ]
                }

                let institution: [String: Any] = [
                    "id": success.metadata.institution.id,
                    "name": success.metadata.institution.name
                ]

                let body: [String: Any] = [
                    "public_token": success.publicToken,
                    "user_id": userID.uuidString,
                    "institution": institution,
                    "accounts": accounts
                ]

                do {
                    request.httpBody = try JSONSerialization.data(
                        withJSONObject: body
                    )
                } catch {
                    print("❌ JSON error: \(error)")
                    return
                }

                URLSession.shared.dataTask(
                    with: request
                ) { data, response, error in

                    if let error = error {
                        print(
                            "❌ Django exchange error: \(error)"
                        )
                        return
                    }

                    guard let data = data else {
                        print("❌ No response from Django")
                        return
                    }

                    print("Django response:")

                    print(
                        String(
                            data: data,
                            encoding: .utf8
                        ) ?? ""
                    )

                    do {
                        guard let result =
                            try JSONSerialization.jsonObject(
                                with: data
                            ) as? [String: Any]
                        else {
                            print("❌ Invalid Django response")
                            return
                        }

                        // Duplicate bank account
                        if let duplicate = result["duplicate"] as? Bool,
                           duplicate == true {

                            print("⚠️ Bank account already connected")

                            Task { @MainActor [weak self] in
                                self?.connectionError = NSLocalizedString(
                                    "bank_connection_duplicate",
                                    comment: ""
                                )
                            }

                            return
                        }

                        // New connection successfully created
                        guard
                            let success = result["success"] as? Bool,
                            success == true,
                            let connectionID =
                                result["connection_id"] as? String
                        else {
                            print(
                                "❌ Bank connection was not created"
                            )
                            return
                        }

                        Task { @MainActor [weak self] in
                            self?.connectionID = connectionID

                            print(
                                "✅ Bank connection saved: \(connectionID)"
                            )

                            await SyncService.shared.syncPlaidConnection(
                                connectionID
                            )
                        }

                    } catch {
                        print(
                            "❌ JSON error: \(error)"
                        )
                    }
                }
                .resume()
            },

            onExit: { exit in

                if let error = exit.error {
                    print(
                        "❌ Plaid Link error: \(error)"
                    )
                } else {
                    print(
                        "ℹ️ Plaid Link closed"
                    )
                }
            },

            onEvent: { event in
                print(
                    "Plaid event: \(event.eventName)"
                )
            },

            onLoad: {
                print(
                    "✅ Plaid Link loaded"
                )
            }
        )

        do {

            linkSession =
                try Plaid.createPlaidLinkSession(
                    configuration: configuration
                )

            print(
                "✅ Plaid Link session created"
            )

        } catch {

            print(
                "❌ Plaid Link initialization error: \(error)"
            )
        }
    }
}
