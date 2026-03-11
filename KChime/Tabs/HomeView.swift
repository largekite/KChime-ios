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

// MARK: - Context-Specific Tones

private func contextToneLabels(for mode: ContextMode) -> [String] {
    switch mode {
    case .any:    return ["Casual", "Warm", "Funny", "Safe"]
    case .office: return ["Professional", "Diplomatic", "Confident", "Friendly"]
    case .text:   return ["Chill", "Witty", "Hype", "Sweet"]
    case .party:  return ["Playful", "Bold", "Energetic", "Smooth"]
    case .family: return ["Warm", "Gentle", "Lighthearted", "Respectful"]
    }
}

private func toneColor(for tone: String) -> Color {
    switch tone {
    case "Casual":       return .indigo
    case "Warm":         return .pink
    case "Funny":        return .yellow
    case "Safe":         return .green
    case "Professional": return .gray
    case "Diplomatic":   return .cyan
    case "Confident":    return .purple
    case "Friendly":     return .teal
    case "Chill":        return .cyan
    case "Witty":        return .orange
    case "Hype":         return .red
    case "Sweet":        return .pink
    case "Playful":      return .yellow
    case "Bold":         return .red
    case "Energetic":    return .green
    case "Smooth":       return .purple
    case "Gentle":       return .blue
    case "Lighthearted": return .yellow
    case "Respectful":   return .green
    default:             return .teal
    }
}

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var confidenceStore = ConfidenceAnalyticsStore.shared
    @State private var remaining = AppConstants.Feature.freeLimit
    @State private var limit = AppConstants.Feature.freeLimit

    // Reply generator
    @State private var inputText = ""
    @State private var contextMode: ContextMode = .any
    @State private var suggestions: [String] = []
    @State private var longerAlternative: String? = nil
    @State private var isGenerating = false
    @State private var generateError: String? = nil
    @State private var copiedIndex: Int? = nil
    @State private var recentPrompts: [String] = []
    @State private var confidenceScores: [Int: ConfidenceScore] = [:]  // index → score
    @FocusState private var inputFocused: Bool

    // Voice input
    @StateObject private var speechRecognizer = SpeechRecognizer(continuous: false)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Compact usage + confidence row
                    topStatsRow

                    replyGeneratorCard

                    if isGenerating {
                        SuggestionsSkeletonCard()
                    } else if !suggestions.isEmpty {
                        suggestionsCard
                    } else if !recentPrompts.isEmpty && inputText.isEmpty {
                        recentPromptsCard
                    }

                    // Feature discovery (shown when idle)
                    if suggestions.isEmpty {
                        discoverSection
                    }
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
                // Auto-submit after speech ends (matching web behavior)
                generate()
            }
        }
    }

    // MARK: - Reply Generator Card

    private var replyGeneratorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Reply", systemImage: "wand.and.stars")
                .font(.headline)
                .foregroundStyle(.teal)

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
                                .background(contextMode == mode ? Color.teal : Color(.tertiarySystemBackground))
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
                            .foregroundStyle(speechRecognizer.isListening ? .red : .teal)
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

            if let err = speechRecognizer.errorMessage ?? generateError {
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
                .background(canGenerate ? Color.teal : Color.teal.opacity(0.4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
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
                        .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }

            VStack(spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { idx, text in
                    VStack(spacing: 0) {
                        Button(action: { copy(text, index: idx) }) {
                            HStack(spacing: 12) {
                                Image(systemName: copiedIndex == idx ? "checkmark.circle.fill" : "doc.on.doc")
                                    .foregroundStyle(copiedIndex == idx ? .green : .teal)
                                    .font(.body)
                                    .frame(width: 24)
                                    .animation(.spring(response: 0.3), value: copiedIndex)
                                VStack(alignment: .leading, spacing: 2) {
                                    let tones = contextToneLabels(for: contextMode)
                                    if idx < tones.count {
                                        Text(tones[idx])
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(toneColor(for: tones[idx]).opacity(0.12))
                                            .foregroundStyle(toneColor(for: tones[idx]))
                                            .clipShape(Capsule())
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

                        if let score = confidenceScores[idx] {
                            ConfidenceBadge(score: score)
                                .padding(.bottom, 4)
                        }
                    }
                    if idx < suggestions.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }

                if let longer = longerAlternative {
                    Divider().padding(.leading, 52)
                    VStack(spacing: 0) {
                        Button(action: { copy(longer, index: 99) }) {
                            HStack(spacing: 12) {
                                Image(systemName: copiedIndex == 99 ? "checkmark.circle.fill" : "doc.on.doc")
                                    .foregroundStyle(copiedIndex == 99 ? .green : .teal)
                                    .font(.body)
                                    .frame(width: 24)
                                    .animation(.spring(response: 0.3), value: copiedIndex)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Detailed")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.teal)
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

                        if let score = confidenceScores[99] {
                            ConfidenceBadge(score: score)
                                .padding(.bottom, 4)
                        }
                    }
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

    // MARK: - Top Stats Row

    private var topStatsRow: some View {
        HStack(spacing: 12) {
            // Usage pill
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.teal)
                if appState.isPro {
                    Text("Pro")
                        .font(.caption.bold())
                        .foregroundStyle(.teal)
                } else {
                    Text("\(remaining)/\(limit)")
                        .font(.caption.bold().monospacedDigit())
                    ProgressView(value: Double(max(0, limit - remaining)), total: Double(max(1, limit)))
                        .tint(remaining > 1 ? .teal : .orange)
                        .frame(width: 40)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())

            Spacer()

            // Confidence score pill
            if confidenceStore.todayAverageScore > 0 {
                NavigationLink(destination: ConfidenceDashboardView()) {
                    HStack(spacing: 6) {
                        ScoreRing(
                            score: confidenceStore.todayAverageScore,
                            color: .teal,
                            size: 22
                        )
                        Text("Avg \(confidenceStore.todayAverageScore)")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(.teal)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                }
            }

            if !appState.isPro {
                NavigationLink(destination: PaywallView()) {
                    Text("Upgrade")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.teal)
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Discover Section

    private var discoverSection: some View {
        VStack(spacing: 12) {
            Text("Explore")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                NavigationLink(destination: ReplyPacksView()) {
                    DiscoverCard(
                        icon: "tray.full.fill",
                        title: "Reply Packs",
                        subtitle: "Browse scenarios",
                        color: .teal
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: ConfidenceDashboardView()) {
                    DiscoverCard(
                        icon: "chart.bar.fill",
                        title: "Confidence",
                        subtitle: "Your score stats",
                        color: .green
                    )
                }
                .buttonStyle(.plain)
            }

            // Keyboard tip (compact)
            HStack(spacing: 10) {
                Image(systemName: "keyboard.fill")
                    .font(.caption)
                    .foregroundStyle(.teal)
                Text("Enable the KChime keyboard in Settings to reply from any app.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
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
        confidenceScores = [:]

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

                // Compute confidence scores for each suggestion
                for (idx, text) in response.suggestions.enumerated() {
                    let score = ConfidenceScorer.score(text)
                    confidenceScores[idx] = score
                    ConfidenceAnalyticsStore.shared.record(score: score)
                }
                if let longer = longerAlternative {
                    let score = ConfidenceScorer.score(longer)
                    confidenceScores[99] = score
                    ConfidenceAnalyticsStore.shared.record(score: score)
                }
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
        ToastManager.shared.show("Copied to clipboard")
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
        if let result = try? await KChimeAPIClient.shared.fetchUsage(featureKey: AppConstants.Feature.keyboard) {
            remaining = result.remaining
            limit = result.limit
            UsageCache.shared.setUsage(remaining: result.remaining, limit: result.limit, for: AppConstants.Feature.keyboard)
        } else if appState.isPro {
            let proLimit = EntitlementStore.shared.dailyLimit(for: AppConstants.Feature.keyboard)
            remaining = proLimit
            limit = proLimit
        }
    }
}

// MARK: - Discover Card

private struct DiscoverCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
