//
//  ShareSheet.swift
//  PayTrack
//
//  Created by bmtech on 25.08.2026.
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {

    let item: Any

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {

        UIActivityViewController(
            activityItems: [item],
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {
    }
}
