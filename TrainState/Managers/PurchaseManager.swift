import StoreKit
import SwiftUI
import SwiftData

@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    @Published private(set) var isProcessingPurchase = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var productLoadError: Error?
    @Published private(set) var debugLog: String = ""
    
    // StoreKit configuration
    private var productIdentifiers: [String] = []
    
    var subscriptionProducts: [Product] {
        products.filter { $0.type == .autoRenewable }
    }
    
    var oneTimeProducts: [Product] {
        products.filter { $0.type == .nonConsumable }
    }
    
    var hasActiveSubscription: Bool {
        !subscriptionProducts.filter { purchasedProductIDs.contains($0.id) }.isEmpty
    }
    
    // Premium access checks
    var hasUnlockedPremiumCategories: Bool {
        hasActiveSubscription
    }
    
    var hasUnlockedUnlimited: Bool {
        hasActiveSubscription
    }
    
    private let modelContext: ModelContext
    private var updateListenerTask: Task<Void, Error>?
    
    private init() {
        // Initialize modelContext first
        let container = try! ModelContainer(for: Workout.self)
        self.modelContext = container.mainContext
        
        print("PurchaseManager: Initializing...")
        debugLog += "PurchaseManager: Initializing...\n"
        
        print("PurchaseManager: ModelContext initialized")
        debugLog += "PurchaseManager: ModelContext initialized\n"
        
        // Load product identifiers from StoreKit configuration
        loadProductIdentifiers()
        
        // Then start the transaction listener
        print("PurchaseManager: Starting transaction listener...")
        debugLog += "PurchaseManager: Starting transaction listener...\n"
        updateListenerTask = listenForTransactions()
        
        // Finally, load products
        print("PurchaseManager: Starting initial product load...")
        debugLog += "PurchaseManager: Starting initial product load...\n"
        
        Task { [weak self] in
            guard let self = self else { return }
            print("PurchaseManager: Loading products...")
            await self.loadProducts()
            print("PurchaseManager: Updating purchased products...")
            await self.updatePurchasedProducts()
        }
    }
    
    deinit {
        print("PurchaseManager: Deinitializing...")
        updateListenerTask?.cancel()
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        print("PurchaseManager: Setting up transaction listener...")
        return Task.detached { [weak self] in
            guard let self = self else { return }
            print("PurchaseManager: Transaction listener started")
            for await result in StoreKit.Transaction.updates {
                await self.handleTransactionResult(result)
            }
        }
    }
    
    private func handleTransactionResult(_ result: VerificationResult<StoreKit.Transaction>) {
        Task {
            switch result {
            case .verified(let transaction):
                print("PurchaseManager: Verified transaction for product: \(transaction.productID)")
                // Update the purchased products set
                purchasedProductIDs.insert(transaction.productID)
                
                // Finish the transaction
                await transaction.finish()
                
                // Double-check the purchase status
                await updatePurchasedProducts()
                
            case .unverified:
                print("PurchaseManager: Unverified transaction detected")
                // Handle unverified transaction
                debugLog += "Unverified transaction detected\n"
            }
        }
    }
    
    func loadProducts() async {
        print("PurchaseManager: Starting product load...")
        isLoadingProducts = true
        productLoadError = nil
        debugLog += "Starting to load products...\n"
        
        do {
            print("PurchaseManager: Attempting to load products with identifiers: \(productIdentifiers)")
            debugLog += "Attempting to load products with identifiers: \(productIdentifiers)\n"
            
            // Load the StoreKit configuration
            if let storeKitConfigURL = Bundle.main.url(forResource: "TrainState", withExtension: "storekit") {
                print("PurchaseManager: Found StoreKit configuration at: \(storeKitConfigURL)")
                debugLog += "Found StoreKit configuration at: \(storeKitConfigURL)\n"
            } else {
                print("PurchaseManager: Warning - StoreKit configuration not found")
                debugLog += "Warning - StoreKit configuration not found\n"
            }
            
            // Try to load products from StoreKit
            let storeProducts = try await Product.products(for: productIdentifiers)
            
            if storeProducts.isEmpty {
                print("PurchaseManager: No products found in StoreKit configuration")
                debugLog += "No products found in StoreKit configuration\n"
                
                // Try to load subscription products specifically
                let subscriptionProducts = try await Product.products(for: productIdentifiers)
                    .filter { $0.type == .autoRenewable }
                if !subscriptionProducts.isEmpty {
                    print("PurchaseManager: Found \(subscriptionProducts.count) subscription products")
                    debugLog += "Found \(subscriptionProducts.count) subscription products\n"
                    for product in subscriptionProducts {
                        print("PurchaseManager: Found subscription: \(product.id) - \(product.displayName) - \(product.displayPrice)")
                        debugLog += "Found subscription: \(product.id) - \(product.displayName) - \(product.displayPrice)\n"
                        debugLog += "Subscription type: \(product.type)\n"
                        debugLog += "Subscription description: \(product.description)\n"
                    }
                    products = subscriptionProducts
                }
            } else {
                print("PurchaseManager: Successfully loaded \(storeProducts.count) products")
                debugLog += "Successfully loaded \(storeProducts.count) products\n"
                for product in storeProducts {
                    print("PurchaseManager: Found product: \(product.id) - \(product.displayName) - \(product.displayPrice)")
                    debugLog += "Found product: \(product.id) - \(product.displayName) - \(product.displayPrice)\n"
                    debugLog += "Product type: \(product.type)\n"
                    debugLog += "Product description: \(product.description)\n"
                }
                products = storeProducts
            }
            
            isLoadingProducts = false
        } catch {
            print("PurchaseManager: Failed to load products: \(error.localizedDescription)")
            productLoadError = error
            isLoadingProducts = false
            debugLog += "Failed to load products: \(error.localizedDescription)\n"
            
            // Log specific error details
            if let storeError = error as? StoreKitError {
                print("PurchaseManager: StoreKit error: \(storeError.localizedDescription)")
                debugLog += "StoreKit error: \(storeError.localizedDescription)\n"
            } else {
                print("PurchaseManager: Unknown error type: \(type(of: error))")
                debugLog += "Unknown error type: \(type(of: error))\n"
            }
        }
    }
    
    func retryLoadingProducts() async {
        print("PurchaseManager: Retrying product load...")
        await loadProducts()
    }
    
    func purchase(_ product: Product) async throws {
        print("PurchaseManager: Starting purchase for product: \(product.id)")
        guard !isProcessingPurchase else {
            print("PurchaseManager: Purchase already in progress")
            throw StoreError.purchaseInProgress
        }
        
        isProcessingPurchase = true
        defer { isProcessingPurchase = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    print("PurchaseManager: Purchase verified for product: \(transaction.productID)")
                    
                    // Validate the transaction
                    let isValid = try await ReceiptValidationService.shared.validateTransaction(transaction)
                    
                    if isValid {
                        print("PurchaseManager: Transaction validated successfully")
                        debugLog += "Transaction validated successfully\n"
                        
                        // Update the UI state
                        purchasedProductIDs.insert(transaction.productID)
                        
                        // Finish the transaction
                        await transaction.finish()
                        
                        // Double-check the purchase status
                        await updatePurchasedProducts()
                    } else {
                        print("PurchaseManager: Transaction validation failed")
                        debugLog += "Transaction validation failed\n"
                        throw StoreError.receiptValidationFailed
                    }
                    
                case .unverified:
                    print("PurchaseManager: Purchase verification failed")
                    throw StoreError.failedVerification
                }
            case .userCancelled:
                print("PurchaseManager: Purchase cancelled by user")
                throw StoreError.userCancelled
            case .pending:
                print("PurchaseManager: Purchase pending")
                throw StoreError.pending
            @unknown default:
                print("PurchaseManager: Unknown purchase result")
                throw StoreError.unknown
            }
        } catch {
            print("PurchaseManager: Purchase failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func updatePurchasedProducts() async {
        print("PurchaseManager: Updating purchased products...")
        do {
            for await result in StoreKit.Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    print("PurchaseManager: Found purchased product: \(transaction.productID)")
                    purchasedProductIDs.insert(transaction.productID)
                    debugLog += "Found purchased product: \(transaction.productID)\n"
                case .unverified:
                    print("PurchaseManager: Found unverified transaction")
                    debugLog += "Found unverified transaction\n"
                }
            }
        } catch {
            print("PurchaseManager: Failed to update purchased products: \(error.localizedDescription)")
            debugLog += "Failed to update purchased products: \(error.localizedDescription)\n"
        }
    }
    
    func restorePurchases() async throws {
        print("PurchaseManager: Starting purchase restoration...")
        // Clear existing purchases
        purchasedProductIDs.removeAll()
        
        // Update with current entitlements
        await updatePurchasedProducts()
    }
    
    #if DEBUG
    func resetPremiumStatus() async {
        print("PurchaseManager: Resetting premium status...")
        purchasedProductIDs.removeAll()
        try? modelContext.save()
    }
    #endif
    
    private func loadProductIdentifiers() {
        guard let storeKitConfigURL = Bundle.main.url(forResource: "TrainState", withExtension: "storekit") else {
            print("PurchaseManager: StoreKit configuration not found")
            debugLog += "StoreKit configuration not found\n"
            return
        }
        
        do {
            let data = try Data(contentsOf: storeKitConfigURL)
            let decoder = JSONDecoder()
            let config = try decoder.decode(StoreKitConfig.self, from: data)
            
            // Extract product IDs from subscription groups
            productIdentifiers = config.subscriptionGroups.flatMap { group in
                group.subscriptions.map { $0.productID }
            }
            
            print("PurchaseManager: Loaded \(productIdentifiers.count) product identifiers")
            debugLog += "Loaded \(productIdentifiers.count) product identifiers\n"
        } catch {
            print("PurchaseManager: Failed to load StoreKit configuration: \(error.localizedDescription)")
            debugLog += "Failed to load StoreKit configuration: \(error.localizedDescription)\n"
        }
    }
    
    // MARK: - StoreKit Configuration Models
    
    private struct StoreKitConfig: Codable {
        let subscriptionGroups: [SubscriptionGroup]
    }
    
    private struct SubscriptionGroup: Codable {
        let subscriptions: [Subscription]
    }
    
    private struct Subscription: Codable {
        let productID: String
        
        enum CodingKeys: String, CodingKey {
            case productID = "productID"
        }
    }
}

#if DEBUG
extension PurchaseManager {
    func forcePremiumForPreview() {
        purchasedProductIDs = ["Premium1Month"]
    }
}
#endif

enum StoreError: LocalizedError {
    case failedVerification
    case userCancelled
    case pending
    case unknown
    case purchaseInProgress
    case receiptValidationFailed
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .userCancelled:
            return "Purchase was cancelled"
        case .pending:
            return "Purchase is pending"
        case .unknown:
            return "An unknown error occurred"
        case .purchaseInProgress:
            return "A purchase is already in progress"
        case .receiptValidationFailed:
            return "Failed to validate the purchase receipt"
        }
    }
} 