import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject var appState: AppState
    @State private var step: OnboardingStep = .welcome

    enum OnboardingStep {
        case welcome
        case privacy
        case keyboardSetup
        case toneProfile
        case done
    }

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeView { step = .privacy }

            case .privacy:
                PrivacyDisclosureView {
                    appState.completePrivacyAcceptance()
                    step = .keyboardSetup
                }

            case .keyboardSetup:
                KeyboardSetupView { step = .toneProfile }

            case .toneProfile:
                ToneProfileSetupView { profile in
                    appState.saveToneProfile(profile)
                    step = .done
                }

            case .done:
                OnboardingDoneView {
                    appState.completeOnboarding()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }
}

// MARK: - Welcome

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.indigo)

                VStack(spacing: 8) {
                    Text("KChime")
                        .font(.largeTitle.bold())
                    Text("Smart replies for real life.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text("Reply to messages faster and with the right tone — without staring at a blank screen.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Done

struct OnboardingDoneView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)

                Text("You're all set")
                    .font(.largeTitle.bold())

                Text("Switch to the KChime keyboard in any app, paste a message, and get instant reply suggestions.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button(action: onFinish) {
                Text("Start Replying")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}
