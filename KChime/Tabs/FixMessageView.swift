import SwiftUI

// MARK: - Message Type

enum MessageType: String, CaseIterable {
    case casualText = "Casual text"
    case workEmail = "Work email"
    case slackTeams = "Slack / Teams"
    case formalLetter = "Formal letter"
    case socialMedia = "Social media"
}

// MARK: - Recipient

enum FixRecipient: String, CaseIterable {
    case manager = "to my manager"
    case coworker = "to a coworker"
    case client = "to a client"
    case friend = "to a friend"
    case landlord = "to my landlord"
    case general = "general"
}

// MARK: - Fix Result

struct MessageFix: Identifiable {
    let id = UUID()
    let tone: String
    let text: String
    let improvements: [String]
}

// MARK: - Tone Colors

private func toneColor(for tone: String) -> Color {
    switch tone {
    case "Polished":      return .indigo
    case "Approachable":  return .pink
    case "Confident":     return .green
    case "Clean":         return .cyan
    case "Friendly":      return .pink
    case "Punchy":        return .orange
    case "Direct":        return .green
    case "Diplomatic":    return .purple
    case "Authoritative": return .gray
    case "Smooth":        return .cyan
    case "Bold":          return .red
    case "Witty":         return .yellow
    default:              return .teal
    }
}

// MARK: - Fix Message View

struct FixMessageView: View {
    @EnvironmentObject var appState: AppState
    @State private var draft = ""
    @State private var messageType: MessageType = .casualText
    @State private var recipient: FixRecipient = .general
    @State private var fixes: [MessageFix] = []
    @State private var isGenerating = false
    @State private var generateError: String? = nil
    @State private var copiedIndex: Int? = nil
    @State private var remaining = AppConstants.Feature.fixFreeLimit
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    inputCard

                    if !fixes.isEmpty {
                        resultsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Fix My Message")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.title3)
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text("Fix My Message")
                    .font(.subheadline.bold())
                Text("Paste a draft — get 3 polished rewrites that sound natural.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Input Card

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Message details")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            // Message type picker
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Message type")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Picker("Type", selection: $messageType) {
                        ForEach(MessageType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sending to")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Picker("Recipient", selection: $recipient) {
                        ForEach(FixRecipient.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
            }

            // Draft input
            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text("Paste or type your draft message here...")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $draft)
                    .font(.subheadline)
                    .frame(minHeight: 100, maxHeight: 160)
                    .focused($inputFocused)
            }
            .padding(8)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .bottomTrailing) {
                Text("\(draft.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(8)
            }

            if let err = generateError {
                Text(err).font(.caption).foregroundStyle(.red)
            }

            // Usage + Generate button
            HStack {
                if !appState.isPro {
                    Text("\(remaining) fix\(remaining == 1 ? "" : "es") left today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: fixMessage) {
                    Group {
                        if isGenerating {
                            ProgressView().tint(.white)
                        } else {
                            Label("Fix it", systemImage: "wand.and.stars")
                                .font(.subheadline.bold())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(canGenerate ? Color.indigo : Color.indigo.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!canGenerate)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var canGenerate: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    // MARK: - Results

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3 REWRITES")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
                .tracking(1)

            ForEach(Array(fixes.enumerated()), id: \.element.id) { idx, fix in
                FixCard(fix: fix, index: idx, copiedIndex: $copiedIndex)
            }
        }
    }

    // MARK: - Actions

    private func fixMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputFocused = false
        isGenerating = true
        generateError = nil
        fixes = []
        copiedIndex = nil

        Task {
            do {
                let request = FixMessageRequest(
                    draft: text,
                    messageType: messageType.rawValue,
                    relationship: recipient.rawValue,
                    toneProfile: appState.toneProfile.toPayload()
                )
                let response = try await KChimeAPIClient.shared.fixMessage(request: request)
                fixes = response.fixes.map { fix in
                    MessageFix(tone: fix.tone, text: fix.text, improvements: fix.improvements)
                }
                remaining = response.remaining
            } catch {
                generateError = error.localizedDescription
            }
            isGenerating = false
        }
    }
}

// MARK: - Fix Card

private struct FixCard: View {
    let fix: MessageFix
    let index: Int
    @Binding var copiedIndex: Int?

    private var color: Color { toneColor(for: fix.tone) }
    private var isCopied: Bool { copiedIndex == index }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(fix.tone)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.15))
                    .foregroundStyle(color)
                    .clipShape(Capsule())

                Spacer()

                Button(action: copy) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.caption)
                        Text(isCopied ? "Copied!" : "Copy")
                            .font(.caption)
                    }
                    .foregroundStyle(isCopied ? .green : .teal)
                }
                .buttonStyle(.plain)
            }

            Text(fix.text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if !fix.improvements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(fix.improvements, id: \.self) { improvement in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(color)
                                .frame(width: 5, height: 5)
                                .padding(.top, 5)
                            Text(improvement)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }

    private func copy() {
        UIPasteboard.general.string = fix.text
        copiedIndex = index
        Task {
            try? await Task.sleep(for: .seconds(2))
            copiedIndex = nil
        }
    }
}
