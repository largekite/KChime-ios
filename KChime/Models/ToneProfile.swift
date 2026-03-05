import Foundation

struct ToneProfile: Codable, Equatable, Identifiable {
    var id: UUID
    var label: String
    var formality: Double       // 0.0 = casual, 1.0 = formal
    var emojiEnabled: Bool
    var lengthPreference: LengthPreference
    var customInstructions: String?

    enum LengthPreference: String, Codable, CaseIterable {
        case short   = "short"
        case medium  = "medium"
        case verbose = "verbose"

        var displayName: String {
            switch self {
            case .short:   return "Brief"
            case .medium:  return "Balanced"
            case .verbose: return "Detailed"
            }
        }
    }

    // MARK: - Presets

    static let defaultProfile = ToneProfile(
        id: UUID(),
        label: "Warm & direct",
        formality: 0.35,
        emojiEnabled: false,
        lengthPreference: .medium,
        customInstructions: nil
    )

    static let allPresets: [ToneProfile] = [
        ToneProfile(id: UUID(), label: "Warm & direct",   formality: 0.35, emojiEnabled: false, lengthPreference: .medium),
        ToneProfile(id: UUID(), label: "Formal & brief",  formality: 0.85, emojiEnabled: false, lengthPreference: .short),
        ToneProfile(id: UUID(), label: "Casual & friendly", formality: 0.1, emojiEnabled: true, lengthPreference: .medium),
    ]

    // Convert to API payload
    func toPayload() -> ToneProfilePayload {
        ToneProfilePayload(
            label: label,
            formality: formality,
            emojiEnabled: emojiEnabled,
            lengthPreference: lengthPreference.rawValue,
            customInstructions: customInstructions
        )
    }
}

// MARK: - Tone Detection Heuristic

struct ToneDetector {
    /// Infer a tone from how the user reacted to 5 sample swipe cards.
    /// likes: indices the user swiped right on (approves).
    static func detect(from samples: [SampleReply], likes: Set<Int>) -> ToneProfile {
        let likedSamples = samples.enumerated().compactMap { likes.contains($0.offset) ? $0.element : nil }

        let avgFormality = likedSamples.isEmpty ? 0.35 :
            likedSamples.map(\.formalityHint).reduce(0, +) / Double(likedSamples.count)

        let emojiEnabled = likedSamples.contains { $0.hasEmoji }

        let avgLength = likedSamples.isEmpty ? 1 :
            likedSamples.map(\.wordCount).reduce(0, +) / likedSamples.count

        let length: ToneProfile.LengthPreference = avgLength < 8 ? .short : avgLength < 18 ? .medium : .verbose

        let label: String
        if avgFormality > 0.6 { label = "Formal & brief" }
        else if emojiEnabled  { label = "Casual & friendly" }
        else                  { label = "Warm & direct" }

        return ToneProfile(id: UUID(), label: label, formality: avgFormality,
                           emojiEnabled: emojiEnabled, lengthPreference: length)
    }
}

struct SampleReply: Identifiable {
    let id = UUID()
    let scenario: String
    let replyText: String
    let formalityHint: Double
    let hasEmoji: Bool

    var wordCount: Int { replyText.split(separator: " ").count }

    static let all: [SampleReply] = [
        SampleReply(scenario: "Running 10 min late to school pickup",
                    replyText: "On my way! Be there in 10.",
                    formalityHint: 0.2, hasEmoji: false),
        SampleReply(scenario: "Declining a party invite",
                    replyText: "Thanks so much for the invite — I won't be able to make it, but hope it's a great time!",
                    formalityHint: 0.4, hasEmoji: false),
        SampleReply(scenario: "Thanking a teacher",
                    replyText: "Thank you for the update. We appreciate your time and dedication.",
                    formalityHint: 0.85, hasEmoji: false),
        SampleReply(scenario: "Confirming weekend plans",
                    replyText: "Sounds good! See you Saturday",
                    formalityHint: 0.15, hasEmoji: false),
        SampleReply(scenario: "Responding to a neighbor's complaint",
                    replyText: "So sorry about that! We'll keep it down.",
                    formalityHint: 0.3, hasEmoji: false),
    ]
}
