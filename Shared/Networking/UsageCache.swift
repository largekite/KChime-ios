import Foundation

/// Thread-safe local cache for usage counts. Reduces API calls from the keyboard extension.
/// Resets to the daily limit at UTC midnight automatically — no server call needed.
public final class UsageCache: @unchecked Sendable {
    public static let shared = UsageCache()

    private let defaults: UserDefaults
    private let lock = NSLock()
    private let cacheKey = "kchime_usage_cache_v1"
    private let cacheTTL: TimeInterval = 5 * 60  // 5 minutes; still valid within same day

    private init() {
        self.defaults = UserDefaults(suiteName: AppConstants.appGroupID) ?? .standard
    }

    private struct CacheEntry: Codable {
        let remaining: Int
        let limit: Int
        let fetchedAt: Date
        let dateKey: String   // UTC "YYYY-MM-DD" — used to detect day rollover
    }

    // MARK: - Today's UTC date key

    private static var todayUTC: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")
        return fmt.string(from: Date())
    }

    // MARK: - Public API

    /// Returns cached usage if still valid for today; nil triggers a fresh server fetch.
    public func cachedUsage(for featureKey: String) -> (remaining: Int, limit: Int)? {
        lock.withLock {
            guard
                let data = defaults.data(forKey: storageKey(featureKey)),
                let entry = try? JSONDecoder().decode(CacheEntry.self, from: data)
            else { return nil }

            let today = Self.todayUTC

            // Day rolled over — return a fresh allocation based on current entitlement
            if entry.dateKey != today {
                let limit = EntitlementStore.shared.dailyLimit
                _setUsage(remaining: limit, limit: limit, for: featureKey)
                return (limit, limit)
            }

            // TTL expired within same day — caller should re-fetch from server
            guard Date().timeIntervalSince(entry.fetchedAt) < cacheTTL else { return nil }

            return (entry.remaining, entry.limit)
        }
    }

    public func setUsage(remaining: Int, limit: Int, for featureKey: String) {
        lock.withLock {
            _setUsage(remaining: remaining, limit: limit, for: featureKey)
        }
    }

    /// Internal setter — caller must hold `lock`.
    private func _setUsage(remaining: Int, limit: Int, for featureKey: String) {
        let entry = CacheEntry(
            remaining: remaining,
            limit: limit,
            fetchedAt: Date(),
            dateKey: Self.todayUTC
        )
        if let data = try? JSONEncoder().encode(entry) {
            defaults.set(data, forKey: storageKey(featureKey))
        }
    }

    public func decrementLocally(for featureKey: String) {
        lock.withLock {
            guard
                let data = defaults.data(forKey: storageKey(featureKey)),
                let entry = try? JSONDecoder().decode(CacheEntry.self, from: data),
                entry.dateKey == Self.todayUTC
            else { return }
            _setUsage(remaining: max(0, entry.remaining - 1), limit: entry.limit, for: featureKey)
        }
    }

    public func invalidate(for featureKey: String) {
        defaults.removeObject(forKey: storageKey(featureKey))
    }

    // MARK: - Private

    private func storageKey(_ featureKey: String) -> String {
        "\(cacheKey)_\(featureKey)"
    }
}
