import Foundation
import Network
import SystemConfiguration

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    @Published var isConnectedToWiFi = false
    @Published var networkStatus: NetworkStatus = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    enum NetworkStatus {
        case unknown
        case disconnected
        case cellular
        case wifi
        case ethernet
    }
    
    private init() {
        startMonitoring()
        checkInitialNetworkStatus()
    }
    
    deinit {
        monitor.cancel()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateNetworkStatus(path: path)
            }
        }
        monitor.start(queue: queue)
    }

    @MainActor
    private func updateNetworkStatus(path: NWPath) {
        let newStatus: NetworkStatus
        let newIsWiFi: Bool

        if path.status == .satisfied {
            if path.usesInterfaceType(.wifi) {
                newStatus = .wifi
                newIsWiFi = true
            } else if path.usesInterfaceType(.cellular) {
                newStatus = .cellular
                newIsWiFi = false
                print("[Network] Connected to Cellular (DATA OPERATIONS BLOCKED)")
            } else if path.usesInterfaceType(.wiredEthernet) {
                newStatus = .ethernet
                newIsWiFi = true
                print("[Network] Connected to Ethernet")
            } else if path.isExpensive || path.isConstrained {
                newStatus = .cellular
                newIsWiFi = false
                print("[Network] Connection marked expensive/constrained - treating as cellular (DATA OPERATIONS BLOCKED)")
            } else {
                newStatus = .unknown
                newIsWiFi = false
                print("[Network] Connected to unknown network type")
            }
        } else {
            newStatus = .disconnected
            newIsWiFi = false
            print("[Network] Disconnected")
        }
        
        networkStatus = newStatus
        isConnectedToWiFi = newIsWiFi
    }
    
    private func checkInitialNetworkStatus() {
        // Fallback check using SystemConfiguration for immediate status
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        let isConnected = isReachable && !needsConnection
        
        if isConnected {
            // We have a connection, but we don't know if it's WiFi yet
            // The NWPathMonitor will provide the accurate status shortly
            print("[Network] Initial check: Connected (type pending)")
        } else {
            networkStatus = .disconnected
            isConnectedToWiFi = false
            print("[Network] Initial check: Disconnected")
        }
    }
    
    // MARK: - Public Methods
    
    /// Returns true if it's safe to use data (WiFi or Ethernet only).
    var isSafeToUseData: Bool {
        return networkStatus == .wifi || networkStatus == .ethernet
    }
    
    /// Returns true if we're on cellular (should block data operations)
    var isOnCellular: Bool {
        return networkStatus == .cellular
    }
    
    /// Get a user-friendly description of the current network status
    var statusDescription: String {
        switch networkStatus {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "Cellular"
        case .ethernet:
            return "Ethernet"
        case .disconnected:
            return "Disconnected"
        case .unknown:
            return "Unknown"
        }
    }
    
    /// Force a network status check (useful for debugging)
    func refreshNetworkStatus() async {
        // The monitor will automatically update, but we can force a check
        print("[Network] Forcing network status refresh...")
        let currentPath = monitor.currentPath
        await MainActor.run {
            self.updateNetworkStatus(path: currentPath)
        }
    }
}

// MARK: - Network Protection Error

enum NetworkProtectionError: LocalizedError {
    case cellularDataBlocked
    case noConnection
    
    var errorDescription: String? {
        switch self {
        case .cellularDataBlocked:
            return "Data operations are blocked on cellular networks. Please connect to WiFi to continue."
        case .noConnection:
            return "No network connection available. Please check your internet connection."
        }
    }
}
