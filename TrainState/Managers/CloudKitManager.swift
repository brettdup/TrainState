import Foundation
import CloudKit
import SwiftData
import UIKit
import os.log

class CloudKitManager {
    static let shared = CloudKitManager()
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    // Debug callback to update UI
    var debugCallback: ((String) -> Void)?
    
    private init() {
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            print("[CloudKit] Initializing with bundle identifier: \(bundleIdentifier)")
            container = CKContainer(identifier: "iCloud.\(bundleIdentifier)")
        } else {
            print("[CloudKit] No bundle identifier found, using default container")
            container = CKContainer.default()
        }
        privateDatabase = container.privateCloudDatabase
        
        // Log environment info for debugging
        #if DEBUG
        print("[CloudKit] Running in DEBUG mode - likely using Sandbox")
        #else
        print("[CloudKit] Running in RELEASE mode - likely using Production")
        #endif
        
        // Check if running from TestFlight
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            print("[CloudKit] Detected TestFlight/Sandbox receipt")
        } else {
            print("[CloudKit] Detected App Store/Production receipt")
        }
    }
    
    // MARK: - Debug Helper
    
    private func updateDebug(_ message: String) {
        print(message)
        DispatchQueue.main.async {
            self.debugCallback?(message)
        }
    }
    
    // MARK: - Backup Operations
    
    func backupToCloud(context: ModelContext) async throws {
        let environment = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "TestFlight/Sandbox" : "App Store/Production"
        
        updateDebug("Environment: \(environment)\nStatus: Starting backup...\nContainer: \(container.containerIdentifier ?? "unknown")")
        
        print("[CloudKit] Starting backup to cloud")
        
        // MARK: - Fetch and Export Data on MainActor
        let (workoutExports, categoryExports, subcategoryExports) = try await MainActor.run {
            print("[CloudKit] Fetching data on MainActor")
            
            // Fetch all data with prefetched relationships
            var workoutDescriptor = FetchDescriptor<Workout>()
            workoutDescriptor.relationshipKeyPathsForPrefetching = [\.categories, \.subcategories]
            
            var subcategoryDescriptor = FetchDescriptor<WorkoutSubcategory>()
            subcategoryDescriptor.relationshipKeyPathsForPrefetching = [\.workouts]
            
            // Perform all fetches
            let workouts = try context.fetch(workoutDescriptor)
            let categories = try context.fetch(FetchDescriptor<WorkoutCategory>())
            let subcategories = try context.fetch(subcategoryDescriptor)
            
            print("[CloudKit] Fetched data - Workouts: \(workouts.count), Categories: \(categories.count), Subcategories: \(subcategories.count)")
            
            updateDebug("Environment: \(environment)\nStatus: Data fetched ✅\nWorkouts: \(workouts.count)\nCategories: \(categories.count)\nSubcategories: \(subcategories.count)")
            
            // Immediately convert to export models to avoid holding SwiftData references
            let workoutExports = workouts.map { WorkoutExport(from: $0) }
            let categoryExports = categories.map { WorkoutCategoryExport(from: $0) }
            let subcategoryExports = subcategories.map { WorkoutSubcategoryExport(from: $0) }
            
            return (workoutExports, categoryExports, subcategoryExports)
        }
        
        // MARK: - Create CloudKit Record
        let timestamp = Date()
        let backupID = CKRecord.ID(recordName: "Backup_\(timestamp.timeIntervalSince1970)")
        let backupRecord = CKRecord(recordType: "Backup", recordID: backupID)
        
        // Add metadata
        backupRecord["timestamp"] = timestamp
        backupRecord["deviceName"] = UIDevice.current.name
        backupRecord["workoutCount"] = workoutExports.count
        backupRecord["categoryCount"] = categoryExports.count
        backupRecord["subcategoryCount"] = subcategoryExports.count
        backupRecord["assignedSubcategoryCount"] = subcategoryExports.filter { $0.id != UUID() }.count
        
        // MARK: - Encode Data
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let workoutsData: Data
        let categoriesData: Data
        let subcategoriesData: Data
        
        do {
            workoutsData = try encoder.encode(workoutExports)
            categoriesData = try encoder.encode(categoryExports)
            subcategoriesData = try encoder.encode(subcategoryExports)
        } catch {
            print("[CloudKit] ❌ Failed to encode data: \(error)")
            throw CloudKitError.invalidBackupData
        }
        
        // MARK: - Create Temporary Files
        let tempDir = FileManager.default.temporaryDirectory
        let workoutsURL = tempDir.appendingPathComponent("workouts_\(UUID().uuidString).json")
        let categoriesURL = tempDir.appendingPathComponent("categories_\(UUID().uuidString).json")
        let subcategoriesURL = tempDir.appendingPathComponent("subcategories_\(UUID().uuidString).json")
        
        // Use defer to ensure cleanup
        defer {
            try? FileManager.default.removeItem(at: workoutsURL)
            try? FileManager.default.removeItem(at: categoriesURL)
            try? FileManager.default.removeItem(at: subcategoriesURL)
        }
        
        do {
            try workoutsData.write(to: workoutsURL)
            try categoriesData.write(to: categoriesURL)
            try subcategoriesData.write(to: subcategoriesURL)
        } catch {
            print("[CloudKit] ❌ Failed to write temporary files: \(error)")
            throw CloudKitError.invalidBackupData
        }
        
        // Create CKAssets
        let workoutsAsset = CKAsset(fileURL: workoutsURL)
        let categoriesAsset = CKAsset(fileURL: categoriesURL)
        let subcategoriesAsset = CKAsset(fileURL: subcategoriesURL)
        
        backupRecord["workouts"] = workoutsAsset
        backupRecord["categories"] = categoriesAsset
        backupRecord["subcategories"] = subcategoriesAsset
        
        updateDebug("Environment: \(environment)\nStatus: Record prepared ✅\nSaving to CloudKit...\nRecord type: Backup")
        
        // MARK: - Save to CloudKit
        do {
            try await privateDatabase.save(backupRecord)
            print("[CloudKit] ✅ Successfully saved backup record")
            updateDebug("Environment: \(environment)\nStatus: BACKUP SUCCESS ✅\nRecord saved to CloudKit\nRecord ID: \(backupID.recordName)")
        } catch let error as CKError {
            print("[CloudKit] ❌ CloudKit error:")
            print("- Error code: \(error.code.rawValue)")
            print("- Error description: \(error.localizedDescription)")
            
            updateDebug("Environment: \(environment)\nStatus: BACKUP ERROR ❌\nCode: \(error.code.rawValue)\nError: \(error.localizedDescription)")
            
            switch error.code {
            case .unknownItem:
                print("[CloudKit] Schema deployment might not be complete yet")
                throw CloudKitError.schemaNotDeployed
            case .notAuthenticated:
                throw CloudKitError.notAuthenticated
            case .networkFailure, .networkUnavailable:
                throw CloudKitError.networkUnavailable
            case .zoneNotFound:
                throw CloudKitError.zoneNotFound
            default:
                throw CloudKitError.queryFailed(error)
            }
        }
    }
    
    // MARK: - Restore Operations
    
    func fetchAvailableBackups() async throws -> [BackupInfo] {
        let environment = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "TestFlight/Sandbox" : "App Store/Production"
        
        updateDebug("Environment: \(environment)\nStatus: Starting backup fetch...\nContainer: \(container.containerIdentifier ?? "unknown")")
        
        print("[CloudKit] Fetching available backups")
        print("[CloudKit] Container: \(container.containerIdentifier ?? "unknown")")
        print("[CloudKit] Database: \(privateDatabase)")
        
        // Force logging that will appear in device logs
        NSLog("[CloudKit] Fetching backups - Container: %@", container.containerIdentifier ?? "unknown")
        os_log("[CloudKit] Starting backup fetch process", log: OSLog.default, type: .default)
        
        updateDebug("Environment: \(environment)\nStatus: Checking iCloud account...\nContainer: \(container.containerIdentifier ?? "unknown")")
        
        // First check if we're signed into iCloud
        let accountStatus = try await container.accountStatus()
        guard accountStatus == .available else {
            print("[CloudKit] ❌ iCloud account not available. Status: \(accountStatus)")
            updateDebug("Environment: \(environment)\nStatus: ERROR ❌\nIssue: iCloud account not available\nAccount Status: \(accountStatus.rawValue)")
            throw CloudKitError.accountNotAvailable(accountStatus)
        }
        
        updateDebug("Environment: \(environment)\nStatus: iCloud account available ✅\nCreating CloudKit query...\nContainer: \(container.containerIdentifier ?? "unknown")")
        
        // Use a field-based predicate since schema shows timestamp is queryable
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date.distantPast
        let predicate = NSPredicate(format: "timestamp > %@", oneYearAgo as NSDate)
        let query = CKQuery(recordType: "Backup", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        print("[CloudKit] Query: \(query) with predicate: \(predicate)")
        
        updateDebug("Environment: \(environment)\nStatus: Executing CloudKit query...\nQuery: Backup records > 1 year ago\nContainer: \(container.containerIdentifier ?? "unknown")")
        
        do {
            let (results, _) = try await privateDatabase.records(matching: query)
            print("[CloudKit] Query executed successfully")
            print("[CloudKit] Found \(results.count) backup records")
            
            updateDebug("Environment: \(environment)\nStatus: Query successful ✅\nFound: \(results.count) backup records\nContainer: \(container.containerIdentifier ?? "unknown")")
            
            if results.isEmpty {
                print("[CloudKit] ⚠️ No backup records found in this environment")
                print("[CloudKit] This could mean:")
                print("[CloudKit] - No backups have been created in Production environment")
                print("[CloudKit] - Backups exist only in Sandbox environment")
                print("[CloudKit] - Different iCloud account being used")
                
                updateDebug("Environment: \(environment)\nStatus: No backups found ⚠️\nPossible causes:\n• No backups in \(environment)\n• Different iCloud account\n• Schema issue")
            }
            
            var backups: [BackupInfo] = []
            
            for (recordID, result) in results {
                switch result {
                case .success(let record):
                    print("[CloudKit] ✅ Record fetched: \(recordID.recordName)")
                    
                    // Validate all required fields exist
                    guard let timestamp = record["timestamp"] as? Date else {
                        print("[CloudKit] ❌ Missing timestamp in record: \(recordID.recordName)")
                        continue
                    }
                    guard let deviceName = record["deviceName"] as? String else {
                        print("[CloudKit] ❌ Missing deviceName in record: \(recordID.recordName)")
                        continue
                    }
                    guard let workoutCount = record["workoutCount"] as? Int else {
                        print("[CloudKit] ❌ Missing workoutCount in record: \(recordID.recordName)")
                        continue
                    }
                    guard let categoryCount = record["categoryCount"] as? Int else {
                        print("[CloudKit] ❌ Missing categoryCount in record: \(recordID.recordName)")
                        continue
                    }
                    guard let subcategoryCount = record["subcategoryCount"] as? Int else {
                        print("[CloudKit] ❌ Missing subcategoryCount in record: \(recordID.recordName)")
                        continue
                    }
                    guard let assignedSubcategoryCount = record["assignedSubcategoryCount"] as? Int else {
                        print("[CloudKit] ❌ Missing assignedSubcategoryCount in record: \(recordID.recordName)")
                        continue
                    }
                    
                    // Validate that assets exist
                    guard record["workouts"] as? CKAsset != nil,
                          record["categories"] as? CKAsset != nil,
                          record["subcategories"] as? CKAsset != nil else {
                        print("[CloudKit] ❌ Missing required assets in record: \(recordID.recordName)")
                        continue
                    }
                    
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
                    print("[CloudKit] ✅ Added backup from \(deviceName) with \(workoutCount) workouts at \(timestamp)")
                    
                case .failure(let error):
                    print("[CloudKit] ❌ Record fetch error for \(recordID.recordName): \(error)")
                    if let ckError = error as? CKError {
                        print("[CloudKit] CloudKit error code: \(ckError.code.rawValue)")
                    }
                }
            }
            
            // Sort backups manually by timestamp (most recent first)
            let sortedBackups = backups.sorted { $0.timestamp > $1.timestamp }
            
            print("[CloudKit] ✅ Returning \(sortedBackups.count) valid backups")
            
            if sortedBackups.isEmpty {
                updateDebug("Environment: \(environment)\nStatus: No valid backups ⚠️\nFound \(results.count) records but none were valid\nContainer: \(container.containerIdentifier ?? "unknown")")
            } else {
                updateDebug("Environment: \(environment)\nStatus: SUCCESS ✅\nValid backups: \(sortedBackups.count)\nLatest: \(sortedBackups.first?.timestamp.formatted() ?? "N/A")")
            }
            
            return sortedBackups
            
        } catch let error as CKError {
            print("[CloudKit] ❌ CloudKit query failed:")
            print("- Error code: \(error.code.rawValue)")
            print("- Error description: \(error.localizedDescription)")
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? Error {
                print("- Underlying error: \(underlyingError.localizedDescription)")
            }
            
            updateDebug("Environment: \(environment)\nStatus: CloudKit ERROR ❌\nCode: \(error.code.rawValue)\nError: \(error.localizedDescription)\nContainer: \(container.containerIdentifier ?? "unknown")")
            
            switch error.code {
            case .notAuthenticated:
                throw CloudKitError.notAuthenticated
            case .networkFailure, .networkUnavailable:
                throw CloudKitError.networkUnavailable
            case .zoneNotFound:
                throw CloudKitError.zoneNotFound
            case .unknownItem:
                print("[CloudKit] Unknown item - Schema likely not deployed to current environment")
                print("[CloudKit] If this is TestFlight, ensure schema is deployed to PRODUCTION")
                let debugError = CloudKitError.queryFailed(NSError(domain: "CloudKitDebug", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "Schema not deployed to \(environment) environment. Error code: \(error.code.rawValue)"
                ]))
                throw debugError
            case .invalidArguments:
                print("[CloudKit] Invalid arguments - trying alternative fetch method...")
                print("[CloudKit] This may indicate schema mismatch between environments")
                // Try a completely different approach
                return try await fetchBackupsAlternativeMethod()
            default:
                let debugError = CloudKitError.queryFailed(NSError(domain: "CloudKitDebug", code: Int(error.code.rawValue), userInfo: [
                    NSLocalizedDescriptionKey: "CloudKit error in \(environment): \(error.localizedDescription) (Code: \(error.code.rawValue))"
                ]))
                throw debugError
            }
        } catch {
            print("[CloudKit] ❌ Unexpected error during query: \(error)")
            throw CloudKitError.queryFailed(error)
        }
    }
    
    private func fetchBackupsWithoutSorting() async throws -> [BackupInfo] {
        print("[CloudKit] Fetching backups without sorting (fallback)")
        
        let query = CKQuery(recordType: "Backup", predicate: NSPredicate(value: true))
        // No sort descriptors to avoid queryable field issues
        
        do {
            let (results, _) = try await privateDatabase.records(matching: query)
            print("[CloudKit] Found \(results.count) backup records (no sorting)")
            
            var backups: [BackupInfo] = []
            
            for (recordID, result) in results {
                switch result {
                case .success(let record):
                    print("[CloudKit] ✅ Record fetched: \(recordID.recordName)")
                    
                    // Validate all required fields exist
                    guard let timestamp = record["timestamp"] as? Date else {
                        print("[CloudKit] ❌ Missing timestamp in record: \(recordID.recordName)")
                        continue
                    }
                    guard let deviceName = record["deviceName"] as? String else {
                        print("[CloudKit] ❌ Missing deviceName in record: \(recordID.recordName)")
                        continue
                    }
                    guard let workoutCount = record["workoutCount"] as? Int else {
                        print("[CloudKit] ❌ Missing workoutCount in record: \(recordID.recordName)")
                        continue
                    }
                    guard let categoryCount = record["categoryCount"] as? Int else {
                        print("[CloudKit] ❌ Missing categoryCount in record: \(recordID.recordName)")
                        continue
                    }
                    guard let subcategoryCount = record["subcategoryCount"] as? Int else {
                        print("[CloudKit] ❌ Missing subcategoryCount in record: \(recordID.recordName)")
                        continue
                    }
                    guard let assignedSubcategoryCount = record["assignedSubcategoryCount"] as? Int else {
                        print("[CloudKit] ❌ Missing assignedSubcategoryCount in record: \(recordID.recordName)")
                        continue
                    }
                    
                    // Validate that assets exist
                    guard record["workouts"] as? CKAsset != nil,
                          record["categories"] as? CKAsset != nil,
                          record["subcategories"] as? CKAsset != nil else {
                        print("[CloudKit] ❌ Missing required assets in record: \(recordID.recordName)")
                        continue
                    }
                    
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
                    print("[CloudKit] ✅ Added backup from \(deviceName) with \(workoutCount) workouts at \(timestamp)")
                    
                case .failure(let error):
                    print("[CloudKit] ❌ Record fetch error for \(recordID.recordName): \(error)")
                }
            }
            
            // Sort backups manually by timestamp (most recent first)
            let sortedBackups = backups.sorted { $0.timestamp > $1.timestamp }
            
            print("[CloudKit] ✅ Returning \(sortedBackups.count) valid backups (manually sorted)")
            return sortedBackups
            
        } catch {
            print("[CloudKit] ❌ Fallback query also failed: \(error)")
            throw CloudKitError.queryFailed(error)
        }
    }
    
    private func fetchBackupsAlternativeMethod() async throws -> [BackupInfo] {
        print("[CloudKit] Using alternative fetch method (zone scan)")
        
        do {
            // Try using the zone's default record scanning approach
            let query = CKQuery(recordType: "Backup", predicate: NSPredicate(value: true))
            // Don't add sort descriptors - let CloudKit return unsorted results
            
            // Use query operation instead of records(matching:)
            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = 100
            
            var backups: [BackupInfo] = []
            var fetchError: Error?
            
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    print("[CloudKit] ✅ Record matched: \(recordID.recordName)")
                    
                    // Validate all required fields exist
                    guard let timestamp = record["timestamp"] as? Date,
                          let deviceName = record["deviceName"] as? String,
                          let workoutCount = record["workoutCount"] as? Int,
                          let categoryCount = record["categoryCount"] as? Int,
                          let subcategoryCount = record["subcategoryCount"] as? Int,
                          let assignedSubcategoryCount = record["assignedSubcategoryCount"] as? Int,
                          record["workouts"] as? CKAsset != nil,
                          record["categories"] as? CKAsset != nil,
                          record["subcategories"] as? CKAsset != nil else {
                        print("[CloudKit] ❌ Invalid record data: \(recordID.recordName)")
                        return
                    }
                    
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
                    print("[CloudKit] ✅ Added backup from \(deviceName) with \(workoutCount) workouts")
                    
                case .failure(let error):
                    print("[CloudKit] ❌ Record match error for \(recordID.recordName): \(error)")
                }
            }
            
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    print("[CloudKit] ✅ Query operation completed successfully")
                case .failure(let error):
                    print("[CloudKit] ❌ Query operation failed: \(error)")
                    fetchError = error
                }
            }
            
            privateDatabase.add(operation)
            
            // Wait for operation to complete
            return try await withCheckedThrowingContinuation { continuation in
                operation.completionBlock = {
                    if let error = fetchError {
                        continuation.resume(throwing: error)
                    } else {
                        // Sort backups manually by timestamp (most recent first)
                        let sortedBackups = backups.sorted { $0.timestamp > $1.timestamp }
                        print("[CloudKit] ✅ Alternative method found \(sortedBackups.count) backups")
                        continuation.resume(returning: sortedBackups)
                    }
                }
            }
            
        } catch {
            print("[CloudKit] ❌ Alternative method also failed: \(error)")
            throw CloudKitError.queryFailed(error)
        }
    }
    
    func restoreFromCloud(backupInfo: BackupInfo, context: ModelContext) async throws {
        print("[CloudKit] Starting restore from backup: \(backupInfo.recordID.recordName)")
        
        do {
            // Fetch the backup record
            let record = try await privateDatabase.record(for: backupInfo.recordID)
            print("[CloudKit] ✅ Retrieved backup record")
            
            // Download and validate assets
            guard let workoutsAsset = record["workouts"] as? CKAsset else {
                print("[CloudKit] ❌ Missing workouts asset")
                throw CloudKitError.invalidBackupData
            }
            guard let categoriesAsset = record["categories"] as? CKAsset else {
                print("[CloudKit] ❌ Missing categories asset")
                throw CloudKitError.invalidBackupData
            }
            guard let subcategoriesAsset = record["subcategories"] as? CKAsset else {
                print("[CloudKit] ❌ Missing subcategories asset")
                throw CloudKitError.invalidBackupData
            }
            
            guard let workoutsURL = workoutsAsset.fileURL else {
                print("[CloudKit] ❌ Invalid workouts asset URL")
                throw CloudKitError.invalidBackupData
            }
            guard let categoriesURL = categoriesAsset.fileURL else {
                print("[CloudKit] ❌ Invalid categories asset URL")
                throw CloudKitError.invalidBackupData
            }
            guard let subcategoriesURL = subcategoriesAsset.fileURL else {
                print("[CloudKit] ❌ Invalid subcategories asset URL")
                throw CloudKitError.invalidBackupData
            }
            
            print("[CloudKit] ✅ All asset URLs validated")
            
            // Read data from files
            let workoutsData: Data
            let categoriesData: Data
            let subcategoriesData: Data
            
            do {
                workoutsData = try Data(contentsOf: workoutsURL)
                print("[CloudKit] ✅ Read workouts data: \(workoutsData.count) bytes")
            } catch {
                print("[CloudKit] ❌ Failed to read workouts data: \(error)")
                throw CloudKitError.invalidBackupData
            }
            
            do {
                categoriesData = try Data(contentsOf: categoriesURL)
                print("[CloudKit] ✅ Read categories data: \(categoriesData.count) bytes")
            } catch {
                print("[CloudKit] ❌ Failed to read categories data: \(error)")
                throw CloudKitError.invalidBackupData
            }
            
            do {
                subcategoriesData = try Data(contentsOf: subcategoriesURL)
                print("[CloudKit] ✅ Read subcategories data: \(subcategoriesData.count) bytes")
            } catch {
                print("[CloudKit] ❌ Failed to read subcategories data: \(error)")
                throw CloudKitError.invalidBackupData
            }
            
            // Decode data
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let workoutExports: [WorkoutExport]
            let categoryExports: [WorkoutCategoryExport]
            let subcategoryExports: [WorkoutSubcategoryExport]
            
            do {
                workoutExports = try decoder.decode([WorkoutExport].self, from: workoutsData)
                print("[CloudKit] ✅ Decoded \(workoutExports.count) workout exports")
            } catch {
                print("[CloudKit] ❌ Failed to decode workouts: \(error)")
                throw CloudKitError.invalidBackupData
            }
            
            do {
                categoryExports = try decoder.decode([WorkoutCategoryExport].self, from: categoriesData)
                print("[CloudKit] ✅ Decoded \(categoryExports.count) category exports")
            } catch {
                print("[CloudKit] ❌ Failed to decode categories: \(error)")
                throw CloudKitError.invalidBackupData
            }
            
            do {
                subcategoryExports = try decoder.decode([WorkoutSubcategoryExport].self, from: subcategoriesData)
                print("[CloudKit] ✅ Decoded \(subcategoryExports.count) subcategory exports")
            } catch {
                print("[CloudKit] ❌ Failed to decode subcategories: \(error)")
                throw CloudKitError.invalidBackupData
            }
            
            // Create a fresh context for the restore operation
            let container = context.container
            let restoreContext = ModelContext(container)
            
            // Get existing data
            let existingWorkouts = try restoreContext.fetch(FetchDescriptor<Workout>())
            let existingCategories = try restoreContext.fetch(FetchDescriptor<WorkoutCategory>())
            let existingSubcategories = try restoreContext.fetch(FetchDescriptor<WorkoutSubcategory>())
            
            print("[CloudKit] Found existing data - Workouts: \(existingWorkouts.count), Categories: \(existingCategories.count), Subcategories: \(existingSubcategories.count)")
            
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
            
            print("[CloudKit] ✅ Deleted existing data")
            
            // Import categories first
            var categoryMap: [UUID: WorkoutCategory] = [:]
            for categoryExport in categoryExports {
                let category = WorkoutCategory(name: categoryExport.name, color: categoryExport.color, workoutType: categoryExport.workoutType)
                category.id = categoryExport.id
                categoryMap[categoryExport.id] = category
                restoreContext.insert(category)
            }
            print("[CloudKit] ✅ Imported \(categoryMap.count) categories")
            
            // Import subcategories second
            var subcategoryMap: [UUID: WorkoutSubcategory] = [:]
            for subcategoryExport in subcategoryExports {
                let subcategory = WorkoutSubcategory(name: subcategoryExport.name)
                subcategory.id = subcategoryExport.id
                subcategoryMap[subcategoryExport.id] = subcategory
                restoreContext.insert(subcategory)
            }
            print("[CloudKit] ✅ Imported \(subcategoryMap.count) subcategories")
            
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
            print("[CloudKit] ✅ Imported \(workoutMap.count) workouts")
            
            // Save all objects first
            do {
                try restoreContext.save()
                print("[CloudKit] ✅ Saved all objects to context")
            } catch {
                print("[CloudKit] ❌ Failed to save objects: \(error)")
                throw CloudKitError.restoreFailed(error)
            }
            
            // Restore relationships
            var relationshipsRestored = 0
            for workoutExport in workoutExports {
                guard let workout = workoutMap[workoutExport.id] else { continue }
                
                if let categoryIds = workoutExport.categoryIds {
                    let categories = categoryIds.compactMap { categoryMap[$0] }
                    for category in categories {
                        workout.addCategory(category)
                        relationshipsRestored += 1
                    }
                }
                
                if let subcategoryIds = workoutExport.subcategoryIds {
                    let subcategories = subcategoryIds.compactMap { subcategoryMap[$0] }
                    for subcategory in subcategories {
                        workout.addSubcategory(subcategory)
                        relationshipsRestored += 1
                    }
                }
            }
            print("[CloudKit] ✅ Restored \(relationshipsRestored) relationships")
            
            // Final save
            do {
                try restoreContext.save()
                print("[CloudKit] ✅ Final save completed successfully")
                print("[CloudKit] ✅ Restore completed - Workouts: \(workoutMap.count), Categories: \(categoryMap.count), Subcategories: \(subcategoryMap.count)")
            } catch {
                print("[CloudKit] ❌ Failed to save relationships: \(error)")
                throw CloudKitError.restoreFailed(error)
            }
            
        } catch let error as CKError {
            print("[CloudKit] ❌ CloudKit error during restore:")
            print("- Error code: \(error.code.rawValue)")
            print("- Error description: \(error.localizedDescription)")
            throw CloudKitError.restoreFailed(error)
        } catch let error as CloudKitError {
            // Re-throw our custom errors
            throw error
        } catch {
            print("[CloudKit] ❌ Unexpected error during restore: \(error)")
            throw CloudKitError.restoreFailed(error)
        }
    }
    
    // MARK: - Status Check
    
    func checkCloudStatus() async throws -> Bool {
        do {
            print("[CloudKit] Checking iCloud account status...")
            let status = try await container.accountStatus()
            print("[CloudKit] iCloud account status: \(status.rawValue)")
            
            switch status {
            case .available:
                print("[CloudKit] ✅ iCloud account is available")
                return true
            case .noAccount:
                print("[CloudKit] ❌ No iCloud account configured")
                throw CloudKitError.accountNotAvailable(status)
            case .restricted:
                print("[CloudKit] ❌ iCloud account is restricted")
                throw CloudKitError.accountNotAvailable(status)
            case .couldNotDetermine:
                print("[CloudKit] ❌ Could not determine iCloud account status")
                throw CloudKitError.accountNotAvailable(status)
            case .temporarilyUnavailable:
                print("[CloudKit] ❌ iCloud account temporarily unavailable")
                throw CloudKitError.accountNotAvailable(status)
            @unknown default:
                print("[CloudKit] ❌ Unknown iCloud account status: \(status.rawValue)")
                throw CloudKitError.accountNotAvailable(status)
            }
        } catch let error as CloudKitError {
            throw error
        } catch {
            print("[CloudKit] ❌ Error checking iCloud status: \(error)")
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
    case accountNotAvailable(CKAccountStatus)
    case notAuthenticated
    case networkUnavailable
    case zoneNotFound
    case schemaNotDeployed
    case queryFailed(Error)
    case restoreFailed(Error)
    
    var localizedDescription: String {
        switch self {
        case .noBackupFound:
            return "No backup found in iCloud"
        case .invalidBackupData:
            return "Invalid backup data in iCloud"
        case .accountStatusCheckFailed(let error):
            return "Failed to check iCloud status: \(error.localizedDescription)"
        case .accountNotAvailable(let status):
            return "iCloud account not available. Status: \(status.rawValue)"
        case .notAuthenticated:
            return "Not signed in to iCloud"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .zoneNotFound:
            return "CloudKit zone not found"
        case .schemaNotDeployed:
            return "CloudKit schema not deployed"
        case .queryFailed(let error):
            return "Failed to query CloudKit: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "Failed to restore backup: \(error.localizedDescription)"
        }
    }
} 
