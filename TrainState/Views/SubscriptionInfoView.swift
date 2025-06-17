import SwiftUI
import StoreKit

struct SubscriptionInfoView: View {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var isSubscribed = false
    @State private var showingTermsOfUse = false
    
    private var monthlyProduct: Product? {
        purchaseManager.products.first { $0.id == "Premium1Month" }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Subscription Status
                VStack(alignment: .leading, spacing: 16) {
                    Text("Subscription Status")
                        .font(.title2.weight(.bold))
                    
                    HStack {
                        Image(systemName: isSubscribed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(isSubscribed ? .green : .red)
                        Text(isSubscribed ? "Active Subscription" : "No Active Subscription")
                            .fontWeight(.medium)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                
                // Subscription Details
                VStack(alignment: .leading, spacing: 16) {
                    Text("Subscription Details")
                        .font(.title2.weight(.bold))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(title: "Title", value: "TrainState Premium")
                        if let product = monthlyProduct {
                            InfoRow(title: "Monthly Plan", value: product.displayPrice + "/month")
                        }
                        
                        // Recurring Information
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recurring Subscription")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            Text("• Automatically renews each month")
                                .font(.subheadline)
                            Text("• Cancel anytime in App Store settings")
                                .font(.subheadline)
                            Text("• Payment charged to your Apple ID account")
                                .font(.subheadline)
                            Text("• Cancel at least 24 hours before renewal")
                                .font(.subheadline)
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                
                // Terms and Privacy
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terms and Privacy")
                        .font(.title2.weight(.bold))
                    
                    VStack(spacing: 12) {
                        Button(action: { showingTermsOfUse = true }) {
                            HStack {
                                Text("Terms of Use")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Link(destination: URL(string: "https://trainstate.app/privacy")!) {
                            HStack {
                                Text("Privacy Policy")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
                
                // Premium Features
                VStack(alignment: .leading, spacing: 16) {
                    Text("Premium Features")
                        .font(.title2.weight(.bold))
                    
                    VStack(spacing: 12) {
                        FeatureRow(icon: "infinity", title: "Unlimited Workouts", description: "Track as many workouts as you want")
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Advanced Analytics", description: "Get detailed insights into your fitness progress")
                        FeatureRow(icon: "folder.fill", title: "Premium Categories", description: "Create unlimited custom categories and subcategories")
                        FeatureRow(icon: "icloud.fill", title: "Cloud Sync", description: "Sync your data across all your devices")
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Subscription Info")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isSubscribed = purchaseManager.hasActiveSubscription
        }
        .onChange(of: purchaseManager.hasActiveSubscription) { newValue in
            isSubscribed = newValue
        }
        .sheet(isPresented: $showingTermsOfUse) {
            NavigationView {
                TermsOfUseView()
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}


#Preview {
    NavigationView {
        SubscriptionInfoView()
    }
} 
