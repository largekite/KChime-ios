import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem { Label("Reply", systemImage: "bubble.left.and.bubble.right.fill") }
                    .tag(0)

                FixMessageView()
                    .tabItem { Label("Fix", systemImage: "wand.and.stars") }
                    .tag(1)

                PracticeView()
                    .tabItem { Label("Practice", systemImage: "graduationcap.fill") }
                    .tag(2)

                ReplyPacksView()
                    .tabItem { Label("Packs", systemImage: "tray.full.fill") }
                    .tag(3)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(4)
            }
            .tint(.teal)

            ToastOverlay()
        }
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
