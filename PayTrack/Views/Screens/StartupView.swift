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

        // First launch
        if !hasShownWelcome {

            phase = .welcome

            try? await Task.sleep(
                for: .seconds(2)
            )

            hasShownWelcome = true
        }

        // Real loading / synchronization
        phase = .loading

        let loadingStart = ContinuousClock.now

        await Task.yield()

        AuthService.shared.startAuthStateListener()

        await AuthService.shared.loadCurrentUser()

        if AuthService.shared.user != nil {
            await SyncService.shared.syncAll()
        }

        let elapsed = loadingStart.duration(to: .now)
        let minimumDuration: Duration = .milliseconds(500)

        if elapsed < minimumDuration {
            try? await Task.sleep(
                for: minimumDuration - elapsed
            )
        }

        phase = .main
    }
}

#Preview {
    StartupView()
}
