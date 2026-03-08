import SwiftUI
import Speech

// MARK: - Transcript Entry

struct TranscriptEntry: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date
    var explanation: String? = nil
    var isLoadingExplanation = false
}

// MARK: - Live Listen View

struct LiveListenView: View {
    @EnvironmentObject var appState: AppState

    @StateObject private var speechRecognizer = SpeechRecognizer(continuous: true)
    @State private var mode: ListenMode = .auto
    @State private var entries: [TranscriptEntry] = []
    @State private var currentDraft = ""
    @State private var silenceTimer: Timer? = nil

    enum ListenMode: String, CaseIterable {
        case auto   = "Auto"
        case manual = "Manual"
        var description: String {
            switch self {
            case .auto:   return "Saves after 2 s silence"
            case .manual: return "Tap to save each phrase"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode picker
                Picker("Mode", selection: $mode) {
                    ForEach(ListenMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                Text(mode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                // Transcript history
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if entries.isEmpty && !speechRecognizer.isListening {
                                ContentUnavailableView(
                                    "Start listening",
                                    systemImage: "mic.circle",
                                    description: Text("Tap the mic button to transcribe what you hear in real time.")
                                )
                                .padding(.top, 60)
                            }

                            ForEach(entries) { entry in
                                TranscriptEntryView(entry: entry, onExplain: { explain(entry: entry) })
                            }

                            // Live draft
                            if !currentDraft.isEmpty {
                                HStack {
                                    Text(currentDraft)
                                        .font(.body)
                                        .foregroundStyle(.primary.opacity(0.6))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(Color(.tertiarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .id("draft")
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                    .onChange(of: currentDraft) { _, _ in
                        withAnimation { proxy.scrollTo("draft", anchor: .bottom) }
                    }
                }

                Divider()

                // Controls bar
                bottomBar
            }
            .navigationTitle("Live Listen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !entries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") {
                            entries.removeAll()
                            currentDraft = ""
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onChange(of: speechRecognizer.transcript) { _, newValue in
            currentDraft = newValue
            if mode == .auto {
                scheduleSilenceCommit()
            }
        }
        .onChange(of: speechRecognizer.isListening) { _, isNowListening in
            if !isNowListening {
                commitCurrentDraft()
            }
        }
        .onDisappear {
            silenceTimer?.invalidate()
            silenceTimer = nil
            speechRecognizer.stopListening()
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 24) {
            // Manual save button (manual mode only)
            if mode == .manual && !currentDraft.isEmpty {
                Button(action: commitCurrentDraft) {
                    Label("Save phrase", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Error badge
            if let err = speechRecognizer.errorMessage {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 200)
            }

            // Mic button
            Button(action: toggleListening) {
                ZStack {
                    Circle()
                        .fill(speechRecognizer.isListening ? Color.red : Color.teal)
                        .frame(width: 64, height: 64)
                    Image(systemName: speechRecognizer.isListening ? "stop.fill" : "mic.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func toggleListening() {
        if speechRecognizer.isListening {
            speechRecognizer.stopListening()
        } else {
            Task { await speechRecognizer.startListening() }
        }
    }

    private func scheduleSilenceCommit() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            Task { @MainActor in self.commitCurrentDraft() }
        }
    }

    private func commitCurrentDraft() {
        let text = currentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        silenceTimer?.invalidate()
        entries.append(TranscriptEntry(text: text, timestamp: Date()))
        currentDraft = ""
    }

    private func explain(entry: TranscriptEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx].isLoadingExplanation = true
        Task {
            do {
                let request = ReplyRequest(
                    featureKey: AppConstants.Feature.keyboard,
                    receivedMessage: "Explain this phrase and suggest how to respond: \"\(entry.text)\"",
                    toneProfile: appState.toneProfile.toPayload()
                )
                let response = try await KChimeAPIClient.shared.generateReplies(request: request)
                if let explanationIdx = entries.firstIndex(where: { $0.id == entry.id }) {
                    entries[explanationIdx].explanation = response.suggestions.first
                    entries[explanationIdx].isLoadingExplanation = false
                }
            } catch {
                if let explanationIdx = entries.firstIndex(where: { $0.id == entry.id }) {
                    entries[explanationIdx].explanation = "Could not generate explanation."
                    entries[explanationIdx].isLoadingExplanation = false
                }
            }
        }
    }
}

// MARK: - Transcript Entry View

private struct TranscriptEntryView: View {
    let entry: TranscriptEntry
    let onExplain: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(.teal)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.text)
                        .font(.body)

                    Text(entry.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Copy button
                Button(action: copyText) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }

            // Explanation
            if entry.isLoadingExplanation {
                ProgressView()
                    .padding(.leading, 28)
            } else if let explanation = entry.explanation {
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.leading, 24)
            } else {
                Button(action: onExplain) {
                    Label("Explain & suggest reply", systemImage: "lightbulb")
                        .font(.caption.bold())
                        .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)
                .padding(.leading, 28)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private func copyText() {
        UIPasteboard.general.string = entry.text
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}
