import Foundation
import HealthKit
import SwiftData

@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()

    // Import throttling
    private(set) var isImporting = false
    private let lastImportKey = "HealthKitManager.lastImportDate"

    private init() {}

    // MARK: Authorization
    func requestAuthorizationIfNeeded() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType()
            // Note: HKSeriesType.workoutRoute() is intentionally omitted to avoid heavy processing/network UI work.
        ]

        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }

    // MARK: Import
    func importNewWorkouts(context: ModelContext) async throws -> Int {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        guard !isImporting else { return 0 }
        isImporting = true
        defer { isImporting = false }

        await NetworkManager.shared.refreshNetworkStatus()

        // Hard block importing on cellular for absolute safety
        // HealthKit reads are local, but we avoid any incidental downstream work on cellular.
        guard NetworkManager.shared.isSafeToUseData else {
            print("[HealthKit] Import blocked on cellular (Wi‑Fi only)")
            return 0
        }

        let lastImportDate = UserDefaults.standard.object(forKey: lastImportKey) as? Date
        // Fetch since last import (or last 180 days if never imported)
        let startDate = lastImportDate ?? Calendar.current.date(byAdding: .day, value: -180, to: Date())!
        let hkWorkouts = try await fetchWorkouts(from: startDate)
        if hkWorkouts.isEmpty {
            UserDefaults.standard.set(Date(), forKey: lastImportKey)
            return 0
        }

        // Build a light index of recent app workouts to prevent duplicates
        let appExisting = try context.fetch(FetchDescriptor<Workout>())
        var existingIndex: [Date: [Workout]] = [:]
        for w in appExisting {
            let key = Calendar.current.startOfDay(for: w.startDate)
            existingIndex[key, default: []].append(w)
        }

        var imported = 0
        for hk in hkWorkouts {
            let workoutType = mapHKType(hk.workoutActivityType)
            let start = hk.startDate
            let duration = hk.duration
            let kcal = hk.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie())
            let meters = hk.totalDistance?.doubleValue(for: HKUnit.meter())

            // Duplicate check: same day + similar start time and duration
            let dayKey = Calendar.current.startOfDay(for: start)
            let candidates = existingIndex[dayKey] ?? []
            let isDuplicate = candidates.contains { w in
                w.type == workoutType &&
                abs(w.startDate.timeIntervalSince(start)) < 60 &&
                abs(w.duration - duration) < 60
            }
            if isDuplicate { continue }

            let new = Workout(
                type: workoutType,
                startDate: start,
                duration: duration,
                calories: kcal,
                distance: meters,
                notes: "Imported from Health",
                hkActivityTypeRaw: Int(hk.workoutActivityType.rawValue)
            )
            context.insert(new)
            imported += 1

            // Save in small batches to keep memory steady
            if imported % 20 == 0 { try? context.save() }
        }

        if imported > 0 { try? context.save() }
        UserDefaults.standard.set(Date(), forKey: lastImportKey)
        return imported
    }

    // MARK: - Fetch
    private func fetchWorkouts(from startDate: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: [])
        let type = HKObjectType.workoutType()
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKWorkout], Error>) in
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, samples, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                cont.resume(returning: workouts)
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: Mapping
    private func mapHKType(_ type: HKWorkoutActivityType) -> WorkoutType {
        switch type {
        case .running: return .running
        case .cycling: return .cycling
        case .swimming: return .swimming
        case .yoga: return .yoga
        case .traditionalStrengthTraining: return .strength
        case .highIntensityIntervalTraining, .elliptical, .stairClimbing, .walking, .mindAndBody, .fitnessGaming, .mixedCardio, .cardioDance, .rowing, .hiking:
            return .cardio
        default:
            return .other
        }
    }
}
