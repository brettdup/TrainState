import Foundation
import CloudKit
import SwiftData
import UIKit
import HealthKit

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

        // Backup creation should not be reported as failed if cleanup/listing is
        // blocked by a production CloudKit query index that has not caught up.
        do {
            try await enforceBackupLimit()
        } catch {
            updateDebug("Backup saved. Cleanup skipped: \(error.localizedDescription)")
        }

        updateDebug("Backup complete.")
    }
    
    func fetchAvailableBackups() async throws -> [BackupInfo] {
        let status = try await container.accountStatus()
        guard status == .available else {
            throw NSError(domain: "CloudKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud account is not available."])
        }

        var records: [CKRecord]
        do {
            records = try await fetchBackupRecords(sortedByTimestamp: true)
        } catch {
            guard shouldRetryWithoutServerSort(error: error) else { throw userFacingCloudKitError(error) }
            do {
                records = try await fetchBackupRecords(sortedByTimestamp: false)
            } catch {
                throw userFacingCloudKitError(error)
            }
        }

        var backups = records.compactMap(makeBackupInfo)

        backups.sort { $0.date > $1.date }
        return Array(backups.prefix(Self.maxBackupCount))
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
        let mergedPayload = try payloadPreservingNewerHealthKitWorkouts(
            payload,
            backupDate: backupInfo.timestamp,
            context: context
        )
        try restorePayload(mergedPayload, context: context)
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

    private func enforceBackupLimit() async throws {
        var backups = try await fetchAvailableBackupsWithoutDeleting()
        backups.sort { $0.date > $1.date }

        if backups.count > Self.maxBackupCount {
            let toDelete = Array(backups.dropFirst(Self.maxBackupCount))
            _ = try await deleteBackups(toDelete)
        }
    }

    private func fetchAvailableBackupsWithoutDeleting() async throws -> [BackupInfo] {
        let records: [CKRecord]
        do {
            records = try await fetchBackupRecords(sortedByTimestamp: true)
        } catch {
            guard shouldRetryWithoutServerSort(error: error) else { throw userFacingCloudKitError(error) }
            do {
                records = try await fetchBackupRecords(sortedByTimestamp: false)
            } catch {
                throw userFacingCloudKitError(error)
            }
        }

        return records.compactMap(makeBackupInfo)
    }

    private func makeBackupInfo(from record: CKRecord) -> BackupInfo? {
        guard
            let date = record["timestamp"] as? Date,
            let workoutCount = record["workoutCount"] as? Int,
            let categoryCount = record["categoryCount"] as? Int,
            let subcategoryCount = record["subcategoryCount"] as? Int
        else { return nil }

        let name = (record["name"] as? String) ?? "Backup \(date.formatted(date: .abbreviated, time: .shortened))"
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

private struct BackupPayload: Codable {
    let workouts: [WorkoutExport]
    let categories: [WorkoutCategoryExport]
    let subcategories: [WorkoutSubcategoryExport]
    let exerciseTemplates: [SubcategoryExerciseExport]
    let strengthTemplates: [StrengthWorkoutTemplateExport]
    let routes: [WorkoutRouteExport]

    enum CodingKeys: String, CodingKey {
        case workouts
        case categories
        case subcategories
        case exerciseTemplates
        case strengthTemplates
        case routes
    }

    init(
        workouts: [WorkoutExport],
        categories: [WorkoutCategoryExport],
        subcategories: [WorkoutSubcategoryExport],
        exerciseTemplates: [SubcategoryExerciseExport],
        strengthTemplates: [StrengthWorkoutTemplateExport],
        routes: [WorkoutRouteExport]
    ) {
        self.workouts = workouts
        self.categories = categories
        self.subcategories = subcategories
        self.exerciseTemplates = exerciseTemplates
        self.strengthTemplates = strengthTemplates
        self.routes = routes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workouts = try container.decode([WorkoutExport].self, forKey: .workouts)
        categories = try container.decode([WorkoutCategoryExport].self, forKey: .categories)
        subcategories = try container.decode([WorkoutSubcategoryExport].self, forKey: .subcategories)
        exerciseTemplates = try container.decodeIfPresent([SubcategoryExerciseExport].self, forKey: .exerciseTemplates) ?? []
        strengthTemplates = try container.decodeIfPresent([StrengthWorkoutTemplateExport].self, forKey: .strengthTemplates) ?? []
        routes = try container.decodeIfPresent([WorkoutRouteExport].self, forKey: .routes) ?? []
    }
}

private extension CloudKitManager {
    static var compressedArchiveHeader: Data {
        Data("TrainState-LZFSE-1\n".utf8)
    }

    enum BackupStorageFormat {
        case archive
        case legacyWithTemplates
        case legacy
    }

    enum BackupMetadataMode {
        case full
        case withoutOptionalFields
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
        let routes = try context.fetch(FetchDescriptor<WorkoutRoute>())
        return BackupPayload(
            workouts: workouts.map(WorkoutExport.init),
            categories: categories.map(WorkoutCategoryExport.init),
            subcategories: subcategories.map(WorkoutSubcategoryExport.init),
            exerciseTemplates: templates.map(SubcategoryExerciseExport.init),
            strengthTemplates: strengthTemplates.map(StrengthWorkoutTemplateExport.init),
            routes: routes.map(WorkoutRouteExport.init)
        )
    }

    func payloadPreservingNewerHealthKitWorkouts(
        _ backupPayload: BackupPayload,
        backupDate: Date,
        context: ModelContext
    ) throws -> BackupPayload {
        let currentWorkouts = try context.fetch(FetchDescriptor<Workout>())
        let backupWorkoutIDs = Set(backupPayload.workouts.map(\.id))
        let backupHealthKitUUIDs = Set(backupPayload.workouts.compactMap(\.hkUUID))

        let workoutsToPreserve = currentWorkouts.filter { workout in
            guard
                workout.startDate > backupDate,
                let hkUUID = workout.hkUUID,
                !hkUUID.isEmpty
            else {
                return false
            }

            return !backupWorkoutIDs.contains(workout.id)
                && !backupHealthKitUUIDs.contains(hkUUID)
        }

        guard !workoutsToPreserve.isEmpty else { return backupPayload }

        let preservedWorkoutIDs = Set(workoutsToPreserve.map(\.id))
        let preservedCategories = workoutsToPreserve.flatMap { $0.categories ?? [] }
        let preservedSubcategories = workoutsToPreserve.flatMap { workout in
            let assigned = workout.subcategories ?? []
            let exerciseSubcategories = (workout.exercises ?? []).compactMap(\.subcategory)
            return assigned + exerciseSubcategories
        }

        let requiredCategories = preservedCategories
            + preservedSubcategories.compactMap(\.category)
        let subcategoryIDs = Set(preservedSubcategories.map(\.id))

        let currentTemplates = try context.fetch(FetchDescriptor<SubcategoryExercise>())
        let currentRoutes = try context.fetch(FetchDescriptor<WorkoutRoute>())

        return BackupPayload(
            workouts: appendingUnique(
                backupPayload.workouts,
                workoutsToPreserve.map(WorkoutExport.init),
                id: \.id
            ),
            categories: appendingUnique(
                backupPayload.categories,
                requiredCategories.map(WorkoutCategoryExport.init),
                id: \.id
            ),
            subcategories: appendingUnique(
                backupPayload.subcategories,
                preservedSubcategories.map(WorkoutSubcategoryExport.init),
                id: \.id
            ),
            exerciseTemplates: appendingUnique(
                backupPayload.exerciseTemplates,
                currentTemplates
                    .filter { template in
                        guard let subcategoryID = template.subcategory?.id else { return false }
                        return subcategoryIDs.contains(subcategoryID)
                    }
                    .map(SubcategoryExerciseExport.init),
                id: \.id
            ),
            strengthTemplates: backupPayload.strengthTemplates,
            routes: appendingUnique(
                backupPayload.routes,
                currentRoutes
                    .filter { route in
                        guard let workoutID = route.workout?.id else { return false }
                        return preservedWorkoutIDs.contains(workoutID)
                    }
                    .map(WorkoutRouteExport.init),
                id: \.id
            )
        )
    }

    func appendingUnique<Element, ID: Hashable>(
        _ original: [Element],
        _ additions: [Element],
        id: KeyPath<Element, ID>
    ) -> [Element] {
        var existingIDs = Set(original.map { $0[keyPath: id] })
        return original + additions.filter { existingIDs.insert($0[keyPath: id]).inserted }
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

            let timestamp = Date()
            let metadataModes: [BackupMetadataMode] = [.full, .withoutOptionalFields]

            for metadataMode in metadataModes {
                let record = await makeBackupRecord(
                    payload: payload,
                    files: files,
                    timestamp: timestamp,
                    metadataMode: metadataMode
                )

                do {
                    _ = try await privateDatabase.save(record)
                    return
                } catch {
                    lastError = error
                    guard shouldRetryWithReducedMetadata(error: error, metadataMode: metadataMode) ||
                            shouldRetryWithLegacySchema(error: error, format: format) else {
                        throw userFacingCloudKitError(error)
                    }

                    if shouldRetryWithLegacySchema(error: error, format: format) {
                        break
                    }
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
            let jsonData = try JSONEncoder.iso8601.encode(payload)
            let compressedData = try (jsonData as NSData).compressed(using: .lzfse) as Data
            var data = Self.compressedArchiveHeader
            data.append(compressedData)
            return ["archive": try writeTemporaryBackupFile(data: data, label: "archive")]
        case .legacyWithTemplates:
            return [
                "workouts": try writeTemporaryBackupFile(data: JSONEncoder.iso8601.encode(payload.workouts), label: "workouts"),
                "categories": try writeTemporaryBackupFile(data: JSONEncoder.iso8601.encode(payload.categories), label: "categories"),
                "subcategories": try writeTemporaryBackupFile(data: JSONEncoder.iso8601.encode(payload.subcategories), label: "subcategories"),
                "exerciseTemplates": try writeTemporaryBackupFile(data: JSONEncoder.iso8601.encode(payload.exerciseTemplates), label: "exerciseTemplates"),
                "strengthTemplates": try writeTemporaryBackupFile(data: JSONEncoder.iso8601.encode(payload.strengthTemplates), label: "strengthTemplates"),
                "routes": try writeTemporaryBackupFile(data: JSONEncoder.iso8601.encode(payload.routes), label: "routes")
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
            .appendingPathComponent("ExercisePal-Backup-\(UUID().uuidString)-\(label).json")
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    func makeBackupRecord(
        payload: BackupPayload,
        files: [String: URL],
        timestamp: Date,
        metadataMode: BackupMetadataMode
    ) async -> CKRecord {
        let record = CKRecord(recordType: "Backup")
        record["timestamp"] = timestamp as CKRecordValue
        record["workoutCount"] = payload.workouts.count as CKRecordValue
        record["categoryCount"] = payload.categories.count as CKRecordValue
        record["subcategoryCount"] = payload.subcategories.count as CKRecordValue

        if metadataMode == .full {
            record["name"] = "Backup \(timestamp.formatted(date: .abbreviated, time: .shortened))" as CKRecordValue
            record["deviceName"] = await UIDevice.current.name as CKRecordValue
            record["assignedSubcategoryCount"] = payload.subcategories.filter { $0.categoryId != nil }.count as CKRecordValue
        }

        for (key, fileURL) in files {
            record[key] = CKAsset(fileURL: fileURL)
        }

        return record
    }

    func shouldRetryWithReducedMetadata(error: Error, metadataMode: BackupMetadataMode) -> Bool {
        guard metadataMode == .full else { return false }

        let message = (error as NSError).localizedDescription.lowercased()
        return message.contains("cannot create or modify field 'name'") ||
               message.contains("cannot create or modify field 'devicename'") ||
               message.contains("cannot create or modify field 'assignedsubcategorycount'") ||
               message.contains("unknown field 'name'") ||
               message.contains("unknown field 'devicename'") ||
               message.contains("unknown field 'assignedsubcategorycount'")
    }

    func shouldRetryWithLegacySchema(error: Error, format: BackupStorageFormat) -> Bool {
        let message = (error as NSError).localizedDescription.lowercased()
        switch format {
        case .archive:
            return message.contains("cannot create or modify field 'archive'") ||
                   message.contains("unknown field 'archive'") ||
                   message.contains("field 'archive'")
        case .legacyWithTemplates:
            return message.contains("cannot create or modify field 'exercisetemplates'") ||
                   message.contains("cannot create or modify field 'strengthtemplates'") ||
                   message.contains("cannot create or modify field 'routes'") ||
                   message.contains("unknown field 'exercisetemplates'") ||
                   message.contains("unknown field 'strengthtemplates'") ||
                   message.contains("unknown field 'routes'") ||
                   message.contains("field 'exercisetemplates'") ||
                   message.contains("field 'strengthtemplates'") ||
                   message.contains("field 'routes'")
        case .legacy:
            return false
        }
    }

    func fetchBackupRecords(sortedByTimestamp: Bool) async throws -> [CKRecord] {
        let query = CKQuery(recordType: "Backup", predicate: NSPredicate(value: true))
        if sortedByTimestamp {
            query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        }

        let result = try await privateDatabase.records(matching: query)
        return result.matchResults.compactMap { try? $0.1.get() }
    }

    func shouldRetryWithoutServerSort(error: Error) -> Bool {
        let message = (error as NSError).localizedDescription.lowercased()
        return message.contains("sort") ||
               message.contains("sortable") ||
               message.contains("timestamp") ||
               message.contains("field 'timestamp'")
    }

    func userFacingCloudKitError(_ error: Error) -> Error {
        let nsError = error as NSError
        let message = nsError.localizedDescription.lowercased()
        let looksLikeSchemaIssue = message.contains("record type") ||
            message.contains("unknown field") ||
            message.contains("cannot create or modify field") ||
            message.contains("field '") ||
            message.contains("not marked queryable") ||
            message.contains("not marked sortable")

        guard looksLikeSchemaIssue else { return error }

        return NSError(
            domain: "CloudKit",
            code: nsError.code,
            userInfo: [
                NSLocalizedDescriptionKey: "iCloud backup is not fully configured for the production app. Deploy the CloudKit Production schema for the Backup record type and its fields, then try again. Original error: \(nsError.localizedDescription)"
            ]
        )
    }

    func payload(from record: CKRecord) throws -> BackupPayload {
        if let archiveAsset = record["archive"] as? CKAsset, let fileURL = archiveAsset.fileURL {
            let data = try Data(contentsOf: fileURL)
            let archiveData: Data
            if data.starts(with: Self.compressedArchiveHeader) {
                let compressedData = data.dropFirst(Self.compressedArchiveHeader.count)
                archiveData = try (Data(compressedData) as NSData).decompressed(using: .lzfse) as Data
            } else {
                archiveData = data
            }
            return try JSONDecoder.iso8601.decode(BackupPayload.self, from: archiveData)
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

        let routes: [WorkoutRouteExport]
        if let routesAsset = record["routes"] as? CKAsset, let routesURL = routesAsset.fileURL {
            let routesData = try Data(contentsOf: routesURL)
            routes = try JSONDecoder.iso8601.decode([WorkoutRouteExport].self, from: routesData)
        } else {
            routes = []
        }

        return BackupPayload(
            workouts: workouts,
            categories: categories,
            subcategories: subcategories,
            exerciseTemplates: exerciseTemplates,
            strengthTemplates: strengthTemplates,
            routes: routes
        )
    }

    func restorePayload(_ payload: BackupPayload, context: ModelContext) throws {
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let categories = try context.fetch(FetchDescriptor<WorkoutCategory>())
        let subcategories = try context.fetch(FetchDescriptor<WorkoutSubcategory>())
        let templates = try context.fetch(FetchDescriptor<SubcategoryExercise>())
        let strengthTemplates = try context.fetch(FetchDescriptor<StrengthWorkoutTemplate>())
        let workoutExercises = try context.fetch(FetchDescriptor<WorkoutExercise>())
        let subcategoryRatings = try context.fetch(FetchDescriptor<WorkoutSubcategoryRating>())
        let routes = try context.fetch(FetchDescriptor<WorkoutRoute>())

        routes.forEach { context.delete($0) }
        subcategoryRatings.forEach { context.delete($0) }
        workoutExercises.forEach { context.delete($0) }
        workouts.forEach { context.delete($0) }
        strengthTemplates.forEach { context.delete($0) }
        categories.forEach { context.delete($0) }
        subcategories.forEach { context.delete($0) }
        templates.forEach { context.delete($0) }
        try context.save()

        var categoryMap: [UUID: WorkoutCategory] = [:]
        for export in payload.categories {
            let category = WorkoutCategory(
                name: export.name,
                color: export.color,
                workoutType: export.workoutType,
                appleWorkoutActivityType: export.appleWorkoutActivityTypeRaw.flatMap {
                    HKWorkoutActivityType(rawValue: UInt($0))
                }
            )
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
            let template = SubcategoryExercise(
                name: export.name,
                subcategory: subcategory,
                orderIndex: export.orderIndex,
                secondarySubcategoryIDs: export.secondarySubcategoryIds
            )
            template.id = export.id
            context.insert(template)
        }

        for export in payload.strengthTemplates {
            let strengthTemplate = StrengthWorkoutTemplate(
                name: export.name,
                mainCategoryRawValue: export.mainCategoryRawValue,
                appleWorkoutActivityType: export.appleWorkoutActivityTypeRaw.flatMap {
                    HKWorkoutActivityType(rawValue: UInt($0))
                },
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

        var workoutMap: [UUID: Workout] = [:]
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
                hkActivityTypeRaw: export.hkActivityTypeRaw,
                hkLocationTypeRaw: export.hkLocationTypeRaw
            )
            workout.id = export.id
            workout.hkUUID = export.hkUUID

            let mappedExercises = export.exercises
                .sorted { $0.orderIndex < $1.orderIndex }
                .map { exerciseExport in
                    let exercise = WorkoutExercise(
                        name: exerciseExport.name,
                        sets: exerciseExport.sets,
                        reps: exerciseExport.reps,
                        weight: exerciseExport.weight,
                        effortScore: exerciseExport.effortScore,
                        notes: exerciseExport.notes,
                        setPlanJSON: exerciseExport.setPlanJSON,
                        orderIndex: exerciseExport.orderIndex,
                        subcategory: exerciseExport.subcategoryId.flatMap { subcategoryMap[$0] }
                    )
                    exercise.id = exerciseExport.id
                    return exercise
                }
            workout.exercises = mappedExercises
            workout.subcategoryRatings = export.subcategoryRatings.compactMap { ratingExport in
                guard let subcategory = subcategoryMap[ratingExport.subcategoryId] else { return nil }
                let rating = WorkoutSubcategoryRating(
                    rating: ratingExport.rating,
                    workout: workout,
                    subcategory: subcategory
                )
                rating.id = ratingExport.id
                return rating
            }

            context.insert(workout)
            workoutMap[export.id] = workout
        }

        try context.save()

        for export in payload.routes {
            let route = WorkoutRoute(
                name: export.name,
                routeData: export.routeData,
                waypointData: export.waypointData,
                createdAt: export.createdAt,
                updatedAt: export.updatedAt
            )
            route.id = export.id

            if let workoutId = export.workoutId, let workout = workoutMap[workoutId] {
                route.workout = workout
                workout.route = route
            }

            context.insert(route)
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
