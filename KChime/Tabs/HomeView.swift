import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var remaining = AppConstants.Feature.freeLimit
    @State private var limit = AppConstants.Feature.freeLimit
    @State private var isLoadingUsage = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    usageBanner
                    quickStartCard
                    howItWorksSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationTitle("KChime")
            .navigationBarTitleDisplayMode(.large)
            .task { await loadUsage() }
        }
    }

    // MARK: - Usage Banner

    private var usageBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(appState.isPro ? "Pro Plan" : "Free Plan")
                    .font(.headline)
                Spacer()
                if !appState.isPro {
                    NavigationLink("Upgrade") {
                        PaywallView()
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.indigo)
                }
            }

            if !appState.isPro {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: Double(limit - remaining), total: Double(limit))
                        .tint(remaining > 1 ? .indigo : .orange)

                    Text("\(remaining) of \(limit) replies remaining today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("Unlimited replies", systemImage: "infinity")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Quick Start

    private var quickStartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Start")
                .font(.headline)
            Text("Switch to the KChime keyboard in any messaging app, paste the message you received, and tap the arrow.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "keyboard.fill")
                    .foregroundStyle(.indigo)
                Text("Tap the globe icon to switch keyboards")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - How It Works

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How it works")
                .font(.headline)

            ForEach(steps, id: \.title) { step in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: step.icon)
                        .font(.title3)
                        .foregroundStyle(.indigo)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title).font(.subheadline.bold())
                        Text(step.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private let steps: [(icon: String, title: String, detail: String)] = [
        ("square.and.arrow.down", "Paste the message", "Paste or type the message you received into the KChime input."),
        ("wand.and.stars", "Get 3 suggestions", "KChime generates 3 replies in your tone within seconds."),
        ("hand.tap.fill", "Tap to insert", "Tap a reply to insert it instantly, or copy it to paste yourself."),
        ("star.fill", "Save favourites", "Star replies you love to reuse them later."),
    ]

    // MARK: - Networking

    private func loadUsage() async {
        if let cached = UsageCache.shared.cachedUsage(for: AppConstants.Feature.keyboard) {
            remaining = cached.remaining
            limit = cached.limit
            return
        }
        isLoadingUsage = true
        defer { isLoadingUsage = false }
        if let result = try? await KChimeAPIClient.shared.fetchUsage(featureKey: AppConstants.Feature.keyboard) {
            remaining = result.remaining
            limit = result.limit
            UsageCache.shared.setUsage(remaining: result.remaining, limit: result.limit, for: AppConstants.Feature.keyboard)
        }
    }
}
