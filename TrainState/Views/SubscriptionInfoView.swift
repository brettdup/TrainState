import SwiftUI

struct SubscriptionInfoView: View {
    @StateObject private var purchaseManager = PurchaseManager.shared

    var body: some View {
        List {
            Section("Status") {
                Text(purchaseManager.hasActiveSubscription ? "Active" : "No active subscription")
                    .foregroundStyle(.secondary)
            }
            Section("Entitlements") {
                if purchaseManager.purchasedProductIDs.isEmpty {
                    Text("None")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(purchaseManager.purchasedProductIDs), id: \.self) { productID in
                        Text(productID)
                    }
                }
            }
            Section("Details") {
                Text("Manage subscriptions in the App Store.")
                    .foregroundStyle(.secondary)
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
