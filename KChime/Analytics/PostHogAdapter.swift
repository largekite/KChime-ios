import Foundation

// MARK: - PostHog adapter stub
//
// Installation:
//   1. Add PostHog SDK via SPM: https://github.com/PostHog/posthog-ios
//      Package: PostHog, target: KChime (main app only — NOT keyboard extension)
//   2. Uncomment the `import PostHog` line and the SDK calls below.
//   3. Replace "phc_REPLACE_WITH_YOUR_KEY" with your PostHog project API key.
//   4. In KChimeApp.init(), call:
//        AnalyticsService.shared.register(PostHogAdapter())
//
// Privacy notes:
//   - `distinctId` is the anonymous device ID — never a real user identifier.
//   - Person profiles are disabled (posthogConfiguration.personProfiles = .never)
//     so PostHog stores no user-level data by default.
//   - All event properties are pre-validated by AnalyticsEvent before reaching here.

// import PostHog   ← uncomment after adding the SDK

struct PostHogAdapter: AnalyticsAdapter {

    private let apiKey = "phc_REPLACE_WITH_YOUR_KEY"
    private let host   = "https://us.i.posthog.com"   // or eu.i.posthog.com

    init() {
        // Uncomment after adding the SDK:
        //
        // let config = PostHogConfig(apiKey: apiKey, host: host)
        // config.captureApplicationLifecycleEvents = false  // we fire manually
        // config.capturePushNotifications = false
        // config.personProfiles = .never          // ← critical for privacy
        // config.sessionReplay = .init(maskAllImages: true, maskAllTextInputs: true)
        // PostHogSDK.shared.setup(config)
    }

    func track(name: String, properties: [String: Any]) {
        // PostHogSDK.shared.capture(name, properties: properties)
        _ = (name, properties)
    }

    func identify(anonymousID: String) {
        // PostHogSDK.shared.identify(anonymousID)   // anonymous ID only — no email/name
        _ = anonymousID
    }
}
