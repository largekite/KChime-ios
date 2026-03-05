import Foundation
import RevenueCat

/// Singleton that owns all RevenueCat SDK interactions.
/// Only link this file in the main app target — the keyboard extension
/// reads entitlement state from EntitlementStore (App Group UserDefaults).
@MainActor
public final class RevenueCatService: ObservableObject {
    public static let shared = RevenueCatService()

    @Published public var isPro: Bool = EntitlementStore.shared.isPro
    @Published public var currentOffering: Offering?
    @Published public var isLoading: Bool = false
    @Published public var purchaseError: String?

    private init() {}

    // MARK: - Setup (call once on app launch)

    public static func configure() {
        Purchases.configure(withAPIKey: AppConstants.RevenueCat.publicKey)
        Purchases.shared.delegate = PurchaseDelegate.shared
        Task { @MainActor in
            await RevenueCatService.shared.refreshEntitlement()
        }
    }

    // MARK: - Identity

    /// Call after Sign in with Apple succeeds.
    public func identify(appleUserID: String) async {
        do {
            let (info, _) = try await Purchases.shared.logIn(appleUserID)
            apply(customerInfo: info)
        } catch {
            // Non-fatal: entitlement state from cache still valid
        }
    }

    public func logOut() async {
        _ = try? await Purchases.shared.logOut()
        EntitlementStore.shared.revoke()
        isPro = false
    }

    // MARK: - Offerings

    public func fetchOfferings() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.offering(identifier: AppConstants.RevenueCat.offeringID)
                ?? offerings.current
        } catch {
            // Offline — proceed with cached entitlement
        }
    }

    // MARK: - Purchase

    public func purchase(package: Package) async throws {
        isLoading = true
        defer { isLoading = false }
        let result = try await Purchases.shared.purchase(package: package)
        apply(customerInfo: result.customerInfo)
    }

    public func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        let info = try await Purchases.shared.restorePurchases()
        apply(customerInfo: info)
    }

    // MARK: - Refresh

    public func refreshEntitlement() async {
        guard let info = try? await Purchases.shared.customerInfo() else { return }
        apply(customerInfo: info)
    }

    // MARK: - Internal

    func apply(customerInfo: CustomerInfo) {
        let entitlement = customerInfo.entitlements[AppConstants.RevenueCat.proEntitlementID]
        let active = entitlement?.isActive == true
        let expiresAt = entitlement?.expirationDate
        EntitlementStore.shared.sync(isPro: active, expiresAt: expiresAt)
        isPro = EntitlementStore.shared.isPro
    }
}

// MARK: - Delegate

private final class PurchaseDelegate: NSObject, PurchasesDelegate, @unchecked Sendable {
    static let shared = PurchaseDelegate()

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            RevenueCatService.shared.apply(customerInfo: customerInfo)
        }
    }
}
