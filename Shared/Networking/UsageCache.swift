import Foundation

/// Thread-safe local cache for usage counts. Reduces API calls from the keyboard extension.
public final class UsageCache: @unchecked Sendable {
    public static let shared = UsageCache()

    private let defaults: UserDefaults
    private let cacheKey = "kchime_usage_cache_v1"
    private let cacheTTL: TimeInterval = 5 * 60  // 5 minutes

    private init() {
        self.defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    private struct CacheEntry: Codable {
        let remaining: Int
        let limit: Int
        let fetchedAt: Date
    }

    public func cachedUsage(for featureKey: String) -> (remaining: Int, limit: Int)? {
        guard
            let data = defaults.data(forKey: "\(cacheKey)_\(featureKey)"),
            let entry = try? JSONDecoder().decode(CacheEntry.self, from: data),
            Date().timeIntervalSince(entry.fetchedAt) < cacheTTL
        else { return nil }
        return (entry.remaining, entry.limit)
    }

    public func setUsage(remaining: Int, limit: Int, for featureKey: String) {
        let entry = CacheEntry(remaining: remaining, limit: limit, fetchedAt: Date())
        if let data = try? JSONEncoder().encode(entry) {
            defaults.set(data, forKey: "\(cacheKey)_\(featureKey)")
        }
    }

    public func decrementLocally(for featureKey: String) {
        guard let current = cachedUsage(for: featureKey) else { return }
        setUsage(remaining: max(0, current.remaining - 1), limit: current.limit, for: featureKey)
    }

    public func invalidate(for featureKey: String) {
        defaults.removeObject(forKey: "\(cacheKey)_\(featureKey)")
    }
}
