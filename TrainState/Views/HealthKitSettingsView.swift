import SwiftUI
import SwiftData

struct HealthKitSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("healthKitActuallyAuthorized") private var isAuthorized = false
    @State private var isImporting = false
    @State private var importResult: String?
    @State private var showingImportError = false
    @State private var importError: HealthKitError?
    @State private var lastImportDate: Date?
    
    // Network monitoring
    @StateObject private var networkManager = NetworkManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemGray6).opacity(0.3)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Header Section
                        headerSection
                        
                        // Authorization Section
                        authorizationSection
                        
                        // Import Section
                        if isAuthorized {
                            importSection
                        }
                        
                        // Network Status Section
                        networkStatusSection
                        
                        // Instructions Section (if not authorized)
                        if !isAuthorized {
                            instructionsSection
                        }
                        
                        // Information Section
                        informationSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("HealthKit Import")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Always test actual data access on appear to handle iOS cache issues
                Task {
                    await testAndUpdateAuthorizationStatus()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Check status when returning from Settings
                print("[HealthKitSettings] App returned to foreground, checking authorization...")
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    await testAndUpdateAuthorizationStatus()
                }
            }
            .alert("Import Error", isPresented: $showingImportError) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError?.errorDescription ?? "Unknown error occurred")
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        ModernSettingsCard {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.red, .pink]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "heart.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HealthKit Integration")
                            .font(.title3.weight(.semibold))
                        Text("Import workouts from Apple Health")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Status indicator
                HStack {
                    Image(systemName: isAuthorized ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(isAuthorized ? .green : .orange)
                    Text(isAuthorized ? "Connected to Apple Health" : "Not Connected")
                        .font(.subheadline)
                        .foregroundColor(isAuthorized ? .green : .orange)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Authorization Section
    
    private var authorizationSection: some View {
        VStack(spacing: 12) {
            SectionHeaderView(title: "Authorization", systemImage: "key.fill")
            
            ModernSettingsCard {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Health Data Access")
                                .font(.body.weight(.medium))
                            Text("Required to import workout data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        if isAuthorized {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    if !isAuthorized {
                        VStack(spacing: 16) {
                            // Permission denied info
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Permission Required")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.orange)
                                }
                                
                                Text("HealthKit access was previously denied. Please enable it manually in Settings.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            VStack(spacing: 12) {
                                Button(action: openHealthSettings) {
                                    HStack {
                                        Image(systemName: "gear")
                                        Text("Open Health Settings")
                                            .font(.body.weight(.medium))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .cyan]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                }
                                
                                Button(action: forceRefreshAuthorization) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Check Permission Again")
                                            .font(.caption.weight(.medium))
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Import Section
    
    private var importSection: some View {
        VStack(spacing: 12) {
            SectionHeaderView(title: "Import Workouts", systemImage: "arrow.down.circle.fill")
            
            ModernSettingsCard {
                VStack(spacing: 16) {
                    // Import Button
                    Button(action: importWorkouts) {
                        ModernSettingsRow(
                            title: "Import from HealthKit",
                            subtitle: "Import workouts from the last 2 years",
                            systemImage: isImporting ? "arrow.clockwise" : "square.and.arrow.down.fill",
                            accentColor: .green,
                            isLoading: isImporting
                        )
                    }
                    .disabled(isImporting)
                    
                    Divider()
                    
                    // Import all history button
                    Button(action: importAllWorkouts) {
                        ModernSettingsRow(
                            title: "Import Complete History",
                            subtitle: "Import ALL workouts (may take longer)",
                            systemImage: isImporting ? "arrow.clockwise" : "clock.arrow.circlepath",
                            accentColor: .orange,
                            isLoading: isImporting
                        )
                    }
                    .disabled(isImporting)
                    
                    // Last import info
                    if let lastImport = lastImportDate {
                        Divider()
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text("Last import: \(lastImport, style: .relative)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    // Import result
                    if let result = importResult {
                        Divider()
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(result)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Instructions Section
    
    private var instructionsSection: some View {
        VStack(spacing: 12) {
            SectionHeaderView(title: "Setup Instructions", systemImage: "list.number")
            
            ModernSettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    instructionStep(
                        number: "1",
                        title: "Open Health Settings",
                        description: "Tap the 'Open Health Settings' button above",
                        color: .blue
                    )
                    
                    Divider()
                    
                    instructionStep(
                        number: "2",
                        title: "Navigate to Data Sources",
                        description: "Tap 'Data Sources & Access' in the Health app",
                        color: .green
                    )
                    
                    Divider()
                    
                    instructionStep(
                        number: "3",
                        title: "Find TrainState",
                        description: "Look for 'TrainState' in the apps list",
                        color: .orange
                    )
                    
                    Divider()
                    
                    instructionStep(
                        number: "4",
                        title: "Enable Workouts",
                        description: "Turn ON the toggle for 'Workouts' data",
                        color: .purple
                    )
                    
                    Divider()
                    
                    instructionStep(
                        number: "5",
                        title: "Return to App",
                        description: "Come back and tap 'Check Permission Again'",
                        color: .red
                    )
                }
            }
        }
    }
    
    private func instructionStep(number: String, title: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    Text(number)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Network Status Section
    
    private var networkStatusSection: some View {
        VStack(spacing: 12) {
            SectionHeaderView(title: "Network Protection", systemImage: "shield.fill")
            
            ModernSettingsCard {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: networkManager.isSafeToUseData ? "wifi" : "cellularbars")
                            .foregroundColor(networkManager.isSafeToUseData ? .green : .orange)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Connection")
                                .font(.body.weight(.medium))
                            Text(networkManager.statusDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(networkManager.isSafeToUseData ? "Protected" : "Cellular")
                                .font(.caption.weight(.medium))
                                .foregroundColor(networkManager.isSafeToUseData ? .green : .orange)
                            if networkManager.isOnCellular {
                                Text("Data blocked")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("HealthKit import is always local-only and never uses mobile data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - Information Section
    
    private var informationSection: some View {
        VStack(spacing: 12) {
            SectionHeaderView(title: "Information", systemImage: "info.circle")
            
            ModernSettingsCard {
                VStack(spacing: 16) {
                    HealthKitInfoRow(
                        icon: "shield.fill",
                        title: "Privacy First",
                        description: "All imported data stays on your device. No cloud syncing during import.",
                        color: .blue
                    )
                    
                    Divider()
                    
                    HealthKitInfoRow(
                        icon: "arrow.2.circlepath",
                        title: "Smart Duplicate Detection",
                        description: "Advanced algorithms prevent duplicate workouts from being imported.",
                        color: .green
                    )
                    
                    Divider()
                    
                    HealthKitInfoRow(
                        icon: "clock.fill",
                        title: "Rate Limited",
                        description: "Import is limited to once every 2 minutes to prevent device overheating.",
                        color: .orange
                    )
                    
                    Divider()
                    
                    HealthKitInfoRow(
                        icon: "wifi.slash",
                        title: "No Data Usage",
                        description: "HealthKit import works entirely offline and uses no mobile data.",
                        color: .purple
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkAuthorizationStatus() {
        print("[HealthKitSettings] Checking authorization status...")
        let newStatus = HealthKitManager.shared.isAuthorized()
        print("[HealthKitSettings] Authorization status result: \(newStatus)")
        isAuthorized = newStatus
    }
    
    private func requestAuthorization() {
        print("[HealthKitSettings] User tapped authorization button")
        
        // Check if HealthKit is available first
        guard HealthKitManager.shared.isHealthKitAvailable() else {
            importError = HealthKitError.notAuthorized
            showingImportError = true
            return
        }
        
        Task {
            do {
                print("[HealthKitSettings] Requesting authorization...")
                try await HealthKitManager.shared.requestAuthorization()
                await MainActor.run {
                    print("[HealthKitSettings] Authorization request completed, checking status...")
                    checkAuthorizationStatus()
                }
            } catch {
                print("[HealthKitSettings] Authorization failed: \(error)")
                await MainActor.run {
                    importError = error as? HealthKitError ?? HealthKitError.notAuthorized
                    showingImportError = true
                }
            }
        }
    }
    
    private func openHealthSettings() {
        print("[HealthKitSettings] Opening Health settings")
        if let settingsUrl = URL(string: "x-apple-health://") {
            UIApplication.shared.open(settingsUrl)
        } else if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func testAndUpdateAuthorizationStatus() async {
        print("[HealthKitSettings] Testing and updating authorization status...")
        
        // Test actual data access instead of just checking status
        let hasDataAccess = await HealthKitManager.shared.testDataAccess()
        
        await MainActor.run {
            let statusCheck = HealthKitManager.shared.isAuthorized()
            
            if hasDataAccess {
                print("[HealthKitSettings] Data access successful - setting authorized to true")
                isAuthorized = true
            } else if statusCheck {
                print("[HealthKitSettings] Status check successful - setting authorized to true")
                isAuthorized = true
            } else {
                print("[HealthKitSettings] Both data access and status check failed - setting authorized to false")
                isAuthorized = false
            }
            
            print("[HealthKitSettings] Final authorization state: \(isAuthorized)")
        }
    }
    
    private func forceRefreshAuthorization() {
        print("[HealthKitSettings] Force refreshing authorization status...")
        Task {
            await testAndUpdateAuthorizationStatus()
        }
    }
    
    private func importWorkouts() {
        Task {
            await MainActor.run {
                isImporting = true
                importResult = nil
            }
            
            do {
                let result = try await HealthKitManager.shared.importWorkouts(to: modelContext)
                await MainActor.run {
                    isImporting = false
                    lastImportDate = Date()
                    importResult = "Imported \(result.added) workouts, skipped \(result.skipped) duplicates"
                }
            } catch let error as HealthKitError {
                await MainActor.run {
                    isImporting = false
                    importError = error
                    showingImportError = true
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    importError = HealthKitError.notAuthorized // Generic fallback
                    showingImportError = true
                }
            }
        }
    }
    
    private func importAllWorkouts() {
        Task {
            await MainActor.run {
                isImporting = true
                importResult = nil
            }
            
            do {
                let result = try await HealthKitManager.shared.importAllWorkouts(to: modelContext)
                await MainActor.run {
                    isImporting = false
                    lastImportDate = Date()
                    importResult = "Complete import: \(result.added) workouts added, \(result.skipped) duplicates skipped"
                }
            } catch let error as HealthKitError {
                await MainActor.run {
                    isImporting = false
                    importError = error
                    showingImportError = true
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    importError = HealthKitError.notAuthorized // Generic fallback
                    showingImportError = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct HealthKitInfoRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
                .font(.system(size: 16, weight: .medium))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Workout.self, configurations: config)
        
        return HealthKitSettingsView()
            .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}