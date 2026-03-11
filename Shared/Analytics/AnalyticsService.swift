import Foundation

// MARK: - Adapter protocol

/// Conform to this protocol to add a new analytics destination.
/// All adapters receive pre-validated, PII-free event payloads.
public protocol AnalyticsAdapter: Sendable {
    func track(name: String, properties: [String: Any])
    func identify(anonymousID: String)
}

// MARK: - Service

/// Central analytics router. Fan-outs to all registered adapters.
/// Thread-safe — `track` is called from the main actor; adapters dispatch internally.
public final class AnalyticsService: @unchecked Sendable {
    public static let shared = AnalyticsService()

    private var adapters: [any AnalyticsAdapter] = [ConsoleAnalyticsAdapter()]
    private let lock = NSLock()

    private init() {}

    // MARK: - Registration

    /// Call from app launch (main app target only) to add production adapters.
    /// The keyboard extension uses only the default ConsoleAdapter.
    public func register(_ adapter: any AnalyticsAdapter) {
        lock.withLock { adapters.append(adapter) }
    }

    public func clearAdapters() {
        lock.withLock { adapters = [] }
    }

    // MARK: - Tracking

    public func track(_ event: AnalyticsEvent) {
        let name = event.name
        let props = event.properties
        let snapshot = lock.withLock { adapters }
        for adapter in snapshot {
            adapter.track(name: name, properties: props)
        }
    }

    /// Call once on launch with the anonymous device ID from App Group UserDefaults.
    /// Never pass Apple User ID or email here.
    public func identify(anonymousID: String) {
        let snapshot = lock.withLock { adapters }
        for adapter in snapshot {
            adapter.identify(anonymousID: anonymousID)
        }
    }
}

// MARK: - Console adapter (always active; no-op in release builds unless env var set)

public struct ConsoleAnalyticsAdapter: AnalyticsAdapter, Sendable {
    public init() {}

    public func track(name: String, properties: [String: Any]) {
        #if DEBUG
        if properties.isEmpty {
            print("[Analytics] \(name)")
        } else {
            let flat = properties.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
            print("[Analytics] \(name) { \(flat) }")
        }
        #endif
    }

    public func identify(anonymousID: String) {
        #if DEBUG
        print("[Analytics] identify anonymousID=\(anonymousID)")
        #endif
    }
}

// MARK: - Backend HTTP adapter (for keyboard extension or when a 3rd-party SDK is unavailable)

/// Sends events to the KChime backend telemetry endpoint.
/// Use this in the keyboard extension (which can't run PostHog/Segment SDKs).
public struct BackendTelemetryAdapter: AnalyticsAdapter, Sendable {
    private let baseURL: String
    private let deviceID: String

    public init(baseURL: String = AppConstants.apiBaseURL, deviceID: String) {
        self.baseURL = baseURL
        self.deviceID = deviceID
    }

    private static func iso8601String(from date: Date) -> String {
        let fmt = ISO8601DateFormatter()
        return fmt.string(from: date)
    }

    public func track(name: String, properties: [String: Any]) {
        var body: [String: Any] = [
            "event": name,
            "device_id": deviceID,
            "ts": Self.iso8601String(from: Date()),
        ]
        if !properties.isEmpty { body["properties"] = properties }

        guard
            let url = URL(string: "\(baseURL)/api/telemetry/event"),
            let data = try? JSONSerialization.data(withJSONObject: body)
        else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        req.timeoutInterval = 5

        // Fire-and-forget; analytics failures must never affect UX.
        URLSession.shared.dataTask(with: req).resume()
    }

    public func identify(anonymousID: String) {
        // identity is passed per-event via device_id; no separate identify call needed
    }
}
