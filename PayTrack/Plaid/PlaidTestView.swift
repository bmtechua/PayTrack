//
//  PlaidTestView.swift
//  PayTrack
//
//  Created by bmtech on 11.09.2026.
//

import SwiftUI
import LinkKit

struct PlaidTestView: View {

    @StateObject private var plaidManager = PlaidLinkManager()
    @State private var showPlaid = false

    var body: some View {

        VStack(spacing: 20) {

            Button("Підключити банк") {
                getLinkToken()
            }
        }
        .sheet(isPresented: $showPlaid) {

            if let session = plaidManager.linkSession {
                session.sheet()
            }
        }
    }

    private func getLinkToken() {

        guard let url = URL(
            string: "http://127.0.0.1:8000/api/plaid/create-link-token/"
        ) else {
            return
        }

        var request = URLRequest(url: url)

        request.httpMethod = "POST"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        let body = [
            "user_id": "23b9160e-be48-4ff8-894b-3521e1172cc8"
        ]

        request.httpBody = try? JSONSerialization.data(
            withJSONObject: body
        )

        URLSession.shared.dataTask(
            with: request
        ) { data, response, error in

            if let error = error {
                print("❌ Django error: \(error)")
                return
            }

            guard let data = data else {
                print("❌ No data")
                return
            }

            do {

                let result = try JSONSerialization.jsonObject(
                    with: data
                ) as? [String: Any]

                guard let linkToken = result?["link_token"] as? String else {
                    print("❌ link_token not found")
                    print(String(data: data, encoding: .utf8) ?? "")
                    return
                }

                print("✅ Link token received")

                DispatchQueue.main.async {

                    plaidManager.prepare(
                        linkToken: linkToken
                    )

                    showPlaid = true
                }

            } catch {

                print("❌ JSON error: \(error)")
            }
        }
        .resume()
    }
}
