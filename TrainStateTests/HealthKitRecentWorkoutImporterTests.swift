import Foundation
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
}
