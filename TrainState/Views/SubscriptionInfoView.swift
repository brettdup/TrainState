import SwiftUI

struct SubscriptionInfoView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var purchaseManager = PurchaseManager.shared

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
                    .glassCard(cornerRadius: 32)

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
                    .glassCard(cornerRadius: 32)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Details")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Manage subscriptions in the App Store.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 32)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Subscription")
        .onAppear {
            Task { await purchaseManager.updatePurchasedProducts() }
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionInfoView()
    }
}
