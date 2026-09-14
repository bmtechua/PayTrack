//
//  PlaidTestView.swift
//  PayTrack
//
//  Created by bmtech on 11.09.2026.
//

import SwiftUI
import LinkKit
import Supabase

struct PlaidTestView: View {

    @StateObject private var plaidManager =
        PlaidLinkManager()

    @State private var showPlaid = false

    var body: some View {

        VStack(spacing: 20) {

            Button("Підключити банк") {
                getLinkToken()
            }
            
            Button("Очистити дублікати Plaid") {

                Task {

                    await SyncService.shared
                        .removeDuplicatePlaidExpensesFromSupabase()
                }
            }

            Button("Завантажити витрати") {

                guard let connectionID =
                        plaidManager.connectionID
                else {
                    print(
                        "❌ Bank connection not available"
                    )
                    return
                }

                Task {

                    do {

                        let expenses =
                            try await PlaidExpenseService.shared
                                .fetchExpenses(
                                    connectionID: connectionID
                                )

                        print(
                            "✅ Отримано витрат: \(expenses.count)"
                        )

                        for expense in expenses {

                            print(
                                "💰 \(expense.title ?? "") | " +
                                "\(expense.amount) | " +
                                "\(expense.category)"
                            )
                        }

                        await SyncService.shared
                            .importPlaidExpenses(expenses)

                    } catch {

                        print(
                            "❌ Помилка отримання витрат: \(error)"
                        )
                    }
                }
            }
            
            Button("Видалити локальні Plaid-витрати") {
                    SyncService.shared.deleteLocalPlaidExpenses()
                }
        }

        .sheet(isPresented: $showPlaid) {

            if let session =
                plaidManager.linkSession {

                session.sheet()
            }
        }
    }

    private func getLinkToken() {

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
                    return
                }

                var request =
                    URLRequest(url: url)

                request.httpMethod = "POST"

                request.setValue(
                    "application/json",
                    forHTTPHeaderField:
                        "Content-Type"
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
                    print(
                        "❌ Invalid Django response"
                    )
                    return
                }

                guard
                    (200...299).contains(
                        httpResponse.statusCode
                    )
                else {
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

                guard
                    let linkToken =
                        result?["link_token"] as? String
                else {

                    print(
                        "❌ link_token not found"
                    )

                    print(
                        String(
                            data: data,
                            encoding: .utf8
                        ) ?? ""
                    )

                    return
                }

                print(
                    "✅ Link token received"
                )

                plaidManager.prepare(
                    linkToken: linkToken,
                    userID: user.id
                )

                showPlaid = true

            } catch {

                print(
                    "❌ Django error: \(error)"
                )
            }
        }
    }
}
