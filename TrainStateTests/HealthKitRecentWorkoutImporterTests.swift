import Foundation
import HealthKit
import SwiftData
import Testing
@testable import TrainState

@MainActor
struct HealthKitRecentWorkoutImporterTests {

    @Test
    func attachWorkoutSyncsStartDateAndDurationFromHealthKit() async throws {
        let container = try ModelContainer(
            for: Workout.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let importer = HealthKitRecentWorkoutImporter()

        let originalStart = Date(timeIntervalSince1970: 1_700_000_000)
        let healthKitStart = originalStart.addingTimeInterval(5_400)
        let workout = Workout(type: .running, startDate: originalStart, duration: 1_200)
        context.insert(workout)

        let item = HealthKitRecentWorkoutMenuItem(
            hkUUID: "not-a-real-healthkit-uuid",
            startDate: healthKitStart,
            duration: 3_600,
            activityTypeRaw: 37,
            locationTypeRaw: nil,
            sourceName: "Apple Health",
            distanceKilometers: 10,
            calories: 720,
            workoutRating: 8
        )

        try await importer.attachWorkout(item, to: workout, in: context)

        #expect(workout.startDate == healthKitStart)
        #expect(workout.duration == 3_600)
        #expect(workout.hkUUID == item.hkUUID)
    }

    @Test
    func replacementUUIDUpdatesExistingImportedWorkoutInsteadOfCreatingDuplicate() async throws {
        let (context, importer) = try makeContextAndImporter()
        let startDate = Date(timeIntervalSince1970: 1_750_000_000)
        let existingWorkout = Workout(
            startDate: startDate,
            duration: 3_600,
            calories: 600,
            distance: 10,
            notes: "Imported from HealthKit",
            hkActivityTypeRaw: Int(HKWorkoutActivityType.running.rawValue)
        )
        existingWorkout.hkUUID = "garmin-original-uuid"
        context.insert(existingWorkout)
        try context.save()

        let replacement = makeItem(
            hkUUID: "garmin-replacement-uuid",
            startDate: startDate.addingTimeInterval(20),
            duration: 3_660,
            distanceKilometers: 10.1,
            calories: 615
        )

        try await importer.importWorkout(replacement, into: context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 1)
        #expect(workouts.first?.hkUUID == replacement.hkUUID)
        #expect(workouts.first?.startDate == replacement.startDate)
        #expect(workouts.first?.duration == replacement.duration)
        #expect(workouts.first?.distance == replacement.distanceKilometers)
        #expect(workouts.first?.calories == replacement.calories)
    }

    @Test
    func existingDuplicateImportsAreConsolidatedAndUserNotesArePreserved() async throws {
        let (context, importer) = try makeContextAndImporter()
        let startDate = Date(timeIntervalSince1970: 1_750_100_000)

        let first = Workout(
            startDate: startDate,
            duration: 2_400,
            calories: 400,
            notes: "Imported from HealthKit",
            hkActivityTypeRaw: Int(HKWorkoutActivityType.running.rawValue)
        )
        first.hkUUID = "garmin-uuid-1"

        let editedCopy = Workout(
            startDate: startDate.addingTimeInterval(10),
            duration: 2_430,
            distance: 7.2,
            notes: "Felt strong after halfway",
            hkActivityTypeRaw: Int(HKWorkoutActivityType.running.rawValue)
        )
        editedCopy.hkUUID = "garmin-uuid-2"

        context.insert(first)
        context.insert(editedCopy)
        try context.save()

        try await importer.importWorkoutsBatch([], into: context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 1)
        #expect(workouts.first?.hkUUID == "garmin-uuid-2")
        #expect(workouts.first?.notes == "Felt strong after halfway")
        #expect(workouts.first?.calories == 400)
        #expect(workouts.first?.distance == 7.2)
    }

    @Test
    func separateNearbyWorkoutsAreNotConsolidated() async throws {
        let (context, importer) = try makeContextAndImporter()
        let startDate = Date(timeIntervalSince1970: 1_750_200_000)
        let first = Workout(
            startDate: startDate,
            duration: 1_800,
            notes: "Imported from HealthKit",
            hkActivityTypeRaw: Int(HKWorkoutActivityType.running.rawValue)
        )
        first.hkUUID = "first-workout"
        context.insert(first)
        try context.save()

        let secondItem = makeItem(
            hkUUID: "second-workout",
            startDate: startDate.addingTimeInterval(10 * 60),
            duration: 1_800,
            distanceKilometers: 5,
            calories: 350
        )
        try await importer.importWorkout(secondItem, into: context)

        let workouts = try context.fetch(FetchDescriptor<Workout>())
        #expect(workouts.count == 2)
        #expect(Set(workouts.compactMap(\.hkUUID)) == ["first-workout", "second-workout"])
    }

    @Test
    func mapsRepresentativeAppleWorkoutTypesIntoAppBuckets() {
        #expect(HKWorkoutActivityType.running.mappedWorkoutType == .running)
        #expect(HKWorkoutActivityType.cycling.mappedWorkoutType == .cycling)
        #expect(HKWorkoutActivityType.handCycling.mappedWorkoutType == .cycling)
        #expect(HKWorkoutActivityType.swimming.mappedWorkoutType == .swimming)
        #expect(HKWorkoutActivityType.underwaterDiving.mappedWorkoutType == .swimming)
        #expect(HKWorkoutActivityType.yoga.mappedWorkoutType == .yoga)
        #expect(HKWorkoutActivityType.pilates.mappedWorkoutType == .yoga)
        #expect(HKWorkoutActivityType.cooldown.mappedWorkoutType == .yoga)
        #expect(HKWorkoutActivityType.traditionalStrengthTraining.mappedWorkoutType == .strength)
        #expect(HKWorkoutActivityType.crossTraining.mappedWorkoutType == .strength)
        #expect(HKWorkoutActivityType.pickleball.mappedWorkoutType == .cardio)
        #expect(HKWorkoutActivityType.swimBikeRun.mappedWorkoutType == .cardio)
        #expect(HKWorkoutActivityType.transition.mappedWorkoutType == .cardio)
        #expect(HKWorkoutActivityType.other.mappedWorkoutType == .other)
    }

    private func makeContextAndImporter() throws -> (ModelContext, HealthKitRecentWorkoutImporter) {
        let container = try ModelContainer(
            for: Workout.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (ModelContext(container), HealthKitRecentWorkoutImporter())
    }

    private func makeItem(
        hkUUID: String,
        startDate: Date,
        duration: TimeInterval,
        distanceKilometers: Double?,
        calories: Double?
    ) -> HealthKitRecentWorkoutMenuItem {
        HealthKitRecentWorkoutMenuItem(
            hkUUID: hkUUID,
            startDate: startDate,
            duration: duration,
            activityTypeRaw: Int(HKWorkoutActivityType.running.rawValue),
            locationTypeRaw: nil,
            sourceName: "Connect",
            distanceKilometers: distanceKilometers,
            calories: calories,
            workoutRating: nil
        )
    }
}
