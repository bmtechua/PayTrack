import SwiftUI
import CoreData

struct RootView: View {

    @State
    private var phase: Phase = .welcome

    @State
    private var persistenceController: PersistenceController?

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

                if let persistenceController {

                    MainTabView()
                        .environment(
                            \.managedObjectContext,
                            persistenceController.container.viewContext
                        )

                } else {

                    LoadingView()
                }
            }
        }
        .task {
            await startApp()
        }
    }

    // MARK: - Start application

    private func startApp() async {

        // MARK: - Welcome

        // WelcomeView is shown immediately
        // when the application process starts.

        try? await Task.sleep(
            for: .seconds(1)
        )

        // MARK: - Loading

        phase = .loading

        // Create Core Data only after WelcomeView.
        // This prevents the white screen caused by
        // PersistenceController.shared being created
        // before the first SwiftUI screen appears.

        persistenceController =
            PersistenceController.shared

        // Artificial loading delay

        try? await Task.sleep(
            for: .seconds(1)
        )

        // MARK: - Real startup

        AuthService.shared.startAuthStateListener()

        await AuthService.shared.loadCurrentUser()

        if AuthService.shared.user != nil {
            await SyncService.shared.syncAll()
        }

        // MARK: - Application ready

        phase = .main
    }
}

#Preview {
    RootView()
}
