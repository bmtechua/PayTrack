//
//  LoadingView.swift
//  PayTrack
//

import SwiftUI

struct LoadingView: View {

    var body: some View {

        ZStack {

            Color.white
                .ignoresSafeArea()

            VStack(spacing: 24) {

                Image("PayTrackLogo")
                    .resizable()
                    .scaledToFit()
                    .containerRelativeFrame(.horizontal) { width, _ in
                        width * 0.40
                    }

                ProgressView()
                    .controlSize(.large)

                Text("loading")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    LoadingView()
}
