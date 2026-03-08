import SwiftUI

// MARK: - Reply Pack Detail View

struct ReplyPackDetailView: View {
    let pack: ReplyPack
    @State private var searchText = ""
    @State private var selectedScenario: ReplyScenario? = nil

    private var filteredScenarios: [ReplyScenario] {
        if searchText.isEmpty { return pack.scenarios }
        let query = searchText.lowercased()
        return pack.scenarios.filter {
            $0.message.lowercased().contains(query) ||
            $0.context.lowercased().contains(query)
        }
    }

    private var accentColor: Color {
        switch pack.color {
        case "orange": return .orange
        case "indigo": return .teal
        case "green":  return .green
        case "red":    return .red
        case "teal":   return .teal
        default:       return .teal
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Pack header
                HStack(spacing: 12) {
                    Text(pack.emoji)
                        .font(.largeTitle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pack.title)
                            .font(.headline)
                        Text("\(pack.scenarios.count) message scenarios")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Scenario list
                LazyVStack(spacing: 10) {
                    ForEach(filteredScenarios) { scenario in
                        ScenarioRow(scenario: scenario, accentColor: accentColor) {
                            selectedScenario = scenario
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle(pack.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search messages…")
        .sheet(item: $selectedScenario) { scenario in
            ReplyVariationsView(scenario: scenario, accentColor: accentColor)
        }
    }
}

// MARK: - Scenario Row

private struct ScenarioRow: View {
    let scenario: ReplyScenario
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Incoming message bubble
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "bubble.left.fill")
                        .font(.caption)
                        .foregroundStyle(accentColor)
                        .padding(.top, 2)

                    Text(scenario.message)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                }

                Text(scenario.context)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    Text("\(scenario.seedReplies.count) replies")
                        .font(.caption2.bold())
                        .foregroundStyle(accentColor)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
