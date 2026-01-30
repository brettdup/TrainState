import Foundation
import CloudKit
import SwiftData
import UIKit

class CloudKitManager {
    static let shared = CloudKitManager()
    
    // Debug properties
    @Published var isLoading = false
    @Published var debugMessage = ""
    
    var debugCallback: ((String) -> Void)?
    
    // CloudKit container and database
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    init() {
        // Try to get bundle identifier for container
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            print("[CloudKit] Initializing with bundle identifier: \(bundleIdentifier)")
            container = CKContainer(identifier: "iCloud.\(bundleIdentifier)")
        } else {
            print("[CloudKit] No bundle identifier found, using default container")
            container = CKContainer.default()
        }
        
        privateDatabase = container.privateCloudDatabase
    }
    
    // MARK: - State Management
    
    private func setSyncState(_ syncing: Bool) {
        DispatchQueue.main.async {
            self.isLoading = syncing
        }
    }
    
    private func updateDebug(_ message: String) {
        DispatchQueue.main.async {
            self.debugMessage = message
            self.debugCallback?(message)
        }
    }
    
    // MARK: - Backup/Restore

    func backupToCloud(context: ModelContext) async throws {
        setSyncState(true)
        defer { setSyncState(false) }

        let status = try await container.accountStatus()
        guard status == .available else {
            throw NSError(domain: "CloudKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud account is not available."])
        }

        updateDebug("Preparing backup...")
        let payload = try exportPayload(context: context)
        let data = try JSONEncoder.iso8601.encode(payload)

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("TrainState-Backup-\(UUID().uuidString).json")
        try data.write(to: tempURL, options: [.atomic])
        let asset = CKAsset(fileURL: tempURL)

        let record = CKRecord(recordType: "Backup")
        record["name"] = "Backup \(Date().formatted(date: .abbreviated, time: .shortened))" as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue
        record["deviceName"] = UIDevice.current.name as CKRecordValue
        record["workoutCount"] = payload.workouts.count as CKRecordValue
        record["categoryCount"] = payload.categories.count as CKRecordValue
        record["subcategoryCount"] = payload.subcategories.count as CKRecordValue
        record["assignedSubcategoryCount"] = payload.subcategories.filter { $0.categoryId != nil }.count as CKRecordValue
        record["archive"] = asset

        updateDebug("Uploading to iCloud...")
        _ = try await privateDatabase.save(record)

        try? FileManager.default.removeItem(at: tempURL)
        updateDebug("Backup complete.")
    }
    
    func fetchAvailableBackups() async throws -> [BackupInfo] {
        let status = try await container.accountStatus()
        guard status == .available else {
            throw NSError(domain: "CloudKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud account is not available."])
        }

        let query = CKQuery(recordType: "Backup", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        let result = try await privateDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }

        return records.compactMap { record in
            guard
                let name = record["name"] as? String,
                let date = record["timestamp"] as? Date,
                let workoutCount = record["workoutCount"] as? Int,
                let categoryCount = record["categoryCount"] as? Int,
                let subcategoryCount = record["subcategoryCount"] as? Int
            else { return nil }

            let deviceName = (record["deviceName"] as? String) ?? "Device"
            let assignedSubcategoryCount = (record["assignedSubcategoryCount"] as? Int) ?? 0

            return BackupInfo(
                id: record.recordID.recordName,
                name: name,
                date: date,
                workoutCount: workoutCount,
                categoryCount: categoryCount,
                subcategoryCount: subcategoryCount,
                recordName: record.recordID.recordName,
                deviceName: deviceName,
                timestamp: date,
                assignedSubcategoryCount: assignedSubcategoryCount
            )
        }
    }
    
    func restoreFromCloud(backupInfo: BackupInfo, context: ModelContext) async throws {
        setSyncState(true)
        defer { setSyncState(false) }

        let status = try await container.accountStatus()
        guard status == .available else {
            throw NSError(domain: "CloudKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud account is not available."])
        }

        updateDebug("Fetching backup...")
        let recordID = CKRecord.ID(recordName: backupInfo.recordName)
        let record = try await privateDatabase.record(for: recordID)
        guard let asset = record["archive"] as? CKAsset, let fileURL = asset.fileURL else {
            throw NSError(domain: "CloudKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Backup data missing."])
        }

        updateDebug("Restoring data...")
        let data = try Data(contentsOf: fileURL)
        let payload = try JSONDecoder.iso8601.decode(BackupPayload.self, from: data)
        try restorePayload(payload, context: context)
        updateDebug("Restore complete.")
    }
    
    func checkCloudStatus() async throws -> CKAccountStatus {
        return try await container.accountStatus()
    }
    
    func deleteBackups(_ backups: [BackupInfo]) async throws -> [BackupInfo] {
        let recordIDs = backups.map { CKRecord.ID(recordName: $0.recordName) }
        _ = try await privateDatabase.modifyRecords(saving: [], deleting: recordIDs)
        return backups
    }
}

private struct BackupPayload: Codable {
    let workouts: [WorkoutExport]
    let categories: [WorkoutCategoryExport]
    let subcategories: [WorkoutSubcategoryExport]
}

private extension CloudKitManager {
    func exportPayload(context: ModelContext) throws -> BackupPayload {
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let categories = try context.fetch(FetchDescriptor<WorkoutCategory>())
        let subcategories = try context.fetch(FetchDescriptor<WorkoutSubcategory>())
        return BackupPayload(
            workouts: workouts.map(WorkoutExport.init),
            categories: categories.map(WorkoutCategoryExport.init),
            subcategories: subcategories.map(WorkoutSubcategoryExport.init)
        )
    }

    func restorePayload(_ payload: BackupPayload, context: ModelContext) throws {
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let categories = try context.fetch(FetchDescriptor<WorkoutCategory>())
        let subcategories = try context.fetch(FetchDescriptor<WorkoutSubcategory>())

        workouts.forEach { context.delete($0) }
        categories.forEach { context.delete($0) }
        subcategories.forEach { context.delete($0) }
        try context.save()

        var categoryMap: [UUID: WorkoutCategory] = [:]
        for export in payload.categories {
            let category = WorkoutCategory(name: export.name, color: export.color, workoutType: export.workoutType)
            category.id = export.id
            context.insert(category)
            categoryMap[export.id] = category
        }

        var subcategoryMap: [UUID: WorkoutSubcategory] = [:]
        for export in payload.subcategories {
            guard let categoryId = export.categoryId, let category = categoryMap[categoryId] else { continue }
            let subcategory = WorkoutSubcategory(name: export.name, category: category)
            subcategory.id = export.id
            context.insert(subcategory)
            subcategoryMap[export.id] = subcategory
        }

        for export in payload.workouts {
            let workout = Workout(
                type: export.type,
                startDate: export.startDate,
                duration: export.duration,
                calories: export.calories,
                distance: export.distance,
                notes: export.notes,
                categories: export.categoryIds?.compactMap { categoryMap[$0] },
                subcategories: export.subcategoryIds?.compactMap { subcategoryMap[$0] },
                hkActivityTypeRaw: export.hkActivityTypeRaw
            )
            workout.id = export.id
            workout.hkUUID = export.hkUUID
            context.insert(workout)
        }

        try context.save()
    }
}

private extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - Data Models (kept for compatibility)

struct BackupInfo: Identifiable, Codable {
    let id: String
    let name: String
    let date: Date
    let workoutCount: Int
    let categoryCount: Int
    let subcategoryCount: Int
    let recordName: String
    // Add missing properties for SettingsView
    let deviceName: String
    let timestamp: Date
    let assignedSubcategoryCount: Int
    
    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

// Note: WorkoutExport, WorkoutCategoryExport, and WorkoutSubcategoryExport 
// are defined in Workout.swift to avoid duplication
