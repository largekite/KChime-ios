import SwiftUI

// MARK: - Confidence Badge

/// Compact score badge shown under each reply suggestion.
/// Tapping it expands to show the full breakdown.
struct ConfidenceBadge: View {
    let score: ConfidenceScore
    @State private var showBreakdown = false

    private var badgeColor: Color {
        switch score.color {
        case "green":  return .green
        case "teal":   return .teal
        case "orange": return .orange
        case "red":    return .red
        default:       return .teal
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3)) { showBreakdown.toggle() } }) {
                HStack(spacing: 6) {
                    ScoreRing(score: score.overall, color: badgeColor, size: 24)

                    Text("\(score.overall)")
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundStyle(badgeColor)

                    Text(score.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: showBreakdown ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(badgeColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)

            if showBreakdown {
                ConfidenceBreakdownView(breakdown: score.breakdown)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Score Ring

struct ScoreRing: View {
    let score: Int
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100.0)
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Breakdown View

struct ConfidenceBreakdownView: View {
    let breakdown: ConfidenceBreakdown

    var body: some View {
        VStack(spacing: 6) {
            ForEach(breakdown.dimensions) { dim in
                HStack(spacing: 8) {
                    Image(systemName: dim.icon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

                    Text(dim.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(dim.dimension.rawValue)
                        .font(.caption2.bold())
                        .foregroundStyle(dimensionColor(dim.dimension))
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.systemFill).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func dimensionColor(_ d: ScoreDimension) -> Color {
        switch d.color {
        case "green":  return .green
        case "orange": return .orange
        case "red":    return .red
        default:       return .teal
        }
    }
}
