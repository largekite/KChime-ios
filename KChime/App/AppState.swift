import SwiftUI
import KeychainSwift
import StoreKit

@MainActor
final class AppState: ObservableObject {
    @Published var onboardingComplete: Bool
    @Published var privacyAccepted: Bool
    @Published var isPro: Bool
    @Published var toneProfile: ToneProfile

    private let defaults: UserDefaults
    private let keychain = KeychainSwift()
    private var transactionListener: Task<Void, Error>?

    init() {
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
        self.defaults = defaults
        self.onboardingComplete = defaults.bool(forKey: AppConstants.UserDefaultsKey.onboardingComplete)
        self.privacyAccepted = defaults.bool(forKey: AppConstants.UserDefaultsKey.privacyAccepted)
        self.isPro = defaults.bool(forKey: AppConstants.UserDefaultsKey.isProUser)

        if let data = defaults.data(forKey: AppConstants.UserDefaultsKey.toneProfile),
           let profile = try? JSONDecoder().decode(ToneProfile.self, from: data) {
            self.toneProfile = profile
        } else {
            self.toneProfile = .defaultProfile
        }

        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
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

    // MARK: - Subscription

    func purchasePro() async throws {
        guard let product = try await Product.products(for: [AppConstants.StoreKit.proMonthlyProductID]).first else {
            throw StoreError.productNotFound
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                unlockPro()
            case .unverified:
                throw StoreError.verificationFailed
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == AppConstants.StoreKit.proMonthlyProductID {
                unlockPro()
                await transaction.finish()
            }
        }
    }

    private func unlockPro() {
        isPro = true
        defaults.set(true, forKey: AppConstants.UserDefaultsKey.isProUser)
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await MainActor.run { self?.unlockPro() }
                    await transaction.finish()
                }
            }
        }
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
