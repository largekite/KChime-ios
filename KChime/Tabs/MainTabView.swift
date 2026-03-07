import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            LiveListenView()
                .tabItem { Label("Live", systemImage: "waveform.circle.fill") }
                .tag(1)

            PracticeView()
                .tabItem { Label("Practice", systemImage: "graduationcap.fill") }
                .tag(2)

            WorkReplyView()
                .tabItem { Label("Work", systemImage: "briefcase.fill") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(.indigo)
        .sheet(isPresented: $appState.deepLinkShowPaywall) {
            PaywallView()
        }
        .onChange(of: appState.deepLinkTab) { _, tab in
            if let tab {
                selectedTab = tab
                appState.deepLinkTab = nil
            }
        }
    }
}
