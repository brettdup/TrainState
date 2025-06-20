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
    
    // Add new state for manage backups sheet
    @State private var showingManageBackups = false
    
    // Add deletion state for better UX
    @State private var isDeletingBackups = false
    @State private var deletionProgress: Float = 0.0
    
    @Query private var categories: [WorkoutCategory]
    @Query private var subcategories: [WorkoutSubcategory]
    @Query private var workouts: [Workout]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if let settings = userSettings.first {
                            // App Settings
                            settingsSection(settings: settings)
                            
                            // Notifications
                            notificationsSection(settings: settings)
                            
                            // Workout Organization
                            workoutOrganizationSection
                            
                            // Premium
                            premiumSection
                            
                            // Backup & Restore
                            backupRestoreSection
                            
                            // Stats
                            statsSection
                            
                            // About
                            aboutSection
                            
                            #if DEBUG
                            // Developer Options
                            developerSection
                            #endif
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                NotificationManager.shared.checkNotificationStatus { authorized in
                    isNotificationAuthorized = authorized
                }
                
                // Set initial debug info
                let environment = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "TestFlight/Sandbox" : "App Store/Production"
                debugInfo = "Environment: \(environment)\nStatus: Settings loaded\nContainer: iCloud.brettduplessis.TrainState\nTime: \(Date().formatted())"
                
                // Set up debug callback for CloudKit
                CloudKitManager.shared.debugCallback = { message in
                    DispatchQueue.main.async {
                        self.debugInfo = message
                    }
                }
            }
        }
    }
    
    // MARK: - Section Views
    
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
                
                NavigationLink(destination: HealthSettingsView()) {
                    SettingsRow(icon: "heart", title: "Health Integration")
                }
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
                                try await CloudKitManager.shared.backupToCloud(context: modelContext)
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
                resetAllData()
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
        // Delete all workouts
        for workout in workouts {
            modelContext.delete(workout)
        }
        
        // Delete all subcategories
        for subcategory in subcategories {
            modelContext.delete(subcategory)
        }
        
        // Delete all categories
        for category in categories {
            modelContext.delete(category)
        }
        
        // Save changes
        do {
            try modelContext.save()
            print("Successfully reset all data")
        } catch {
            print("Failed to reset data: \(error.localizedDescription)")
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
}

// MARK: - Supporting Views

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
    SettingsView()
        .modelContainer(for: [UserSettings.self, WorkoutCategory.self, WorkoutSubcategory.self], inMemory: true)
}

