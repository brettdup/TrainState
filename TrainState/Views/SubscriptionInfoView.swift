import SwiftUI

struct SubscriptionInfoView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var restoreStatusMessage: String?
    @State private var restoreErrorMessage: String?

    private var statusText: String {
        guard purchaseManager.hasCompletedInitialPremiumCheck else { return "Checking…" }
        return purchaseManager.hasActiveSubscription ? "Active" : "No active subscription"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.4 : 0.2),
                    Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 20) {
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
                        Text("Entitlements")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        if purchaseManager.purchasedProductIDs.isEmpty {
                            Text("None")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(purchaseManager.purchasedProductIDs), id: \.self) { productID in
                                Text(productID)
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
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Subscription")
        .onAppear {
            Task { await purchaseManager.updatePurchasedProducts() }
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
}

#Preview {
    NavigationStack {
        SubscriptionInfoView()
    }
}
