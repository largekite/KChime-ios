import Foundation

// MARK: - Confidence Analytics Store

/// Privacy-safe analytics store.
/// Stores only numeric evaluation metrics — never message content.
/// Data persists in App Group UserDefaults for cross-target access.
@MainActor
final class ConfidenceAnalyticsStore: ObservableObject {
    nonisolated(unsafe) static let shared = ConfidenceAnalyticsStore()

    private let defaults: UserDefaults
    private let storageKey = "kchime_confidence_analytics"

    @Published private(set) var entries: [DayEntry] = []

    private init() {
        defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
        load()
    }

    // MARK: - Public API

    func record(score: ConfidenceScore) {
        let today = Self.dayKey()
        if let idx = entries.firstIndex(where: { $0.dayKey == today }) {
            entries[idx].repliesGenerated += 1
            entries[idx].totalScore += score.overall
            entries[idx].toneSum += score.breakdown.tone.numericValue
            entries[idx].claritySum += score.breakdown.clarity.numericValue
            entries[idx].politenessSum += score.breakdown.politeness.numericValue
            entries[idx].professionalismSum += score.breakdown.professionalism.numericValue
            entries[idx].brevitySum += score.breakdown.brevity.numericValue
        } else {
            var entry = DayEntry(dayKey: today)
            entry.repliesGenerated = 1
            entry.totalScore = score.overall
            entry.toneSum = score.breakdown.tone.numericValue
            entry.claritySum = score.breakdown.clarity.numericValue
            entry.politenessSum = score.breakdown.politeness.numericValue
            entry.professionalismSum = score.breakdown.professionalism.numericValue
            entry.brevitySum = score.breakdown.brevity.numericValue
            entries.append(entry)
        }
        // Keep only last 30 days
        if entries.count > 30 { entries = Array(entries.suffix(30)) }
        save()
    }

    // MARK: - Computed Stats

    var todayEntry: DayEntry? {
        entries.first { $0.dayKey == Self.dayKey() }
    }

    var todayReplies: Int {
        todayEntry?.repliesGenerated ?? 0
    }

    var todayAverageScore: Int {
        guard let e = todayEntry, e.repliesGenerated > 0 else { return 0 }
        return e.totalScore / e.repliesGenerated
    }

    var weekEntries: [DayEntry] {
        let calendar = Calendar.current
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: Date()) else { return [] }
        let cutoff = Self.dayKey(for: sevenDaysAgo)
        return entries.filter { $0.dayKey >= cutoff }.sorted { $0.dayKey < $1.dayKey }
    }

    var weeklyReplies: Int {
        weekEntries.reduce(0) { $0 + $1.repliesGenerated }
    }

    var weeklyAverageScore: Int {
        let total = weekEntries.reduce(0) { $0 + $1.totalScore }
        let count = weekEntries.reduce(0) { $0 + $1.repliesGenerated }
        guard count > 0 else { return 0 }
        return total / count
    }

    /// Clarity improvement: compare this week's average clarity to last week's.
    var clarityImprovement: Int {
        let thisWeek = weeklyAverage(\.claritySum)
        let lastWeek = lastWeekAverage(\.claritySum)
        guard lastWeek > 0 else { return 0 }
        return thisWeek - lastWeek
    }

    /// Tone consistency: standard deviation of daily tone averages this week (lower = more consistent).
    var toneConsistency: String {
        let dailyAverages = weekEntries.compactMap { entry -> Double? in
            guard entry.repliesGenerated > 0 else { return nil }
            return Double(entry.toneSum) / Double(entry.repliesGenerated)
        }
        guard dailyAverages.count >= 2 else { return "—" }
        let mean = dailyAverages.reduce(0, +) / Double(dailyAverages.count)
        let variance = dailyAverages.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(dailyAverages.count)
        let stdDev = variance.squareRoot()
        if stdDev < 8 { return "Very consistent" }
        if stdDev < 15 { return "Consistent" }
        return "Varies"
    }

    // MARK: - Helpers

    private func weeklyAverage(_ keyPath: KeyPath<DayEntry, Int>) -> Int {
        let w = weekEntries
        let count = w.reduce(0) { $0 + $1.repliesGenerated }
        guard count > 0 else { return 0 }
        return w.reduce(0) { $0 + $1[keyPath: keyPath] } / count
    }

    private func lastWeekAverage(_ keyPath: KeyPath<DayEntry, Int>) -> Int {
        let calendar = Calendar.current
        guard let fourteenDaysAgo = calendar.date(byAdding: .day, value: -13, to: Date()),
              let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        let start = Self.dayKey(for: fourteenDaysAgo)
        let end = Self.dayKey(for: sevenDaysAgo)
        let w = entries.filter { $0.dayKey >= start && $0.dayKey < end }
        let count = w.reduce(0) { $0 + $1.repliesGenerated }
        guard count > 0 else { return 0 }
        return w.reduce(0) { $0 + $1[keyPath: keyPath] } / count
    }

    private static func dayKey(for date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([DayEntry].self, from: data) else { return }
        entries = decoded
    }
}

// MARK: - Day Entry

struct DayEntry: Codable, Identifiable {
    var id: String { dayKey }
    let dayKey: String              // "yyyy-MM-dd"
    var repliesGenerated: Int = 0
    var totalScore: Int = 0         // sum of overall scores
    var toneSum: Int = 0
    var claritySum: Int = 0
    var politenessSum: Int = 0
    var professionalismSum: Int = 0
    var brevitySum: Int = 0

    var averageScore: Int {
        guard repliesGenerated > 0 else { return 0 }
        return totalScore / repliesGenerated
    }

    var displayDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        guard let date = f.date(from: dayKey) else { return dayKey }
        let display = DateFormatter()
        display.dateFormat = "EEE"
        return display.string(from: date)
    }
}
