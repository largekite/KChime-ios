import SwiftUI
import UIKit

/// Root SwiftUI view for the keyboard extension.
struct KeyboardRootView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    weak var inputController: KeyboardViewController?

    var body: some View {
        KeyboardView(viewModel: viewModel, inputController: inputController)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Main keyboard layout

struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    weak var inputController: KeyboardViewController?

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            contextInput
            Divider()
            suggestionArea
            toneChipRow
            MemoryOptInBanner(
                isVisible: $viewModel.showMemoryBanner,
                onYes: { viewModel.showContactNoteSheet = true }
            )
            savedTab
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $viewModel.showContactNoteSheet) {
            QuickContactNoteSheet(isPresented: $viewModel.showContactNoteSheet)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Header bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            // Globe (switch keyboard)
            Button(action: { inputController?.advanceToNextKeyboard() }) {
                Image(systemName: "globe")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }

            Text("KChime")
                .font(.caption.bold())
                .foregroundStyle(.primary)

            Spacer()

            // Usage indicator
            usageIndicator

            // Settings deep link
            if let url = URL(string: "kchime://settings") {
                Link(destination: url) {
                    Image(systemName: "gearshape")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color(.secondarySystemGroupedBackground))
    }

    @ViewBuilder
    private var usageIndicator: some View {
        if viewModel.remaining <= 0 {
            Text("Limit reached")
                .font(.caption2.bold())
                .foregroundStyle(.orange)
        } else {
            HStack(spacing: 4) {
                // Small dots representing remaining
                ForEach(0..<viewModel.limit, id: \.self) { i in
                    Circle()
                        .fill(i < viewModel.remaining ? Color.indigo : Color(.systemFill))
                        .frame(width: 5, height: 5)
                }
            }
        }
    }

    // MARK: - Context input

    private var contextInput: some View {
        HStack(spacing: 8) {
            TextField("Paste the message you received…", text: $viewModel.receivedMessage, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...3)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onSubmit { Task { await viewModel.generate() } }

            Button(action: { Task { await viewModel.generate() } }) {
                Image(systemName: viewModel.isLoading ? "ellipsis" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.receivedMessage.isEmpty ? .secondary : .indigo)
                    .symbolEffect(.pulse, isActive: viewModel.isLoading)
            }
            .disabled(viewModel.receivedMessage.isEmpty || viewModel.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Suggestion area

    @ViewBuilder
    private var suggestionArea: some View {
        if let error = viewModel.errorMessage {
            errorBanner(error)
        } else if viewModel.isLoading {
            loadingSkeleton
        } else if viewModel.suggestions.isEmpty {
            emptyState
        } else {
            suggestionStrip
        }
    }

    private var suggestionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(viewModel.suggestions.enumerated()), id: \.offset) { index, text in
                    SuggestionCell(
                        text: text,
                        isInserted: viewModel.insertedIndex == index,
                        onInsert: {
                            viewModel.insertSuggestion(text, at: index)
                        },
                        onCopy: {
                            viewModel.copySuggestion(text)
                        },
                        onSave: {
                            saveReply(text)
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 90)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var loadingSkeleton: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemFill))
                    .frame(width: 140, height: 60)
                    .shimmer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 90)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var emptyState: some View {
        HStack {
            Image(systemName: "arrow.up.circle")
                .foregroundStyle(.secondary)
            Text("Paste a message to get reply suggestions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 90)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Tone chips

    private var toneChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(KeyboardViewModel.ToneChip.allCases) { chip in
                    let isActive = viewModel.activeToneChip == chip
                    Button(action: { Task { await viewModel.applyToneChip(chip) } }) {
                        Text(chip.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isActive ? Color.indigo : Color(.systemFill))
                            .foregroundStyle(isActive ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .disabled(viewModel.suggestions.isEmpty || viewModel.isLoading
                              || viewModel.regenerationsUsed >= 3)
                }

                if viewModel.regenerationsUsed >= 3 {
                    Text("Regeneration limit reached")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Saved tab

    private var savedTab: some View {
        // In a future iteration this will show a horizontal scroll of saved replies.
        // For now it's a compact placeholder that deep-links to the main app.
        Group {
            if let url = URL(string: "kchime://saved") {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Image(systemName: "bookmark.fill")
                            .font(.caption)
                        Text("Saved")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - CoreData save (lightweight, via App Group shared store)

    private func saveReply(_ text: String) {
        // Persist to shared UserDefaults as a lightweight list;
        // the main app CoreData stack will pick it up on next launch.
        let defaults = UserDefaults(suiteName: AppConstants.appGroupID)!
        var pending = defaults.stringArray(forKey: "kchime_pending_saves") ?? []
        pending.append(text)
        defaults.set(pending, forKey: "kchime_pending_saves")
    }
}

// MARK: - Suggestion cell

struct SuggestionCell: View {
    let text: String
    let isInserted: Bool
    let onInsert: () -> Void
    let onCopy: () -> Void
    let onSave: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onInsert) {
                Text(text)
                    .font(.caption)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .padding(10)
                    .frame(width: 160, alignment: .topLeading)
                    .background(
                        isInserted
                            ? Color.green.opacity(0.2)
                            : Color(.systemBackground)
                    )
            }
            .buttonStyle(.plain)

            Divider()

            HStack(spacing: 0) {
                Button(action: {
                    onCopy()
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copied = false
                    }
                }) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(copied ? .green : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }

                Divider().frame(height: 20)

                Button(action: onSave) {
                    Image(systemName: "star")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
            }
            .background(Color(.secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

// MARK: - Shimmer modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: phase - 0.3),
                        .init(color: .white.opacity(0.4), location: phase),
                        .init(color: .clear, location: phase + 0.3),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .blendMode(.screen)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.3
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
