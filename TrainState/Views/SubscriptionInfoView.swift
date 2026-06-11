import SwiftUI

struct SubscriptionInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var restoreStatusMessage: String?
    @State private var restoreErrorMessage: String?

    private var statusText: String {
        guard purchaseManager.hasCompletedInitialPremiumCheck else { return "Checking…" }
        return purchaseManager.hasActiveSubscription ? "Active" : "No active subscription"
    }

    private var currentPackageName: String {
        guard let productID = purchaseManager.activePremiumProductID else {
            return "None"
        }

        if let package = purchaseManager.availablePackages.first(where: { $0.storeProduct.productIdentifier == productID }) {
            return package.storeProduct.localizedTitle
        }

        return fallbackPackageName(for: productID)
    }

    var body: some View {
        ScrollView {
            GlassEffectContainerWrapper(spacing: 16) {
                LazyVStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Status")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(statusText)
                            .font(.body)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Current Package")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(currentPackageName)
                            .font(.body)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Entitlements")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if purchaseManager.activeEntitlementIDs.isEmpty {
                            Text("None")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(purchaseManager.activeEntitlementIDs).sorted(), id: \.self) { entitlementID in
                                Text(entitlementID)
                                    .font(.body)
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Details")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Manage subscriptions in the App Store.")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Button {
                            Task { await restorePurchases() }
                        } label: {
                            HStack(spacing: 10) {
                                if purchaseManager.isRestoringPurchases {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text(purchaseManager.isRestoringPurchases ? "Restoring Purchases..." : "Restore Purchases")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(purchaseManager.isRestoringPurchases)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Subscription")
        .onAppear {
            Task {
                await purchaseManager.retryLoadingProducts()
                await purchaseManager.updatePurchasedProducts()
            }
        }
        .alert("Restore Complete", isPresented: Binding(
            get: { restoreStatusMessage != nil },
            set: { if !$0 { restoreStatusMessage = nil } }
        )) {
            Button("OK") {
                restoreStatusMessage = nil
                if purchaseManager.hasActiveSubscription {
                    dismiss()
                }
            }
        } message: {
            Text(restoreStatusMessage ?? "")
        }
        .alert("Restore Failed", isPresented: Binding(
            get: { restoreErrorMessage != nil },
            set: { if !$0 { restoreErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                restoreErrorMessage = nil
            }
        } message: {
            Text(restoreErrorMessage ?? "")
        }
    }

    @MainActor
    private func restorePurchases() async {
        do {
            try await purchaseManager.restorePurchases()
            await purchaseManager.retryLoadingProducts()
            await purchaseManager.updatePurchasedProducts()
            if purchaseManager.hasActiveSubscription {
                restoreStatusMessage = "Your premium access has been restored."
            } else {
                restoreStatusMessage = "No active purchases were found for this Apple account."
            }
        } catch {
            restoreErrorMessage = error.localizedDescription
        }
    }

    private func fallbackPackageName(for productID: String) -> String {
        switch productID {
        case "premiumlifetime":
            return "Premium Lifetime"
        case "premium1year":
            return "Premium 1 Year"
        case "Premium1Month":
            return "Premium 1 Month"
        default:
            return productID
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionInfoView()
    }
}
