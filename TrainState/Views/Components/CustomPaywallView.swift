import RevenueCat
import SwiftUI

struct CustomPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var selectedPackageID: String?
    @State private var purchaseErrorMessage: String?
    @State private var restoreMessage: String?

    private var packages: [Package] {
        purchaseManager.availablePackages.sorted { lhs, rhs in
            sortRank(for: lhs.storeProduct.productIdentifier) < sortRank(for: rhs.storeProduct.productIdentifier)
        }
    }

    private var selectedPackage: Package? {
        guard let selectedPackageID else { return packages.first }
        return packages.first { $0.identifier == selectedPackageID } ?? packages.first
    }

    private var currentPackageProductID: String? {
        purchaseManager.activePremiumProductID
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(spacing: 24) {
                        hero

                        VStack(spacing: 12) {
                            ForEach(packages, id: \.identifier) { package in
                                PackageOptionView(
                                    package: package,
                                    isSelected: selectedPackage?.identifier == package.identifier,
                                    badgeText: badgeText(for: package),
                                    isCurrentPlan: package.storeProduct.productIdentifier == currentPackageProductID
                                ) {
                                    selectedPackageID = package.identifier
                                }
                            }
                        }

                        purchaseButton

                        Button {
                            Task { await restorePurchases() }
                        } label: {
                            if purchaseManager.isRestoringPurchases {
                                ProgressView()
                            } else {
                                Text("Restore purchases")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(purchaseManager.isRestoringPurchases || purchaseManager.isProcessingPurchase)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 26)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await purchaseManager.retryLoadingProducts()
                selectedPackageID = selectedPackage?.identifier
            }
            .alert("Purchase Failed", isPresented: Binding(
                get: { purchaseErrorMessage != nil },
                set: { if !$0 { purchaseErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { purchaseErrorMessage = nil }
            } message: {
                Text(purchaseErrorMessage ?? "")
            }
            .alert("Restore Purchases", isPresented: Binding(
                get: { restoreMessage != nil },
                set: { if !$0 { restoreMessage = nil } }
            )) {
                Button("OK", role: .cancel) {
                    restoreMessage = nil
                    if purchaseManager.hasActiveSubscription {
                        dismiss()
                    }
                }
            } message: {
                Text(restoreMessage ?? "")
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(colorScheme == .dark ? 0.28 : 0.16),
                Color(.systemBackground),
                Color(.secondarySystemBackground).opacity(0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var hero: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: 74, height: 74)
                Image(systemName: "crown.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 8) {
                Text("TrainState Premium")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Unlock unlimited workouts, categories, subcategories, and premium tracking tools.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                PaywallFeatureRow(icon: "infinity", title: "Unlimited workout logging")
                PaywallFeatureRow(icon: "folder.badge.plus", title: "More categories and subcategories")
                PaywallFeatureRow(icon: "chart.xyaxis.line", title: "Premium progress views")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }

    @ViewBuilder
    private var purchaseButton: some View {
        if purchaseManager.isLoadingProducts && packages.isEmpty {
            ProgressView("Loading options...")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        } else if packages.isEmpty {
            VStack(spacing: 12) {
                Text("Purchase options are unavailable right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Try again") {
                    Task { await purchaseManager.retryLoadingProducts() }
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
        } else {
            Button {
                Task { await purchaseSelectedPackage() }
            } label: {
                HStack(spacing: 10) {
                    if purchaseManager.isProcessingPurchase {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "crown.fill")
                    }

                    Text(purchaseManager.isProcessingPurchase ? "Processing..." : buttonTitle)
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                purchaseManager.isProcessingPurchase ||
                selectedPackage == nil ||
                selectedPackage?.storeProduct.productIdentifier == currentPackageProductID
            )
        }
    }

    private var buttonTitle: String {
        guard let selectedPackage else { return "Continue" }
        if selectedPackage.storeProduct.productIdentifier == currentPackageProductID {
            return "Current plan"
        }
        return "Continue - \(selectedPackage.storeProduct.localizedPriceString)"
    }

    @MainActor
    private func purchaseSelectedPackage() async {
        guard let selectedPackage else { return }

        do {
            try await purchaseManager.purchase(selectedPackage)
            await purchaseManager.updatePurchasedProducts()
            if purchaseManager.hasActiveSubscription {
                dismiss()
            }
        } catch StoreError.userCancelled {
            return
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func restorePurchases() async {
        do {
            try await purchaseManager.restorePurchases()
            await purchaseManager.updatePurchasedProducts()
            restoreMessage = purchaseManager.hasActiveSubscription
                ? "Your premium access has been restored."
                : "No active purchases were found for this Apple account."
        } catch {
            restoreMessage = error.localizedDescription
        }
    }

    private func badgeText(for package: Package) -> String? {
        switch package.storeProduct.productIdentifier {
        case "premiumlifetime":
            return "Best value"
        case "premium1year":
            return "Popular"
        default:
            return nil
        }
    }

    private func sortRank(for productID: String) -> Int {
        switch productID {
        case "premiumlifetime":
            return 0
        case "premium1year":
            return 1
        case "Premium1Month":
            return 2
        default:
            return 3
        }
    }
}

private struct PackageOptionView: View {
    let package: Package
    let isSelected: Bool
    let badgeText: String?
    let isCurrentPlan: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let badgeText {
                            Text(badgeText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }

                        if isCurrentPlan {
                            Text("Current plan")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.12), in: Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                Text(package.storeProduct.localizedPriceString)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch package.storeProduct.productIdentifier {
        case "premiumlifetime":
            return "Lifetime"
        case "premium1year":
            return "Yearly"
        case "Premium1Month":
            return "Monthly"
        default:
            return package.storeProduct.localizedTitle
        }
    }

    private var subtitle: String {
        switch package.storeProduct.productIdentifier {
        case "premiumlifetime":
            return "Pay once, keep Premium forever"
        case "premium1year":
            return "Premium access billed yearly"
        case "Premium1Month":
            return "Flexible monthly Premium access"
        default:
            return package.storeProduct.localizedDescription
        }
    }
}

private struct PaywallFeatureRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    CustomPaywallView()
}
