import SwiftUI
import KeychainSwift
import RevenueCat

@MainActor
final class AppState: ObservableObject {
    @Published var onboardingComplete: Bool
    @Published var privacyAccepted: Bool
    @Published var isPro: Bool
    @Published var toneProfile: ToneProfile

    private let defaults: UserDefaults
    private let keychain = KeychainSwift()

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

        // Mirror RevenueCatService's isPro into this object whenever it changes
        Task {
            for await pro in RevenueCatService.shared.$isPro.values {
                self.isPro = pro
            }
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

    // MARK: - Subscription (delegates to RevenueCatService)

    func purchasePro(package: Package) async throws {
        try await RevenueCatService.shared.purchase(package: package)
    }

    func restorePurchases() async throws {
        try await RevenueCatService.shared.restorePurchases()
    }

    enum StoreError: Error, LocalizedError {
        case productNotFound
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .productNotFound: return "Pro subscription not available. Try again later."
            case .verificationFailed: return "Purchase could not be verified. Contact support."
            }
        }
    }
}
