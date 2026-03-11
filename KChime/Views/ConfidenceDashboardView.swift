import SwiftUI

// MARK: - Confidence Dashboard

struct ConfidenceDashboardView: View {
    @StateObject private var store = ConfidenceAnalyticsStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Hero score ring
                heroCard

                // Daily stats
                dailyStatsCard

                // Weekly stats
                weeklyStatsCard

                // Weekly chart
                if !store.weekEntries.isEmpty {
                    weeklyChartCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle("Confidence Score")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 12) {
            ScoreRing(
                score: store.todayAverageScore,
                color: heroColor,
                size: 80
            )

            Text(store.todayAverageScore > 0 ? "Today's Average" : "No replies yet today")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if store.todayAverageScore > 0 {
                Text(scoreLabel(store.todayAverageScore))
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(heroColor.opacity(0.12))
                    .foregroundStyle(heroColor)
                    .clipShape(Capsule())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var heroColor: Color {
        let s = store.todayAverageScore
        if s >= 80 { return .green }
        if s >= 60 { return .teal }
        if s >= 40 { return .orange }
        if s > 0 { return .red }
        return .secondary
    }

    // MARK: - Daily Stats Card

    private var dailyStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Today", systemImage: "calendar")
                .font(.headline)

            HStack(spacing: 16) {
                StatTile(
                    title: "Replies",
                    value: "\(store.todayReplies)",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .teal
                )
                StatTile(
                    title: "Avg Score",
                    value: store.todayAverageScore > 0 ? "\(store.todayAverageScore)" : "—",
                    icon: "chart.bar.fill",
                    color: .teal
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Weekly Stats Card

    private var weeklyStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("This Week", systemImage: "calendar.badge.clock")
                .font(.headline)

            HStack(spacing: 16) {
                StatTile(
                    title: "Replies",
                    value: "\(store.weeklyReplies)",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .teal
                )
                StatTile(
                    title: "Avg Score",
                    value: store.weeklyAverageScore > 0 ? "\(store.weeklyAverageScore)" : "—",
                    icon: "chart.bar.fill",
                    color: .teal
                )
            }

            Divider()

            HStack(spacing: 16) {
                WeeklyMetricRow(
                    label: "Clarity trend",
                    value: clarityTrendLabel,
                    icon: "text.alignleft",
                    color: clarityTrendColor
                )
                WeeklyMetricRow(
                    label: "Tone consistency",
                    value: store.toneConsistency,
                    icon: "waveform.path",
                    color: toneConsistencyColor
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var clarityTrendLabel: String {
        let diff = store.clarityImprovement
        if diff > 0 { return "+\(diff)%" }
        if diff < 0 { return "\(diff)%" }
        return "Steady"
    }

    private var clarityTrendColor: Color {
        let diff = store.clarityImprovement
        if diff > 0 { return .green }
        if diff < 0 { return .orange }
        return .secondary
    }

    private var toneConsistencyColor: Color {
        switch store.toneConsistency {
        case "Very consistent": return .green
        case "Consistent":      return .teal
        default:                return .orange
        }
    }

    // MARK: - Weekly Chart Card

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Score History", systemImage: "chart.xyaxis.line")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(store.weekEntries) { entry in
                    VStack(spacing: 4) {
                        Text("\(entry.averageScore)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(entry.averageScore))
                            .frame(height: max(4, CGFloat(entry.averageScore) * 0.8))

                        Text(entry.displayDate)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func barColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .teal }
        if score >= 40 { return .orange }
        return .red
    }

    private func scoreLabel(_ s: Int) -> String {
        switch s {
        case 90...100: return "Excellent"
        case 75..<90:  return "Strong"
        case 60..<75:  return "Good"
        case 40..<60:  return "Fair"
        default:       return "Needs work"
        }
    }
}

// MARK: - Stat Tile

private struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold().monospacedDigit())

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Weekly Metric Row

private struct WeeklyMetricRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
