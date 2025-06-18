import SwiftUI
import SwiftData
import CloudKit

struct BackupRestoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workouts: [Workout]
    @Query private var categories: [WorkoutCategory]
    @Query private var subcategories: [WorkoutSubcategory]
    
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showingExportSuccess = false
    @State private var showingExportError = false
    @State private var exportErrorMessage = ""
    @State private var isCloudBackingUp = false
    @State private var isCloudRestoring = false
    @State private var showingCloudError = false
    @State private var showingCloudSuccess = false
    @State private var cloudErrorMessage = ""
    @State private var cloudSuccessMessage = ""
    @State private var isCloudAvailable = false
    @State private var showingCloudRestoreConfirmation = false
    @State private var availableBackups: [BackupInfo] = []
    @State private var selectedBackup: BackupInfo?
    @State private var isLoadingBackups = false
    @State private var showingBackupSelection = false
    
    var body: some View {
        NavigationView {
            List {
                // Local Backup Section
                Section {
                    Button(action: exportData) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Export Data")
                                    .font(.headline)
                                Text("Create a backup file")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isExporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(isExporting)
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: importData) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import Data")
                                    .font(.headline)
                                Text("Restore from backup file")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isImporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(isImporting)
                    .buttonStyle(PlainButtonStyle())
                    
                } header: {
                    Text("Local Backup")
                } footer: {
                    Text("Export your data to backup or transfer to another device. Import will replace all existing data.")
                }
                
                // iCloud Backup Section
                Section {
                    // Backup to iCloud Button
                    Button(action: {
                        Task { await backupToCloud() }
                    }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                                .foregroundColor(isCloudAvailable ? .blue : .gray)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Backup to iCloud")
                                    .font(.headline)
                                    .foregroundColor(isCloudAvailable ? .primary : .secondary)
                                Text("Save data to your iCloud account")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isCloudBackingUp {
                                ProgressView()
                                    .controlSize(.small)
                            } else if isCloudAvailable {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(isCloudBackingUp || !isCloudAvailable)
                    .buttonStyle(PlainButtonStyle())
                    
                    // Available Backups List
                    if isCloudAvailable {
                        if isLoadingBackups {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
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
                                    showingCloudRestoreConfirmation = true
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(backup.deviceName)
                                                .font(.headline)
                                            Spacer()
                                            Text(backup.timestamp, style: .relative)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
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
                    
                } header: {
                    Text("iCloud Backup")
                } footer: {
                    if !isCloudAvailable {
                        Label("iCloud is not available. Please sign in to iCloud in Settings.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    } else {
                        Text("Automatically backup and restore your data using your iCloud account. Restore will replace all existing data.")
                    }
                }
                
                // Data Summary Section
                if !isCloudRestoring && !isImporting {
                    Section("Current Data") {
                        HStack {
                            Label("\(workouts.count)", systemImage: "figure.strengthtraining.traditional")
                            Spacer()
                            Text("Workouts")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("\(categories.count)", systemImage: "folder.fill")
                            Spacer()
                            Text("Categories")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("\(subcategories.count)", systemImage: "tag.fill")
                            Spacer()
                            Text("Subcategories")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Backup & Restore")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await checkCloudStatus()
                await loadAvailableBackups()
            }
            .task {
                await checkCloudStatus()
                await loadAvailableBackups()
            }
            .overlay {
                if isCloudBackingUp || isCloudRestoring {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack {
                        ProgressView {
                            Text(isCloudBackingUp ? "Backing up..." : "Restoring...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                        .padding(30)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                    )
                }
            }
        }
        .alert("Export Successful", isPresented: $showingExportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your data has been exported successfully. You can now share the backup file.")
        }
        .alert("Export Failed", isPresented: $showingExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Failed to export data: \(exportErrorMessage)")
        }
        .alert("iCloud Error", isPresented: $showingCloudError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cloudErrorMessage)
        }
        .alert("Success", isPresented: $showingCloudSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cloudSuccessMessage)
        }
        .alert("Restore from iCloud", isPresented: $showingCloudRestoreConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) {
                if let backup = selectedBackup {
                    Task { await restoreFromCloud(backup: backup) }
                }
            }
        } message: {
            if let backup = selectedBackup {
                Text("This will replace all your current data with the backup from \(backup.deviceName) (\(backup.timestamp, style: .relative)). This action cannot be undone.")
            }
        }
        .alert("Backup Selection", isPresented: $showingBackupSelection) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cloudErrorMessage)
        }
    }
    
    private func checkCloudStatus() async {
        do {
            let available = try await CloudKitManager.shared.checkCloudStatus()
            await MainActor.run {
                isCloudAvailable = available
            }
        } catch {
            await MainActor.run {
                isCloudAvailable = false
                cloudErrorMessage = error.localizedDescription
                showingCloudError = true
            }
        }
    }
    
    private func loadAvailableBackups() async {
        guard isCloudAvailable else { return }
        
        await MainActor.run {
            isLoadingBackups = true
        }
        
        do {
            let backups = try await CloudKitManager.shared.fetchAvailableBackups()
            await MainActor.run {
                availableBackups = backups
                isLoadingBackups = false
            }
        } catch {
            await MainActor.run {
                isLoadingBackups = false
                cloudErrorMessage = "Error: Failed to load backups: \(error.localizedDescription)"
                showingCloudError = true
            }
        }
    }
    
    private func backupToCloud() async {
        await MainActor.run {
            isCloudBackingUp = true
        }
        
        do {
            try await CloudKitManager.shared.backupToCloud(context: modelContext)
            await MainActor.run {
                isCloudBackingUp = false
                cloudSuccessMessage = "Your data has been successfully backed up to iCloud."
                showingCloudSuccess = true
            }
            // Reload available backups
            await loadAvailableBackups()
        } catch let error as CloudKitError {
            await MainActor.run {
                isCloudBackingUp = false
                cloudErrorMessage = "Error: \(error.localizedDescription)"
                showingCloudError = true
                
                // Check for available backups when error occurs
                Task {
                    await loadAvailableBackups()
                    if !availableBackups.isEmpty {
                        cloudErrorMessage += "\n\nPrevious backups are available for restore."
                        showingBackupSelection = true
                    }
                }
            }
        } catch {
            await MainActor.run {
                isCloudBackingUp = false
                cloudErrorMessage = "Error: An unexpected error occurred. Please try again later."
                showingCloudError = true
                
                // Check for available backups when error occurs
                Task {
                    await loadAvailableBackups()
                    if !availableBackups.isEmpty {
                        cloudErrorMessage += "\n\nPrevious backups are available for restore."
                        showingBackupSelection = true
                    }
                }
            }
        }
    }
    
    private func restoreFromCloud(backup: BackupInfo) async {
        await MainActor.run {
            isCloudRestoring = true
        }
        
        do {
            try await CloudKitManager.shared.restoreFromCloud(backupInfo: backup, context: modelContext)
            await MainActor.run {
                isCloudRestoring = false
                cloudSuccessMessage = "Your data has been successfully restored from iCloud."
                showingCloudSuccess = true
            }
        } catch let error as CloudKitError {
            await MainActor.run {
                isCloudRestoring = false
                cloudErrorMessage = "Error: \(error.localizedDescription)"
                showingCloudError = true
                
                // Check for other available backups when restore fails
                Task {
                    await loadAvailableBackups()
                    if availableBackups.count > 1 {
                        cloudErrorMessage += "\n\nOther backups are available to try."
                        showingBackupSelection = true
                    }
                }
            }
        } catch {
            await MainActor.run {
                isCloudRestoring = false
                cloudErrorMessage = "Error: An unexpected error occurred. Please try again later."
                showingCloudError = true
                
                // Check for other available backups when restore fails
                Task {
                    await loadAvailableBackups()
                    if availableBackups.count > 1 {
                        cloudErrorMessage += "\n\nOther backups are available to try."
                        showingBackupSelection = true
                    }
                }
            }
        }
    }
    
    private func exportData() {
        isExporting = true
        
        Task {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                
                // Export workouts using export structures
                let workoutExports = workouts.map { WorkoutExport(from: $0) }
                let workoutsData = try encoder.encode(workoutExports)
                
                // Export categories using export structures
                let categoryExports = categories.map { WorkoutCategoryExport(from: $0) }
                let categoriesData = try encoder.encode(categoryExports)
                
                // Export subcategories using export structures
                let subcategoryExports = subcategories.map { WorkoutSubcategoryExport(from: $0) }
                let subcategoriesData = try encoder.encode(subcategoryExports)
                
                // Create a dictionary with all data
                let exportData: [String: Data] = [
                    "workouts": workoutsData,
                    "categories": categoriesData,
                    "subcategories": subcategoriesData
                ]
                
                // Encode the dictionary
                let finalData = try JSONEncoder().encode(exportData)
                
                // Get documents directory
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
                let timestamp = dateFormatter.string(from: Date())
                let fileURL = documentsDirectory.appendingPathComponent("TrainState_Backup_\(timestamp).json")
                
                // Write to file
                try finalData.write(to: fileURL)
                
                await MainActor.run {
                    isExporting = false
                    
                    // Share the file
                    let activityVC = UIActivityViewController(
                        activityItems: [fileURL],
                        applicationActivities: nil
                    )
                    
                    // Get the root view controller to present the share sheet
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        rootViewController.present(activityVC, animated: true)
                    }
                    
                    showingExportSuccess = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportErrorMessage = error.localizedDescription
                    showingExportError = true
                }
            }
        }
    }
    
    private func importData() {
        isImporting = true
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        let delegate = DocumentPickerDelegate { [self] importData in
            Task {
                await performImport(importData)
            }
        }
        documentPicker.delegate = delegate
        objc_setAssociatedObject(documentPicker, &AssociatedKeys.delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(documentPicker, animated: true)
        }
    }
    
    private func performImport(_ importData: [String: Data]) async {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Delete existing data
            for workout in workouts {
                modelContext.delete(workout)
            }
            for category in categories {
                modelContext.delete(category)
            }
            for subcategory in subcategories {
                modelContext.delete(subcategory)
            }
            
            // Import categories first
            var categoryMap: [UUID: WorkoutCategory] = [:]
            if let categoriesData = importData["categories"] {
                let importedCategoryExports = try decoder.decode([WorkoutCategoryExport].self, from: categoriesData)
                for categoryExport in importedCategoryExports {
                    let category = WorkoutCategory(name: categoryExport.name, color: categoryExport.color, workoutType: categoryExport.workoutType)
                    category.id = categoryExport.id
                    categoryMap[categoryExport.id] = category
                    modelContext.insert(category)
                }
            }
            
            // Import subcategories second
            var subcategoryMap: [UUID: WorkoutSubcategory] = [:]
            if let subcategoriesData = importData["subcategories"] {
                let importedSubcategoryExports = try decoder.decode([WorkoutSubcategoryExport].self, from: subcategoriesData)
                for subcategoryExport in importedSubcategoryExports {
                    let subcategory = WorkoutSubcategory(name: subcategoryExport.name)
                    subcategory.id = subcategoryExport.id
                    subcategoryMap[subcategoryExport.id] = subcategory
                    modelContext.insert(subcategory)
                }
            }
            
            // Import workouts without relationships first
            var workoutMap: [UUID: Workout] = [:]
            if let workoutsData = importData["workouts"] {
                let importedWorkoutExports = try decoder.decode([WorkoutExport].self, from: workoutsData)
                for workoutExport in importedWorkoutExports {
                    let workout = Workout(
                        type: workoutExport.type,
                        startDate: workoutExport.startDate,
                        duration: workoutExport.duration,
                        calories: workoutExport.calories,
                        distance: workoutExport.distance,
                        notes: workoutExport.notes,
                        healthKitUUID: workoutExport.healthKitUUID
                    )
                    workout.id = workoutExport.id
                    workoutMap[workoutExport.id] = workout
                    modelContext.insert(workout)
                }
                
                // Save all objects first to establish them in the context
                try modelContext.save()
                
                // Now restore relationships after all objects are persisted
                for workoutExport in importedWorkoutExports {
                    guard let workout = workoutMap[workoutExport.id] else { continue }
                    
                    // Safely restore category relationships
                    if let categoryIds = workoutExport.categoryIds {
                        let categories = categoryIds.compactMap { categoryMap[$0] }
                        for category in categories {
                            workout.addCategory(category)
                        }
                    }
                    
                    // Safely restore subcategory relationships
                    if let subcategoryIds = workoutExport.subcategoryIds {
                        let subcategories = subcategoryIds.compactMap { subcategoryMap[$0] }
                        for subcategory in subcategories {
                            workout.addSubcategory(subcategory)
                        }
                    }
                }
            }
            
            try modelContext.save()
            
            await MainActor.run {
                isImporting = false
                showingExportSuccess = true
            }
        } catch {
            await MainActor.run {
                isImporting = false
                exportErrorMessage = "Failed to import data: \(error.localizedDescription)"
                showingExportError = true
            }
        }
    }
}

// MARK: - Document Picker Delegate
private class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let importHandler: ([String: Data]) -> Void
    
    init(importHandler: @escaping ([String: Data]) -> Void) {
        self.importHandler = importHandler
        super.init()
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedFileURL = urls.first else { return }
        
        do {
            let data = try Data(contentsOf: selectedFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Decode the dictionary
            let importData = try decoder.decode([String: Data].self, from: data)
            
            // Show confirmation alert
            let alert = UIAlertController(
                title: "Import Data",
                message: "This will replace all existing data. Are you sure?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Import", style: .destructive) { [weak self] _ in
                self?.importHandler(importData)
            })
            
            // Get the root view controller to present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        } catch {
            print("Error importing data: \(error)")
        }
    }
}

// MARK: - Associated Keys
private enum AssociatedKeys {
    static var delegateKey = "DocumentPickerDelegateKey"
} 