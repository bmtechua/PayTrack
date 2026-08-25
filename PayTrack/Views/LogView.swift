//
//  LogView.swift
//  PayTrack
//
//  Created by bmtech on 25.08.2026.
//

import SwiftUI

struct LogView: View {

    @Environment(\.dismiss)
    private var dismiss

    @State private var logText = ""
    @State private var showMailComposer = false

    var body: some View {

        NavigationStack {

            ScrollView {

                Text(
                    logText.isEmpty
                    ? "Лог порожній"
                    : logText
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .font(.system(
                    size: 12,
                    design: .monospaced
                ))
                .textSelection(.enabled)
                .padding()
            }
            .navigationTitle("Лог програми")
            .toolbar {

                ToolbarItemGroup(
                    placement: .topBarTrailing
                ) {

                    ShareLink(
                        item: AppLogger.shared.fileURL,
                        subject: Text("PayTrack Log")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(logText.isEmpty)

                    Button {
                        showMailComposer = true
                    } label: {
                        Image(systemName: "envelope")
                    }
                    .disabled(logText.isEmpty)
                }
            }
            .onAppear {
                loadLog()
            }
            .sheet(isPresented: $showMailComposer) {

                MailComposerView(
                    recipient: "YOUR_EMAIL@example.com",
                    subject: "PayTrack — звіт про проблему",
                    body: """
                    Вітаю.

                    Опис проблеми:

                    

                    Дякую.
                    """,
                    attachmentURL: AppLogger.shared.fileURL
                )
            }
        }
    }

    private func loadLog() {

        let url = AppLogger.shared.fileURL

        guard
            let data = try? Data(contentsOf: url),
            let text = String(
                data: data,
                encoding: .utf8
            )
        else {
            return
        }

        logText = text
    }
}

#Preview {
    LogView()
}
