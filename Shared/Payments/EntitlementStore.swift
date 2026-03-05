import Foundation

/// App Group UserDefaults bridge for entitlement state.
/// Main app writes after every RevenueCat check; keyboard extension reads offline-first.
public final class EntitlementStore: @unchecked Sendable {
    public static let shared = EntitlementStore()

    private let defaults: UserDefaults

    private init() {
        self.defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    // MARK: - Read (safe from any target)

    public var isPro: Bool {
        guard defaults.bool(forKey: AppConstants.UserDefaultsKey.isProUser) else {
            return false
        }
        // Treat as free if the subscription has expired
        if let expiresAt = proExpiresAt, expiresAt < Date() {
            return false
        }
        return true
    }

    public var proExpiresAt: Date? {
        let interval = defaults.double(forKey: AppConstants.UserDefaultsKey.proExpiresAt)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    public var dailyLimit: Int {
        isPro ? AppConstants.Feature.proLimit : AppConstants.Feature.freeLimit
    }

    // MARK: - Write (main app only)

    public func sync(isPro: Bool, expiresAt: Date?) {
        defaults.set(isPro, forKey: AppConstants.UserDefaultsKey.isProUser)
        if let date = expiresAt {
            defaults.set(date.timeIntervalSince1970, forKey: AppConstants.UserDefaultsKey.proExpiresAt)
        } else {
            defaults.removeObject(forKey: AppConstants.UserDefaultsKey.proExpiresAt)
        }
    }

    public func revoke() {
        defaults.set(false, forKey: AppConstants.UserDefaultsKey.isProUser)
        defaults.removeObject(forKey: AppConstants.UserDefaultsKey.proExpiresAt)
    }
}
