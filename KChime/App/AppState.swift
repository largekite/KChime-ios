import SwiftUI
import KeychainSwift

@MainActor
final class AppState: ObservableObject {
    @Published var onboardingComplete: Bool
    @Published var privacyAccepted: Bool
    @Published var isPro: Bool
    @Published var toneProfile: ToneProfile

    // Deep-link routing state (set by KChimeApp, consumed by MainTabView)
    @Published var deepLinkShowPaywall = false
    @Published var deepLinkTab: Int? = nil

    private let defaults: UserDefaults

    init() {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
        self.defaults = defaults
        self.onboardingComplete = defaults.bool(forKey: AppConstants.UserDefaultsKey.onboardingComplete)
        self.privacyAccepted = defaults.bool(forKey: AppConstants.UserDefaultsKey.privacyAccepted)
        self.isPro = EntitlementStore.shared.isPro

        if let data = defaults.data(forKey: AppConstants.UserDefaultsKey.toneProfile),
           let profile = try? JSONDecoder().decode(ToneProfile.self, from: data) {
            self.toneProfile = profile
        } else {
            self.toneProfile = .defaultProfile
        }
    }

    // MARK: - Onboarding

    func completePrivacyAcceptance() {
        privacyAccepted = true
        defaults.set(true, forKey: AppConstants.UserDefaultsKey.privacyAccepted)
    }

    func completeOnboarding() {
        onboardingComplete = true
        defaults.set(true, forKey: AppConstants.UserDefaultsKey.onboardingComplete)
    }

    func saveToneProfile(_ profile: ToneProfile) {
        toneProfile = profile
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: AppConstants.UserDefaultsKey.toneProfile)
        }
    }

    /// Persists the contact-context selection from onboarding.
    func saveSelectedContacts(_ selectedIDs: Set<String>) {
        let all = RelationshipProfileStore.shared.allProfiles
        let priority = ["boss", "client", "teacher", "coworker", "family", "friend"]
        let defaultID = priority.first { selectedIDs.contains($0) } ?? selectedIDs.first
        RelationshipProfileStore.shared.selectedProfile =
            defaultID.flatMap { id in all.first(where: { $0.id == id }) }
    }

    // MARK: - Subscription

    /// Called after sign-in to reflect the server's Pro status in the UI.
    func refreshProStatus() {
        isPro = EntitlementStore.shared.isPro
    }
}
