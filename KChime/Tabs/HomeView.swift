import SwiftUI
import Speech

// MARK: - Context Mode

enum ContextMode: String, CaseIterable {
    case any    = "Any"
    case office = "Office"
    case text   = "Text"
    case party  = "Party"
    case family = "Family"

    var emoji: String {
        switch self {
        case .any:    return "✨"
        case .office: return "💼"
        case .text:   return "💬"
        case .party:  return "🎉"
        case .family: return "🏠"
        }
    }

    var apiValue: String? {
        self == .any ? nil : rawValue.lowercased()
    }
}

// MARK: - Tone Label

private let toneLabels = ["Casual", "Warm", "Funny"]

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var remaining = AppConstants.Feature.freeLimit
    @State private var limit = AppConstants.Feature.freeLimit
    @State private var isLoadingUsage = false

    // Reply generator
    @State private var inputText = ""
    @State private var contextMode: ContextMode = .any
    @State private var suggestions: [String] = []
    @State private var longerAlternative: String? = nil
    @State private var isGenerating = false
    @State private var generateError: String? = nil
    @State private var copiedIndex: Int? = nil
    @State private var recentPrompts: [String] = []
    @FocusState private var inputFocused: Bool

    // Voice input
    @StateObject private var speechRecognizer = SpeechRecognizer(continuous: false)
    @State private var micError: String? = nil
    @State private var generateButtonPulse = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    usageBanner
                    replyGeneratorCard
                    if !suggestions.isEmpty {
                        suggestionsCard
                    } else if !recentPrompts.isEmpty && inputText.isEmpty {
                        recentPromptsCard
                    }
                    quickStartCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("KChime")
            .navigationBarTitleDisplayMode(.large)
            .task { await loadUsage() }
        }
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            if !newValue.isEmpty {
                inputText = newValue
            }
        }
        .onChange(of: speechRecognizer.isListening) { _, isListening in
            if !isListening && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                    generateButtonPulse = true
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        generateButtonPulse = false
                    }
                }
            }
        }
    }

    // MARK: - Reply Generator Card

    private var replyGeneratorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Reply", systemImage: "wand.and.stars")
                .font(.headline)
                .foregroundStyle(.indigo)

            Text("Paste or speak a message to get instant reply suggestions.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Context mode chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ContextMode.allCases, id: \.self) { mode in
                        Button(action: { contextMode = mode }) {
                            Text("\(mode.emoji) \(mode.rawValue)")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(contextMode == mode ? Color.indigo : Color(.tertiarySystemBackground))
                                .foregroundStyle(contextMode == mode ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Text input with mic button
            ZStack(alignment: .topLeading) {
                if inputText.isEmpty && !speechRecognizer.isListening {
                    Text("Paste or type a message here…")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                HStack(alignment: .bottom, spacing: 0) {
                    TextEditor(text: $inputText)
                        .font(.subheadline)
                        .frame(minHeight: 72, maxHeight: 120)
                        .focused($inputFocused)

                    Button(action: toggleMic) {
                        Image(systemName: speechRecognizer.isListening ? "mic.fill" : "mic")
                            .font(.body)
                            .foregroundStyle(speechRecognizer.isListening ? .red : .indigo)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(speechRecognizer.isListening ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )

            if speechRecognizer.isListening {
                Label("Listening…", systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let err = micError ?? speechRecognizer.errorMessage ?? generateError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button(action: generate) {
                Group {
                    if isGenerating {
                        ProgressView().tint(.white)
                    } else {
                        Label("Generate replies", systemImage: "sparkles")
                            .font(.subheadline.bold())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(canGenerate ? Color.indigo : Color.indigo.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .scaleEffect(generateButtonPulse ? 1.06 : 1.0)
            }
            .disabled(!canGenerate)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var canGenerate: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    // MARK: - Suggestions Card

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reply suggestions")
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

            VStack(spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { idx, text in
                    Button(action: { copy(text, index: idx) }) {
                        HStack(spacing: 12) {
                            Image(systemName: copiedIndex == idx ? "checkmark.circle.fill" : "doc.on.doc")
                                .foregroundStyle(copiedIndex == idx ? .green : .indigo)
                                .font(.body)
                                .frame(width: 24)
                                .animation(.spring(response: 0.3), value: copiedIndex)
                            VStack(alignment: .leading, spacing: 2) {
                                if idx < toneLabels.count {
                                    Text(toneLabels[idx])
                                        .font(.caption2.bold())
                                        .foregroundStyle(.indigo)
                                }
                                Text(text)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if idx < suggestions.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }

                if let longer = longerAlternative {
                    Divider().padding(.leading, 52)
                    Button(action: { copy(longer, index: 99) }) {
                        HStack(spacing: 12) {
                            Image(systemName: copiedIndex == 99 ? "checkmark.circle.fill" : "doc.on.doc")
                                .foregroundStyle(copiedIndex == 99 ? .green : .indigo)
                                .font(.body)
                                .frame(width: 24)
                                .animation(.spring(response: 0.3), value: copiedIndex)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Detailed")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.indigo)
                                Text(longer)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Recent Prompts Card

    private var recentPromptsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentPrompts, id: \.self) { prompt in
                        Button(action: { inputText = prompt }) {
                            Text(prompt)
                                .font(.caption)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Usage Banner

    private var usageBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(appState.isPro ? "Pro Plan" : "Free Plan")
                    .font(.headline)
                Spacer()
                if !appState.isPro {
                    NavigationLink("Upgrade") {
                        PaywallView()
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.indigo)
                }
            }

            if !appState.isPro {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: Double(limit - remaining), total: Double(limit))
                        .tint(remaining > 1 ? .indigo : .orange)

                    Text("\(remaining) of \(limit) replies remaining today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("50 replies/day", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Quick Start Card

    private var quickStartCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "keyboard.fill")
                .font(.title3)
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text("Also works in any app")
                    .font(.subheadline.bold())
                Text("Enable the KChime keyboard in Settings to reply without leaving your messaging app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Actions

    private func toggleMic() {
        if speechRecognizer.isListening {
            speechRecognizer.stopListening()
        } else {
            Task { await speechRecognizer.startListening() }
        }
    }

    private func generate() {
        let msg = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }
        inputFocused = false
        speechRecognizer.stopListening()
        isGenerating = true
        generateError = nil
        suggestions = []
        longerAlternative = nil
        copiedIndex = nil

        // Store in recents (max 5)
        recentPrompts.removeAll { $0 == msg }
        recentPrompts.insert(msg, at: 0)
        if recentPrompts.count > 5 { recentPrompts = Array(recentPrompts.prefix(5)) }

        Task {
            do {
                let request = ReplyRequest(
                    featureKey: AppConstants.Feature.keyboard,
                    receivedMessage: msg,
                    toneProfile: appState.toneProfile.toPayload(),
                    contextMode: contextMode.apiValue
                )
                let response = try await KChimeAPIClient.shared.generateReplies(request: request)
                suggestions = response.suggestions
                longerAlternative = response.longerAlternative.isEmpty ? nil : response.longerAlternative
                remaining = response.remaining
                limit = response.limit
                UsageCache.shared.setUsage(remaining: response.remaining, limit: response.limit,
                                           for: AppConstants.Feature.keyboard)
            } catch {
                generateError = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func copy(_ text: String, index: Int) {
        UIPasteboard.general.string = text
        copiedIndex = index
        Task {
            try? await Task.sleep(for: .seconds(2))
            copiedIndex = nil
        }
    }

    // MARK: - Networking

    private func loadUsage() async {
        if let cached = UsageCache.shared.cachedUsage(for: AppConstants.Feature.keyboard) {
            remaining = cached.remaining
            limit = cached.limit
            return
        }
        isLoadingUsage = true
        defer { isLoadingUsage = false }
        if let result = try? await KChimeAPIClient.shared.fetchUsage(featureKey: AppConstants.Feature.keyboard) {
            remaining = result.remaining
            limit = result.limit
            UsageCache.shared.setUsage(remaining: result.remaining, limit: result.limit, for: AppConstants.Feature.keyboard)
        }
    }
}
