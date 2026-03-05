import SwiftUI

// MARK: - Promise banner (keyboard extension)

/// Compact banner that appears inside the keyboard after a promise phrase is
/// detected in an inserted suggestion. The user can confirm the reminder (→
/// schedules a local notification + saves to PromiseStore) or dismiss it.
struct PromiseBannerView: View {
    let detected: DetectedPromise
    let onSet: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.badge.fill")
                .foregroundStyle(.orange)
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 2) {
                Text("Promise detected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Remind you \(detected.dateDescription)?")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button("Set", action: onSet)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.orange))

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(
            Rectangle()
                .fill(Color.orange.opacity(0.25))
                .frame(width: 3),
            alignment: .leading
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
