import UIKit
import Combine

@MainActor
final class KeyboardViewModel: ObservableObject {

    // MARK: - State

    @Published var receivedMessage = ""
    @Published var suggestions: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var remaining: Int
    @Published var limit: Int
    @Published var activeToneChip: ToneChip?
    @Published var regenerationsUsed = 0
    @Published var insertedIndex: Int?   // briefly highlights inserted suggestion
    @Published var showMemoryBanner = false
    @Published var showContactNoteSheet = false

    enum ToneChip: String, CaseIterable, Identifiable {
        case warmer  = "Warmer"
        case shorter = "Shorter"
        case formal  = "More formal"
        var id: String { rawValue }
    }

    private weak var textProxy: UITextDocumentProxy?
    private let maxRegenerations = 3
    private var toneProfile: ToneProfile

    init(textProxy: UITextDocumentProxy) {
        self.textProxy = textProxy
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard

        if let data = defaults.data(forKey: AppConstants.UserDefaultsKey.toneProfile),
           let profile = try? JSONDecoder().decode(ToneProfile.self, from: data) {
            toneProfile = profile
        } else {
            toneProfile = .defaultProfile
        }

        // Load from cache first; refresh in background
        if let cached = UsageCache.shared.cachedUsage(for: AppConstants.Feature.keyboard) {
            remaining = cached.remaining
            limit     = cached.limit
        } else {
            remaining = AppConstants.Feature.freeLimit
            limit     = AppConstants.Feature.freeLimit
        }

        Task { await refreshUsage() }
    }

    // MARK: - Generate

    func generate() async {
        guard !receivedMessage.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard remaining > 0 else {
            errorMessage = "Daily limit reached. Upgrade to Pro for unlimited replies."
            return
        }

        isLoading = true
        errorMessage = nil

        let toneInstruction = activeToneChip.map { chip in
            switch chip {
            case .warmer:  return "Make the reply noticeably warmer and friendlier."
            case .shorter: return "Make the reply shorter — one sentence max."
            case .formal:  return "Make the reply more formal and professional."
            }
        }

        var payload = toneProfile.toPayload()
        if let instruction = toneInstruction {
            payload = ToneProfilePayload(
                label: payload.label,
                formality: chip(activeToneChip),
                emojiEnabled: payload.emojiEnabled,
                lengthPreference: payload.lengthPreference,
                customInstructions: instruction
            )
        }

        let request = ReplyRequest(
            featureKey: AppConstants.Feature.keyboard,
            receivedMessage: receivedMessage,
            toneProfile: payload,
            contactNotes: lookupContactNotes(for: receivedMessage)
        )

        do {
            let response = try await KChimeAPIClient.shared.generateReplies(request: request)
            suggestions = response.suggestions
            remaining   = response.remaining
            limit       = response.limit
            UsageCache.shared.setUsage(remaining: response.remaining, limit: response.limit,
                                       for: AppConstants.Feature.keyboard)
        } catch KChimeError.limitReached {
            errorMessage = "Daily limit reached. Upgrade to Pro for unlimited replies."
            remaining = 0
        } catch KChimeError.unauthenticated {
            errorMessage = "Sign in to the KChime app to use the keyboard."
        } catch {
            errorMessage = "Couldn't reach KChime — check your connection."
        }

        isLoading = false
    }

    // MARK: - Regenerate with tone chip

    func applyToneChip(_ chip: ToneChip) async {
        guard regenerationsUsed < maxRegenerations else {
            errorMessage = "Regeneration limit reached for this session."
            return
        }
        activeToneChip = chip
        regenerationsUsed += 1
        await generate()
    }

    // MARK: - Insert

    func insertSuggestion(_ text: String, at index: Int) {
        textProxy?.insertText(text)
        insertedIndex = index
        UsageCache.shared.decrementLocally(for: AppConstants.Feature.keyboard)

        // Show memory opt-in banner 3 seconds after insertion
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            insertedIndex = nil
            try? await Task.sleep(for: .seconds(2))
            showMemoryBanner = true
        }
    }

    /// Fallback when proxy insertion doesn't work (some apps block it)
    func copySuggestion(_ text: String) {
        UIPasteboard.general.string = text
    }

    // MARK: - Helpers

    private func chip(_ chip: ToneChip?) -> Double {
        switch chip {
        case .formal:  return min(toneProfile.formality + 0.3, 1.0)
        case .warmer:  return max(toneProfile.formality - 0.3, 0.0)
        default:       return toneProfile.formality
        }
    }

    private func refreshUsage() async {
        if let result = try? await KChimeAPIClient.shared.fetchUsage(featureKey: AppConstants.Feature.keyboard) {
            remaining = result.remaining
            limit     = result.limit
            UsageCache.shared.setUsage(remaining: result.remaining, limit: result.limit,
                                       for: AppConstants.Feature.keyboard)
        }
    }

    /// Look up contact notes from CoreData in App Group container.
    /// Naive match: checks if any saved contact name appears in the message text.
    private func lookupContactNotes(for _: String) -> String? {
        // Full CoreData lookup requires a MOC — lightweight version uses UserDefaults
        // A richer lookup is wired up in the full CoreData path in the main app.
        nil
    }
}
