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

        let persistence =
            PersistenceController.shared

        persistenceController =
            persistence

        // Wait until Free default categories exist.

        let context =
            persistence.container.viewContext

        var categoriesReady = false

        while !categoriesReady {

            let request: NSFetchRequest<Category> =
                Category.fetchRequest()

            request.predicate = NSPredicate(
                format: "userID == nil"
            )

            do {

                let categories =
                    try context.fetch(request)

                categoriesReady =
                    !categories.isEmpty

            } catch {

                AppLogger.shared.error(
                    "Failed to check Free categories: \(error.localizedDescription)"
                )
            }

            if !categoriesReady {

                try? await Task.sleep(
                    for: .milliseconds(100)
                )
            }
        }

        // MARK: - Load current user

        await AuthService.shared.loadCurrentUser()

        // MARK: - Application ready

        phase = .main
    }
}

#Preview {
    RootView()
}
