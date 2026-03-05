import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var product: Product?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    heroSection
                    featuresSection
                    pricingSection
                    legalFooter
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .navigationTitle("KChime Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await loadProduct() }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
            Text("Reply without limits.")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("Upgrade to Pro for unlimited AI replies every day.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private let proFeatures: [(icon: String, text: String)] = [
        ("infinity",               "Unlimited replies per day"),
        ("bookmark.fill",          "Unlimited saved replies"),
        ("person.2.fill",          "Unlimited contact memory"),
        ("wand.and.stars",         "Priority reply generation"),
        ("heart.fill",             "Support indie development"),
    ]

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(proFeatures, id: \.text) { feature in
                HStack(spacing: 14) {
                    Image(systemName: feature.icon)
                        .font(.body)
                        .foregroundStyle(.indigo)
                        .frame(width: 24)
                    Text(feature.text)
                        .font(.body)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var pricingSection: some View {
        VStack(spacing: 16) {
            // Price
            VStack(spacing: 4) {
                if let product {
                    Text(product.displayPrice)
                        .font(.system(size: 40, weight: .bold))
                    Text("per month · cancel anytime")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .frame(height: 50)
                }
            }

            // CTA
            Button(action: purchase) {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Start Pro")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.indigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isLoading || product == nil)

            // Free tier reminder
            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Free plan: 5 replies/day forever")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var legalFooter: some View {
        VStack(spacing: 4) {
            Text("Subscription auto-renews monthly. Cancel anytime in App Store settings.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Logic

    private func loadProduct() async {
        product = try? await Product.products(for: [AppConstants.StoreKit.proMonthlyProductID]).first
    }

    private func purchase() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                try await appState.purchasePro()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
