import Foundation

// MARK: - Confidence Score

struct ConfidenceScore: Identifiable {
    let id = UUID()
    let overall: Int                     // 0–100
    let breakdown: ConfidenceBreakdown

    /// Human-readable label for the overall score.
    var label: String {
        switch overall {
        case 90...100: return "Excellent"
        case 75..<90:  return "Strong"
        case 60..<75:  return "Good"
        case 40..<60:  return "Fair"
        default:       return "Needs work"
        }
    }

    var color: String {
        switch overall {
        case 80...100: return "green"
        case 60..<80:  return "teal"
        case 40..<60:  return "orange"
        default:       return "red"
        }
    }
}

struct ConfidenceBreakdown {
    let tone: ScoreDimension
    let clarity: ScoreDimension
    let politeness: ScoreDimension
    let professionalism: ScoreDimension
    let brevity: ScoreDimension

    var dimensions: [(label: String, icon: String, dimension: ScoreDimension)] {
        [
            ("Professional tone", "person.fill.checkmark", tone),
            ("Clarity", "text.alignleft", clarity),
            ("Politeness", "hand.wave.fill", politeness),
            ("Professionalism", "briefcase.fill", professionalism),
            ("Conciseness", "arrow.down.right.and.arrow.up.left", brevity),
        ]
    }
}

enum ScoreDimension: String {
    case high   = "High"
    case medium = "Medium"
    case low    = "Low"

    var numericValue: Int {
        switch self {
        case .high:   return 90
        case .medium: return 65
        case .low:    return 35
        }
    }

    var color: String {
        switch self {
        case .high:   return "green"
        case .medium: return "orange"
        case .low:    return "red"
        }
    }
}

// MARK: - Local Confidence Scorer

/// Scores a reply locally using text heuristics.
/// No message content leaves the device — only numeric metrics are stored.
enum ConfidenceScorer {

    static func score(_ reply: String) -> ConfidenceScore {
        let tone = evaluateTone(reply)
        let clarity = evaluateClarity(reply)
        let politeness = evaluatePoliteness(reply)
        let professionalism = evaluateProfessionalism(reply)
        let brevity = evaluateBrevity(reply)

        let breakdown = ConfidenceBreakdown(
            tone: tone,
            clarity: clarity,
            politeness: politeness,
            professionalism: professionalism,
            brevity: brevity
        )

        let overall = computeOverall(breakdown)
        return ConfidenceScore(overall: overall, breakdown: breakdown)
    }

    // MARK: - Dimension Evaluators

    private static func evaluateTone(_ text: String) -> ScoreDimension {
        let lower = text.lowercased()
        let positiveMarkers = ["thank", "appreciate", "glad", "happy", "great", "hope", "looking forward"]
        let negativeMarkers = ["whatever", "idc", "lol", "lmao", "bruh", "smh", "tbh"]

        let positiveCount = positiveMarkers.filter { lower.contains($0) }.count
        let negativeCount = negativeMarkers.filter { lower.contains($0) }.count

        if positiveCount >= 2 && negativeCount == 0 { return .high }
        if negativeCount >= 2 { return .low }
        if positiveCount >= 1 { return .high }
        if negativeCount >= 1 { return .medium }
        return .medium
    }

    private static func evaluateClarity(_ text: String) -> ScoreDimension {
        let words = text.split(separator: " ")
        let avgWordLength = words.isEmpty ? 0 : words.reduce(0) { $0 + $1.count } / words.count

        // Clear sentences: moderate length, punctuation present
        let hasPunctuation = text.contains(".") || text.contains("!") || text.contains("?")
        let sentenceCount = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count

        if hasPunctuation && sentenceCount >= 1 && sentenceCount <= 4 && avgWordLength < 10 {
            return .high
        }
        if !hasPunctuation || sentenceCount > 5 { return .medium }
        return .medium
    }

    private static func evaluatePoliteness(_ text: String) -> ScoreDimension {
        let lower = text.lowercased()
        let politeMarkers = ["please", "thank", "appreciate", "sorry", "excuse me", "would you",
                             "could you", "kindly", "grateful", "no worries", "pardon"]
        let rudeMarkers = ["whatever", "ugh", "seriously?", "fine.", "k", "nah"]

        let politeCount = politeMarkers.filter { lower.contains($0) }.count
        let rudeCount = rudeMarkers.filter { lower.contains($0) }.count

        if politeCount >= 2 && rudeCount == 0 { return .high }
        if rudeCount >= 2 { return .low }
        if politeCount >= 1 { return .high }
        if rudeCount >= 1 { return .medium }
        // Neutral-to-polite messages score medium
        return .medium
    }

    private static func evaluateProfessionalism(_ text: String) -> ScoreDimension {
        let lower = text.lowercased()
        let proMarkers = ["update", "follow up", "schedule", "review", "confirm", "discuss",
                          "regarding", "attached", "deadline", "priority", "circl"]
        let casualMarkers = ["lol", "haha", "omg", "gonna", "wanna", "gotta", "ngl", "tbh",
                             "bruh", "yo ", "dude"]

        let proCount = proMarkers.filter { lower.contains($0) }.count
        let casualCount = casualMarkers.filter { lower.contains($0) }.count

        if proCount >= 2 && casualCount == 0 { return .high }
        if casualCount >= 2 { return .low }
        if proCount >= 1 && casualCount == 0 { return .high }
        if casualCount >= 1 { return .medium }
        return .medium
    }

    private static func evaluateBrevity(_ text: String) -> ScoreDimension {
        let wordCount = text.split(separator: " ").count
        if wordCount <= 25 { return .high }
        if wordCount <= 50 { return .medium }
        return .low
    }

    // MARK: - Overall

    private static func computeOverall(_ b: ConfidenceBreakdown) -> Int {
        let weights: [(ScoreDimension, Double)] = [
            (b.tone, 0.25),
            (b.clarity, 0.20),
            (b.politeness, 0.20),
            (b.professionalism, 0.20),
            (b.brevity, 0.15),
        ]
        let raw = weights.reduce(0.0) { $0 + Double($1.0.numericValue) * $1.1 }
        // Add slight randomness for natural feel (±3)
        let jitter = Int.random(in: -3...3)
        return min(100, max(0, Int(raw) + jitter))
    }
}
