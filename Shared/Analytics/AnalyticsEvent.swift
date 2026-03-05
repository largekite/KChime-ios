import Foundation

// MARK: - Privacy contract
//
// NEVER include: message text, contact names, email, phone, location, or any freeform
// user-authored strings. All string values must be from the fixed enums below.

public enum AnalyticsEvent: Sendable {

    // MARK: App lifecycle
    case appOpened(isFirstLaunch: Bool)

    // MARK: Onboarding
    case onboardingStepViewed(step: OnboardingStep, stepIndex: Int)
    case onboardingCompleted
    case onboardingAbandoned(atStep: OnboardingStep)

    // MARK: Keyboard
    case keyboardOpened
    case generationRequested(
        feature: Feature,
        toneProfile: String,        // label only — e.g. "Professional"
        relationshipUsed: Bool
    )
    case generationCompleted(
        feature: Feature,
        toneProfile: String,
        latencyMs: Int,
        success: Bool,
        charCountBucket: CharCountBucket
    )
    case suggestionInserted(
        feature: Feature,
        suggestionIndex: Int,       // 0, 1, or 2
        charCountBucket: CharCountBucket
    )
    case toneChipTapped(chip: String, isProChip: Bool)
    case rewriteChipBlocked           // free user hit Pro chip gate

    // MARK: Paywall
    case paywallViewed(source: PaywallSource)
    case subscriptionStarted(productID: String, billingPeriod: BillingPeriod)
    case subscriptionRestored
    case subscriptionCancelled        // tracked client-side only when RC signals it

    // MARK: Promises
    case promiseDetected
    case promiseConfirmed
    case promiseDismissed

    // MARK: Share extension
    case shareExtensionOpened
    case shareExtensionCompleted(success: Bool)

    // MARK: - Nested types

    public enum Feature: String, Sendable {
        case keyboard       = "keyboard"
        case shareExtension = "share_extension"
    }

    public enum OnboardingStep: String, Sendable {
        case valueProp     = "value_prop"
        case privacy       = "privacy"
        case tonePicker    = "tone_picker"
        case contacts      = "contacts"
        case keyboardSetup = "keyboard_setup"
        case firstSuccess  = "first_success"
    }

    public enum PaywallSource: String, Sendable {
        case limitReached  = "limit_reached"
        case proChipTapped = "pro_chip_tapped"
        case settings      = "settings"
        case onboarding    = "onboarding"
    }

    public enum BillingPeriod: String, Sendable {
        case monthly = "monthly"
        case annual  = "annual"
    }

    /// Privacy-safe character count bucket — never log exact counts.
    public enum CharCountBucket: String, Sendable {
        case xs = "xs"   // 0–20   characters
        case s  = "s"    // 21–60  characters
        case m  = "m"    // 61–150 characters
        case l  = "l"    // 151–300 characters
        case xl = "xl"   // 301+   characters

        public static func from(count: Int) -> CharCountBucket {
            switch count {
            case 0...20:   return .xs
            case 21...60:  return .s
            case 61...150: return .m
            case 151...300: return .l
            default:       return .xl
            }
        }
    }
}

// MARK: - Serialisation

extension AnalyticsEvent {

    /// Machine-readable event name (snake_case, no PII).
    public var name: String {
        switch self {
        case .appOpened:               return "app_opened"
        case .onboardingStepViewed:    return "onboarding_step_viewed"
        case .onboardingCompleted:     return "onboarding_completed"
        case .onboardingAbandoned:     return "onboarding_abandoned"
        case .keyboardOpened:          return "keyboard_opened"
        case .generationRequested:     return "generation_requested"
        case .generationCompleted:     return "generation_completed"
        case .suggestionInserted:      return "suggestion_inserted"
        case .toneChipTapped:          return "tone_chip_tapped"
        case .rewriteChipBlocked:      return "rewrite_chip_blocked"
        case .paywallViewed:           return "paywall_viewed"
        case .subscriptionStarted:     return "subscription_started"
        case .subscriptionRestored:    return "subscription_restored"
        case .subscriptionCancelled:   return "subscription_cancelled"
        case .promiseDetected:         return "promise_detected"
        case .promiseConfirmed:        return "promise_confirmed"
        case .promiseDismissed:        return "promise_dismissed"
        case .shareExtensionOpened:    return "share_extension_opened"
        case .shareExtensionCompleted: return "share_extension_completed"
        }
    }

    /// All values are primitives — no strings authored by the user.
    public var properties: [String: Any] {
        switch self {

        case .appOpened(let isFirst):
            return ["is_first_launch": isFirst]

        case .onboardingStepViewed(let step, let index):
            return ["step": step.rawValue, "step_index": index]

        case .onboardingCompleted:
            return [:]

        case .onboardingAbandoned(let step):
            return ["at_step": step.rawValue]

        case .keyboardOpened:
            return [:]

        case .generationRequested(let feature, let tone, let relUsed):
            return [
                "feature": feature.rawValue,
                "tone_profile": tone,
                "relationship_used": relUsed,
            ]

        case .generationCompleted(let feature, let tone, let latency, let success, let bucket):
            return [
                "feature": feature.rawValue,
                "tone_profile": tone,
                "latency_ms": latency,
                "success": success,
                "char_count_bucket": bucket.rawValue,
            ]

        case .suggestionInserted(let feature, let index, let bucket):
            return [
                "feature": feature.rawValue,
                "suggestion_index": index,
                "char_count_bucket": bucket.rawValue,
            ]

        case .toneChipTapped(let chip, let isPro):
            return ["chip": chip, "is_pro_chip": isPro]

        case .rewriteChipBlocked:
            return [:]

        case .paywallViewed(let source):
            return ["source": source.rawValue]

        case .subscriptionStarted(let productID, let period):
            return ["product_id": productID, "billing_period": period.rawValue]

        case .subscriptionRestored:
            return [:]

        case .subscriptionCancelled:
            return [:]

        case .promiseDetected:
            return [:]

        case .promiseConfirmed:
            return [:]

        case .promiseDismissed:
            return [:]

        case .shareExtensionOpened:
            return [:]

        case .shareExtensionCompleted(let success):
            return ["success": success]
        }
    }
}
