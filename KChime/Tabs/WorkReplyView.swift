import SwiftUI

// MARK: - Work Preset

struct WorkPreset: Identifiable {
    let id: String
    let title: String
    let description: String
    let emoji: String
    let placeholder: String
    let promptPrefix: String
}

private let workPresets: [WorkPreset] = [
    WorkPreset(
        id: "manager",
        title: "Reply to Manager",
        description: "Professional, respectful, proactive",
        emoji: "👔",
        placeholder: "Paste your manager's message…",
        promptPrefix: "Reply to my manager professionally and respectfully:"
    ),
    WorkPreset(
        id: "direct-report",
        title: "Message a Direct Report",
        description: "Clear, supportive, motivating",
        emoji: "📋",
        placeholder: "What do you need to communicate?",
        promptPrefix: "Write a message to a direct report that is clear and supportive:"
    ),
    WorkPreset(
        id: "client",
        title: "Reply to Client",
        description: "Polished, confident, client-focused",
        emoji: "🤝",
        placeholder: "Paste the client's message…",
        promptPrefix: "Reply to a client professionally and with confidence:"
    ),
    WorkPreset(
        id: "pushback",
        title: "Push Back Politely",
        description: "Assert your position diplomatically",
        emoji: "🛡️",
        placeholder: "What request or decision are you pushing back on?",
        promptPrefix: "Help me politely but firmly push back on this without damaging the relationship:"
    ),
    WorkPreset(
        id: "feedback",
        title: "Deliver Feedback",
        description: "Constructive, specific, actionable",
        emoji: "💡",
        placeholder: "What situation or behavior needs feedback?",
        promptPrefix: "Help me deliver constructive feedback that is specific and actionable:"
    ),
    WorkPreset(
        id: "escalate",
        title: "Escalate an Issue",
        description: "Urgent, factual, solution-oriented",
        emoji: "🚨",
        placeholder: "Describe the issue that needs escalation…",
        promptPrefix: "Help me escalate this issue professionally with clear facts and a proposed path forward:"
    ),
]

// MARK: - Work Variation

struct WorkVariation: Identifiable {
    let id = UUID()
    let title: String
    let toneLabel: String
    let toneColor: Color
    let text: String
    let riskLevel: String   // "Low" / "Medium" / "High"
}

// MARK: - Work Reply View

struct WorkReplyView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPreset: WorkPreset? = nil
    @State private var inputText = ""
    @State private var variations: [WorkVariation] = []
    @State private var isGenerating = false
    @State private var generateError: String? = nil
    @State private var copiedIndex: Int? = nil
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Intro
                    introCard

                    // Preset grid
                    presetGrid

                    // Input + generate
                    if selectedPreset != nil {
                        inputCard
                    }

                    // Variations
                    if !variations.isEmpty {
                        variationsCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Work Reply")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Intro Card

    private var introCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "briefcase.fill")
                .font(.title3)
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text("Workplace Communication")
                    .font(.subheadline.bold())
                Text("Get 3 strategic reply variations — choose the right tone for the situation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Preset Grid

    private var presetGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(workPresets) { preset in
                PresetCell(
                    preset: preset,
                    isSelected: selectedPreset?.id == preset.id,
                    onTap: {
                        if selectedPreset?.id == preset.id {
                            selectedPreset = nil
                            variations = []
                        } else {
                            selectedPreset = preset
                            variations = []
                            inputText = ""
                        }
                    }
                )
            }
        }
    }

    // MARK: - Input Card

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let preset = selectedPreset {
                Label(preset.title, systemImage: "text.cursor")
                    .font(.headline)
                    .foregroundStyle(.indigo)
            }

            ZStack(alignment: .topLeading) {
                if inputText.isEmpty {
                    Text(selectedPreset?.placeholder ?? "Describe the situation…")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $inputText)
                    .font(.subheadline)
                    .frame(minHeight: 80, maxHeight: 140)
                    .focused($inputFocused)
            }
            .padding(8)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if let err = generateError {
                Text(err).font(.caption).foregroundStyle(.red)
            }

            Button(action: generate) {
                Group {
                    if isGenerating {
                        ProgressView().tint(.white)
                    } else {
                        Label("Generate 3 variations", systemImage: "sparkles")
                            .font(.subheadline.bold())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(canGenerate ? Color.indigo : Color.indigo.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!canGenerate)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var canGenerate: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    // MARK: - Variations Card

    private var variationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Strategic variations")
                    .font(.headline)
                Spacer()
                Button(action: generate) {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }

            VStack(spacing: 12) {
                ForEach(Array(variations.enumerated()), id: \.element.id) { idx, variation in
                    WorkVariationCard(
                        variation: variation,
                        index: idx,
                        copiedIndex: $copiedIndex
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Actions

    private func generate() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let preset = selectedPreset else { return }
        inputFocused = false
        isGenerating = true
        generateError = nil
        variations = []
        copiedIndex = nil

        // Build a structured prompt for 3 strategic variations
        let prompt = """
        \(preset.promptPrefix)

        Situation: \(text)

        Give me 3 distinct strategic variations:
        1. Safe/Neutral — minimal risk, keeps everyone comfortable
        2. Direct — clear and assertive without being aggressive
        3. Bold — confident and impactful, slightly higher stakes

        Label each variation clearly.
        """

        Task {
            do {
                let request = ReplyRequest(
                    featureKey: AppConstants.Feature.keyboard,
                    receivedMessage: prompt,
                    toneProfile: appState.toneProfile.toPayload(),
                    contextMode: "office"
                )
                let response = try await KChimeAPIClient.shared.generateReplies(request: request)
                variations = buildVariations(from: response)
            } catch {
                generateError = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func buildVariations(from response: ReplyResponse) -> [WorkVariation] {
        let variationDefs: [(String, String, Color, String)] = [
            ("Safe / Neutral",  "Safe",   .green,  "Low"),
            ("Direct",          "Direct", .indigo, "Medium"),
            ("Bold",            "Bold",   .orange, "High"),
        ]
        var result: [WorkVariation] = []
        let allTexts = response.suggestions + (response.longerAlternative.isEmpty ? [] : [response.longerAlternative])
        for (idx, def) in variationDefs.enumerated() {
            let text = idx < allTexts.count ? allTexts[idx] : ""
            result.append(WorkVariation(
                title: def.0,
                toneLabel: def.1,
                toneColor: def.2,
                text: text,
                riskLevel: def.3
            ))
        }
        return result
    }
}

// MARK: - Preset Cell

private struct PresetCell: View {
    let preset: WorkPreset
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(preset.emoji)
                    .font(.title2)
                Text(preset.title)
                    .font(.caption.bold())
                    .foregroundStyle(isSelected ? .indigo : .primary)
                Text(preset.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.indigo.opacity(0.1) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.indigo : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Work Variation Card

private struct WorkVariationCard: View {
    let variation: WorkVariation
    let index: Int
    @Binding var copiedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(variation.toneLabel)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(variation.toneColor.opacity(0.15))
                    .foregroundStyle(variation.toneColor)
                    .clipShape(Capsule())

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: riskIcon(variation.riskLevel))
                        .font(.caption2)
                    Text("Risk: \(variation.riskLevel)")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)

                Button(action: copy) {
                    Image(systemName: copiedIndex == index ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(copiedIndex == index ? .green : .indigo)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }

            Text(variation.text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func riskIcon(_ level: String) -> String {
        switch level {
        case "Low":    return "checkmark.shield"
        case "Medium": return "exclamationmark.shield"
        default:       return "flame"
        }
    }

    private func copy() {
        UIPasteboard.general.string = variation.text
        copiedIndex = index
        Task {
            try? await Task.sleep(for: .seconds(2))
            copiedIndex = nil
        }
    }
}
