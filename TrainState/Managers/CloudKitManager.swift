import Foundation
import CloudKit
import SwiftData
import UIKit

class CloudKitManager {
    static let shared = CloudKitManager()

    /// Maximum number of iCloud backups to retain. Oldest backups are deleted when exceeded.
    static let maxBackupCount = 3
    
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

        updateDebug("Uploading to iCloud...")
        try await saveBackupRecord(payload: payload)

        // Enforce max backup limit: delete oldest when exceeding limit
        let allBackups = try await fetchAvailableBackups()
        if allBackups.count > Self.maxBackupCount {
            let toDelete = Array(allBackups.dropFirst(Self.maxBackupCount))
            _ = try await deleteBackups(toDelete)
        }

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

        var backups = records.compactMap { record -> BackupInfo? in
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

        // Enforce max backup limit: delete oldest when exceeding limit
        if backups.count > Self.maxBackupCount {
            let toDelete = Array(backups.dropFirst(Self.maxBackupCount))
            _ = try await deleteBackups(toDelete)
            backups = Array(backups.prefix(Self.maxBackupCount))
        }

        return backups
    }

    func fetchBackupPreview(backupInfo: BackupInfo) async throws -> BackupPreview {
        let status = try await container.accountStatus()
        guard status == .available else {
            throw NSError(domain: "CloudKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud account is not available."])
        }

        let recordID = CKRecord.ID(recordName: backupInfo.recordName)
        let record = try await privateDatabase.record(for: recordID)
        let payload = try payload(from: record)
        return BackupPreview(
            info: backupInfo,
            workouts: payload.workouts,
            categories: payload.categories,
            subcategories: payload.subcategories
        )
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

        updateDebug("Restoring data...")
        let payload = try payload(from: record)
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
    let exerciseTemplates: [SubcategoryExerciseExport]
    let strengthTemplates: [StrengthWorkoutTemplateExport]

    enum CodingKeys: String, CodingKey {
        case workouts
        case categories
        case subcategories
        case exerciseTemplates
        case strengthTemplates
    }

    init(
        workouts: [WorkoutExport],
        categories: [WorkoutCategoryExport],
        subcategories: [WorkoutSubcategoryExport],
        exerciseTemplates: [SubcategoryExerciseExport],
        strengthTemplates: [StrengthWorkoutTemplateExport]
    ) {
        self.workouts = workouts
        self.categories = categories
        self.subcategories = subcategories
        self.exerciseTemplates = exerciseTemplates
        self.strengthTemplates = strengthTemplates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workouts = try container.decode([WorkoutExport].self, forKey: .workouts)
        categories = try container.decode([WorkoutCategoryExport].self, forKey: .categories)
        subcategories = try container.decode([WorkoutSubcategoryExport].self, forKey: .subcategories)
        exerciseTemplates = try container.decodeIfPresent([SubcategoryExerciseExport].self, forKey: .exerciseTemplates) ?? []
        strengthTemplates = try container.decodeIfPresent([StrengthWorkoutTemplateExport].self, forKey: .strengthTemplates) ?? []
    }
}

private extension CloudKitManager {
    enum BackupStorageFormat {
        case archive
        case legacyWithTemplates
        case legacy
    }

    func exportPayload(context: ModelContext) throws -> BackupPayload {
        // Ensure newly created/edited categories and subcategories are persisted
        // before reading a backup snapshot.
        if context.hasChanges {
            try context.save()
        }

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let categories = try context.fetch(FetchDescriptor<WorkoutCategory>())
        let subcategories = try context.fetch(FetchDescriptor<WorkoutSubcategory>())
        let templates = try context.fetch(FetchDescriptor<SubcategoryExercise>())
        let strengthTemplates = try context.fetch(FetchDescriptor<StrengthWorkoutTemplate>())
        return BackupPayload(
            workouts: workouts.map(WorkoutExport.init),
            categories: categories.map(WorkoutCategoryExport.init),
            subcategories: subcategories.map(WorkoutSubcategoryExport.init),
            exerciseTemplates: templates.map(SubcategoryExerciseExport.init),
            strengthTemplates: strengthTemplates.map(StrengthWorkoutTemplateExport.init)
        )
    }

    func saveBackupRecord(payload: BackupPayload) async throws {
        let formats: [BackupStorageFormat] = [.archive, .legacyWithTemplates, .legacy]
        var lastError: Error?

        for format in formats {
            let files = try temporaryBackupFiles(payload: payload, format: format)
            defer {
                for fileURL in files.values {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }

            let record = CKRecord(recordType: "Backup")
            record["name"] = "Backup \(Date().formatted(date: .abbreviated, time: .shortened))" as CKRecordValue
            record["timestamp"] = Date() as CKRecordValue
            record["deviceName"] = UIDevice.current.name as CKRecordValue
            record["workoutCount"] = payload.workouts.count as CKRecordValue
            record["categoryCount"] = payload.categories.count as CKRecordValue
            record["subcategoryCount"] = payload.subcategories.count as CKRecordValue
            record["assignedSubcategoryCount"] = payload.subcategories.filter { $0.categoryId != nil }.count as CKRecordValue

            for (key, fileURL) in files {
                record[key] = CKAsset(fileURL: fileURL)
            }

            do {
                _ = try await privateDatabase.save(record)
                return
            } catch {
                lastError = error
                guard shouldRetryWithLegacySchema(error: error, format: format) else {
                    throw error
                }
            }
        }

        throw lastError ?? NSError(
            domain: "CloudKit",
            code: 99,
            userInfo: [NSLocalizedDescriptionKey: "Unable to save backup record."]
        )
    }

    func temporaryBackupFiles(payload: BackupPayload, format: BackupStorageFormat) throws -> [String: URL] {
        switch format {
        case .archive:
            let data = try JSONEncoder.iso8601.encode(payload)
            return ["archive": try writeTemporaryBackupFile(data: data, label: "archive")]
        case .legacyWithTemplates:
            return [
                "workouts": try writeTemporaryBackupFile(data: JSONEncoder.iso8601.encode(payload.workouts), label: "workouts"),
                "categories": try writeTemporaryBackupFile(data: JSONEncoder.iso8601.encode(payload.categories), label: "categories"),
                "subcategories": try writeTemporaryBackupFile(data: JSONEncoder.iso8601.encode(payload.subcategories), label: "subcategories"),
                "exerciseTemplates": try writeTemporaryBackupFile(data: JSONEncoder.iso8601.encode(payload.exerciseTemplates), label: "exerciseTemplates"),
                "strengthTemplates": try writeTemporaryBackupFile(data: JSONEncoder.iso8601.encode(payload.strengthTemplates), label: "strengthTemplates")
            ]
        case .legacy:
            return [
                "workouts": try writeTemporaryBackupFile(data: JSONEncoder.iso8601.encode(payload.workouts), label: "workouts"),
                "categories": try writeTemporaryBackupFile(data: JSONEncoder.iso8601.encode(payload.categories), label: "categories"),
                "subcategories": try writeTemporaryBackupFile(data: JSONEncoder.iso8601.encode(payload.subcategories), label: "subcategories")
            ]
        }
    }

    func writeTemporaryBackupFile(data: Data, label: String) throws -> URL {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrainState-Backup-\(UUID().uuidString)-\(label).json")
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    func shouldRetryWithLegacySchema(error: Error, format: BackupStorageFormat) -> Bool {
        let message = (error as NSError).localizedDescription.lowercased()
        switch format {
        case .archive:
            return message.contains("cannot create or modify field 'archive'")
        case .legacyWithTemplates:
            return message.contains("cannot create or modify field 'exercisetemplates'") ||
                   message.contains("cannot create or modify field 'strengthtemplates'")
        case .legacy:
            return false
        }
    }

    func payload(from record: CKRecord) throws -> BackupPayload {
        if let archiveAsset = record["archive"] as? CKAsset, let fileURL = archiveAsset.fileURL {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder.iso8601.decode(BackupPayload.self, from: data)
        }

        guard
            let workoutsAsset = record["workouts"] as? CKAsset,
            let categoriesAsset = record["categories"] as? CKAsset,
            let subcategoriesAsset = record["subcategories"] as? CKAsset,
            let workoutsURL = workoutsAsset.fileURL,
            let categoriesURL = categoriesAsset.fileURL,
            let subcategoriesURL = subcategoriesAsset.fileURL
        else {
            throw NSError(domain: "CloudKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Backup data missing."])
        }

        let workoutsData = try Data(contentsOf: workoutsURL)
        let categoriesData = try Data(contentsOf: categoriesURL)
        let subcategoriesData = try Data(contentsOf: subcategoriesURL)

        let workouts = try JSONDecoder.iso8601.decode([WorkoutExport].self, from: workoutsData)
        let categories = try JSONDecoder.iso8601.decode([WorkoutCategoryExport].self, from: categoriesData)
        let subcategories = try JSONDecoder.iso8601.decode([WorkoutSubcategoryExport].self, from: subcategoriesData)

        let exerciseTemplates: [SubcategoryExerciseExport]
        if let templatesAsset = record["exerciseTemplates"] as? CKAsset, let templatesURL = templatesAsset.fileURL {
            let templatesData = try Data(contentsOf: templatesURL)
            exerciseTemplates = try JSONDecoder.iso8601.decode([SubcategoryExerciseExport].self, from: templatesData)
        } else {
            exerciseTemplates = []
        }

        let strengthTemplates: [StrengthWorkoutTemplateExport]
        if let strengthTemplatesAsset = record["strengthTemplates"] as? CKAsset,
           let strengthTemplatesURL = strengthTemplatesAsset.fileURL {
            let strengthTemplatesData = try Data(contentsOf: strengthTemplatesURL)
            strengthTemplates = try JSONDecoder.iso8601.decode([StrengthWorkoutTemplateExport].self, from: strengthTemplatesData)
        } else {
            strengthTemplates = []
        }

        return BackupPayload(
            workouts: workouts,
            categories: categories,
            subcategories: subcategories,
            exerciseTemplates: exerciseTemplates,
            strengthTemplates: strengthTemplates
        )
    }

    func restorePayload(_ payload: BackupPayload, context: ModelContext) throws {
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let categories = try context.fetch(FetchDescriptor<WorkoutCategory>())
        let subcategories = try context.fetch(FetchDescriptor<WorkoutSubcategory>())
        let templates = try context.fetch(FetchDescriptor<SubcategoryExercise>())
        let strengthTemplates = try context.fetch(FetchDescriptor<StrengthWorkoutTemplate>())

        workouts.forEach { context.delete($0) }
        strengthTemplates.forEach { context.delete($0) }
        categories.forEach { context.delete($0) }
        subcategories.forEach { context.delete($0) }
        templates.forEach { context.delete($0) }
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

        for export in payload.exerciseTemplates {
            guard let subcategoryId = export.subcategoryId, let subcategory = subcategoryMap[subcategoryId] else { continue }
            let template = SubcategoryExercise(name: export.name, subcategory: subcategory, orderIndex: export.orderIndex)
            template.id = export.id
            context.insert(template)
        }

        for export in payload.strengthTemplates {
            let strengthTemplate = StrengthWorkoutTemplate(
                name: export.name,
                mainCategoryRawValue: export.mainCategoryRawValue,
                createdAt: export.createdAt,
                updatedAt: export.updatedAt,
                exercises: []
            )
            strengthTemplate.id = export.id

            let mappedExercises = export.exercises
                .sorted { $0.orderIndex < $1.orderIndex }
                .map { exerciseExport in
                    let exercise = StrengthWorkoutTemplateExercise(
                        name: exerciseExport.name,
                        orderIndex: exerciseExport.orderIndex,
                        sets: exerciseExport.sets,
                        reps: exerciseExport.reps,
                        weight: exerciseExport.weight,
                        subcategoryID: exerciseExport.subcategoryId,
                        setPlanJSON: exerciseExport.setPlanJSON,
                        template: strengthTemplate
                    )
                    exercise.id = exerciseExport.id
                    return exercise
                }

            strengthTemplate.exercises = mappedExercises
            context.insert(strengthTemplate)
        }

        for export in payload.workouts {
            let workout = Workout(
                type: export.type,
                startDate: export.startDate,
                duration: export.duration,
                calories: export.calories,
                distance: export.distance,
                rating: export.rating,
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

struct BackupPreview: Identifiable {
    var id: String { info.id }
    let info: BackupInfo
    let workouts: [WorkoutExport]
    let categories: [WorkoutCategoryExport]
    let subcategories: [WorkoutSubcategoryExport]
}

// Note: WorkoutExport, WorkoutCategoryExport, and WorkoutSubcategoryExport 
// are defined in Workout.swift to avoid duplication
