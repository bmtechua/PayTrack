//
//  MailComposerView.swift
//  PayTrack
//
//  Created by bmtech on 25.08.2026.
//

import SwiftUI
import MessageUI

struct MailComposerView: UIViewControllerRepresentable {

    let recipient: String
    let subject: String
    let body: String
    let attachmentURL: URL

    @Environment(\.dismiss)
    private var dismiss

    func makeUIViewController(
        context: Context
    ) -> MFMailComposeViewController {

        let composer = MFMailComposeViewController()

        composer.mailComposeDelegate = context.coordinator

        composer.setToRecipients([
            recipient
        ])

        composer.setSubject(subject)

        composer.setMessageBody(
            body,
            isHTML: false
        )

        if let data = try? Data(contentsOf: attachmentURL) {

            composer.addAttachmentData(
                data,
                mimeType: "text/plain",
                fileName: "PayTrack.log"
            )
        }

        return composer
    }

    func updateUIViewController(
        _ uiViewController: MFMailComposeViewController,
        context: Context
    ) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {

        private let parent: MailComposerView

        init(_ parent: MailComposerView) {
            self.parent = parent
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {

            controller.dismiss(
                animated: true
            )
        }
    }
}
