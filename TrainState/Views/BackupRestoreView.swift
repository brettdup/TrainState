import SwiftUI
import SwiftData

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
    
    var body: some View {
        Section {
            Button(action: {
                exportData()
            }) {
                HStack {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                    if isExporting {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(isExporting)
            
            Button(action: {
                importData()
            }) {
                HStack {
                    Label("Import Data", systemImage: "square.and.arrow.down")
                    if isImporting {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(isImporting)
        } header: {
            Text("Backup & Restore")
        } footer: {
            Text("Export your data to backup or transfer to another device")
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
    }
    
    private func exportData() {
        isExporting = true
        
        Task {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                
                // Export workouts
                let workoutsData = try encoder.encode(workouts)
                
                // Export categories
                let categoriesData = try encoder.encode(categories)
                
                // Export subcategories
                let subcategoriesData = try encoder.encode(subcategories)
                
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
                let fileURL = documentsDirectory.appendingPathComponent("TrainState_Backup.json")
                
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
            
            // Import new data
            if let workoutsData = importData["workouts"] {
                let importedWorkouts = try decoder.decode([Workout].self, from: workoutsData)
                for workout in importedWorkouts {
                    modelContext.insert(workout)
                }
            }
            
            if let categoriesData = importData["categories"] {
                let importedCategories = try decoder.decode([WorkoutCategory].self, from: categoriesData)
                for category in importedCategories {
                    modelContext.insert(category)
                }
            }
            
            if let subcategoriesData = importData["subcategories"] {
                let importedSubcategories = try decoder.decode([WorkoutSubcategory].self, from: subcategoriesData)
                for subcategory in importedSubcategories {
                    modelContext.insert(subcategory)
                }
            }
            
            try modelContext.save()
            
            await MainActor.run {
                isImporting = false
                // Show success alert
                let alert = UIAlertController(
                    title: "Success",
                    message: "Data imported successfully",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(alert, animated: true)
                }
            }
        } catch {
            await MainActor.run {
                isImporting = false
                // Show error alert
                let alert = UIAlertController(
                    title: "Import Failed",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(alert, animated: true)
                }
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