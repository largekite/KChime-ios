import Foundation

@MainActor
final class ShareViewModel: ObservableObject {
    @Published var receivedMessage: String
    @Published var suggestions: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var activeToneChip: ToneChip?
    @Published var copiedIndex: Int?
    @Published var savedIndex: Int?
    @Published var remaining = AppConstants.Feature.freeLimit

    enum ToneChip: String, CaseIterable, Identifiable {
        case warmer  = "Warmer"
        case shorter = "Shorter"
        case formal  = "More formal"
        var id: String { rawValue }
    }

    private var toneProfile: ToneProfile

    init(prefilledText: String) {
        self.receivedMessage = prefilledText
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
        if let data = defaults.data(forKey: AppConstants.UserDefaultsKey.toneProfile),
           let profile = try? JSONDecoder().decode(ToneProfile.self, from: data) {
            toneProfile = profile
        } else {
            toneProfile = .defaultProfile
        }
        if let cached = UsageCache.shared.cachedUsage(for: AppConstants.Feature.shareExtension) {
            remaining = cached.remaining
        }
    }

    func generate() async {
        guard !receivedMessage.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isLoading = true
        errorMessage = nil

        var payload = toneProfile.toPayload()
        if let chip = activeToneChip {
            let instruction: String
            switch chip {
            case .warmer:  instruction = "Make the reply warmer and friendlier."
            case .shorter: instruction = "Make the reply shorter — one sentence max."
            case .formal:  instruction = "Make the reply more formal and professional."
            }
            payload = ToneProfilePayload(
                label: payload.label,
                formality: payload.formality,
                emojiEnabled: payload.emojiEnabled,
                lengthPreference: payload.lengthPreference,
                customInstructions: instruction
            )
        }

        let request = ReplyRequest(
            featureKey: AppConstants.Feature.shareExtension,
            receivedMessage: receivedMessage,
            toneProfile: payload
        )

        do {
            try Task.checkCancellation()
            let response = try await KChimeAPIClient.shared.generateReplies(request: request)
            try Task.checkCancellation()
            suggestions = response.suggestions
            remaining   = response.remaining
            UsageCache.shared.setUsage(remaining: response.remaining, limit: response.limit,
                                       for: AppConstants.Feature.shareExtension)
        } catch KChimeError.limitReached {
            errorMessage = "Daily limit reached. Open KChime to upgrade to Pro."
            remaining = 0
        } catch is CancellationError {
            // Extension dismissed — silently stop
            return
        } catch {
            errorMessage = "Couldn't reach KChime — check your connection and try again."
        }

        isLoading = false
    }

    func copy(_ text: String, at index: Int) {
        UIPasteboard.general.setItems(
            [[UTType.plainText.identifier: text]],
            options: [.expirationDate: Date(timeIntervalSinceNow: 60)]
        )
        copiedIndex = index
        Task {
            try? await Task.sleep(for: .seconds(2))
            copiedIndex = nil
        }
    }

    func save(_ text: String, at index: Int) {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
        var pending = defaults.stringArray(forKey: "kchime_pending_saves") ?? []
        pending.append(text)
        defaults.set(pending, forKey: "kchime_pending_saves")
        savedIndex = index
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            savedIndex = nil
        }
    }
}

// Make UTType available without import in this file
import UniformTypeIdentifiers
