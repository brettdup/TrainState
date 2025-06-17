import SwiftUI
import StoreKit
import SwiftData

struct PremiumView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showingSubscriptionInfo = false
    
    init() {
        print("PremiumView: Initializing...")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Section
                    PremiumHeroSection()
                    
                    // Subscription Options
                    if purchaseManager.isLoadingProducts {
                        LoadingView(message: "Loading premium options...")
                    } else if let error = purchaseManager.productLoadError {
                        ErrorView(error: error) {
                            Task {
                                print("PremiumView: Retrying product load...")
                                await purchaseManager.retryLoadingProducts()
                            }
                        }
                    } else {
                        // Subscription Products
                        if !purchaseManager.subscriptionProducts.isEmpty {
                            PremiumSection(title: "Premium Subscription") {
                                ForEach(purchaseManager.subscriptionProducts) { product in
                                    SubscriptionCard(
                                        product: product,
                                        isPurchased: purchaseManager.purchasedProductIDs.contains(product.id)
                                    ) {
                                        await purchase(product)
                                    }
                                }
                            }
                        } else {
                            Text("No subscription products available")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                        
                        // One-time Purchase Products
                        if !purchaseManager.oneTimeProducts.isEmpty {
                            PremiumSection(title: "One-time Purchase") {
                                ForEach(purchaseManager.oneTimeProducts) { product in
                                    ProductCard(
                                        product: product,
                                        isPurchased: purchaseManager.purchasedProductIDs.contains(product.id)
                                    ) {
                                        await purchase(product)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Premium Status
                    PremiumSection(title: "Your Premium Status") {
                        VStack(spacing: 16) {
                            StatusCard(
                                title: "Premium Subscription",
                                description: "Active subscription with all premium features",
                                icon: "crown.fill",
                                isActive: purchaseManager.hasActiveSubscription
                            )
                        }
                        
                        // Restore Purchases Button
                        Button(action: restorePurchases) {
                            Label("Restore Purchases", systemImage: "arrow.clockwise.circle.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.ultraThinMaterial)
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                        }
                        .padding(.top, 8)
                    }
                    
                    // Subscription Info Button
                    Button(action: { showingSubscriptionInfo = true }) {
                        Label("View Subscription Details", systemImage: "info.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.ultraThinMaterial)
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                    
                    // Messages
                    if let errorMessage = errorMessage {
                        MessageView(message: errorMessage, type: .error)
                    }
                    
                    if let successMessage = successMessage {
                        MessageView(message: successMessage, type: .success)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .overlay {
                if isLoading {
                    LoadingOverlay()
                }
            }
            .sheet(isPresented: $showingSubscriptionInfo) {
                NavigationView {
                    SubscriptionInfoView()
                }
            }
            .onAppear {
                print("PremiumView: Appeared")
                Task {
                    print("PremiumView: Reloading products...")
                    await purchaseManager.retryLoadingProducts()
                }
            }
            
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: {
                            Task {
                                await purchaseManager.resetPremiumStatus()
                            }
                        }) {
                            Label("Reset Premium Status", systemImage: "arrow.counterclockwise")
                        }
                        
                        // Button(role: .destructive, action: clearDatabase) {
                        //     Label("Clear Database", systemImage: "trash.circle.fill")
                        // }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            #endif
        }
    }
    
    private func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await purchaseManager.purchase(product)
            successMessage = "Purchase successful! Thank you for upgrading to premium."
            clearMessageAfterDelay()
        } catch StoreError.userCancelled {
            // User cancelled, no need to show error
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func restorePurchases() {
        Task {
            isLoading = true
            errorMessage = nil
            successMessage = nil
            
            do {
                try await purchaseManager.restorePurchases()
                successMessage = "Purchases restored successfully!"
                clearMessageAfterDelay()
            } catch {
                errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            }
            
            isLoading = false
        }
    }
    
    private func clearMessageAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            successMessage = nil
        }
    }
    
    #if DEBUG
    private func clearDatabase() {
        do {
            try modelContext.delete(model: Workout.self)
            try modelContext.delete(model: WorkoutCategory.self)
            try modelContext.delete(model: WorkoutSubcategory.self)
            try modelContext.save()
        } catch {
            print("Failed to clear database: \(error)")
        }
    }
    #endif
}

// MARK: - Supporting Views

struct PremiumHeroSection: View {
    @StateObject private var purchaseManager = PurchaseManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .shadow(color: .blue.opacity(0.2), radius: 20, y: 10)
                
                Image(systemName: purchaseManager.hasActiveSubscription ? "crown.fill" : "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(purchaseManager.hasActiveSubscription ? .yellow : .blue)
            }
            
            VStack(spacing: 8) {
                Text(purchaseManager.hasActiveSubscription ? "You're Premium!" : "Upgrade to Premium")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                
                Text(purchaseManager.hasActiveSubscription ? "Enjoy all premium features" : "Take your training to the next level")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }
}

struct PremiumSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.bold))
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct ErrorView: View {
    let error: Error
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30))
                .foregroundColor(.orange)
            
            Text("Failed to load options")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: retryAction) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

struct MessageView: View {
    enum MessageType {
        case error
        case success
        
        var color: Color {
            switch self {
            case .error: return .red
            case .success: return .green
            }
        }
    }
    
    let message: String
    let type: MessageType
    
    var body: some View {
        Text(message)
            .foregroundColor(type.color)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(type.color.opacity(0.1))
            )
    }
}

struct LoadingOverlay: View {
    var body: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .overlay {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }
    }
}

// MARK: - Card Views

struct SubscriptionCard: View {
    let product: Product
    let isPurchased: Bool
    let action: () async -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.yellow)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                    Text(product.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Benefits
            VStack(alignment: .leading, spacing: 8) {
                BenefitRow(icon: "infinity", text: "Unlimited workouts")
                BenefitRow(icon: "folder.fill", text: "Unlimited categories")
                BenefitRow(icon: "chart.line.uptrend.xyaxis", text: "Advanced analytics")
                BenefitRow(icon: "icloud.fill", text: "Cloud sync")
            }
            
            // Purchase Button or Status
            if isPurchased {
                Label("Active Subscription", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            } else {
                Button(action: {
                    Task {
                        await action()
                    }
                }) {
                    Text("Subscribe for \(product.displayPrice)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .yellow.opacity(0.1), radius: 15, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
        )
    }
}

struct ProductCard: View {
    let product: Product
    let isPurchased: Bool
    let action: () async -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 16) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                    Text(product.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Benefits
            VStack(alignment: .leading, spacing: 8) {
                BenefitRow(icon: "infinity", text: "Unlimited workouts")
                BenefitRow(icon: "folder.fill", text: "Unlimited categories")
                BenefitRow(icon: "chart.line.uptrend.xyaxis", text: "Advanced analytics")
                BenefitRow(icon: "icloud.fill", text: "Cloud sync")
            }
            
            // Purchase Button or Status
            if isPurchased {
                Label("Purchased", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            } else {
                Button(action: {
                    Task {
                        await action()
                    }
                }) {
                    Text("Purchase for \(product.displayPrice)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .blue.opacity(0.1), radius: 15, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

struct StatusCard: View {
    let title: String
    let description: String
    let icon: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(isActive ? Color.green.opacity(0.1) : Color.secondary.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isActive ? .green : .secondary)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Status
            if isActive {
                Label("Active", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Text("Not Active")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
        }
    }
} 
