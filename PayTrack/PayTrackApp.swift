//
//  PayTrackApp.swift
//  PayTrack
//
//  Created by bmtech on 29.06.2026.
//

import SwiftUI
import CoreData
import Auth

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
                ).id(language)

                .preferredColorScheme(selectedScheme())
            
                .task {
                    await AuthService.shared.loadCurrentUser()
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

