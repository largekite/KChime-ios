import SwiftUI

@main
struct KChimeApp: App {
    @StateObject private var appState = AppState()
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .onOpenURL { url in handleDeepLink(url) }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "kchime" else { return }
        switch url.host {
        case "paywall", "upgrade":
            appState.deepLinkShowPaywall = true
        case "settings":
            appState.deepLinkTab = 4
        case "saved":
            appState.deepLinkTab = 4   // Settings tab hosts Saved Replies nav
        default:
            break
        }
    }
}

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.onboardingComplete {
                MainTabView()
                    .task { flushPendingExtensionData() }
            } else {
                OnboardingFlowView()
            }
        }
        .animation(.easeInOut, value: appState.onboardingComplete)
    }

    /// Picks up data queued by the keyboard / share extensions (stored in App Group
    /// UserDefaults) and merges it into CoreData so it appears in the main app.
    private func flushPendingExtensionData() {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID)!
        let ctx = PersistenceController.shared.container.viewContext

        // Starred replies
        if let pending = defaults.stringArray(forKey: "kchime_pending_saves"), !pending.isEmpty {
            for text in pending {
                let entity = SavedReplyEntity(context: ctx)
                entity.id = UUID()
                entity.text = text
                entity.createdAt = Date()
            }
            defaults.removeObject(forKey: "kchime_pending_saves")
        }

        // Contact memory opt-ins queued from the keyboard
        if let pending = defaults.array(forKey: "kchime_pending_contacts") as? [[String: String]],
           !pending.isEmpty {
            for entry in pending {
                guard let name = entry["name"], !name.isEmpty else { continue }
                let contact = ContactEntity(context: ctx)
                contact.id = UUID()
                contact.displayName = name
                contact.createdAt = Date()
                contact.updatedAt = Date()
                if let notes = entry["notes"] { try? contact.setEncryptedNotes(notes) }
            }
            defaults.removeObject(forKey: "kchime_pending_contacts")
        }

        try? ctx.save()
    }
}
