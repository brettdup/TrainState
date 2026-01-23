import Foundation
import SwiftData
import CoreLocation
import HealthKit

@Model
final class Workout {
    var id: UUID = UUID()
    var typeRawValue: String = WorkoutType.other.rawValue
    
    var type: WorkoutType {
        get { WorkoutType(rawValue: typeRawValue) ?? .other }
        set { typeRawValue = newValue.rawValue }
    }
    var startDate: Date = Date()
    var duration: TimeInterval = 0
    var calories: Double?
    var distance: Double?
    var notes: String?
    var hkActivityTypeRaw: Int?
    
    // SwiftData relationships - CloudKit compatible
    @Relationship(inverse: \WorkoutCategory.workouts)
    var categories: [WorkoutCategory]? = []
    @Relationship(inverse: \WorkoutSubcategory.workouts)
    var subcategories: [WorkoutSubcategory]? = []
    var route: WorkoutRoute?
    
    @Relationship(deleteRule: .cascade)
    var exercises: [WorkoutExercise]?
    
    init(
        type: WorkoutType = .other,
        startDate: Date = Date(),
        duration: TimeInterval = 0,
        calories: Double? = nil,
        distance: Double? = nil,
        notes: String? = nil,
        categories: [WorkoutCategory]? = nil,
        subcategories: [WorkoutSubcategory]? = nil,
        exercises: [WorkoutExercise]? = nil,
        hkActivityTypeRaw: Int? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.startDate = startDate
        self.duration = duration
        self.calories = calories
        self.distance = distance
        self.notes = notes
        self.categories = categories
        self.subcategories = subcategories
        self.exercises = exercises
        self.hkActivityTypeRaw = hkActivityTypeRaw
    }
    
    var hkActivityTypeName: String? {
        guard let raw = hkActivityTypeRaw,
              let hkType = HKWorkoutActivityType(rawValue: UInt(raw)) else { return nil }
        return hkType.readableName
    }
    
    // Helper methods to maintain relationship integrity
    // Note: Only modify one side of the relationship - SwiftData handles the inverse automatically
    func addCategory(_ category: WorkoutCategory) {
        if categories == nil { self.categories = [] }
        if !(categories?.contains(where: { $0.id == category.id }) ?? false) {
            categories?.append(category)
        }
    }
    
    func removeCategory(_ category: WorkoutCategory) {
        categories?.removeAll { $0.id == category.id }
    }
    
    func addSubcategory(_ subcategory: WorkoutSubcategory) {
        if subcategories == nil { self.subcategories = [] }
        if !(subcategories?.contains(where: { $0.id == subcategory.id }) ?? false) {
            subcategories?.append(subcategory)
        }
    }
    
    func removeSubcategory(_ subcategory: WorkoutSubcategory) {
        subcategories?.removeAll { $0.id == subcategory.id }
    }
}

// Make WorkoutType codable for export/import functionality
enum WorkoutType: String, Codable, CaseIterable, Identifiable, Sendable {
    case strength = "Strength Training"
    case cardio = "Cardio"
    case yoga = "Yoga"
    case running = "Running"
    case cycling = "Cycling"
    case swimming = "Swimming"
    case other = "Other"

    public var id: Self { self }
    
    var systemImage: String {
        switch self {
        case .running:
            return "figure.run"
        case .cycling:
            return "bicycle"
        case .swimming:
            return "figure.pool.swim"
        case .yoga:
            return "figure.mind.and.body"
        case .strength:
            return "dumbbell.fill"
        case .cardio:
            return "heart.fill"
        case .other:
            return "square.stack.3d.up"
        }
    }
}

// Filter enum that includes "All" option for UI filtering
enum WorkoutFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case strength = "Strength Training"
    case cardio = "Cardio"
    case yoga = "Yoga"
    case running = "Running"
    case cycling = "Cycling"
    case swimming = "Swimming"
    case other = "Other"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .all: return "square.stack.3d.up"
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.fill"
        case .yoga: return "figure.mind.and.body"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .other: return "square.stack.3d.up"
        }
    }
    
    var workoutType: WorkoutType? {
        switch self {
        case .all: return nil
        case .strength: return .strength
        case .cardio: return .cardio
        case .yoga: return .yoga
        case .running: return .running
        case .cycling: return .cycling
        case .swimming: return .swimming
        case .other: return .other
        }
    }
}

// MARK: - HealthKit Helpers
private extension HKWorkoutActivityType {
    var readableName: String {
        switch self {
        case .americanFootball: return "American Football"
        case .archery: return "Archery"
        case .australianFootball: return "Australian Football"
        case .badminton: return "Badminton"
        case .barre: return "Barre"
        case .baseball: return "Baseball"
        case .basketball: return "Basketball"
        case .bowling: return "Bowling"
        case .boxing: return "Boxing"
        case .climbing: return "Climbing"
        case .cooldown: return "Cooldown"
        case .coreTraining: return "Core Training"
        case .cricket: return "Cricket"
        case .crossCountrySkiing: return "Cross-Country Skiing"
        case .crossTraining: return "Cross Training"
        case .curling: return "Curling"
        case .cycling: return "Cycling"
        case .dance: return "Dance"
        case .danceInspiredTraining: return "Dance-Inspired Training"
        case .downhillSkiing: return "Downhill Skiing"
        case .elliptical: return "Elliptical"
        case .equestrianSports: return "Equestrian Sports"
        case .fencing: return "Fencing"
        case .fishing: return "Fishing"
        case .flexibility: return "Flexibility"
        case .functionalStrengthTraining: return "Functional Strength Training"
        case .golf: return "Golf"
        case .gymnastics: return "Gymnastics"
        case .handCycling: return "Hand Cycling"
        case .handball: return "Handball"
        case .hiking: return "Hiking"
        case .hockey: return "Hockey"
        case .hunting: return "Hunting"
        case .jumpRope: return "Jump Rope"
        case .kickboxing: return "Kickboxing"
        case .lacrosse: return "Lacrosse"
        case .martialArts: return "Martial Arts"
        case .mindAndBody: return "Mind & Body"
        case .mixedCardio: return "Mixed Cardio"
        case .mixedMetabolicCardioTraining: return "Mixed Metabolic Cardio"
        case .other: return "Other"
        case .paddleSports: return "Paddle Sports"
        case .pilates: return "Pilates"
        case .play: return "Play"
        case .preparationAndRecovery: return "Preparation & Recovery"
        case .racquetball: return "Racquetball"
        case .rowing: return "Rowing"
        case .rugby: return "Rugby"
        case .running: return "Running"
        case .sailing: return "Sailing"
        case .skatingSports: return "Skating Sports"
        case .snowSports: return "Snow Sports"
        case .soccer: return "Soccer"
        case .softball: return "Softball"
        case .squash: return "Squash"
        case .stairClimbing: return "Stair Climbing"
        case .stairs: return "Stairs"
        case .stepTraining: return "Step Training"
        case .surfingSports: return "Surfing Sports"
        case .swimming: return "Swimming"
        case .tableTennis: return "Table Tennis"
        case .taiChi: return "Tai Chi"
        case .tennis: return "Tennis"
        case .trackAndField: return "Track & Field"
        case .traditionalStrengthTraining: return "Traditional Strength Training"
        case .volleyball: return "Volleyball"
        case .walking: return "Walking"
        case .waterFitness: return "Water Fitness"
        case .waterPolo: return "Water Polo"
        case .waterSports: return "Water Sports"
        case .wrestling: return "Wrestling"
        case .yoga: return "Yoga"
        case .highIntensityIntervalTraining: return "High Intensity Interval Training"
        case .cardioDance: return "Cardio Dance"
        case .socialDance: return "Social Dance"
        case .pickleball: return "Pickleball"
        case .fitnessGaming: return "Fitness Gaming"
        @unknown default:
            return "Workout"
        }
    }
}

// MARK: - Codable Extensions for Export/Import
// These are separate from the @Model classes to avoid SwiftData conflicts

struct WorkoutExport: Codable {
    let id: UUID
    let type: WorkoutType
    let startDate: Date
    let duration: TimeInterval
    let calories: Double?
    let distance: Double?
    let notes: String?
    let categoryIds: [UUID]?
    let subcategoryIds: [UUID]?
    
    init(workout: Workout) {
        self.id = workout.id
        self.type = workout.type
        self.startDate = workout.startDate
        self.duration = workout.duration
        self.calories = workout.calories
        self.distance = workout.distance
        self.notes = workout.notes
        
        // Safely access relationships with nil checks to avoid SwiftData crashes
        if let categories = workout.categories {
            self.categoryIds = categories.map { $0.id }
        } else {
            self.categoryIds = nil
        }
        
        if let subcategories = workout.subcategories {
            self.subcategoryIds = subcategories.map { $0.id }
        } else {
            self.subcategoryIds = nil
        }
    }
}

struct WorkoutCategoryExport: Codable {
    let id: UUID
    let name: String
    let color: String
    let workoutType: WorkoutType?
    
    init(category: WorkoutCategory) {
        self.id = category.id
        self.name = category.name
        self.color = category.color
        self.workoutType = category.workoutType
    }
}

struct WorkoutSubcategoryExport: Codable {
    let id: UUID
    let name: String
    
    init(subcategory: WorkoutSubcategory) {
        self.id = subcategory.id
        self.name = subcategory.name
    }
} 
