import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            SavedRepliesView()
                .tabItem {
                    Label("Saved", systemImage: "bookmark.fill")
                }

            ContactsView()
                .tabItem {
                    Label("Contacts", systemImage: "person.2.fill")
                }

            PromisesListView()
                .tabItem {
                    Label("Promises", systemImage: "bell.badge.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.indigo)
    }
}
