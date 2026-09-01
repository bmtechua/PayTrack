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

            RootView()

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

                

                .onOpenURL { url in
                    AppLogger.shared.info(
                        "Auth deep link received: \(url.absoluteString)"
                    )

                    if url.scheme == "paytrack",
                       url.host == "reset-password" {

                        AuthService.shared.isPasswordRecovery = true

                        AppLogger.shared.info(
                            "Password reset deep link detected"
                        )

                        AppLogger.shared.info(
                            "isPasswordRecovery set to true"
                        )
                    }

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
