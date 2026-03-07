import SwiftUI

// MARK: - Reply Variations View

struct ReplyVariationsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let scenario: ReplyScenario
    let accentColor: Color

    @State private var aiVariations: [String] = []
    @State private var isGenerating = false
    @State private var generateError: String? = nil
    @State private var copiedIndex: Int? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Message header
                    messageHeader

                    // Seed replies section
                    seedRepliesSection

                    // AI variations section
                    aiSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Replies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Message Header

    private var messageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Incoming Message", systemImage: "bubble.left.fill")
                .font(.caption.bold())
                .foregroundStyle(accentColor)

            Text(scenario.message)
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text(scenario.context)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Seed Replies

    private var seedRepliesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Replies")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(scenario.seedReplies.enumerated()), id: \.offset) { idx, reply in
                    replyRow(text: reply, index: idx)

                    if idx < scenario.seedReplies.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - AI Section

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI Variations", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(accentColor)
                Spacer()
                if !aiVariations.isEmpty {
                    Button(action: generateVariations) {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                            .font(.caption.bold())
                            .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(isGenerating)
                }
            }

            if aiVariations.isEmpty && !isGenerating {
                Button(action: generateVariations) {
                    Group {
                        Label("Generate AI variations", systemImage: "sparkles")
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.teal)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            if isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Generating variations…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }

            if let err = generateError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !aiVariations.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(aiVariations.enumerated()), id: \.offset) { idx, reply in
                        replyRow(text: reply, index: idx + 100)

                        if idx < aiVariations.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Reply Row

    private func replyRow(text: String, index: Int) -> some View {
        Button(action: { copy(text, index: index) }) {
            HStack(spacing: 12) {
                Image(systemName: copiedIndex == index ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(copiedIndex == index ? .green : accentColor)
                    .font(.body)
                    .frame(width: 24)
                    .animation(.spring(response: 0.3), value: copiedIndex)

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
    }

    // MARK: - Actions

    private func copy(_ text: String, index: Int) {
        UIPasteboard.general.string = text
        copiedIndex = index
        Task {
            try? await Task.sleep(for: .seconds(2))
            copiedIndex = nil
        }
    }

    private func generateVariations() {
        isGenerating = true
        generateError = nil
        aiVariations = []
        copiedIndex = nil

        let prompt = """
        Someone received this message: "\(scenario.message)"
        Context: \(scenario.context)

        Generate 3 different reply variations with distinct tones:
        1. Casual and friendly
        2. Warm and thoughtful
        3. Witty and clever

        Keep each reply concise (1-2 sentences). Just provide the replies, no labels.
        """

        Task {
            do {
                let request = ReplyRequest(
                    featureKey: AppConstants.Feature.keyboard,
                    receivedMessage: prompt,
                    toneProfile: appState.toneProfile.toPayload()
                )
                let response = try await KChimeAPIClient.shared.generateReplies(request: request)
                aiVariations = response.suggestions
                if !response.longerAlternative.isEmpty {
                    aiVariations.append(response.longerAlternative)
                }
            } catch {
                generateError = error.localizedDescription
            }
            isGenerating = false
        }
    }
}
