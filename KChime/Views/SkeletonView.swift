import SwiftUI

// MARK: - Skeleton Shape

struct SkeletonShape: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Reply Skeleton Card

struct ReplySkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                SkeletonShape(width: 24, height: 24)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonShape(width: 60, height: 12)
                    SkeletonShape(height: 14)
                    SkeletonShape(width: 200, height: 14)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Suggestions Skeleton

struct SuggestionsSkeletonCard: View {
    // Pre-computed widths to avoid re-randomizing on every body evaluation
    private static let barWidths: [CGFloat] = [160, 190, 140]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SkeletonShape(width: 130, height: 18)
                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { idx in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            SkeletonShape(width: 24, height: 24)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 6) {
                                SkeletonShape(width: 50, height: 10)
                                SkeletonShape(height: 14)
                                SkeletonShape(width: Self.barWidths[idx], height: 14)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    if idx < 2 {
                        Divider().padding(.leading, 52)
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
}

