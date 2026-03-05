import Foundation

// MARK: - Event definitions
//
// Drop-in integration points:
//   Amplitude : Amplitude.instance().logEvent(name, withEventProperties: props)
//   Mixpanel  : Mixpanel.mainInstance().track(event: name, properties: props)
//   Firebase  : Analytics.logEvent(name, parameters: props)
//
// Event naming convention: snake_case, prefixed with "onboarding_"
// No PII is ever included in event properties.

enum OnboardingEvent {
    case started
    case privacyAccepted
    case toneSelected(tone: String)           // "Professional" | "Friendly" | "Direct"
    case contactsSelected(contacts: [String]) // e.g. ["Boss", "Client"]
    case keyboardSetupStarted
    case keyboardEnabled
    case demoGenerated(success: Bool)
    case demoSuggestionCopied
    case completed
    case stepBack(fromStep: String)
}

enum OnboardingAnalytics {

    // MARK: - Public

    static func track(_ event: OnboardingEvent) {
        let (name, props) = payload(for: event)
        // Replace with your analytics SDK call here.
        // Example — Amplitude:
        //   Amplitude.instance().logEvent(name, withEventProperties: props)
        log(name: name, props: props)
    }

    // MARK: - Payload

    private static func payload(for event: OnboardingEvent) -> (String, [String: Any]) {
        switch event {
        case .started:
            return ("onboarding_started", [:])

        case .privacyAccepted:
            return ("onboarding_privacy_accepted", [:])

        case .toneSelected(let tone):
            return ("onboarding_tone_selected", ["tone": tone])

        case .contactsSelected(let contacts):
            return ("onboarding_contacts_selected", [
                "contacts": contacts,
                "count": contacts.count,
            ])

        case .keyboardSetupStarted:
            return ("onboarding_keyboard_setup_started", [:])

        case .keyboardEnabled:
            return ("onboarding_keyboard_enabled", [:])

        case .demoGenerated(let success):
            return ("onboarding_demo_generated", ["success": success])

        case .demoSuggestionCopied:
            return ("onboarding_demo_suggestion_copied", [:])

        case .completed:
            return ("onboarding_completed", [:])

        case .stepBack(let step):
            return ("onboarding_step_back", ["from_step": step])
        }
    }

    // MARK: - Console logger (replace in production)

    private static func log(name: String, props: [String: Any]) {
        if props.isEmpty {
            print("[Analytics] \(name)")
        } else {
            let flat = props.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            print("[Analytics] \(name) { \(flat) }")
        }
    }
}
