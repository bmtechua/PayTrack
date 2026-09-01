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

        if !hasShownWelcome {

            phase = .welcome

            try? await Task.sleep(
                for: .seconds(2)
            )

            hasShownWelcome = true
        }

        phase = .loading

        try? await Task.sleep(
            for: .seconds(2)
        )

        phase = .main
    }
}

#Preview {
    RootView()
}
