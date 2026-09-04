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

        try? await Task.sleep(
            for: .seconds(1)
        )

        // MARK: - Loading

        phase = .loading

        // Core Data is created only after WelcomeView.
        persistenceController =
            PersistenceController.shared
        
        // Load current authenticated user
           await AuthService.shared.loadCurrentUser()

        try? await Task.sleep(
            for: .seconds(1)
        )

        // MARK: - Application ready

        phase = .main
    }
}

#Preview {
    RootView()
}
