import SwiftUI
import RevenueCat

struct PaywallView: View {
    @EnvironmentObject var rcService: RevenueCatService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPackageIndex: Int = 0
    @State private var errorMessage: String?

    private var packages: [Package] { rcService.currentOffering?.availablePackages ?? [] }
    private var selectedPackage: Package? { packages.indices.contains(selectedPackageIndex) ? packages[selectedPackageIndex] : nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    heroSection
                    comparisonTable
                    if !packages.isEmpty { packagePicker }
                    ctaSection
                    legalFooter
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 48)
            }
            .navigationTitle("KChime Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Restore") {
                        Task {
                            try? await rcService.restorePurchases()
                            if rcService.isPro { dismiss() }
                        }
                    }
                    .font(.subheadline)
                }
            }
            .task { await rcService.fetchOfferings() }
            .alert("Purchase Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.indigo)

            Text("Reply without limits.")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("Get Pro for unlimited AI replies, custom tone profiles, and priority generation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Comparison Table

    private struct FeatureRow: Identifiable {
        var id: String { label }   // stable — label strings are fixed constants
        let icon: String
        let label: String
        let free: String
        let pro: String
    }

    private let rows: [FeatureRow] = [
        FeatureRow(icon: "wand.and.stars",     label: "AI replies / day",       free: "10",             pro: "Unlimited"),
        FeatureRow(icon: "slider.horizontal.3",label: "Custom tone profiles",    free: "–",              pro: "✓"),
        FeatureRow(icon: "arrow.2.squarepath", label: "Rewrite chip",           free: "–",              pro: "✓"),
        FeatureRow(icon: "bell.badge",         label: "Promise reminders",      free: "–",              pro: "✓"),
        FeatureRow(icon: "bookmark.fill",      label: "Saved replies",          free: "Limited",        pro: "Unlimited"),
        FeatureRow(icon: "person.2.fill",      label: "Contact memory",         free: "Limited",        pro: "Unlimited"),
        FeatureRow(icon: "heart.fill",         label: "Support indie dev",      free: "–",              pro: "✓"),
    ]

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("Free")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .center)
                Text("Pro")
                    .font(.caption.bold())
                    .foregroundStyle(.indigo)
                    .frame(width: 72, alignment: .center)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider()

            ForEach(rows) { row in
                HStack(spacing: 10) {
                    Image(systemName: row.icon)
                        .font(.body)
                        .foregroundStyle(.indigo)
                        .frame(width: 24)

                    Text(row.label)
                        .font(.subheadline)

                    Spacer()

                    Text(row.free)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .center)

                    Text(row.pro)
                        .font(.subheadline.bold())
                        .foregroundStyle(row.pro == "–" ? .secondary : .indigo)
                        .frame(width: 72, alignment: .center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Package Picker

    private var packagePicker: some View {
        VStack(spacing: 10) {
            ForEach(packages.indices, id: \.self) { idx in
                let pkg = packages[idx]
                PackageCard(
                    package: pkg,
                    isSelected: selectedPackageIndex == idx,
                    onSelect: { selectedPackageIndex = idx }
                )
            }
        }
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button(action: purchase) {
                Group {
                    if rcService.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(selectedPackage.map { "Start Pro — \($0.localizedPriceString)" } ?? "Start Pro")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.indigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(rcService.isLoading || selectedPackage == nil)

            Label("10 replies/day free — always", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Legal

    private var legalFooter: some View {
        Text("Subscriptions auto-renew unless cancelled at least 24 hours before the renewal date. Manage in App Store Settings.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Actions

    private func purchase() {
        guard let pkg = selectedPackage else { return }
        Task {
            do {
                try await rcService.purchase(package: pkg)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Package Card

private struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    let onSelect: () -> Void

    private var isBestValue: Bool {
        package.packageType == .annual
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(package.storeProduct.localizedTitle)
                            .font(.headline)
                        if isBestValue {
                            Text("BEST VALUE")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.indigo.opacity(0.15))
                                .foregroundStyle(.indigo)
                                .clipShape(Capsule())
                        }
                    }
                    if let intro = package.storeProduct.introductoryDiscount {
                        Text("Free \(intro.subscriptionPeriod.periodTitle) trial")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(package.localizedPriceString)
                        .font(.headline)
                    if package.packageType == .annual,
                       let monthlyEquiv = annualMonthlyEquiv {
                        Text("\(monthlyEquiv)/mo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(isSelected ? Color.indigo.opacity(0.08) : Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.indigo : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var annualMonthlyEquiv: String? {
        let price = package.storeProduct.price as Decimal
        let monthly = price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = package.storeProduct.priceLocale
        return formatter.string(from: monthly as NSDecimalNumber)
    }
}

// MARK: - Period helper

private extension SubscriptionPeriod {
    var periodTitle: String {
        switch unit {
        case .day:   return value == 1 ? "1-day" : "\(value)-day"
        case .week:  return value == 1 ? "1-week" : "\(value)-week"
        case .month: return value == 1 ? "1-month" : "\(value)-month"
        case .year:  return value == 1 ? "1-year" : "\(value)-year"
        @unknown default: return "\(value) period"
        }
    }
}
