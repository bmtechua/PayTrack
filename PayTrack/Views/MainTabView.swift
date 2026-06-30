//
//  MainTabView.swift
//  PayTrack
//
//  Created by bmtech on 29.06.2026.
//

import SwiftUI

struct MainTabView: View {

    var body: some View {

        TabView {

            HomeView()
                .tabItem {
                    Label(
                        "home_title",
                        systemImage: "house"
                    )
                }


            AnalyticsView()
                .tabItem {
                    Label(
                        "analytics_title",
                        systemImage: "chart.bar"
                    )
                }


            ExpensesListView()
                .tabItem {
                    Label(
                        "expenses",
                        systemImage: "list.bullet"
                    )
                }


            CategoriesView()
                .tabItem {
                    Label(
                        "categories",
                        systemImage: "tag"
                    )
                }


            SettingsView()
                .tabItem {
                    Label(
                        "settings_title",
                        systemImage: "gear"
                    )
                }
        }
    }
}


#Preview {
    MainTabView()
}
