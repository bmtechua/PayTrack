//
//  PayTrackApp.swift
//  PayTrack
//
//  Created by bmtech on 29.06.2026.
//

import SwiftUI
import CoreData

@main
struct PayTrackApp: App {

    let persistenceController = PersistenceController.shared

    @AppStorage("theme")
    private var theme = "Система"

    @AppStorage("language")
    private var language = "uk"


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
        }
    }

    private func selectedScheme() -> ColorScheme? {

        switch theme {

        case "Світла": return .light
        case "Темна": return .dark
        default: return nil
        }
    }
}

