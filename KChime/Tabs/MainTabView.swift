import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            LiveListenView()
                .tabItem {
                    Label("Live", systemImage: "waveform.circle.fill")
                }

            PracticeView()
                .tabItem {
                    Label("Practice", systemImage: "graduationcap.fill")
                }

            WorkReplyView()
                .tabItem {
                    Label("Work", systemImage: "briefcase.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.indigo)
    }
}
