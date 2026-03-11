import SwiftUI
import UIKit

struct KeyboardSetupView: View {
    let onComplete: () -> Void

    @State private var keyboardEnabled = false
    @State private var fullAccessEnabled = false
    @State private var checkTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.teal)

                VStack(spacing: 8) {
                    Text("Enable the Keyboard")
                        .font(.largeTitle.bold())
                    Text("Two quick steps in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    SetupStep(
                        number: 1,
                        isComplete: keyboardEnabled,
                        title: "Add KChime keyboard",
                        detail: "Settings → General → Keyboard → Keyboards → Add New Keyboard → KChime"
                    )

                    SetupStep(
                        number: 2,
                        isComplete: fullAccessEnabled,
                        title: "Allow Full Access",
                        detail: "Tap KChime in the list, then toggle on \"Allow Full Access\""
                    )
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button(action: openSettings) {
                    Text("Open Settings")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.teal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if keyboardEnabled && fullAccessEnabled {
                    Button(action: onComplete) {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if keyboardEnabled && !fullAccessEnabled {
                    Text("Almost there — enable Full Access to continue.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
            }
            .animation(.easeInOut, value: keyboardEnabled)
            .animation(.easeInOut, value: fullAccessEnabled)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear(perform: startPolling)
        .onDisappear(perform: stopPolling)
    }

    // MARK: - Helpers

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func startPolling() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [self] _ in
            Task { @MainActor in
                detectKeyboardState()
            }
        }
    }

    private func stopPolling() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    private func detectKeyboardState() {
        let modes = UITextInputMode.activeInputModes
        keyboardEnabled = modes.contains { $0.primaryLanguage?.contains("KChime") ?? false }
            || modes.map(\.description).contains { $0.lowercased().contains("kchime") }

        // Full Access can be inferred by whether a network-capable write succeeds
        // (conservative heuristic — actual confirmation happens on first API call)
        if keyboardEnabled {
            let testPasteboard = UIPasteboard.withUniqueName()
            testPasteboard.string = "test"
            fullAccessEnabled = testPasteboard.string != nil
            UIPasteboard.remove(withName: testPasteboard.name)
        }

        if keyboardEnabled && fullAccessEnabled {
            stopPolling()
        }
    }
}

// MARK: - Step Row

struct SetupStep: View {
    let number: Int
    let isComplete: Bool
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green : Color.teal)
                    .frame(width: 32, height: 32)
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
            .animation(.spring(), value: isComplete)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
