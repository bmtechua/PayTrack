import SwiftUI

struct MainTabView: View {

    @ObservedObject
    private var authService = AuthService.shared

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
        .sheet(
            isPresented: $authService.isPasswordRecovery
        ) {
            NavigationStack {
                ChangePasswordView()
            }
        }
    }
}

#Preview {
    MainTabView()
}
