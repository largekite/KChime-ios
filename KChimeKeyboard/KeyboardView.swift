import SwiftUI
import UIKit

// MARK: - Root

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

            // Who are you replying to?
            profilePickerRow

            KDivider()

            // Top area: suggestion chips (3 short + 1 detailed)
            suggestionArea

            // Controls: tone modifiers + Regenerate
            controlsRow
                .disabled(viewModel.isLoading)

            KDivider()

            // Input: paste received message + generate button
            inputRow

            // Promise reminder banner (appears when a promise phrase is detected in inserted text)
            if let detected = viewModel.detectedPromise {
                PromiseBannerView(
                    detected: detected,
                    onSet: { viewModel.confirmPromise() },
                    onDismiss: { viewModel.dismissPromise() }
                )
            }

            // Memory opt-in (shown after insert, mutually exclusive with promise banner)
            MemoryOptInBanner(
                isVisible: $viewModel.showMemoryBanner,
                onYes: { viewModel.showContactNoteSheet = true }
            )
            .animation(.easeInOut(duration: 0.2), value: viewModel.showMemoryBanner)

            savedBar
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $viewModel.showContactNoteSheet) {
            QuickContactNoteSheet(isPresented: $viewModel.showContactNoteSheet)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Header bar

    private var headerBar: some View {
        HStack(spacing: 4) {
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

            usagePill

            settingsButton
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
        .background(Color(.secondarySystemGroupedBackground))
    }

    @ViewBuilder
    private var usagePill: some View {
        if viewModel.remaining <= 0 {
            Text("Limit reached")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.orange))
        } else {
            HStack(spacing: 3) {
                ForEach(0..<min(viewModel.limit, 5), id: \.self) { i in
                    Circle()
                        .fill(i < viewModel.remaining ? Color.indigo : Color(.systemFill))
                        .frame(width: 5, height: 5)
                }
                if viewModel.limit > 5 {
                    Text("+").font(.system(size: 8)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
        }
    }

    private var settingsButton: some View {
        Group {
            if let url = URL(string: "kchime://settings") {
                Link(destination: url) {
                    Image(systemName: "gearshape")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
            }
        }
    }

    // MARK: - Profile picker row

    private var profilePickerRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "None" chip — no relationship context
                ProfileChipButton(
                    emoji: nil,
                    label: "None",
                    isSelected: viewModel.selectedRelationshipProfile == nil,
                    onTap: { viewModel.selectedRelationshipProfile = nil }
                )

                ForEach(RelationshipProfileStore.shared.allProfiles) { profile in
                    ProfileChipButton(
                        emoji: profile.emoji,
                        label: profile.name,
                        isSelected: viewModel.selectedRelationshipProfile?.id == profile.id,
                        onTap: {
                            viewModel.selectedRelationshipProfile =
                                viewModel.selectedRelationshipProfile?.id == profile.id
                                    ? nil   // tap again to deselect
                                    : profile
                        }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Suggestion area

    @ViewBuilder
    private var suggestionArea: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            if let error = viewModel.errorState {
                errorView(error)
            } else if viewModel.isLoading {
                loadingSkeletonView
            } else if viewModel.suggestions.isEmpty {
                emptyStateView
            } else {
                repliesStack
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.2), value: viewModel.suggestions.count)
    }

    /// 3 short chips + optional "Detailed" chip at the bottom
    private var repliesStack: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.suggestions.enumerated()), id: \.offset) { index, text in
                SuggestionChip(
                    text: text,
                    badge: nil,
                    isInserted: viewModel.insertedIndex == index,
                    onInsert: { viewModel.insertSuggestion(text, at: index) },
                    onCopy:   { viewModel.copySuggestion(text) },
                    onSave:   { viewModel.saveSuggestion(text) }
                )
                KDivider()
            }

            if let longer = viewModel.longerAlternative {
                SuggestionChip(
                    text: longer,
                    badge: "Detailed",
                    isInserted: viewModel.insertedIndex == 99,   // dedicated sentinel index
                    onInsert: { viewModel.insertSuggestion(longer, at: 99) },
                    onCopy:   { viewModel.copySuggestion(longer) },
                    onSave:   { viewModel.saveSuggestion(longer) }
                )
            }
        }
    }

    private var loadingSkeletonView: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { i in
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemFill))
                        .frame(width: [260, 200, 240, 180][i], height: 12)
                        .shimmer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemFill))
                        .frame(width: [180, 140, 160, 220][i], height: 10)
                        .shimmer()
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                if i < 3 { KDivider() }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.title2)
                .foregroundStyle(Color.indigo.opacity(0.5))
            Text("Paste a message above to get reply suggestions")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, minHeight: 132)
    }

    private func errorView(_ error: KeyboardViewModel.ErrorState) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: error.showsUpgradeButton ? "star.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(error.showsUpgradeButton ? .indigo : .orange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(error.message)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if error.showsUpgradeButton {
                        Text("Free tier: \(AppConstants.Feature.freeLimit) replies/day")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !error.showsUpgradeButton {
                    Button(action: viewModel.dismissError) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            if error.showsUpgradeButton, let url = URL(string: "kchime://upgrade") {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Upgrade to Pro — Unlimited replies")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.indigo))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 132)
    }

    // MARK: - Controls row

    private var controlsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(KeyboardViewModel.ToneChip.allCases) { chip in
                    ToneChipButton(
                        chip: chip,
                        isActive: viewModel.activeToneChip == chip,
                        isDisabled: viewModel.suggestions.isEmpty || viewModel.isLoading
                            || viewModel.remaining <= 0,
                        onTap: { Task { await viewModel.applyToneChip(chip) } }
                    )
                }

                Capsule()
                    .fill(Color(.separator))
                    .frame(width: 1, height: 20)
                    .padding(.horizontal, 2)

                let regenDisabled = viewModel.suggestions.isEmpty || viewModel.isLoading
                    || viewModel.regenerationsUsed >= 3 || viewModel.remaining <= 0
                Button(action: { Task { await viewModel.regenerate() } }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise").font(.caption2.bold())
                        Text("Regenerate").font(.caption.bold())
                        if viewModel.regenerationsUsed > 0 {
                            Text("\(3 - viewModel.regenerationsUsed) left")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(regenDisabled
                        ? Color(.systemFill) : Color(.tertiarySystemGroupedBackground)))
                    .foregroundStyle(regenDisabled ? Color.secondary : Color.primary)
                }
                .disabled(regenDisabled)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Input row

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField("Paste the message you received…", text: $viewModel.receivedMessage, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...3)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator), lineWidth: 0.5))

            Button(action: { Task { await viewModel.generate() } }) {
                ZStack {
                    Circle()
                        .fill(viewModel.receivedMessage.isEmpty ? Color(.systemFill) : Color.indigo)
                        .frame(width: 36, height: 36)
                    if viewModel.isLoading {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.subheadline.bold())
                            .foregroundStyle(viewModel.receivedMessage.isEmpty ? .secondary : .white)
                    }
                }
            }
            .disabled(viewModel.receivedMessage.isEmpty || viewModel.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Saved bar

    private var savedBar: some View {
        HStack {
            if let url = URL(string: "kchime://saved") {
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Image(systemName: "bookmark.fill").font(.caption2)
                        Text("Saved Replies").font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(action: { inputController?.dismissKeyboardAction() }) {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 28)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Profile chip button

private struct ProfileChipButton: View {
    let emoji: String?
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if let emoji { Text(emoji).font(.caption) }
                Text(label).font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(isSelected ? Color.indigo : Color(.tertiarySystemGroupedBackground))
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Suggestion chip

struct SuggestionChip: View {
    let text: String
    let badge: String?        // nil = normal chip; "Detailed" = longer alternative chip
    let isInserted: Bool
    let onInsert: () -> Void
    let onCopy: () -> Void
    let onSave: () -> Void

    @State private var copiedFeedback = false

    var body: some View {
        Button(action: onInsert) {
            HStack(spacing: 10) {
                // Insert indicator
                ZStack {
                    Circle()
                        .fill(isInserted ? Color.green : Color(.tertiarySystemGroupedBackground))
                        .frame(width: 24, height: 24)
                    Image(systemName: isInserted ? "checkmark" : insertIcon)
                        .font(.caption2.bold())
                        .foregroundStyle(isInserted ? .white : .secondary)
                }
                .animation(.spring(response: 0.3), value: isInserted)

                VStack(alignment: .leading, spacing: 2) {
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.indigo.opacity(0.75)))
                    }
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(isInserted ? .secondary : .primary)
                        .lineLimit(badge == nil ? 2 : 4)   // show more lines for the detailed chip
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeInOut, value: isInserted)

                // Inline actions
                HStack(spacing: 0) {
                    Button(action: {
                        onCopy()
                        copiedFeedback = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            copiedFeedback = false
                        }
                    }) {
                        Image(systemName: copiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(copiedFeedback ? .green : .secondary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)

                    Button(action: onSave) {
                        Image(systemName: "star")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(
                badge != nil
                    ? Color.indigo.opacity(isInserted ? 0.1 : 0.04)
                    : isInserted ? Color.green.opacity(0.07) : Color(.secondarySystemGroupedBackground)
            )
        }
        .buttonStyle(.plain)
    }

    private var insertIcon: String {
        badge != nil ? "arrow.up.left.and.arrow.down.right" : "arrow.up.left"
    }
}

// MARK: - Tone chip button

struct ToneChipButton: View {
    let chip: KeyboardViewModel.ToneChip
    let isActive: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: chip.systemImage).font(.caption2.bold())
                Text(chip.rawValue).font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(
                isActive ? Color.indigo : isDisabled ? Color(.systemFill) : Color(.tertiarySystemGroupedBackground)
            ))
            .foregroundStyle(isActive ? Color.white : isDisabled ? Color.secondary : Color.primary)
        }
        .disabled(isDisabled)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - Helpers

private struct KDivider: View {
    var body: some View {
        Rectangle().fill(Color(.separator)).frame(height: 0.5)
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -0.5
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: phase),
                            .init(color: .white.opacity(0.45), location: phase + 0.2),
                            .init(color: .clear, location: phase + 0.4),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: geo.size.width * phase)
                }
                .blendMode(.screen)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}
