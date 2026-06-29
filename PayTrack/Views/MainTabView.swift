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
                    Label("Головна",
                          systemImage: "house")
                }

            ExpensesListView()
                .tabItem {
                    Label("Витрати",
                          systemImage: "list.bullet")
                }
            
            CategoriesView()
                .tabItem {
                    Label(
                        "Категорії",
                        systemImage: "tag"
                    )
                }
        }
    }
}

#Preview {
    MainTabView()
}
