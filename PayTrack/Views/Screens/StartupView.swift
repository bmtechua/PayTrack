//
//  StartupView.swift
//  PayTrack
//

import SwiftUI

struct StartupView: View {

    @AppStorage("hasShownWelcome")
    private var hasShownWelcome = false

    @State
    private var phase: Phase = .loading

    private enum Phase {
        case welcome
        case loading
        case main
    }

    var body: some View {

        Group {

            switch phase {

            case .welcome:
                WelcomeView()

            case .loading:
                LoadingView()

            case .main:
                MainTabView()
            }
        }
        .task {
            await startApp()
        }
    }

    // MARK: - Start application

    private func startApp() async {

        if !hasShownWelcome {

            phase = .welcome

            try? await Task.sleep(
                for: .seconds(2)
            )

            hasShownWelcome = true
        }

        phase = .loading

        // Даємо AuthService завершити перевірку
        // локальної Supabase-сесії.
        try? await Task.sleep(
            for: .milliseconds(500)
        )

        phase = .main
    }
}

#Preview {
    StartupView()
}
