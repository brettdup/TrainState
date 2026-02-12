import RevenueCat
import SwiftUI
import SwiftData

@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    @Published private(set) var offerings: Offerings?
    @Published private(set) var availablePackages: [Package] = []
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var purchasedProductIDs = Set<String>()
    #if DEBUG
    @Published private(set) var debugPremiumOverride = false
    #endif
    @Published private(set) var isProcessingPurchase = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var productLoadError: Error?
    @Published private(set) var debugLog: String = ""
    /// True once the initial customer info fetch has completed. Use to avoid flashing "not premium" before status is known.
    @Published private(set) var hasCompletedInitialPremiumCheck = false
    
    var hasActiveSubscription: Bool {
        #if DEBUG
        if debugPremiumOverride { return true }
        #endif
        return customerInfo?.entitlements["Premium"]?.isActive == true
    }
    
    // Premium access checks
    var hasUnlockedPremiumCategories: Bool {
        hasActiveSubscription
    }
    
    var hasUnlockedUnlimited: Bool {
        hasActiveSubscription
    }
    
    // Keep a context reference only if needed later; avoid separate containers.
    private let modelContext: ModelContext?
    #if DEBUG
    private let debugPremiumOverrideDefaultsKey = "TrainState.debugPremiumOverrideEnabled"
    #endif
    private init() {
        // Avoid creating a separate container; purchases don't require a local store.
        self.modelContext = nil
        
        print("PurchaseManager: Initializing...")
        debugLog += "PurchaseManager: Initializing...\n"
        
        print("PurchaseManager: ModelContext initialized")
        debugLog += "PurchaseManager: ModelContext initialized\n"

        #if DEBUG
        // Restore the developer premium override from UserDefaults so it
        // persists across simulator runs and new debug builds.
        debugPremiumOverride = UserDefaults.standard.bool(forKey: debugPremiumOverrideDefaultsKey)
        #endif
        
        Task { [weak self] in
            guard let self else { return }
            print("PurchaseManager: Loading products...")
            await self.loadProducts()
            print("PurchaseManager: Updating purchased products...")
            await self.updatePurchasedProducts()
            self.hasCompletedInitialPremiumCheck = true
        }
    }
    
    func loadProducts() async {
        print("PurchaseManager: Starting product load...")
        isLoadingProducts = true
        productLoadError = nil
        debugLog += "Starting to load products...\n"
        
        await withCheckedContinuation { continuation in
            Purchases.shared.getOfferings { [weak self] offerings, error in
                guard let self else {
                    continuation.resume()
                    return
                }
                if let error {
                    print("PurchaseManager: Failed to load offerings: \(error.localizedDescription)")
                    self.productLoadError = error
                    self.debugLog += "Failed to load offerings: \(error.localizedDescription)\n"
                    self.availablePackages = []
                } else {
                    self.offerings = offerings
                    let packages = offerings?.current?.availablePackages ?? []
                    self.availablePackages = packages
                    print("PurchaseManager: Loaded \(packages.count) packages")
                    self.debugLog += "Loaded \(packages.count) packages\n"
                    self.logLoadedPackageDetails(packages)
                }
                self.isLoadingProducts = false
                continuation.resume()
            }
        }
    }
    
    func retryLoadingProducts() async {
        print("PurchaseManager: Retrying product load...")
        await loadProducts()
    }
    
    func purchase(_ package: Package) async throws {
        print("PurchaseManager: Starting purchase for package: \(package.identifier)")
        guard !isProcessingPurchase else {
            print("PurchaseManager: Purchase already in progress")
            throw StoreError.purchaseInProgress
        }
        
        isProcessingPurchase = true
        defer { isProcessingPurchase = false }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Purchases.shared.purchase(package: package) { [weak self] _, customerInfo, error, userCancelled in
                guard let self else {
                    continuation.resume(throwing: StoreError.unknown)
                    return
                }
                if let error {
                    print("PurchaseManager: Purchase failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                if userCancelled {
                    print("PurchaseManager: Purchase cancelled by user")
                    continuation.resume(throwing: StoreError.userCancelled)
                    return
                }
                if let customerInfo {
                    self.applyCustomerInfo(customerInfo)
                }
                continuation.resume()
            }
        }
    }
    
    func updatePurchasedProducts() async {
        print("PurchaseManager: Updating purchased products...")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Purchases.shared.getCustomerInfo { [weak self] info, error in
                guard let self else {
                    continuation.resume()
                    return
                }
                if let error {
                    print("PurchaseManager: Failed to update purchases: \(error.localizedDescription)")
                    self.debugLog += "Failed to update purchases: \(error.localizedDescription)\n"
                } else if let info {
                    self.applyCustomerInfo(info)
                }
                continuation.resume()
            }
        }
    }
    
    func restorePurchases() async throws {
        print("PurchaseManager: Starting purchase restoration...")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Purchases.shared.restorePurchases { [weak self] info, error in
                guard let self else {
                    continuation.resume(throwing: StoreError.unknown)
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let info {
                    self.applyCustomerInfo(info)
                }
                continuation.resume()
            }
        }
    }
    
    #if DEBUG
    func resetPremiumStatus() async {
        print("PurchaseManager: Resetting premium status...")
        purchasedProductIDs.removeAll()
        try? modelContext?.save()
    }
    #endif
    
    private func applyCustomerInfo(_ info: CustomerInfo) {
        customerInfo = info
        purchasedProductIDs = info.activeSubscriptions
        debugLog += "Active subscriptions: \(info.activeSubscriptions)\n"
        debugLog += "Active entitlements: \(info.entitlements.active.keys)\n"
    }

    private func logLoadedPackageDetails(_ packages: [Package]) {
        let expectedProductIDs = ["Premium1Month", "premium1year", "premiumlifetime"]
        let loadedProductIDs = Set(packages.map { $0.storeProduct.productIdentifier })
        let missing = expectedProductIDs.filter { !loadedProductIDs.contains($0) }

        for package in packages {
            let detail = "Package \(package.identifier) -> \(package.storeProduct.productIdentifier)"
            print("PurchaseManager: \(detail)")
            debugLog += "\(detail)\n"
        }

        if missing.isEmpty {
            debugLog += "All expected product IDs are present.\n"
        } else {
            let message = "Missing expected product IDs: \(missing.joined(separator: ", "))"
            print("PurchaseManager: \(message)")
            debugLog += "\(message)\n"
        }
    }
}

#if DEBUG
extension PurchaseManager {
    var isDebugPremiumOverrideEnabled: Bool {
        debugPremiumOverride
    }
    
    func forcePremiumForPreview() {
        debugPremiumOverride = true
        UserDefaults.standard.set(true, forKey: debugPremiumOverrideDefaultsKey)
    }
    
    func togglePremiumOverride() {
        debugPremiumOverride.toggle()
        UserDefaults.standard.set(debugPremiumOverride, forKey: debugPremiumOverrideDefaultsKey)
    }
    
    func setPremiumOverride(_ enabled: Bool) {
        debugPremiumOverride = enabled
        UserDefaults.standard.set(enabled, forKey: debugPremiumOverrideDefaultsKey)
    }
}
#endif

enum StoreError: LocalizedError {
    case userCancelled
    case unknown
    case purchaseInProgress
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase was cancelled"
        case .unknown:
            return "An unknown error occurred"
        case .purchaseInProgress:
            return "A purchase is already in progress"
        }
    }
} 
