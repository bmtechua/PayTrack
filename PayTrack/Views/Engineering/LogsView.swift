//
//  LogsView.swift
//  PayTrack
//
//  Created by bmtech on 14.09.2026.
//

import SwiftUI

struct LogsView: View {

    let text: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(
                        .system(
                            .caption,
                            design: .monospaced
                        )
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding()
                    .textSelection(.enabled)
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
