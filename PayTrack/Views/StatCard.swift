//
//  StatCard.swift
//  PayTrack
//
//  Created by bmtech on 29.06.2026.
//

import SwiftUI

struct StatCard: View {

    let title: String
    let value: String

    var body: some View {

        VStack(spacing: 6) {

            Text(LocalizedStringKey(title))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
                .bold()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.gray.opacity(0.15))
        )
    }
}
