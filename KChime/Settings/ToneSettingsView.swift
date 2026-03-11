import SwiftUI

/// Full tone-profile configuration screen, accessible from Settings.
/// Shows a live preview so users can see how their settings affect output.
struct ToneSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // Local editable copy — saved only on explicit tap
    @State private var draft: ToneProfile
    @State private var showPreview = false
    @State private var previewText = ""
    @State private var isGeneratingPreview = false

    init(current: ToneProfile) {
        _draft = State(initialValue: current)
    }

    var body: some View {
        NavigationStack {
            Form {
                presetSection
                formalitySection
                lengthSection
                emojiSection
                customInstructionsSection
                previewSection
            }
            .navigationTitle("Tone Defaults")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.saveToneProfile(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Preset picker

    private var presetSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ToneProfile.allPresets) { preset in
                        PresetCard(
                            preset: preset,
                            isSelected: draft.label == preset.label
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                draft = preset
                            }
                        }
                    }
                    // Custom — if the user edits away from all presets
                    if !ToneProfile.allPresets.contains(where: { $0.label == draft.label }) {
                        PresetCard(
                            preset: draft,
                            isSelected: true,
                            onSelect: {}
                        )
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } header: {
            Text("Quick Presets")
        } footer: {
            Text("Select a preset as a starting point, then fine-tune below.")
        }
    }

    // MARK: - Formality slider

    private var formalitySection: some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    Text("Casual")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formalityLabel(draft.formality))
                        .font(.caption.bold())
                        .foregroundStyle(.teal)
                    Spacer()
                    Text("Formal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $draft.formality, in: 0...1, step: 0.05) {
                    Text("Formality")
                } minimumValueLabel: {
                    Image(systemName: "face.smiling")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Image(systemName: "briefcase")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tint(.teal)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Formality")
        }
    }

    // MARK: - Length picker

    private var lengthSection: some View {
        Section {
            Picker("Reply length", selection: $draft.lengthPreference) {
                ForEach(ToneProfile.LengthPreference.allCases, id: \.self) { option in
                    VStack(alignment: .leading) {
                        Text(option.displayName)
                        Text(lengthDescription(option))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Reply Length")
        }
    }

    // MARK: - Emoji toggle

    private var emojiSection: some View {
        Section {
            Toggle(isOn: $draft.emojiEnabled) {
                Label("Allow emoji in replies", systemImage: "face.smiling.inverse")
            }
            .tint(.teal)
        } footer: {
            Text(draft.emojiEnabled
                 ? "KChime may include 1–2 relevant emojis per reply."
                 : "Replies will be emoji-free.")
        }
    }

    // MARK: - Custom instructions

    private var customInstructionsSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                if draft.customInstructions?.isEmpty ?? true {
                    Text("e.g. Always mention my name, avoid sarcasm, keep it positive…")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: Binding(
                    get: { draft.customInstructions ?? "" },
                    set: { draft.customInstructions = $0.isEmpty ? nil : $0 }
                ))
                .font(.subheadline)
                .frame(minHeight: 80)
            }
        } header: {
            Text("Custom Instructions")
        } footer: {
            Text("These instructions are sent with every reply request. Max 200 characters.")
        }
        .onChange(of: draft.customInstructions) { _, newValue in
            if let v = newValue, v.count > 200 {
                draft.customInstructions = String(v.prefix(200))
            }
        }
    }

    // MARK: - Live preview

    private var previewSection: some View {
        Section {
            if previewText.isEmpty && !isGeneratingPreview {
                Button(action: generatePreview) {
                    Label("Preview a reply with these settings", systemImage: "eye")
                        .foregroundStyle(.teal)
                }
            } else if isGeneratingPreview {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating preview…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Preview", systemImage: "eye")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Refresh", action: generatePreview)
                            .font(.caption)
                            .foregroundStyle(.teal)
                    }

                    Text(previewText)
                        .font(.subheadline)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )

                    Text("Based on the sample message: \"Running 10 min late to school pickup\"")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Live Preview")
        }
    }

    // MARK: - Helpers

    private func formalityLabel(_ value: Double) -> String {
        switch value {
        case ..<0.2:  return "Very casual"
        case 0.2..<0.4: return "Casual"
        case 0.4..<0.6: return "Balanced"
        case 0.6..<0.8: return "Formal"
        default:      return "Very formal"
        }
    }

    private func lengthDescription(_ pref: ToneProfile.LengthPreference) -> String {
        switch pref {
        case .short:   return "1 sentence or fewer"
        case .medium:  return "1–2 sentences"
        case .verbose: return "2–3 full sentences"
        }
    }

    private func generatePreview() {
        isGeneratingPreview = true
        previewText = ""
        Task {
            let payload = draft.toPayload()
            let request = ReplyRequest(
                featureKey: AppConstants.Feature.keyboard,
                receivedMessage: "Running 10 min late to school pickup",
                toneProfile: payload
            )
            if let response = try? await KChimeAPIClient.shared.generateReplies(request: request) {
                previewText = response.suggestions.first ?? "(no preview)"
            } else {
                previewText = "(Preview unavailable — check your connection)"
            }
            isGeneratingPreview = false
        }
    }
}

// MARK: - Preset card

private struct PresetCard: View {
    let preset: ToneProfile
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                Text(preset.label)
                    .font(.caption.bold())
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    formalityDots(preset.formality)
                    if preset.emojiEnabled {
                        Text("😊")
                            .font(.system(size: 9))
                    }
                }
            }
            .padding(10)
            .frame(width: 110, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.teal : Color(.tertiarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.teal : Color(.separator), lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func formalityDots(_ value: Double) -> some View {
        let filled = max(1, Int((value * 4).rounded()))
        return HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(i < filled
                          ? (isSelected ? Color.white.opacity(0.8) : Color.teal)
                          : (isSelected ? Color.white.opacity(0.3) : Color(.systemFill)))
                    .frame(width: 4, height: 4)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ToneSettingsView(current: .defaultProfile)
        .environmentObject(AppState())
}
