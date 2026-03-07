import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            Form {
                // Subscription
                Section("Plan") {
                    if appState.isMax {
                        HStack {
                            Label("Max — Unlimited replies", systemImage: "star.fill")
                                .foregroundStyle(.indigo)
                            Spacer()
                            Link("Manage", destination: URL(string: "https://kchime.com/account")!)
                                .font(.subheadline)
                        }
                    } else if appState.isPro {
                        HStack {
                            Label("Pro — 50 replies/day", systemImage: "star.fill")
                                .foregroundStyle(.indigo)
                            Spacer()
                            Link("Manage", destination: URL(string: "https://kchime.com/account")!)
                                .font(.subheadline)
                        }
                    } else {
                        NavigationLink(destination: PaywallView()) {
                            Label("Upgrade to Pro", systemImage: "star")
                                .foregroundStyle(.indigo)
                        }
                    }
                }

                // Tone
                Section("Your Tone") {
                    NavigationLink(destination: ToneSettingsView(current: appState.toneProfile)) {
                        HStack {
                            Label(appState.toneProfile.label, systemImage: "wand.and.stars")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(formalityLabel(appState.toneProfile.formality))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Length", value: appState.toneProfile.lengthPreference.displayName)
                    LabeledContent("Emoji", value: appState.toneProfile.emojiEnabled ? "On" : "Off")
                    if let custom = appState.toneProfile.customInstructions, !custom.isEmpty {
                        LabeledContent("Custom instructions") {
                            Text(custom)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                // Library
                Section("Library") {
                    NavigationLink(destination: SavedRepliesView()) {
                        Label("Saved Replies", systemImage: "bookmark.fill")
                    }
                    NavigationLink(destination: ContactsView()) {
                        Label("Contacts", systemImage: "person.2.fill")
                    }
                    NavigationLink(destination: PromisesListView()) {
                        Label("Promises", systemImage: "bell.badge.fill")
                    }
                }

                // Analytics
                Section("Analytics") {
                    NavigationLink(destination: ConfidenceDashboardView()) {
                        HStack {
                            Label("Confidence Score", systemImage: "chart.bar.fill")
                                .foregroundStyle(.teal)
                            Spacer()
                            if ConfidenceAnalyticsStore.shared.todayAverageScore > 0 {
                                Text("\(ConfidenceAnalyticsStore.shared.todayAverageScore)")
                                    .font(.caption.bold().monospacedDigit())
                                    .foregroundStyle(.teal)
                            }
                        }
                    }
                }

                // Privacy
                Section("Privacy") {
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete all my data", systemImage: "trash")
                    }
                }

                // About
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.shortVersionString)
                    Link("Send Feedback", destination: URL(string: "mailto:hello@kchime.app")!)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Delete all your data?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    Task { await deleteAllData() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all saved replies, contact notes, and your account from our servers. This cannot be undone.")
            }
            .alert("Error", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    private func deleteAllData() async {
        // 1. Wipe CoreData
        PersistenceController.shared.deleteAllData()

        // 2. Wipe UserDefaults in App Group
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID)
        defaults?.removePersistentDomain(forName: AppConstants.appGroupID)

        // 3. Call server delete
        _ = try? await KChimeAPIClient.shared.deleteAccount()

        // 4. Reset app state
        appState.onboardingComplete = false
    }

    private func formalityLabel(_ value: Double) -> String {
        switch value {
        case ..<0.3: return "Casual"
        case 0.3..<0.65: return "Balanced"
        default: return "Formal"
        }
    }
}

// MARK: - Privacy Policy placeholder

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 4)
                Text("Last updated: March 2026")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Group {
                    Text("**Message Content**").font(.headline)
                    Text("KChime processes message text only to generate reply suggestions. Message content is not stored on our servers at any time.")
                    Text("**Contact Notes**").font(.headline)
                    Text("Contact notes you create are stored locally on your device, encrypted with a key only your device holds. They are sent over TLS to generate suggestions but are never written to our database.")
                    Text("**Usage Data**").font(.headline)
                    Text("We store a daily count of API calls per device to enforce usage limits. No message content is associated with these records.")
                    Text("**Deleting Your Data**").font(.headline)
                    Text("Tap Settings → Delete all my data to remove all local data and your usage record from our servers immediately.")
                }
            }
            .padding(24)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension Bundle {
    var shortVersionString: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
