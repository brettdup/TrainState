import Foundation
import SwiftData
import CoreLocation
import SwiftUI

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
    var hkUUID: String?
    
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

    var tintColor: Color {
        switch self {
        case .running:
            return .blue
        case .cycling:
            return .teal
        case .swimming:
            return .cyan
        case .yoga:
            return .green
        case .strength:
            return .orange
        case .cardio:
            return .red
        case .other:
            return .purple
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
    let hkActivityTypeRaw: Int?
    let hkUUID: String?
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
        self.hkActivityTypeRaw = workout.hkActivityTypeRaw
        self.hkUUID = workout.hkUUID
        
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
    let categoryId: UUID?
    
    init(subcategory: WorkoutSubcategory) {
        self.id = subcategory.id
        self.name = subcategory.name
        self.categoryId = subcategory.category?.id
    }
} 
