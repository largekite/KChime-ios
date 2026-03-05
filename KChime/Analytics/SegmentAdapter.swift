import Foundation

// MARK: - Segment (Twilio) adapter stub
//
// Installation:
//   1. Add Segment SDK via SPM: https://github.com/segmentio/analytics-swift
//      Package: Segment, target: KChime (main app only — NOT keyboard extension)
//   2. Uncomment the `import Segment` line and the SDK calls below.
//   3. Replace "REPLACE_WITH_YOUR_WRITE_KEY" with your Segment Source Write Key.
//   4. In KChimeApp.init(), call:
//        AnalyticsService.shared.register(SegmentAdapter())
//
// Privacy notes:
//   - `anonymousId` is set to the device-level anonymous ID; no Segment auto-ID is used.
//   - Do NOT call `.identify(userId:)` with Apple User ID — it creates a person record.
//   - Disable automatic tracking in the config to avoid collecting IP / device model.
//   - GDPR: Segment supports consent management natively; wire to your consent store.

// import Segment   ← uncomment after adding the SDK

struct SegmentAdapter: AnalyticsAdapter {

    private let writeKey = "REPLACE_WITH_YOUR_WRITE_KEY"

    // private var analytics: Analytics?   ← uncomment after adding the SDK

    init() {
        // Uncomment after adding the SDK:
        //
        // var config = Configuration(writeKey: writeKey)
        //     .trackApplicationLifecycleEvents(false)   // fired manually
        //     .autoAddSegmentDestination(true)
        //     .flushInterval(30)
        //     .flushAt(20)
        // analytics = Analytics(configuration: config)
    }

    func track(name: String, properties: [String: Any]) {
        // analytics?.track(name: name, properties: properties)
        _ = (name, properties)
    }

    func identify(anonymousID: String) {
        // analytics?.identify(userId: nil, traits: ["anonymous_id": anonymousID])
        // — or set anonymousId directly if the SDK supports it.
        _ = anonymousID
    }
}
