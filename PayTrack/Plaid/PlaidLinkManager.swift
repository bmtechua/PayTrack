//
//  PlaidLinkManager.swift
//  PayTrack
//
//  Created by bmtech on 11.09.2026.
//

import Foundation
import Combine
import LinkKit

@MainActor
final class PlaidLinkManager: ObservableObject {

    @Published var linkSession: PlaidLinkSession?

    func prepare(linkToken: String) {

        let configuration = LinkTokenConfiguration(
            token: linkToken,

            onSuccess: { success in
                print("✅ Plaid Link success")
                print("Public token received")

                guard let url = URL(
                    string: "http://127.0.0.1:8000/api/plaid/exchange-public-token/"
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

                let body: [String: Any] = [
                    "public_token": success.publicToken,
                    "user_id": "23b9160e-be48-4ff8-894b-3521e1172cc8"
                ]

                do {
                    request.httpBody = try JSONSerialization.data(
                        withJSONObject: body
                    )
                } catch {
                    print("❌ JSON error: \(error)")
                    return
                }

                URLSession.shared.dataTask(with: request) { data, response, error in

                    if let error = error {
                        print("❌ Django exchange error: \(error)")
                        return
                    }

                    guard let data = data else {
                        print("❌ No response from Django")
                        return
                    }

                    print("Django response:")
                    print(String(data: data, encoding: .utf8) ?? "")
                }
                .resume()
            },

            onExit: { exit in
                if let error = exit.error {
                    print("❌ Plaid Link error: \(error)")
                } else {
                    print("ℹ️ Plaid Link closed")
                }
            },

            onEvent: { event in
                print("Plaid event: \(event.eventName)")
            },

            onLoad: {
                print("✅ Plaid Link loaded")
            }
        )

        do {
            linkSession = try Plaid.createPlaidLinkSession(
                configuration: configuration
            )

            print("✅ Plaid Link session created")

        } catch {
            print("❌ Plaid Link initialization error: \(error)")
        }
    }
}
