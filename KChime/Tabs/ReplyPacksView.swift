import SwiftUI

// MARK: - Reply Packs View

struct ReplyPacksView: View {
    var embedded = false

    var body: some View {
        if embedded {
            content
        } else {
            NavigationStack {
                content
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 20) {
                introCard

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(ReplyPacks.all) { pack in
                        NavigationLink(value: pack) {
                            PackCard(pack: pack)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle("Reply Packs")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: ReplyPack.self) { pack in
            ReplyPackDetailView(pack: pack)
        }
    }

    // MARK: - Intro Card

    private var introCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.full.fill")
                .font(.title3)
                .foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 2) {
                Text("Browse Reply Packs")
                    .font(.subheadline.bold())
                Text("Pre-built message scenarios with instant replies. Tap a pack to explore.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Pack Card

private struct PackCard: View {
    let pack: ReplyPack

    private var accentColor: Color {
        switch pack.color {
        case "orange": return .orange
        case "indigo": return .indigo
        case "green":  return .green
        case "red":    return .red
        case "teal":   return .teal
        default:       return .teal
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pack.emoji)
                .font(.largeTitle)

            Text(pack.title)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Text(pack.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Text("\(pack.scenarios.count) scenarios")
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(accentColor.opacity(0.15))
                .foregroundStyle(accentColor)
                .clipShape(Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
    }
}
