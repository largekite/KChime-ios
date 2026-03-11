import Foundation

// MARK: - Result type

/// The output of a successful promise detection pass.
struct DetectedPromise: Equatable {
    let text: String              // original reply text
    let reminderDate: Date        // when to remind
    let dateDescription: String   // human-readable label shown in the banner
}

// MARK: - Detector

/// Detects commitment phrases ("I'll send it tonight") in a drafted reply and
/// extracts a suggested reminder time.
///
/// Detection pipeline:
///   1. Commitment-phrase scan (simple lowercased substring matching)
///   2. NSDataDetector date extraction (handles "tomorrow", "next Monday", "in 2 hours")
///   3. Keyword heuristic fallback for relative time words NSDataDetector misses
///      ("tonight", "this weekend", "later", etc.)
///   4. Default: tomorrow at 9 AM
///
/// All processing is local — no network calls, no PII logging.
enum PromiseDetector {

    // MARK: - Public

    static func detect(in text: String) -> DetectedPromise? {
        guard containsCommitment(text) else { return nil }
        let (date, description) = extractDate(from: text)
        return DetectedPromise(text: text, reminderDate: date, dateDescription: description)
    }

    // MARK: - Commitment phrase detection

    /// Simple substring scan. Avoids regex overhead in a keyboard context.
    private static let commitmentPhrases: [String] = [
        "i'll", "i will", "i am going to", "i'm going to",
        "let me", "i can get", "i promise", "i'll get back",
        "i'll follow up", "i'll send", "i'll check", "i'll look",
        "i'll reach out", "i'll take care", "i'll handle",
        "will do", "will get back", "will send", "will follow up",
    ]

    private static func containsCommitment(_ text: String) -> Bool {
        let lower = text.lowercased()
        return commitmentPhrases.contains { lower.contains($0) }
    }

    // MARK: - Date extraction

    private static func extractDate(from text: String) -> (Date, String) {
        // 1. Try NSDataDetector — parses "tomorrow", "next Monday", "in 2 hours", etc.
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = detector.matches(in: text, options: [], range: range)
            if let match = matches.first, let date = match.date {
                // Ensure we don't schedule in the past (e.g. "earlier today" parsed as past time)
                let future = max(date, Date().addingTimeInterval(60))
                return (future, formatDate(future))
            }
        }

        // 2. Keyword heuristics for relative time words NSDataDetector tends to miss
        return heuristicDate(from: text)
    }

    // MARK: - Heuristic fallback

    private static func heuristicDate(from text: String) -> (Date, String) {
        let lower = text.lowercased()
        let cal   = Calendar.current
        let now   = Date()

        // Helper: clamp to future if a same-day time has already passed
        func futureTime(_ date: Date) -> Date { max(date, now.addingTimeInterval(5 * 60)) }

        if lower.contains("tonight") {
            let d = cal.date(bySettingHour: 21, minute: 0, second: 0, of: now) ?? now
            return (futureTime(d), "tonight at 9 PM")
        }

        if lower.contains("this morning") || lower.contains("this am") {
            let d = cal.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
            return (futureTime(d), "this morning at 9 AM")
        }

        if lower.contains("this afternoon") {
            let d = cal.date(bySettingHour: 14, minute: 0, second: 0, of: now) ?? now
            return (futureTime(d), "this afternoon at 2 PM")
        }

        if lower.contains("this evening") {
            let d = cal.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now
            return (futureTime(d), "this evening at 6 PM")
        }

        if lower.contains("tomorrow morning") {
            guard let tomorrow = cal.date(byAdding: .day, value: 1, to: now),
                  let d = cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
            else { return defaultDate(cal: cal, now: now) }
            return (d, "tomorrow morning at 9 AM")
        }

        if lower.contains("tomorrow afternoon") {
            guard let tomorrow = cal.date(byAdding: .day, value: 1, to: now),
                  let d = cal.date(bySettingHour: 14, minute: 0, second: 0, of: tomorrow)
            else { return defaultDate(cal: cal, now: now) }
            return (d, "tomorrow afternoon at 2 PM")
        }

        if lower.contains("tomorrow") {
            guard let tomorrow = cal.date(byAdding: .day, value: 1, to: now),
                  let d = cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
            else { return defaultDate(cal: cal, now: now) }
            return (d, "tomorrow at 9 AM")
        }

        if lower.contains("this weekend") || lower.contains("over the weekend") {
            let weekday = cal.component(.weekday, from: now)     // 1 = Sun, 7 = Sat
            let daysToSaturday = (7 - weekday + 7) % 7
            guard let saturday = cal.date(byAdding: .day, value: max(daysToSaturday, 1), to: now),
                  let d = cal.date(bySettingHour: 10, minute: 0, second: 0, of: saturday)
            else { return defaultDate(cal: cal, now: now) }
            return (d, "this Saturday at 10 AM")
        }

        if lower.contains("end of the week") || lower.contains("end of week") || lower.contains("by friday") {
            let weekday = cal.component(.weekday, from: now)
            let daysToFriday = (6 - weekday + 7) % 7
            guard let friday = cal.date(byAdding: .day, value: max(daysToFriday, 1), to: now),
                  let d = cal.date(bySettingHour: 17, minute: 0, second: 0, of: friday)
            else { return defaultDate(cal: cal, now: now) }
            return (d, "this Friday at 5 PM")
        }

        if lower.contains("next week") {
            guard let d = cal.date(byAdding: .day, value: 7, to: now) else {
                return defaultDate(cal: cal, now: now)
            }
            let monday = nextMonday(from: d, cal: cal)
            guard let at9 = cal.date(bySettingHour: 9, minute: 0, second: 0, of: monday)
            else { return defaultDate(cal: cal, now: now) }
            return (at9, "next week (Monday at 9 AM)")
        }

        if lower.contains("in an hour") || lower.contains("in 1 hour") {
            return (now.addingTimeInterval(3600), "in 1 hour")
        }

        if lower.contains("in a few") || lower.contains("in a couple") {
            return (now.addingTimeInterval(2 * 3600), "in 2 hours")
        }

        if lower.contains("later today") || lower.contains("later this") {
            return (now.addingTimeInterval(3 * 3600), "in 3 hours")
        }

        if lower.contains("soon") || lower.contains("shortly") {
            return (now.addingTimeInterval(2 * 3600), "in 2 hours")
        }

        if lower.contains("later") {
            return (now.addingTimeInterval(4 * 3600), "in 4 hours")
        }

        // Default: tomorrow at 9 AM
        return defaultDate(cal: cal, now: now)
    }

    private static func defaultDate(cal: Calendar, now: Date) -> (Date, String) {
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: now),
              let d = cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
        else { return (now.addingTimeInterval(24 * 3600), "tomorrow at 9 AM") }
        return (d, "tomorrow at 9 AM")
    }

    // MARK: - Helpers

    private static func nextMonday(from date: Date, cal: Calendar) -> Date {
        var components = DateComponents()
        components.weekday = 2  // Monday
        return cal.nextDate(after: date, matching: components, matchingPolicy: .nextTime) ?? date
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }
}
