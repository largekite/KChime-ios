import SwiftUI

// MARK: - Practice View

struct PracticeView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("practice_streak") private var streak = 0
    @AppStorage("practice_completedToday") private var completedTodayRaw = ""
    @AppStorage("practice_lastDate") private var lastDateString = ""

    @State private var selectedCategory: PracticeCategory? = nil
    @State private var dailyPicks: [PracticeScenario] = []
    @State private var activeScenario: PracticeScenario? = nil

    private let dailyGoal = 3

    private var completedToday: Set<String> {
        Set(completedTodayRaw.split(separator: ",").map(String.init))
    }

    private var todayProgress: Int { min(completedToday.count, dailyGoal) }

    private var displayedScenarios: [PracticeScenario] {
        if let cat = selectedCategory {
            return PracticeScenarios.all.filter { $0.category == cat }
        }
        return dailyPicks
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Streak + progress header
                    streakHeader

                    // Category filter
                    categoryFilterRow

                    // Scenario list
                    if displayedScenarios.isEmpty {
                        ContentUnavailableView(
                            "No scenarios",
                            systemImage: "text.bubble",
                            description: Text("Check back tomorrow for new daily picks.")
                        )
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            if selectedCategory == nil {
                                Text("Today's Picks")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                            }
                            ForEach(displayedScenarios) { scenario in
                                ScenarioCard(
                                    scenario: scenario,
                                    isCompleted: completedToday.contains(scenario.id),
                                    onTap: { activeScenario = scenario }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { refreshDailyState() }
        }
        .sheet(item: $activeScenario) { scenario in
            PracticeSessionView(scenario: scenario) { id in
                markCompleted(id: id)
                activeScenario = nil
            }
            .environmentObject(appState)
        }
    }

    // MARK: - Header

    private var streakHeader: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("🔥")
                    Text("\(streak) day streak")
                        .font(.title3.bold())
                }
                Text("Practice responding naturally in American social contexts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.teal.opacity(0.2), lineWidth: 4)
                        .frame(width: 52, height: 52)
                    Circle()
                        .trim(from: 0, to: CGFloat(todayProgress) / CGFloat(dailyGoal))
                        .stroke(Color.teal, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90))
                    Text("\(todayProgress)/\(dailyGoal)")
                        .font(.caption.bold())
                        .foregroundStyle(.teal)
                }
                Text("Today")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Category Filter

    private var categoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(nil, label: "Daily Picks", emoji: "⭐")
                ForEach(PracticeCategory.allCases) { cat in
                    categoryChip(cat, label: cat.rawValue, emoji: cat.emoji)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private func categoryChip(_ category: PracticeCategory?, label: String, emoji: String) -> some View {
        let selected = selectedCategory == category
        Button(action: { selectedCategory = category }) {
            Text("\(emoji) \(label)")
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? Color.teal : Color(.secondarySystemBackground))
                .foregroundStyle(selected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - State management

    private func refreshDailyState() {
        let today = dateString(Date())
        if lastDateString != today {
            // New day — reset completions, potentially update streak
            if let last = Calendar.current.date(from: DateFormatter().calendar.dateComponents([.year, .month, .day], from: Date())),
               let lastDate = dateFromString(lastDateString) {
                let diff = Calendar.current.dateComponents([.day], from: lastDate, to: last).day ?? 0
                if diff == 1 && completedToday.count >= dailyGoal {
                    streak += 1
                } else if diff > 1 {
                    streak = 0
                }
            }
            completedTodayRaw = ""
            lastDateString = today
        }
        pickDailyScenarios()
    }

    private func pickDailyScenarios() {
        // Deterministic daily picks based on day-of-year
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        var rng = SeededRandomNumberGenerator(seed: UInt64(dayOfYear))
        var picks: [PracticeScenario] = []
        var usedCategories = Set<PracticeCategory>()
        var shuffled = PracticeScenarios.all.shuffled(using: &rng)
        for scenario in shuffled {
            if !usedCategories.contains(scenario.category) {
                picks.append(scenario)
                usedCategories.insert(scenario.category)
            }
            if picks.count >= 6 { break }
        }
        // Fill remaining if needed
        if picks.count < 6 {
            let remaining = shuffled.filter { !picks.contains($0) }
            picks += Array(remaining.prefix(6 - picks.count))
        }
        dailyPicks = picks
    }

    private func markCompleted(id: String) {
        var ids = completedToday
        ids.insert(id)
        completedTodayRaw = ids.joined(separator: ",")
        // Check if goal reached today
        if ids.count == dailyGoal {
            let today = dateString(Date())
            lastDateString = today
        }
    }

    private func dateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private func dateFromString(_ str: String) -> Date? {
        guard !str.isEmpty else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: str)
    }
}

// MARK: - Scenario Card

private struct ScenarioCard: View {
    let scenario: PracticeScenario
    let isCompleted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(scenario.category.emoji)
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(scenario.title)
                            .font(.subheadline.bold())
                        Spacer()
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                    Text(scenario.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCompleted ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Practice Session View

struct PracticeSessionView: View {
    @EnvironmentObject var appState: AppState
    let scenario: PracticeScenario
    let onComplete: (String) -> Void

    @State private var suggestions: [String] = []
    @State private var longerAlternative: String? = nil
    @State private var isGenerating = false
    @State private var error: String? = nil
    @State private var copiedIndex: Int? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Scenario message
                    VStack(alignment: .leading, spacing: 8) {
                        Label(scenario.category.rawValue, systemImage: "bubble.left.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.teal)

                        Text(scenario.message)
                            .font(.body)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Text(scenario.context)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    if let err = error {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }

                    if suggestions.isEmpty {
                        Button(action: generateReplies) {
                            Group {
                                if isGenerating {
                                    ProgressView().tint(.white)
                                } else {
                                    Label("Generate reply suggestions", systemImage: "sparkles")
                                        .font(.subheadline.bold())
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.teal)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isGenerating)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tap a reply to copy it")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            VStack(spacing: 0) {
                                ForEach(Array(suggestions.enumerated()), id: \.offset) { idx, text in
                                    Button(action: { copyAndComplete(text: text, index: idx) }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: copiedIndex == idx ? "checkmark.circle.fill" : "doc.on.doc")
                                                .foregroundStyle(copiedIndex == idx ? .green : .teal)
                                                .frame(width: 20)
                                            Text(text)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if idx < suggestions.count - 1 {
                                        Divider().padding(.leading, 46)
                                    }
                                }
                                if let longer = longerAlternative {
                                    Divider().padding(.leading, 46)
                                    Button(action: { copyAndComplete(text: longer, index: 99) }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: copiedIndex == 99 ? "checkmark.circle.fill" : "doc.on.doc")
                                                .foregroundStyle(copiedIndex == 99 ? .green : .teal)
                                                .frame(width: 20)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Detailed").font(.caption2.bold()).foregroundStyle(.teal)
                                                Text(longer)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.primary)
                                                    .multilineTextAlignment(.leading)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle(scenario.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                if !suggestions.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: generateReplies) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isGenerating)
                    }
                }
            }
            .task { generateReplies() }
        }
    }

    private func generateReplies() {
        isGenerating = true
        error = nil
        Task {
            do {
                let request = ReplyRequest(
                    featureKey: AppConstants.Feature.keyboard,
                    receivedMessage: scenario.message,
                    toneProfile: appState.toneProfile.toPayload()
                )
                let response = try await KChimeAPIClient.shared.generateReplies(request: request)
                suggestions = response.suggestions
                longerAlternative = response.longerAlternative.isEmpty ? nil : response.longerAlternative
            } catch {
                self.error = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func copyAndComplete(text: String, index: Int) {
        UIPasteboard.general.string = text
        copiedIndex = index
        Task {
            try? await Task.sleep(for: .seconds(1))
            onComplete(scenario.id)
        }
    }
}

// MARK: - Seeded RNG

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    var seed: UInt64
    mutating func next() -> UInt64 {
        seed ^= seed << 13
        seed ^= seed >> 7
        seed ^= seed << 17
        return seed
    }
}
