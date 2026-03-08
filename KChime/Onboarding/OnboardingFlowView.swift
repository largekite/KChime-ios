import SwiftUI

// MARK: - Flow orchestrator

struct OnboardingFlowView: View {
    @EnvironmentObject var appState: AppState
    @State private var step: OnboardingStep = .valueProp
    @State private var selectedTone: ToneProfile = .allPresets[1]           // "Friendly" default
    @State private var selectedContactIDs: Set<String> = ["boss", "client", "teacher", "family"]

    enum OnboardingStep: Int {
        case valueProp = 0
        case privacy = 1
        case tonePicker = 2
        case contacts = 3
        case keyboardSetup = 4
        case firstSuccess = 5

        var analyticsName: String {
            switch self {
            case .valueProp:     return "value_prop"
            case .privacy:       return "privacy"
            case .tonePicker:    return "tone_picker"
            case .contacts:      return "contacts"
            case .keyboardSetup: return "keyboard_setup"
            case .firstSuccess:  return "first_success"
            }
        }

        /// 0–1 progress fraction shown in stepped headers (nil = no bar)
        var progressFraction: Double? {
            switch self {
            case .valueProp, .privacy: return nil
            case .tonePicker:          return 1 / 4.0
            case .contacts:            return 2 / 4.0
            case .keyboardSetup:       return 3 / 4.0
            case .firstSuccess:        return 4 / 4.0
            }
        }
    }

    var body: some View {
        ZStack {
            switch step {
            case .valueProp:
                ValuePropView {
                    OnboardingAnalytics.track(.started)
                    advance(to: .privacy)
                }

            case .privacy:
                PrivacyDisclosureView {
                    OnboardingAnalytics.track(.privacyAccepted)
                    appState.completePrivacyAcceptance()
                    advance(to: .tonePicker)
                }

            case .tonePicker:
                OnboardingShell(step: step, onBack: {
                    OnboardingAnalytics.track(.stepBack(fromStep: step.analyticsName))
                    advance(to: .privacy)
                }, cta: {
                    OnboardingAnalytics.track(.toneSelected(tone: selectedTone.label))
                    appState.saveToneProfile(selectedTone)
                    advance(to: .contacts)
                }) {
                    TonePickerStep(selected: $selectedTone)
                }

            case .contacts:
                OnboardingShell(step: step, onBack: {
                    OnboardingAnalytics.track(.stepBack(fromStep: step.analyticsName))
                    advance(to: .tonePicker)
                }, cta: {
                    let names = RelationshipProfileStore.shared.allProfiles
                        .filter { selectedContactIDs.contains($0.id) }
                        .map(\.name)
                    OnboardingAnalytics.track(.contactsSelected(contacts: names))
                    appState.saveSelectedContacts(selectedContactIDs)
                    advance(to: .keyboardSetup)
                }) {
                    ContactsPickerStep(selectedIDs: $selectedContactIDs)
                }

            case .keyboardSetup:
                OnboardingShell(step: step, onBack: {
                    OnboardingAnalytics.track(.stepBack(fromStep: step.analyticsName))
                    advance(to: .contacts)
                }, cta: {
                    advance(to: .firstSuccess)
                }) {
                    KeyboardSetupStep()
                }

            case .firstSuccess:
                FirstSuccessView(toneProfile: selectedTone) {
                    OnboardingAnalytics.track(.completed)
                    appState.completeOnboarding()
                }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: step)
    }

    private func advance(to next: OnboardingStep) {
        withAnimation { step = next }
    }
}

// MARK: - Reusable shell (progress bar + back + CTA)

/// Wraps tone, contacts, and keyboard steps with a consistent chrome:
/// progress indicator, back chevron, scrollable content, and a bottom CTA.
private struct OnboardingShell<Content: View>: View {
    let step: OnboardingFlowView.OnboardingStep
    let onBack: () -> Void
    let cta: () -> Void
    @ViewBuilder let content: () -> Content

    private var copy: (title: String, subtitle: String, ctaLabel: String) {
        switch step {
        case .tonePicker:
            return (
                "How do you usually sound?",
                "Pick the style that feels most like you.",
                "This is me →"
            )
        case .contacts:
            return (
                "Who do you message most?",
                "KChime will tailor replies to each relationship.",
                "Looks good →"
            )
        case .keyboardSetup:
            return (
                "Set up the keyboard",
                "Two quick steps in Settings — takes 30 seconds.",
                "All set, let's go →"
            )
        default:
            return ("", "", "Continue")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Progress header ────────────────────────────────────────────────
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                }

                if let fraction = step.progressFraction {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.systemFill)).frame(height: 4)
                            Capsule().fill(Color.teal)
                                .frame(width: geo.size.width * fraction, height: 4)
                                .animation(.spring(response: 0.5), value: fraction)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)

            // ── Title block ────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text(copy.title)
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text(copy.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            // ── Content (caller-provided) ──────────────────────────────────────
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Primary CTA ────────────────────────────────────────────────────
            Button(action: cta) {
                Text(copy.ctaLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.teal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Step 1: Value Prop

struct ValuePropView: View {
    let onContinue: () -> Void

    private let highlights: [(icon: String, heading: String, detail: String)] = [
        ("bolt.fill",
         "Instant replies, zero blank-screen panic",
         "See 3 contextual options the moment you paste a message."),
        ("person.2.fill",
         "Reads the room based on who you're texting",
         "Boss vs. best friend — KChime adjusts automatically."),
        ("slider.horizontal.3",
         "Your tone, not a generic AI bot",
         "Choose Professional, Friendly, or Direct and it stays that way."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                // Logo mark
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.1))
                        .frame(width: 100, height: 100)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.teal)
                }

                // Hero copy
                VStack(spacing: 12) {
                    Text("Never stare at your phone\nwondering how to reply.")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)

                    Text("KChime reads the room and writes back for you.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Feature proof points
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(highlights, id: \.icon) { item in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.teal)
                                .frame(width: 22, alignment: .top)
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.heading)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
            }

            Spacer()

            // CTA
            VStack(spacing: 10) {
                Button(action: onContinue) {
                    Text("Let's set you up  →")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Text("Free to start — no credit card needed")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Step 3: Tone Picker

private struct TonePickerStep: View {
    @Binding var selected: ToneProfile

    struct ToneOption: Identifiable {
        let id = UUID()
        let profile: ToneProfile
        let displayName: String
        let tagline: String       // one-liner shown below name
        let exampleReply: String  // italic preview quote
        let icon: String
    }

    private let options: [ToneOption] = [
        ToneOption(
            profile: ToneProfile(id: UUID(), label: "Professional",
                                 formality: 0.85, emojiEnabled: false,
                                 lengthPreference: .short),
            displayName: "Professional",
            tagline: "Formal, concise, no fluff",
            exampleReply: "\"Thank you for the update. I'll review and respond by EOD.\"",
            icon: "briefcase.fill"
        ),
        ToneOption(
            profile: ToneProfile(id: UUID(), label: "Friendly",
                                 formality: 0.15, emojiEnabled: true,
                                 lengthPreference: .medium),
            displayName: "Friendly",
            tagline: "Warm, natural, human",
            exampleReply: "\"Sounds great! Really looking forward to it 😊\"",
            icon: "face.smiling.fill"
        ),
        ToneOption(
            profile: ToneProfile(id: UUID(), label: "Direct",
                                 formality: 0.4, emojiEnabled: false,
                                 lengthPreference: .short,
                                 customInstructions: "Be direct and get straight to the point."),
            displayName: "Direct",
            tagline: "Short, sharp, no small talk",
            exampleReply: "\"Got it. I'll handle it.\"",
            icon: "arrow.right.circle.fill"
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(options) { option in
                    ToneOptionCard(
                        option: option,
                        isSelected: selected.label == option.profile.label,
                        onTap: { selected = option.profile }
                    )
                }
                Text("You can fine-tune this anytime in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

private struct ToneOptionCard: View {
    let option: TonePickerStep.ToneOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.teal : Color(.tertiarySystemGroupedBackground))
                        .frame(width: 44, height: 44)
                    Image(systemName: option.icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
                .animation(.spring(response: 0.25), value: isSelected)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(option.displayName).font(.headline)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.teal)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    Text(option.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(option.exampleReply)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.teal : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Step 4: Contact Picker

private struct ContactsPickerStep: View {
    @Binding var selectedIDs: Set<String>

    private let profiles = RelationshipProfileStore.shared.builtIns

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(profiles) { profile in
                        ContactChipCard(
                            profile: profile,
                            isSelected: selectedIDs.contains(profile.id),
                            onTap: {
                                if selectedIDs.contains(profile.id) {
                                    selectedIDs.remove(profile.id)
                                } else {
                                    selectedIDs.insert(profile.id)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)

                Text("Select all that apply. KChime uses these to tune each reply.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 16)
        }
    }
}

private struct ContactChipCard: View {
    let profile: RelationshipProfile
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    Text(profile.emoji)
                        .font(.system(size: 36))
                        .frame(maxWidth: .infinity)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.teal)
                            .offset(x: 4, y: -4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                VStack(spacing: 2) {
                    Text(profile.name).font(.subheadline.bold())
                    Text(contextLabel(profile))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.teal.opacity(0.08) : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.teal : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private func contextLabel(_ p: RelationshipProfile) -> String {
        if p.formality >= 7 { return "Very formal" }
        if p.warmth >= 9    { return "Very warm" }
        if p.formality >= 5 { return "Professional" }
        return "Casual"
    }
}

// MARK: - Step 5: Keyboard Setup (thin wrapper)

private struct KeyboardSetupStep: View {
    @State private var enabled = false

    var body: some View {
        KeyboardSetupView(onComplete: { enabled = true })
            .onAppear { OnboardingAnalytics.track(.keyboardSetupStarted) }
            .onChange(of: enabled) { _, newValue in if newValue { OnboardingAnalytics.track(.keyboardEnabled) } }
    }
}

// MARK: - Step 6: First Success Moment

struct FirstSuccessView: View {
    let toneProfile: ToneProfile
    let onComplete: () -> Void

    // Pre-canned demo scenario — boss persona, relatable context
    private let sampleMessage = "Hey, can you get me the Q3 numbers before Friday? Need them for the board deck."

    // Shown if the API call fails (feels real, matches boss context)
    private let fallbackSuggestions = [
        "Sure — I'll get those to you by Thursday EOD.",
        "On it! Will send the Q3 numbers over before Friday.",
        "Got it, I'll pull it all together and have it to you today.",
    ]

    @State private var suggestions: [String] = []
    @State private var isLoading = false
    @State private var hasGenerated = false
    @State private var copiedIndex: Int? = nil
    @State private var hasCopied = false
    @State private var showContinue = false

    var body: some View {
        VStack(spacing: 0) {
            // Minimal header — no back on final step
            HStack {
                Spacer()
                Text("Step 5 of 5")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.top, 16)
            .padding(.bottom, 4)

            // Progress bar at 100%
            Capsule().fill(Color.teal).frame(height: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)

            ScrollView {
                VStack(spacing: 0) {
                    // ── Header ───────────────────────────────────────────────
                    VStack(spacing: 8) {
                        Text("See it in action")
                            .font(.largeTitle.bold())
                        Text("Here's how KChime replies to a real work message for you.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 28)

                    // ── Incoming message ──────────────────────────────────────
                    VStack(spacing: 0) {
                        HStack {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color.teal.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Text("👔").font(.body)
                                }
                                Text("Boss")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.bottom, 6)

                        HStack {
                            Text(sampleMessage)
                                .font(.subheadline)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            Spacer(minLength: 48)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Separator
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5)
                        .padding(.vertical, 20)

                    // ── Generate / Loading / Results ──────────────────────────
                    if !hasGenerated && !isLoading {
                        generateButton
                    } else if isLoading {
                        loadingSkeleton
                    } else {
                        suggestionsStack
                    }

                    Spacer(minLength: 48)
                }
                .padding(.top, 4)
            }

            // ── Bottom CTA ────────────────────────────────────────────────────
            if showContinue {
                VStack(spacing: 10) {
                    Button(action: onComplete) {
                        HStack(spacing: 8) {
                            Text("Start using KChime")
                                .font(.headline)
                            Text("🎉").font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.teal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Text("Your keyboard is ready in every app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 48)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(.systemBackground))
        .animation(.easeInOut(duration: 0.25), value: showContinue)
        .animation(.easeInOut(duration: 0.2), value: hasGenerated)
    }

    // MARK: - Sub-views

    private var generateButton: some View {
        Button(action: runGeneration) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(.teal)
                Text("Generate my replies").font(.headline).foregroundStyle(.teal)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.teal.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.teal.opacity(0.3), lineWidth: 1.5)
            )
        }
        .padding(.horizontal, 20)
    }

    private var loadingSkeleton: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { i in
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(.systemFill))
                        .frame(width: [220, 180, 200][i], height: 12).shimmer()
                    RoundedRectangle(cornerRadius: 4).fill(Color(.systemFill))
                        .frame(width: [160, 220, 140][i], height: 10).shimmer()
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                if i < 2 { Rectangle().fill(Color(.separator)).frame(height: 0.5) }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 20)
    }

    private var suggestionsStack: some View {
        VStack(spacing: 12) {
            Text("Tap a reply to copy it")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { idx, text in
                    Button(action: { copySuggestion(text, index: idx) }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(copiedIndex == idx ? Color.green : Color(.tertiarySystemGroupedBackground))
                                    .frame(width: 28, height: 28)
                                Image(systemName: copiedIndex == idx ? "checkmark" : "doc.on.doc")
                                    .font(.caption2.bold())
                                    .foregroundStyle(copiedIndex == idx ? .white : .secondary)
                            }
                            .animation(.spring(response: 0.3), value: copiedIndex == idx)

                            Text(text)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if idx < suggestions.count - 1 {
                        Rectangle().fill(Color(.separator)).frame(height: 0.5)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 20)

            if hasCopied {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Copied! Paste it anywhere.")
                }
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasCopied)
    }

    // MARK: - Actions

    private func runGeneration() {
        isLoading = true
        hasGenerated = true

        Task {
            do {
                let boss = RelationshipProfile.builtIns.first(where: { $0.id == "boss" })
                let request = ReplyRequest(
                    featureKey: AppConstants.Feature.keyboard,
                    receivedMessage: sampleMessage,
                    toneProfile: toneProfile.toPayload(),
                    relationshipProfile: boss?.toPayload()
                )
                let response = try await KChimeAPIClient.shared.generateReplies(request: request)
                OnboardingAnalytics.track(.demoGenerated(success: true))
                suggestions = Array(response.suggestions.prefix(3))
            } catch {
                OnboardingAnalytics.track(.demoGenerated(success: false))
                suggestions = fallbackSuggestions
            }
            isLoading = false
            withAnimation { showContinue = true }
        }
    }

    private func copySuggestion(_ text: String, index: Int) {
        UIPasteboard.general.string = text
        OnboardingAnalytics.track(.demoSuggestionCopied)
        hasCopied = true
        copiedIndex = index
        Task {
            try? await Task.sleep(for: .seconds(2))
            copiedIndex = nil
        }
    }
}

// MARK: - Done (kept as fallback, no longer shown by default)

struct OnboardingDoneView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72)).foregroundStyle(.green)
                Text("You're all set").font(.largeTitle.bold())
                Text("Switch to the KChime keyboard in any app, paste a message, and get instant reply suggestions.")
                    .font(.body).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            Spacer()
            Button(action: onFinish) {
                Text("Start Replying").font(.headline)
                    .frame(maxWidth: .infinity).padding()
                    .background(.teal).foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24).padding(.bottom, 48)
        }
    }
}
