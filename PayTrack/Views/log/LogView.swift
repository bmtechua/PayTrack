//
//  LogView.swift
//  PayTrack
//
//  Created by bmtech on 25.08.2026.
//

import SwiftUI
import MessageUI

struct LogView: View {

    @Environment(\.dismiss)
    private var dismiss

    @State private var logText = ""
    @State private var showMailComposer = false
    @State private var showMailUnavailable = false
    @State private var showShareSheet = false

    var body: some View {

        NavigationStack {

            ScrollView {

                Text(
                    logText.isEmpty
                    ? "log_empty"
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
            .navigationTitle("log_title")
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

                        if MFMailComposeViewController.canSendMail() {
                            showMailComposer = true
                        } else {
                            showShareSheet = true
                        }

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
                    recipient: DeveloperSupport.email,
                    subject: "log_share_subject",
                    body: """
                    log_mail_greeting.

                    log_mail_description:


                    log_mail_thanks.
                    """,
                    attachmentURL: AppLogger.shared.fileURL
                )
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(
                    item: AppLogger.shared.fileURL
                )
            }
            
            .alert(
                "mail_unavailable_title",
                isPresented: $showMailUnavailable
            ) {
                Button("OK", role: .cancel) {
                }
            } message: {
                Text(
                    "mail_unavailable_message"
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
