import SwiftUI
import CoreData
import Supabase

@main
struct PayTrackApp: App {

    let persistenceController = PersistenceController.shared

    @AppStorage("theme")
    private var theme = "Система"

    @AppStorage("language")
    private var language = "uk"

    init() {
        AppLogger.shared.info("PayTrack started")
    }

    var body: some Scene {
        WindowGroup {

            MainTabView()
                .environment(
                    \.managedObjectContext,
                    persistenceController.container.viewContext
                )
                .environment(
                    \.locale,
                    Locale(identifier: language)
                )
                .id(language)
                .preferredColorScheme(selectedScheme())
                .task {
                    AuthService.shared.startAuthStateListener()
                    await AuthService.shared.loadCurrentUser()
                }
                .onOpenURL { url in
                    AppLogger.shared.info(
                        "Auth deep link received: \(url.absoluteString)"
                    )
                    SupabaseManager.shared.client.auth.handle(url)
                }
        }
    }

    private func selectedScheme() -> ColorScheme? {

        switch theme {

        case "light":
            return .light

        case "dark":
            return .dark

        default:
            return nil
        }
    }
}
