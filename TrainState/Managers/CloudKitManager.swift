import Foundation
import CloudKit
import SwiftData
import UIKit

class CloudKitManager {
    static let shared = CloudKitManager()
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    private init() {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            print("[CloudKit] Initializing with bundle identifier: \(bundleIdentifier)")
            container = CKContainer(identifier: "iCloud.\(bundleIdentifier)")
        } else {
            print("[CloudKit] No bundle identifier found, using default container")
            container = CKContainer.default()
        }
        privateDatabase = container.privateCloudDatabase
    }
    
    // MARK: - Backup Operations
    
    func backupToCloud(context: ModelContext) async throws {
        print("[CloudKit] Starting backup to cloud")
        // Fetch all data
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let categories = try context.fetch(FetchDescriptor<WorkoutCategory>())
        let subcategories = try context.fetch(FetchDescriptor<WorkoutSubcategory>())
        
        print("[CloudKit] Fetched data - Workouts: \(workouts.count), Categories: \(categories.count), Subcategories: \(subcategories.count)")
        
        // Create a new backup record with timestamp
        let timestamp = Date()
        let backupID = CKRecord.ID(recordName: "Backup_\(timestamp.timeIntervalSince1970)")
        let backupRecord = CKRecord(recordType: "Backup", recordID: backupID)
        
        // Add metadata
        backupRecord["timestamp"] = timestamp
        backupRecord["deviceName"] = UIDevice.current.name
        backupRecord["workoutCount"] = workouts.count
        backupRecord["categoryCount"] = categories.count
        backupRecord["subcategoryCount"] = subcategories.count
        backupRecord["assignedSubcategoryCount"] = subcategories.filter { $0.workouts?.count ?? 0 > 0 }.count
        
        // Encode data using export structures
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let workoutExports = workouts.map { WorkoutExport(from: $0) }
        let workoutsData = try encoder.encode(workoutExports)
        
        let categoryExports = categories.map { WorkoutCategoryExport(from: $0) }
        let categoriesData = try encoder.encode(categoryExports)
        
        let subcategoryExports = subcategories.map { WorkoutSubcategoryExport(from: $0) }
        let subcategoriesData = try encoder.encode(subcategoryExports)
        
        // Create temporary files
        let tempDir = FileManager.default.temporaryDirectory
        let workoutsURL = tempDir.appendingPathComponent("workouts.json")
        let categoriesURL = tempDir.appendingPathComponent("categories.json")
        let subcategoriesURL = tempDir.appendingPathComponent("subcategories.json")
        
        try workoutsData.write(to: workoutsURL)
        try categoriesData.write(to: categoriesURL)
        try subcategoriesData.write(to: subcategoriesURL)
        
        // Create CKAssets
        let workoutsAsset = CKAsset(fileURL: workoutsURL)
        let categoriesAsset = CKAsset(fileURL: categoriesURL)
        let subcategoriesAsset = CKAsset(fileURL: subcategoriesURL)
        
        backupRecord["workouts"] = workoutsAsset
        backupRecord["categories"] = categoriesAsset
        backupRecord["subcategories"] = subcategoriesAsset
        
        // Save to CloudKit with detailed error handling
        do {
            try await privateDatabase.save(backupRecord)
            print("[CloudKit] Successfully saved backup record")
        } catch let error as CKError {
            print("[CloudKit] Detailed error information:")
            print("- Error code: \(error.code.rawValue)")
            print("- Error description: \(error.localizedDescription)")
            print("- Server record: \(String(describing: error.serverRecord))")
            print("- Client record: \(String(describing: error.clientRecord))")
            print("- Retry after: \(String(describing: error.retryAfterSeconds))")
            
            switch error.code {
            case .unknownItem:
                print("[CloudKit] Schema deployment might not be complete yet")
            case .serverRecordChanged:
                print("[CloudKit] Server record was changed")
            case .zoneNotFound:
                print("[CloudKit] Zone not found")
            case .networkFailure, .networkUnavailable:
                print("[CloudKit] Network issue")
            case .notAuthenticated:
                print("[CloudKit] Not authenticated with iCloud")
            case .permissionFailure:
                print("[CloudKit] Permission issue")
            case .quotaExceeded:
                print("[CloudKit] Quota exceeded")
            default:
                print("[CloudKit] Other CloudKit error")
            }
            throw error
        }
        
        // Clean up temporary files
        try? FileManager.default.removeItem(at: workoutsURL)
        try? FileManager.default.removeItem(at: categoriesURL)
        try? FileManager.default.removeItem(at: subcategoriesURL)
    }
    
    // MARK: - Restore Operations
    
    func fetchAvailableBackups() async throws -> [BackupInfo] {
        print("[CloudKit] Fetching available backups")
        let query = CKQuery(recordType: "Backup", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let (results, _) = try await privateDatabase.records(matching: query)
        print("[CloudKit] Found \(results.count) backup records")
        var backups: [BackupInfo] = []
        
        for (_, result) in results {
            switch result {
            case .success(let record):
                print("[CloudKit] Successfully fetched backup record: \(record.recordID.recordName)")
                if let timestamp = record["timestamp"] as? Date,
                   let deviceName = record["deviceName"] as? String,
                   let workoutCount = record["workoutCount"] as? Int,
                   let categoryCount = record["categoryCount"] as? Int,
                   let subcategoryCount = record["subcategoryCount"] as? Int,
                   let assignedSubcategoryCount = record["assignedSubcategoryCount"] as? Int {
                    let backupInfo = BackupInfo(
                        recordID: record.recordID,
                        timestamp: timestamp,
                        deviceName: deviceName,
                        workoutCount: workoutCount,
                        categoryCount: categoryCount,
                        subcategoryCount: subcategoryCount,
                        assignedSubcategoryCount: assignedSubcategoryCount
                    )
                    backups.append(backupInfo)
                    print("[CloudKit] Added backup from \(deviceName) with \(workoutCount) workouts")
                } else {
                    print("[CloudKit] Failed to parse backup record: \(record.recordID.recordName)")
                }
            case .failure(let error):
                print("[CloudKit] Error fetching backup record: \(error)")
            }
        }
        
        print("[CloudKit] Returning \(backups.count) valid backups")
        return backups
    }
    
    func restoreFromCloud(backupInfo: BackupInfo, context: ModelContext) async throws {
        let record = try await privateDatabase.record(for: backupInfo.recordID)
        
        // Download assets
        guard let workoutsAsset = record["workouts"] as? CKAsset,
              let categoriesAsset = record["categories"] as? CKAsset,
              let subcategoriesAsset = record["subcategories"] as? CKAsset,
              let workoutsURL = workoutsAsset.fileURL,
              let categoriesURL = categoriesAsset.fileURL,
              let subcategoriesURL = subcategoriesAsset.fileURL else {
            throw CloudKitError.invalidBackupData
        }
        
        // Read data
        let workoutsData = try Data(contentsOf: workoutsURL)
        let categoriesData = try Data(contentsOf: categoriesURL)
        let subcategoriesData = try Data(contentsOf: subcategoriesURL)
        
        // Decode data
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let workoutExports = try decoder.decode([WorkoutExport].self, from: workoutsData)
        let categoryExports = try decoder.decode([WorkoutCategoryExport].self, from: categoriesData)
        let subcategoryExports = try decoder.decode([WorkoutSubcategoryExport].self, from: subcategoriesData)
        
        // Create a fresh context for the restore operation
        let container = context.container
        let restoreContext = ModelContext(container)
        
        // Get existing data
        let existingWorkouts = try restoreContext.fetch(FetchDescriptor<Workout>())
        let existingCategories = try restoreContext.fetch(FetchDescriptor<WorkoutCategory>())
        let existingSubcategories = try restoreContext.fetch(FetchDescriptor<WorkoutSubcategory>())
        
        // Delete existing data
        for workout in existingWorkouts {
            restoreContext.delete(workout)
        }
        for category in existingCategories {
            restoreContext.delete(category)
        }
        for subcategory in existingSubcategories {
            restoreContext.delete(subcategory)
        }
        
        // Import categories first
        var categoryMap: [UUID: WorkoutCategory] = [:]
        for categoryExport in categoryExports {
            let category = WorkoutCategory(name: categoryExport.name, color: categoryExport.color, workoutType: categoryExport.workoutType)
            category.id = categoryExport.id
            categoryMap[categoryExport.id] = category
            restoreContext.insert(category)
        }
        
        // Import subcategories second
        var subcategoryMap: [UUID: WorkoutSubcategory] = [:]
        for subcategoryExport in subcategoryExports {
            let subcategory = WorkoutSubcategory(name: subcategoryExport.name)
            subcategory.id = subcategoryExport.id
            subcategoryMap[subcategoryExport.id] = subcategory
            restoreContext.insert(subcategory)
        }
        
        // Import workouts
        var workoutMap: [UUID: Workout] = [:]
        for workoutExport in workoutExports {
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
            restoreContext.insert(workout)
        }
        
        // Save all objects first
        try restoreContext.save()
        
        // Restore relationships
        for workoutExport in workoutExports {
            guard let workout = workoutMap[workoutExport.id] else { continue }
            
            if let categoryIds = workoutExport.categoryIds {
                let categories = categoryIds.compactMap { categoryMap[$0] }
                for category in categories {
                    workout.addCategory(category)
                }
            }
            
            if let subcategoryIds = workoutExport.subcategoryIds {
                let subcategories = subcategoryIds.compactMap { subcategoryMap[$0] }
                for subcategory in subcategories {
                    workout.addSubcategory(subcategory)
                }
            }
        }
        
        try restoreContext.save()
    }
    
    // MARK: - Status Check
    
    func checkCloudStatus() async throws -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            throw CloudKitError.accountStatusCheckFailed(error)
        }
    }
}

// MARK: - Models

struct BackupInfo: Identifiable {
    var id: String { recordID.recordName }
    let recordID: CKRecord.ID
    let timestamp: Date
    let deviceName: String
    let workoutCount: Int
    let categoryCount: Int
    let subcategoryCount: Int
    let assignedSubcategoryCount: Int
}

// MARK: - Error Types

enum CloudKitError: Error {
    case noBackupFound
    case invalidBackupData
    case accountStatusCheckFailed(Error)
    
    var localizedDescription: String {
        switch self {
        case .noBackupFound:
            return "No backup found in iCloud"
        case .invalidBackupData:
            return "Invalid backup data in iCloud"
        case .accountStatusCheckFailed(let error):
            return "Failed to check iCloud status: \(error.localizedDescription)"
        }
    }
} 

