import SwiftUI

struct ShareView: View {
    @ObservedObject var viewModel: ShareViewModel
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Message input
                VStack(alignment: .leading, spacing: 6) {
                    Text("Message received")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    TextEditor(text: $viewModel.receivedMessage)
                        .font(.body)
                        .frame(minHeight: 60, maxHeight: 120)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Divider().padding(.top, 12)

                // Suggestions
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else {
                    suggestionList
                }

                // Tone chips
                toneChips

                Spacer(minLength: 0)
            }
            .navigationTitle("KChime Reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { Task { await viewModel.generate() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }

    // MARK: - Suggestions

    private var suggestionList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(Array(viewModel.suggestions.enumerated()), id: \.offset) { index, text in
                    ShareSuggestionRow(
                        text: text,
                        isCopied: viewModel.copiedIndex == index,
                        isSaved: viewModel.savedIndex == index,
                        onCopy: { viewModel.copy(text, at: index) },
                        onSave: { viewModel.save(text, at: index) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemFill))
                    .frame(maxWidth: .infinity)
                    .frame(height: 70)
                    .shimmer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Tone chips

    private var toneChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShareViewModel.ToneChip.allCases) { chip in
                    let isActive = viewModel.activeToneChip == chip
                    Button(action: {
                        viewModel.activeToneChip = isActive ? nil : chip
                        Task { await viewModel.generate() }
                    }) {
                        Text(chip.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isActive ? Color.indigo : Color(.systemFill))
                            .foregroundStyle(isActive ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Row

struct ShareSuggestionRow: View {
    let text: String
    let isCopied: Bool
    let isSaved: Bool
    let onCopy: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(.body)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack(spacing: 0) {
                Button(action: onCopy) {
                    HStack(spacing: 6) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Copied" : "Copy")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(isCopied ? .green : .indigo)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }

                Divider().frame(height: 28)

                Button(action: onSave) {
                    HStack(spacing: 6) {
                        Image(systemName: isSaved ? "star.fill" : "star")
                        Text(isSaved ? "Saved" : "Save")
                    }
                    .font(.subheadline)
                    .foregroundStyle(isSaved ? .yellow : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
