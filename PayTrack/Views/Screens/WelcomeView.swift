//
//  WelcomeView.swift
//  PayTrack
//
//  Created by bmtech on 01.09.2026.
//

//
//  WelcomeView.swift
//  PayTrack
//
//  Created by bmtech on 01.09.2026.
//

import SwiftUI

struct WelcomeView: View {

    var body: some View {

        ZStack {

            Color.white
                .ignoresSafeArea()

            VStack {
                
                Spacer()
                
                // MARK: - App Logo
                
                Image("PayTrackLogo")
                    .resizable()
                    .scaledToFit()
                    .containerRelativeFrame(.horizontal) { width, _ in
                        width * 0.95
                    }
                
                // MARK: - Tagline
                
                Text("welcome_tagline")
                    .font(.title)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.top, 5)
                
                Spacer()
                // MARK: - Company
                
                Text("company_name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
                
                // MARK: - Divider
                
                Rectangle()
                    .fill(Color.primary.opacity(0.15))
                    .frame(height: 1)
                    .containerRelativeFrame(.horizontal) { width, _ in
                        width * 0.95
                    }
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    WelcomeView()
}
