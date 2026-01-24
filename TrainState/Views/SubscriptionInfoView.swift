import SwiftUI

struct SubscriptionInfoView: View {
    var body: some View {
        List {
            Section("Status") {
                Text("No active subscription")
                    .foregroundStyle(.secondary)
            }
            Section("Details") {
                Text("Manage subscriptions in the App Store.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Subscription")
    }
}

#Preview {
    NavigationStack {
        SubscriptionInfoView()
    }
}
