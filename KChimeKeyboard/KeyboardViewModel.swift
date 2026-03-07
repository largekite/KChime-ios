import UIKit
import Combine

@MainActor
final class KeyboardViewModel: ObservableObject {

    // MARK: - Published state

    @Published var receivedMessage = ""
    @Published var suggestions: [String] = []
    @Published var longerAlternative: String?
    @Published var isLoading = false
    @Published var errorState: ErrorState?

    @Published var remaining: Int
    @Published var limit: Int

    /// Which tone modifier chip is active (changes the *next* generation)
    @Published var activeToneChip: ToneChip?
    /// How many regenerations have happened this session (cap = 3)
    @Published var regenerationsUsed = 0
    /// Index briefly highlighted green after a successful insert
    @Published var insertedIndex: Int?

    /// The relationship profile selected in the picker; persisted across sessions
    @Published var selectedRelationshipProfile: RelationshipProfile? {
        didSet { RelationshipProfileStore.shared.selectedProfile = selectedRelationshipProfile }
    }

    @Published var showMemoryBanner = false
    @Published var showContactNoteSheet = false

    /// Non-nil when the last inserted suggestion contained a promise phrase.
    /// Drives the PromiseBannerView in KeyboardView.
    @Published var detectedPromise: DetectedPromise?

    // MARK: - Types

    enum ToneChip: String, CaseIterable, Identifiable {
        case shorter    = "Shorter"
        case formal     = "More formal"
        case friendlier = "More friendly"
        case rewrite    = "Rewrite"    // Pro only

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .shorter:    return "text.badge.minus"
            case .formal:     return "briefcase"
            case .friendlier: return "face.smiling"
            case .rewrite:    return "arrow.2.squarepath"
            }
        }

        /// Only shown to free users as a locked chip.
        var requiresPro: Bool { self == .rewrite }
    }

    enum ErrorState: Equatable {
        case limitReached
        case unauthenticated
        case network
        case regenerationLimitReached
        case proRequired
        case custom(String)

        var message: String {
            switch self {
            case .limitReached:
                return "You've used all 10 free replies for today."
            case .unauthenticated:
                return "Open the KChime app and sign in to use the keyboard."
            case .network:
                return "Couldn't reach KChime — check your connection."
            case .regenerationLimitReached:
                return "Regeneration limit reached for this session."
            case .proRequired:
                return "Rewrite is a Pro feature. Upgrade to unlock it."
            case .custom(let msg):
                return msg
            }
        }

        var showsUpgradeButton: Bool { self == .limitReached || self == .proRequired }
    }

    /// True when the current user has an active Pro subscription (read from App Group UDs).
    var isPro: Bool { EntitlementStore.shared.isPro }

    // MARK: - Private

    private weak var textProxy: UITextDocumentProxy?
    private let maxRegenerations = 3
    private var baseProfile: ToneProfile

    // MARK: - Init

    init(textProxy: UITextDocumentProxy) {
        self.textProxy = textProxy
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard

        if let data = defaults.data(forKey: AppConstants.UserDefaultsKey.toneProfile),
           let profile = try? JSONDecoder().decode(ToneProfile.self, from: data) {
            baseProfile = profile
        } else {
            baseProfile = .defaultProfile
        }

        let dailyLimit = EntitlementStore.shared.dailyLimit
        if let cached = UsageCache.shared.cachedUsage(for: AppConstants.Feature.keyboard) {
            remaining = cached.remaining
            limit     = cached.limit
        } else {
            remaining = dailyLimit
            limit     = dailyLimit
        }

        // Restore last-used relationship profile
        selectedRelationshipProfile = RelationshipProfileStore.shared.selectedProfile

        Task { await refreshUsage() }
    }

    // MARK: - Generation

    func generate() async {
        guard !receivedMessage.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard remaining > 0 else { errorState = .limitReached; return }
        activeToneChip = nil
        regenerationsUsed = 0
        await runGeneration(chip: nil)
    }

    func applyToneChip(_ chip: ToneChip) async {
        if chip.requiresPro && !isPro {
            errorState = .proRequired
            openPaywall()
            return
        }
        guard remaining > 0 else { errorState = .limitReached; return }
        guard regenerationsUsed < maxRegenerations else {
            errorState = .regenerationLimitReached; return
        }
        activeToneChip = chip
        regenerationsUsed += 1
        await runGeneration(chip: chip)
    }

    func regenerate() async {
        guard !receivedMessage.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard remaining > 0 else { errorState = .limitReached; return }
        guard regenerationsUsed < maxRegenerations else {
            errorState = .regenerationLimitReached; return
        }
        regenerationsUsed += 1
        await runGeneration(chip: activeToneChip)
    }

    // MARK: - Insert / Copy / Save

    func insertSuggestion(_ text: String, at index: Int) {
        textProxy?.insertText(text)
        insertedIndex = index
        UsageCache.shared.decrementLocally(for: AppConstants.Feature.keyboard)

        // Run promise detection on the inserted text.
        let promise = PromiseDetector.detect(in: text)
        detectedPromise = promise

        Task {
            try? await Task.sleep(for: .milliseconds(700))
            insertedIndex = nil
            // Only surface the memory opt-in banner if no promise was detected.
            if detectedPromise == nil {
                try? await Task.sleep(for: .seconds(2))
                showMemoryBanner = true
            }
        }
    }

    // MARK: - Promise actions

    /// Called when the user taps "Set" on the PromiseBannerView.
    /// Persists the promise and schedules a local notification.
    func confirmPromise() {
        guard let detected = detectedPromise else { return }
        let promise = KChimePromise(
            id: UUID(),
            text: detected.text,
            reminderDate: detected.reminderDate,
            notificationID: UUID().uuidString,
            createdAt: Date(),
            isCompleted: false
        )
        PromiseStore.shared.add(promise)
        PromiseNotificationScheduler.schedule(promise)
        detectedPromise = nil
        // Show memory banner after promise is confirmed
        Task {
            try? await Task.sleep(for: .seconds(1))
            showMemoryBanner = true
        }
    }

    /// Called when the user dismisses the PromiseBannerView without setting a reminder.
    func dismissPromise() {
        detectedPromise = nil
        Task {
            try? await Task.sleep(for: .seconds(1))
            showMemoryBanner = true
        }
    }

    func copySuggestion(_ text: String) {
        UIPasteboard.general.string = text
    }

    func saveSuggestion(_ text: String) {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID)!
        var pending = defaults.stringArray(forKey: "kchime_pending_saves") ?? []
        pending.append(text)
        defaults.set(pending, forKey: "kchime_pending_saves")
    }

    func dismissError() { errorState = nil }

    /// Opens the main app to the paywall via a deep-link URL.
    /// The keyboard extension cannot present modal UI directly.
    func openPaywall() {
        guard let url = URL(string: "kchime://paywall") else { return }
        _ = url   // Keyboard extensions open URLs via the responder chain; caller handles this.
        // In KeyboardViewController, observe errorState == .proRequired and call
        //   self.extensionContext?.open(url, completionHandler: nil)
        NotificationCenter.default.post(name: .kchimeOpenPaywall, object: nil)
    }

    private func runGeneration(chip: ToneChip?) async {
        isLoading = true
        errorState = nil

        let request = ReplyRequest(
            featureKey: AppConstants.Feature.keyboard,
            receivedMessage: receivedMessage.trimmingCharacters(in: .whitespaces),
            toneProfile: makePayload(chip: chip),
            relationshipProfile: selectedRelationshipProfile?.toPayload()
        )

        do {
            let response = try await KChimeAPIClient.shared.generateReplies(request: request)
            suggestions        = response.suggestions
            longerAlternative  = response.longerAlternative.isEmpty ? nil : response.longerAlternative
            remaining          = response.remaining
            limit              = response.limit
            UsageCache.shared.setUsage(remaining: response.remaining,
                                       limit: response.limit,
                                       for: AppConstants.Feature.keyboard)
        } catch KChimeError.limitReached {
            errorState = .limitReached
            remaining  = 0
        } catch KChimeError.unauthenticated {
            errorState = .unauthenticated
        } catch {
            errorState = .network
        }

        isLoading = false
    }

    private func makePayload(chip: ToneChip?) -> ToneProfilePayload {
        guard let chip else { return baseProfile.toPayload() }
        switch chip {
        case .shorter:
            return ToneProfilePayload(label: baseProfile.label, formality: baseProfile.formality,
                                      emojiEnabled: baseProfile.emojiEnabled, lengthPreference: "short",
                                      customInstructions: "Be very concise — one sentence maximum.")
        case .formal:
            return ToneProfilePayload(label: baseProfile.label,
                                      formality: min(baseProfile.formality + 0.35, 1.0),
                                      emojiEnabled: false,
                                      lengthPreference: baseProfile.lengthPreference.rawValue,
                                      customInstructions: "Use a professional, formal tone.")
        case .friendlier:
            return ToneProfilePayload(label: baseProfile.label,
                                      formality: max(baseProfile.formality - 0.3, 0.0),
                                      emojiEnabled: true,
                                      lengthPreference: baseProfile.lengthPreference.rawValue,
                                      customInstructions: "Sound warm, upbeat, and genuinely friendly.")
        case .rewrite:
            return ToneProfilePayload(label: baseProfile.label, formality: baseProfile.formality,
                                      emojiEnabled: baseProfile.emojiEnabled,
                                      lengthPreference: baseProfile.lengthPreference.rawValue,
                                      customInstructions: "Rewrite completely — different phrasing, same meaning.")
        }
    }

    private func refreshUsage() async {
        guard let result = try? await KChimeAPIClient.shared.fetchUsage(
            featureKey: AppConstants.Feature.keyboard
        ) else { return }
        remaining = result.remaining
        limit     = result.limit
        UsageCache.shared.setUsage(remaining: result.remaining, limit: result.limit,
                                   for: AppConstants.Feature.keyboard)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let kchimeOpenPaywall = Notification.Name("com.kchime.openPaywall")
}
