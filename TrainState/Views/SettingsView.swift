import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userSettings: [UserSettings]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var isNotificationAuthorized = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedAppIcon: String?
    @State private var showingResetConfirmation = false
    @State private var showingOnboardingResetConfirmation = false
    @State private var showingPremiumPaywall = false
    
    // Backup & Restore States
    @State private var isBackingUp = false
    @State private var isRestoring = false
    @State private var showingBackupSuccess = false
    @State private var showingBackupError = false
    @State private var showingRestoreSuccess = false
    @State private var showingRestoreError = false
    @State private var backupErrorMessage = ""
    @State private var restoreErrorMessage = ""
    @State private var lastBackupDate: Date?
    @State private var availableBackups: [BackupInfo] = []
    @State private var selectedBackup: BackupInfo?
    @State private var showingBackupSelection = false
    @State private var isLoadingBackups = false
    @State private var debugInfo = "Initializing CloudKit debug..."
    @State private var showingDataUsageWarning = false
    
    // Network monitoring
    @StateObject private var networkManager = NetworkManager.shared
    
    // Add new state for manage backups sheet
    @State private var showingManageBackups = false
    
    // Add deletion state for better UX
    @State private var isDeletingBackups = false
    @State private var deletionProgress: Float = 0.0
    
    @Query private var categories: [WorkoutCategory]
    @Query private var subcategories: [WorkoutSubcategory]
    @Query private var workouts: [Workout]
    
    private var defaultUserSettings: UserSettings {
        UserSettings()
    }
    
    var body: some View {
        NavigationStack {
            let settings = userSettings.first ?? defaultUserSettings

            List {
                Section {
                    profileSection
                }

                Section {
                    preferencesSection(settings: settings)
                }

                Section {
                    workoutManagementSection
                }

                Section {
                    dataSyncSection
                }

                Section {
                    supportSection
                }

                #if DEBUG
                Section {
                    developerSection
                }
                #endif
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Ensure UserSettings exists - do this asynchronously to avoid blocking
                Task {
                    if userSettings.isEmpty {
                        let newSettings = UserSettings()
                        modelContext.insert(newSettings)
                        try? modelContext.save()
                    }
                }
                
                // Do notification check asynchronously
                Task {
                    NotificationManager.shared.checkNotificationStatus { authorized in
                        Task { @MainActor in
                            isNotificationAuthorized = authorized
                        }
                    }
                }
                
                // Set initial debug info
                let environment = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "TestFlight/Sandbox" : "App Store/Production"
                debugInfo = "Environment: \(environment)\nStatus: Settings loaded\nContainer: iCloud.brettduplessis.TrainState\nTime: \(Date().formatted())"
                
                // Set up debug callback for CloudKit
                CloudKitManager.shared.debugCallback = { message in
                    Task { @MainActor in
                        self.debugInfo = message
                    }
                }
            }
        }
        .alert("WiFi Backup Confirmation", isPresented: $showingDataUsageWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                performBackup()
            }
        } message: {
            Text("You're connected to WiFi. Backup will proceed safely without using mobile data. Continue?")
        }
    }
    
    // MARK: - New Section Views
    
    private var profileSection: some View {
        ModernSettingsCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TrainState User")
                            .font(.title3.weight(.semibold))
                        Text("Fitness Journey")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Quick stats
                HStack(spacing: 24) {
                    ProfileStatView(value: "\(workouts.count)", label: "Workouts", color: .blue)
                    ProfileStatView(value: "\(categories.count)", label: "Categories", color: .green)
                    ProfileStatView(value: "\(subcategories.count)", label: "Subcategories", color: .purple)
                }
            }
        }
    }
    
    private func preferencesSection(settings: UserSettings) -> some View {
        VStack(spacing: 12) {
            SectionHeaderView(title: "Preferences", systemImage: "gear")
            
            ModernSettingsCard {
                VStack(spacing: 16) {
                    // Dark Mode Toggle
                    ModernToggleRow(
                        title: "Dark Mode",
                        subtitle: "Appearance setting",
                        systemImage: "moon.fill",
                        isOn: Binding(
                            get: { settings.darkModeEnabled },
                            set: { settings.darkModeEnabled = $0 }
                        ),
                        accentColor: .indigo
                    )
                    
                    Divider()
                    
                    // Measurement System
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "ruler.fill")
                                .foregroundColor(.orange)
                                .frame(width: 20)
                            Text("Measurement System")
                                .font(.body.weight(.medium))
                            Spacer()
                        }
                        
                        Picker("Measurement System", selection: Binding(
                            get: { settings.measurementSystem },
                            set: { settings.measurementSystem = $0 }
                        )) {
                            Text("Metric").tag(MeasurementSystem.metric)
                            Text("Imperial").tag(MeasurementSystem.imperial)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Divider()
                    
                    // App Icon
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "app.fill")
                                .foregroundColor(.pink)
                                .frame(width: 20)
                            Text("App Icon")
                                .font(.body.weight(.medium))
                            Spacer()
                        }
                        
                        Menu {
                            Button(action: {
                                selectedAppIcon = nil
                                AppIconManager.shared.resetToDefaultIcon()
                            }) {
                                Label("Default", systemImage: "app")
                            }
                            
                            Button(action: {
                                selectedAppIcon = "TrainState-iOS-Dark"
                                AppIconManager.shared.setAppIcon(for: "TrainState-iOS-Dark")
                            }) {
                                Label("Dark", systemImage: "moon.fill")
                            }
                            
                            Button(action: {
                                selectedAppIcon = "TrainState-iOS-TintedDark"
                                AppIconManager.shared.setAppIcon(for: "TrainState-iOS-TintedDark")
                            }) {
                                Label("Tinted Dark", systemImage: "moon.stars.fill")
                            }
                        } label: {
                            HStack {
                                Text(selectedAppIcon == nil ? "Default" : selectedAppIcon ?? "Default")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    Divider()
                    
                    // Notifications
                    ModernToggleRow(
                        title: "Notifications",
                        subtitle: "Workout reminders",
                        systemImage: "bell.fill",
                        isOn: Binding(
                            get: { settings.notificationEnabled },
                            set: { newValue in
                                settings.notificationEnabled = newValue
                                if newValue {
                                    NotificationManager.shared.requestAuthorization()
                                } else {
                                    NotificationManager.shared.cancelWorkoutReminder()
                                }
                            }
                        ),
                        accentColor: .orange
                    )
                    
                    if settings.notificationEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.orange)
                                    .frame(width: 20)
                                Text("Reminder Time")
                                    .font(.body.weight(.medium))
                                Spacer()
                            }
                            
                            DatePicker(
                                "Reminder Time",
                                selection: Binding(
                                    get: { settings.notificationTime ?? Date() },
                                    set: { newValue in
                                        settings.notificationTime = newValue
                                        NotificationManager.shared.scheduleWorkoutReminder(at: newValue)
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }
                    }
                }
            }
        }
    }
    
    private var workoutManagementSection: some View {
        VStack(spacing: 12) {
            SectionHeaderView(title: "Workout Management", systemImage: "dumbbell.fill")
            
            ModernSettingsCard {
                VStack(spacing: 16) {
                    NavigationLink(destination: CategoriesManagementView()) {
                        ModernSettingsRow(
                            title: "Categories & Exercises",
                            subtitle: "Manage your workout categories",
                            systemImage: "folder.fill",
                            accentColor: .blue
                        )
                    }
                    
                    Divider()
                    
                    // HealthKit integration removed - manual workouts only
                    // Users can manually add workouts through the main interface
                }
            }
        }
    }
    
    private var dataSyncSection: some View {
        VStack(spacing: 12) {
            SectionHeaderView(title: "Data & Sync", systemImage: "arrow.triangle.2.circlepath")
            
            VStack(spacing: 12) {
                // Premium Card
                if purchaseManager.hasActiveSubscription {
                    ModernSettingsCard {
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Premium Active")
                                        .font(.headline)
                                    Text("All features unlocked")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                NavigationLink(destination: PremiumView()) {
                                    Text("Manage")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } else {
                    ModernSettingsCard {
                        Button(action: { showingPremiumPaywall = true }) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.purple)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Premium")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Cloud sync and advanced features")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                // Network Status Indicator
                ModernSettingsCard {
                    HStack {
                        Image(systemName: networkManager.isSafeToUseData ? "wifi" : "cellularbars")
                            .foregroundColor(networkManager.isSafeToUseData ? .green : .orange)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Network Status")
                                .font(.body.weight(.medium))
                            Text("\(networkManager.statusDescription) - \(networkManager.isSafeToUseData ? "Data operations allowed" : "Data operations blocked")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if networkManager.isOnCellular {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Backup & Restore
                ModernSettingsCard {
                    VStack(spacing: 16) {
                        if purchaseManager.hasActiveSubscription {
                            VStack(spacing: 12) {
                                Button(action: {
                                    if networkManager.isSafeToUseData {
                                        showingDataUsageWarning = true
                                    } else {
                                        backupErrorMessage = "Please connect to WiFi to backup your data. CloudKit operations are blocked on cellular networks."
                                        showingBackupError = true
                                    }
                                }) {
                                    ModernSettingsRow(
                                        title: "Backup to iCloud",
                                        subtitle: networkManager.isSafeToUseData ? "Save your data (WiFi only)" : "Requires WiFi connection",
                                        systemImage: networkManager.isSafeToUseData ? "icloud.and.arrow.up" : "wifi.slash",
                                        accentColor: networkManager.isSafeToUseData ? .blue : .orange,
                                        isLoading: isBackingUp
                                    )
                                }
                                .disabled(isBackingUp || isRestoring)
                                
                                Divider()
                                
                                Button(action: {
                                    if networkManager.isSafeToUseData {
                                        Task {
                                            await loadAvailableBackups()
                                            showingBackupSelection = true
                                        }
                                    } else {
                                        restoreErrorMessage = "Please connect to WiFi to restore your data. CloudKit operations are blocked on cellular networks."
                                        showingRestoreError = true
                                    }
                                }) {
                                    ModernSettingsRow(
                                        title: "Restore from iCloud",
                                        subtitle: networkManager.isSafeToUseData ? "Restore your data (WiFi only)" : "Requires WiFi connection",
                                        systemImage: networkManager.isSafeToUseData ? "icloud.and.arrow.down" : "wifi.slash",
                                        accentColor: networkManager.isSafeToUseData ? .green : .orange,
                                        isLoading: isRestoring
                                    )
                                }
                                .disabled(isBackingUp || isRestoring)
                                
                                if let lastBackup = lastBackupDate {
                                    HStack {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                        Text("Last backup: \(lastBackup, style: .relative)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                }
                            }
                        } else {
                            Button(action: { showingPremiumPaywall = true }) {
                                ModernSettingsRow(
                                    title: "Cloud Sync",
                                    subtitle: "Requires Premium",
                                    systemImage: "lock.fill",
                                    accentColor: .purple
                                )
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingBackupSelection) {
            NavigationView {
                List {
                    if isLoadingBackups {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if availableBackups.isEmpty {
                        Text("No backups available")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(availableBackups) { backup in
                            Button(action: {
                                selectedBackup = backup
                                showingBackupSelection = false
                                Task {
                                    await restoreFromCloud(backup: backup)
                                }
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(backup.deviceName)
                                        .font(.headline)
                                    
                                    Text(backup.timestamp, style: .relative)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 12) {
                                        Label("\(backup.workoutCount)", systemImage: "figure.strengthtraining.traditional")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Label("\(backup.categoryCount)", systemImage: "folder.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Label("\(backup.subcategoryCount)", systemImage: "tag.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .navigationTitle("Select Backup")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            showingBackupSelection = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingPremiumPaywall) {
            PremiumSheet(isPresented: $showingPremiumPaywall)
        }
        .alert("Backup Successful", isPresented: $showingBackupSuccess) {
            Button("OK") { }
        } message: {
            Text("Your data has been successfully backed up to iCloud.")
        }
        .alert("Backup Failed", isPresented: $showingBackupError) {
            Button("OK") { }
        } message: {
            Text("Backup failed: \(backupErrorMessage)")
        }
        .alert("Restore Successful", isPresented: $showingRestoreSuccess) {
            Button("OK") { }
        } message: {
            Text("Your data has been successfully restored from iCloud.")
        }
        .alert("Restore Failed", isPresented: $showingRestoreError) {
            Button("OK") { }
        } message: {
            Text("Restore failed: \(restoreErrorMessage)")
        }
    }
    
    private var supportSection: some View {
        VStack(spacing: 12) {
            SectionHeaderView(title: "Support & About", systemImage: "questionmark.circle")
            
            ModernSettingsCard {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("Version")
                            .font(.body.weight(.medium))
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    Link(destination: URL(string: "https://github.com/yourusername/TrainState")!) {
                        ModernSettingsRow(
                            title: "GitHub Repository",
                            subtitle: "View source code",
                            systemImage: "link",
                            accentColor: .gray
                        )
                    }
                    
                    Divider()
                    
                    Button(action: {
                        if let url = URL(string: "mailto:duplessisbrett@icloud.com?subject=TrainState%20App%20Feedback&body=Hi%20Brett%2C%0A%0AI%20would%20like%20to%20share%20my%20feedback%20about%20TrainState%3A%0A%0A") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        ModernSettingsRow(
                            title: "Send Feedback",
                            subtitle: "Get in touch",
                            systemImage: "envelope.fill",
                            accentColor: .orange
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Legacy Section Views
    
    private func settingsSection(settings: UserSettings) -> some View {
        SettingsSection(title: "App Settings", icon: "gear", color: .blue) {
            VStack(spacing: 16) {
                // Dark Mode Toggle
                Toggle(isOn: Binding(
                    get: { settings.darkModeEnabled },
                    set: { settings.darkModeEnabled = $0 }
                )) {
                    Label("Dark Mode", systemImage: "moon.fill")
                }
                
                // Measurement System
                VStack(alignment: .leading, spacing: 8) {
                    Text("Measurement System")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Picker("Measurement System", selection: Binding(
                        get: { settings.measurementSystem },
                        set: { settings.measurementSystem = $0 }
                    )) {
                        Text("Metric").tag(MeasurementSystem.metric)
                        Text("Imperial").tag(MeasurementSystem.imperial)
                    }
                    .pickerStyle(.segmented)
                }
                
                // App Icon
                Menu {
                    Button(action: {
                        selectedAppIcon = nil
                        AppIconManager.shared.resetToDefaultIcon()
                    }) {
                        Label("Default", systemImage: "app")
                    }
                    
                    Button(action: {
                        selectedAppIcon = "TrainState-iOS-Dark"
                        AppIconManager.shared.setAppIcon(for: "TrainState-iOS-Dark")
                    }) {
                        Label("Dark", systemImage: "moon.fill")
                    }
                    
                    Button(action: {
                        selectedAppIcon = "TrainState-iOS-TintedDark"
                        AppIconManager.shared.setAppIcon(for: "TrainState-iOS-TintedDark")
                    }) {
                        Label("Tinted Dark", systemImage: "moon.stars.fill")
                    }
                } label: {
                    HStack {
                        Label(selectedAppIcon == nil ? "Default" : selectedAppIcon ?? "Default", 
                              systemImage: selectedAppIcon == nil ? "app" : "moon.fill")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
        }
    }
    
    private func notificationsSection(settings: UserSettings) -> some View {
        SettingsSection(title: "Notifications", icon: "bell.fill", color: .orange) {
            VStack(spacing: 16) {
                Toggle(isOn: Binding(
                    get: { settings.notificationEnabled },
                    set: { newValue in
                        settings.notificationEnabled = newValue
                        if newValue {
                            NotificationManager.shared.requestAuthorization()
                        } else {
                            NotificationManager.shared.cancelWorkoutReminder()
                        }
                    }
                )) {
                    Label("Enable Notifications", systemImage: "bell")
                }
                
                if settings.notificationEnabled {
                    DatePicker(
                        "Reminder Time",
                        selection: Binding(
                            get: { settings.notificationTime ?? Date() },
                            set: { newValue in
                                settings.notificationTime = newValue
                                NotificationManager.shared.scheduleWorkoutReminder(at: newValue)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                }
            }
        }
    }
    
    private var workoutOrganizationSection: some View {
        SettingsSection(title: "Workout Organization", icon: "folder.fill", color: .green) {
            VStack(spacing: 16) {
                NavigationLink(destination: CategoriesManagementView()) {
                    SettingsRow(icon: "folder", title: "Manage Categories")
                }
                
                // HealthKit integration removed - manual workouts only
            }
        }
    }
    
    private var premiumSection: some View {
        SettingsSection(title: "Premium", icon: "star.fill", color: .purple) {
            VStack(spacing: 16) {
                if purchaseManager.hasActiveSubscription {
                    // Active subscription status
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Premium Active")
                                .font(.headline)
                            Text("Enjoy all premium features")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.1))
                    )
                    
                    NavigationLink(destination: PremiumView()) {
                        SettingsRow(icon: "gear", title: "Manage Subscription")
                    }
                } else {
                    // Upgrade to premium
                    NavigationLink(destination: PremiumView()) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Upgrade to Premium")
                                    .font(.headline)
                                Text("Unlock cloud sync and advanced features")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var backupRestoreSection: some View {
        SettingsSection(title: "Backup & Restore", icon: "arrow.triangle.2.circlepath", color: .indigo) {
            VStack(spacing: 16) {
                // Debug Info Card - Always visible for debugging
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("DEBUG INFO")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    Text(debugInfo.isEmpty ? "Debug info not set" : debugInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                if purchaseManager.hasActiveSubscription {
                    // Backup Button
                    Button(action: {
                        Task { @MainActor in
                            isBackingUp = true
                            let environment = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "TestFlight/Sandbox" : "App Store/Production"
                            debugInfo = "Environment: \(environment)\nStatus: Creating backup...\nContainer: iCloud.brettduplessis.TrainState"
                            
                            // Set up debug callback
                            CloudKitManager.shared.debugCallback = { message in
                                DispatchQueue.main.async {
                                    self.debugInfo = message
                                }
                            }
                            
                            do {
                                // CloudKit backup disabled to prevent data usage
                                print("CloudKit backup disabled")
                                lastBackupDate = Date()
                                debugInfo = "Environment: \(environment)\nStatus: BACKUP SUCCESS ✅\nLast backup: \(Date().formatted())"
                                showingBackupSuccess = true
                            } catch {
                                debugInfo = "Environment: \(environment)\nStatus: BACKUP ERROR ❌\nError: \(error.localizedDescription)"
                                backupErrorMessage = error.localizedDescription
                                showingBackupError = true
                            }
                            isBackingUp = false
                        }
                    }) {
                        SettingsRow(
                            icon: "arrow.up.to.icloud",
                            title: "Backup to iCloud",
                            isLoading: isBackingUp
                        )
                    }
                    .disabled(isBackingUp || isRestoring)
                    
                    // Restore Button
                    Button(action: {
                        Task {
                            await loadAvailableBackups()
                            showingBackupSelection = true
                        }
                    }) {
                        SettingsRow(
                            icon: "arrow.down.to.iphone",
                            title: "Restore from iCloud",
                            isLoading: isRestoring
                        )
                    }
                    .disabled(isBackingUp || isRestoring)
                    
                    // Last Backup Info
                    if let lastBackup = lastBackupDate {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.secondary)
                            Text("Last backup: \(lastBackup, style: .relative)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    
                    // Add Manage Backups button
                    Button(action: {
                        Task {
                            await loadAvailableBackups()
                            showingManageBackups = true
                        }
                    }) {
                        SettingsRow(
                            icon: "tray.full",
                            title: "Manage Backups",
                            subtitle: "View and delete old backups"
                        )
                    }
                    .disabled(isBackingUp || isRestoring)
                } else {
                    Button(action: { showingPremiumPaywall = true }) {
                        SettingsRow(
                            icon: "lock.fill",
                            title: "Upgrade to Premium for Cloud Sync",
                            subtitle: "Backup and restore your data across devices"
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingBackupSelection) {
            NavigationView {
                List {
                    if isLoadingBackups {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if availableBackups.isEmpty {
                        Text("No backups available")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(availableBackups) { backup in
                            Button(action: {
                                selectedBackup = backup
                                showingBackupSelection = false
                                Task {
                                    await restoreFromCloud(backup: backup)
                                }
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(backup.deviceName)
                                        .font(.headline)
                                    
                                    Text(backup.timestamp, style: .relative)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    HStack(spacing: 12) {
                                        Label("\(backup.workoutCount)", systemImage: "figure.strengthtraining.traditional")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Label("\(backup.categoryCount)", systemImage: "folder.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Label("\(backup.subcategoryCount)", systemImage: "tag.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Label("\(backup.assignedSubcategoryCount)", systemImage: "tag.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .navigationTitle("Select Backup")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            showingBackupSelection = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingPremiumPaywall) {
            PremiumSheet(isPresented: $showingPremiumPaywall)
        }
        .sheet(isPresented: $showingManageBackups) {
            NavigationView {
                ZStack {
                    List {
                        if isLoadingBackups {
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    ProgressView()
                                    Text("Loading backups...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        } else if availableBackups.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "tray")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                    Text("No backups available")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text("Create your first backup to get started")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(availableBackups) { backup in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(backup.deviceName)
                                                .font(.headline)
                                            Text(backup.timestamp, style: .relative)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        
                                        // Show backup size indicator
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(backup.workoutCount)")
                                                .font(.title3.weight(.semibold))
                                                .foregroundColor(.primary)
                                            Text("workouts")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    HStack(spacing: 16) {
                                        Label("\(backup.categoryCount)", systemImage: "folder.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Label("\(backup.subcategoryCount)", systemImage: "tag.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if backup.assignedSubcategoryCount > 0 {
                                            Label("\(backup.assignedSubcategoryCount)", systemImage: "tag.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                .padding(.vertical, 8)
                                .opacity(isDeletingBackups ? 0.6 : 1.0)
                            }
                            .onDelete(perform: isDeletingBackups ? nil : deleteBackups)
                        }
                    }
                    .disabled(isDeletingBackups)
                    
                    // Deletion overlay
                    if isDeletingBackups {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                
                                Text("Deleting backups...")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Please wait while we remove the selected backups")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                            )
                            .shadow(radius: 20)
                        }
                    }
                }
                .navigationTitle("Manage Backups")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingManageBackups = false
                        }
                        .disabled(isDeletingBackups)
                    }
                }
            }
        }
    }
    
    private var statsSection: some View {
        SettingsSection(title: "Quick Stats", icon: "chart.bar.fill", color: .pink) {
            HStack(spacing: 16) {
                StatCard(icon: "figure.strengthtraining.traditional", value: "\(workouts.count)", color: .orange)
                StatCard(icon: "folder", value: "\(categories.count)", color: .blue)
                StatCard(icon: "square.grid.2x2", value: "\(subcategories.count)", color: .purple)
            }
        }
    }
    
    private var aboutSection: some View {
        SettingsSection(title: "About", icon: "info.circle.fill", color: .teal) {
            VStack(spacing: 16) {
                HStack {
                    Label("Version", systemImage: "number")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Link(destination: URL(string: "https://github.com/yourusername/TrainState")!) {
                    SettingsRow(icon: "arrow.up.right.square", title: "GitHub Repository")
                }
                
                Button(action: {
                    if let url = URL(string: "mailto:duplessisbrett@icloud.com?subject=TrainState%20App%20Feedback&body=Hi%20Brett%2C%0A%0AI%20would%20like%20to%20share%20my%20feedback%20about%20TrainState%3A%0A%0A") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    SettingsRow(icon: "envelope.fill", title: "Send Feedback")
                }
            }
        }
    }
    
    private var developerSection: some View {
        SettingsSection(title: "Developer Options", icon: "hammer.fill", color: .red) {
            VStack(spacing: 16) {
                Button(action: { showingResetConfirmation = true }) {
                    SettingsRow(icon: "trash", title: "Reset All Data", color: .red)
                }
                
                Button(action: { showingOnboardingResetConfirmation = true }) {
                    SettingsRow(icon: "arrow.counterclockwise", title: "Reset Onboarding", color: .orange)
                }
            }
        }
        .alert("Reset All Data?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                Task {
                    await performDataReset()
                }
            }
        } message: {
            Text("This will delete all workouts, categories, and subcategories. This action cannot be undone.")
        }
        .alert("Reset Onboarding?", isPresented: $showingOnboardingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetOnboarding()
            }
        } message: {
            Text("This will reset the onboarding process. You'll need to go through it again when you restart the app.")
        }
    }
    
    // MARK: - Helper Methods
    
    private func resetAllData() {
        print("[Reset] Starting data reset...")
        
        do {
            // Use batch deletion approach for better memory efficiency
            
            // 1. Delete workout routes first (no relationships to worry about)
            let routeDescriptor = FetchDescriptor<WorkoutRoute>()
            let allRoutes = try modelContext.fetch(routeDescriptor)
            print("[Reset] Deleting \(allRoutes.count) routes...")
            
            for route in allRoutes {
                modelContext.delete(route)
            }
            
            // 2. Delete workouts in small batches to avoid memory issues
            let workoutDescriptor = FetchDescriptor<Workout>()
            let allWorkouts = try modelContext.fetch(workoutDescriptor)
            print("[Reset] Deleting \(allWorkouts.count) workouts...")
            
            // Process in batches of 50 to avoid memory spikes
            let batchSize = 50
            for i in stride(from: 0, to: allWorkouts.count, by: batchSize) {
                let endIndex = min(i + batchSize, allWorkouts.count)
                let batch = Array(allWorkouts[i..<endIndex])
                
                for workout in batch {
                    modelContext.delete(workout)
                }
                
                // Save every batch to free memory
                try modelContext.save()
                print("[Reset] Deleted batch \(i/batchSize + 1), \(endIndex) of \(allWorkouts.count) workouts")
            }
            
            // 3. Delete subcategories
            let subcategoryDescriptor = FetchDescriptor<WorkoutSubcategory>()
            let allSubcategories = try modelContext.fetch(subcategoryDescriptor)
            print("[Reset] Deleting \(allSubcategories.count) subcategories...")
            
            for subcategory in allSubcategories {
                modelContext.delete(subcategory)
            }
            
            // 4. Delete categories
            let categoryDescriptor = FetchDescriptor<WorkoutCategory>()
            let allCategories = try modelContext.fetch(categoryDescriptor)
            print("[Reset] Deleting \(allCategories.count) categories...")
            
            for category in allCategories {
                modelContext.delete(category)
            }
            
            // 5. Reset user settings (don't delete, just reset to defaults)
            let settingsDescriptor = FetchDescriptor<UserSettings>()
            let userSettings = try modelContext.fetch(settingsDescriptor)
            for setting in userSettings {
                modelContext.delete(setting)
            }
            
            // Final save
            try modelContext.save()
            print("[Reset] Successfully reset all data")
            
        } catch {
            print("[Reset] Failed to reset data: \(error.localizedDescription)")
            
            // Rollback to prevent corruption
            modelContext.rollback()
            
            if let detailedError = error as? NSError {
                print("[Reset] Detailed error: \(detailedError)")
            }
        }
    }
    
    // MARK: - Async Reset Helper
    
    private func performDataReset() async {
        await MainActor.run {
            resetAllData()
        }
    }
    
    private func resetOnboarding() {
        hasCompletedOnboarding = false
    }
    
    private func loadAvailableBackups() async {
        // Prevent concurrent loading
        if isLoadingBackups { return }
        
        await MainActor.run {
            isLoadingBackups = true
            let environment = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "TestFlight/Sandbox" : "App Store/Production"
            debugInfo = "Environment: \(environment)\nStatus: Loading backups...\nContainer: iCloud.brettduplessis.TrainState"
        }
        
        // Set up debug callback
        CloudKitManager.shared.debugCallback = { message in
            DispatchQueue.main.async {
                self.debugInfo = message
            }
        }
        
        do {
            let backups = try await CloudKitManager.shared.fetchAvailableBackups()
            await MainActor.run {
                availableBackups = backups
                isLoadingBackups = false
                debugInfo = "Successfully loaded \(backups.count) backup(s)"
            }
        } catch {
            await MainActor.run {
                isLoadingBackups = false
                let environment = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "TestFlight/Sandbox" : "App Store/Production"
                debugInfo = "Environment: \(environment)\nStatus: FINAL ERROR ❌\nError: \(error.localizedDescription)\nType: \(type(of: error))"
                restoreErrorMessage = "Failed to load backups: \(error.localizedDescription)"
                showingRestoreError = true
            }
        }
    }

    private func restoreFromCloud(backup: BackupInfo) async {
        await MainActor.run {
            isRestoring = true
        }
        
        do {
            try await CloudKitManager.shared.restoreFromCloud(backupInfo: backup, context: modelContext)
            await MainActor.run {
                isRestoring = false
                showingRestoreSuccess = true
            }
        } catch {
            await MainActor.run {
                isRestoring = false
                restoreErrorMessage = "Failed to restore from iCloud: \(error.localizedDescription)"
                showingRestoreError = true
            }
        }
    }

    // Add deleteBackups helper
    private func deleteBackups(at offsets: IndexSet) {
        let backupsToDelete = offsets.map { availableBackups[$0] }
        
        // Set deletion state for UI feedback
        isDeletingBackups = true
        
        // Immediately remove from UI for responsive feedback
        availableBackups.remove(atOffsets: offsets)
        
        Task {
            do {
                // Use batch deletion for better performance
                let failedBackups = try await CloudKitManager.shared.deleteBackups(backupsToDelete)
                
                await MainActor.run {
                    isDeletingBackups = false
                    
                    // If some deletions failed, add them back to the list
                    if !failedBackups.isEmpty {
                        availableBackups.append(contentsOf: failedBackups)
                        availableBackups.sort { $0.timestamp > $1.timestamp }
                        debugInfo = "Some backups could not be deleted. \(failedBackups.count) deletion(s) failed."
                    } else {
                        debugInfo = "Successfully deleted \(backupsToDelete.count) backup(s)"
                    }
                }
            } catch {
                // If the entire batch failed, restore all items and show error
                await MainActor.run {
                    isDeletingBackups = false
                    availableBackups.append(contentsOf: backupsToDelete)
                    availableBackups.sort { $0.timestamp > $1.timestamp }
                    debugInfo = "Failed to delete backups: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Backup Function
    
    private func performBackup() {
        Task { @MainActor in
            isBackingUp = true
            let environment = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "TestFlight/Sandbox" : "App Store/Production"
            debugInfo = "Environment: \(environment)\nStatus: Creating backup...\nContainer: iCloud.brettduplessis.TrainState"
            
            CloudKitManager.shared.debugCallback = { message in
                DispatchQueue.main.async {
                    self.debugInfo = message
                }
            }
            
            do {
                // CloudKit backup disabled to prevent data usage
                print("CloudKit backup disabled")
                lastBackupDate = Date()
                debugInfo = "Environment: \(environment)\nStatus: BACKUP SUCCESS ✅\nLast backup: \(Date().formatted())"
                showingBackupSuccess = true
            } catch {
                debugInfo = "Environment: \(environment)\nStatus: BACKUP ERROR ❌\nError: \(error.localizedDescription)"
                backupErrorMessage = error.localizedDescription
                showingBackupError = true
            }
            isBackingUp = false
        }
    }
}

// MARK: - Modern Supporting Views

struct ModernSettingsCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .appCard(padding: 20)
    }
}

struct SectionHeaderView: View {
    let title: String
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

struct ModernSettingsRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let accentColor: Color
    let isLoading: Bool
    
    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        accentColor: Color,
        isLoading: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.accentColor = accentColor
        self.isLoading = isLoading
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if isLoading {
                ProgressView()
                    .tint(.primary)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: systemImage)
                    .foregroundColor(accentColor)
                    .frame(width: 20)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if !isLoading {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(.vertical, 4)
    }
}

struct ModernToggleRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let isOn: Binding<Bool>
    let accentColor: Color
    
    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        isOn: Binding<Bool>,
        accentColor: Color
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isOn = isOn
        self.accentColor = accentColor
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(accentColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .toggleStyle(SwitchToggleStyle(tint: accentColor))
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

struct ProfileStatView: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Legacy Supporting Views

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            
            // Content
            content
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: color.opacity(0.05), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(color.opacity(0.10), lineWidth: 1)
        )
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    var isLoading: Bool = false
    var color: Color = .primary
    
    var body: some View {
        HStack {
            if isLoading {
                ProgressView()
                    .tint(.primary)
                    .padding(.trailing, 8)
            }
            
            Label(title, systemImage: icon)
                .foregroundColor(color)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !isLoading {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        )
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: UserSettings.self, WorkoutCategory.self, WorkoutSubcategory.self, configurations: config)
        
        // Add mock UserSettings
        let settings = UserSettings()
        settings.darkModeEnabled = false
        settings.measurementSystem = .metric
        settings.notificationEnabled = true
        settings.notificationTime = Date()
        container.mainContext.insert(settings)
        
        // Add mock categories
        let category = WorkoutCategory(name: "Strength")
        container.mainContext.insert(category)
        
        // Add mock subcategories
        let subcategory = WorkoutSubcategory(name: "Bench Press")
        subcategory.category = category
        container.mainContext.insert(subcategory)
        
        return SettingsView()
            .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}

