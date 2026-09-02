import SwiftUI

struct RootView: View {

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

        // Real startup / synchronization
        phase = .loading

        AuthService.shared.startAuthStateListener()

        await AuthService.shared.loadCurrentUser()

        // If a user is already authenticated,
        // perform the real full synchronization.
        if AuthService.shared.user != nil {

            await SyncService.shared.syncAll()
        }

        // Application is ready
        phase = .main
    }
}

#Preview {
    RootView()
}
