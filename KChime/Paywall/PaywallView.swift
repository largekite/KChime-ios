import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let proURL = URL(string: "https://kchime.com/#pricing")!

    private struct FeatureRow: Identifiable {
        var id: String { label }
        let icon: String
        let label: String
        let free: String
        let pro: String
    }

    private let rows: [FeatureRow] = [
        FeatureRow(icon: "wand.and.stars",      label: "AI replies / day",      free: "10",      pro: "50"),
        FeatureRow(icon: "slider.horizontal.3", label: "Custom tone profiles",  free: "–",       pro: "✓"),
        FeatureRow(icon: "arrow.2.squarepath",  label: "Rewrite chip",          free: "–",       pro: "✓"),
        FeatureRow(icon: "bell.badge",          label: "Promise reminders",     free: "–",       pro: "✓"),
        FeatureRow(icon: "bookmark.fill",       label: "Saved replies",         free: "Limited", pro: "Unlimited"),
        FeatureRow(icon: "person.2.fill",       label: "Contact memory",        free: "Limited", pro: "Unlimited"),
        FeatureRow(icon: "heart.fill",          label: "Support indie dev",     free: "–",       pro: "✓"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    heroSection
                    comparisonTable
                    ctaSection
                    legalFooter
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 48)
            }
            .navigationTitle("KChime Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.teal)

            Text("Reply without limits.")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("Get Pro for 50 AI replies/day, custom tone profiles, and priority generation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Free")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .center)
                Text("Pro")
                    .font(.caption.bold())
                    .foregroundStyle(.teal)
                    .frame(width: 72, alignment: .center)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider()

            ForEach(rows) { row in
                HStack(spacing: 10) {
                    Image(systemName: row.icon)
                        .font(.body)
                        .foregroundStyle(.teal)
                        .frame(width: 24)

                    Text(row.label)
                        .font(.subheadline)

                    Spacer()

                    Text(row.free)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .center)

                    Text(row.pro)
                        .font(.subheadline.bold())
                        .foregroundStyle(row.pro == "–" ? Color.secondary : .teal)
                        .frame(width: 72, alignment: .center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button {
                openURL(proURL)
            } label: {
                Text("Start Pro — $7 / month")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.teal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Text("Subscribe at kchime.com — sign in with Apple on the website to activate Pro on this device.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Label("10 replies/day free — always", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var legalFooter: some View {
        Text("Subscriptions are managed at kchime.com. After purchase, sign in with Apple here to sync your Pro status.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }
}
