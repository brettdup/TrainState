import Foundation
import SwiftData

@Model
final class Workout: Codable {
    var id: UUID
    var healthKitUUID: UUID?
    var type: WorkoutType
    var startDate: Date
    var duration: TimeInterval
    var calories: Double?
    var distance: Double?
    var notes: String?
    @Relationship var categories: [WorkoutCategory]
    @Relationship var subcategories: [WorkoutSubcategory]
    
    enum CodingKeys: String, CodingKey {
        case id, healthKitUUID, type, startDate, duration, calories, distance, notes
        case categories, subcategories
    }
    
    init(
        type: WorkoutType,
        startDate: Date = Date(),
        duration: TimeInterval,
        calories: Double? = nil,
        distance: Double? = nil,
        notes: String? = nil,
        categories: [WorkoutCategory] = [],
        subcategories: [WorkoutSubcategory] = [],
        healthKitUUID: UUID? = nil
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
        self.healthKitUUID = healthKitUUID
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        healthKitUUID = try container.decodeIfPresent(UUID.self, forKey: .healthKitUUID)
        type = try container.decode(WorkoutType.self, forKey: .type)
        startDate = try container.decode(Date.self, forKey: .startDate)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        calories = try container.decodeIfPresent(Double.self, forKey: .calories)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        categories = try container.decode([WorkoutCategory].self, forKey: .categories)
        subcategories = try container.decode([WorkoutSubcategory].self, forKey: .subcategories)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(healthKitUUID, forKey: .healthKitUUID)
        try container.encode(type, forKey: .type)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(duration, forKey: .duration)
        try container.encodeIfPresent(calories, forKey: .calories)
        try container.encodeIfPresent(distance, forKey: .distance)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(categories, forKey: .categories)
        try container.encode(subcategories, forKey: .subcategories)
    }
}

enum WorkoutType: String, Codable, CaseIterable {
    case strength = "Strength Training"
    case cardio = "Cardio"
    case yoga = "Yoga"
    case running = "Running"
    case cycling = "Cycling"
    case swimming = "Swimming"
    case other = "Other"
}

@Model
final class WorkoutCategory: Codable {
    var id: UUID
    var name: String
    var color: String // Store as hex string
    @Relationship(deleteRule: .cascade) var workouts: [Workout]?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSubcategory.category) var subcategories: [WorkoutSubcategory]?
    var workoutType: WorkoutType?
    
    enum CodingKeys: String, CodingKey {
        case id, name, color, workoutType
    }
    
    init(name: String, color: String = "#FF0000", workoutType: WorkoutType? = nil) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.workoutType = workoutType
        self.subcategories = []
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decode(String.self, forKey: .color)
        workoutType = try container.decodeIfPresent(WorkoutType.self, forKey: .workoutType)
        subcategories = []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color, forKey: .color)
        try container.encodeIfPresent(workoutType, forKey: .workoutType)
    }
    
    // Helper to create default categories for the app
    static func createDefaultCategories() -> [WorkoutCategory] {
        // Create main categories
        let push = WorkoutCategory(name: "Push", color: "#E53935", workoutType: .strength)
        let pull = WorkoutCategory(name: "Pull", color: "#1E88E5", workoutType: .strength)
        let legs = WorkoutCategory(name: "Legs", color: "#43A047", workoutType: .strength)
        let core = WorkoutCategory(name: "Core", color: "#8E24AA", workoutType: .strength)
        let cardio = WorkoutCategory(name: "Cardio", color: "#F4511E", workoutType: .cardio)
        let flexibility = WorkoutCategory(name: "Flexibility", color: "#039BE5", workoutType: .yoga)
        
        // Create subcategories for each main category
        let pushSubcategories = [
            "Chest": ["Bench Press", "Incline Press", "Decline Press", "Push-ups", "Dips", "Cable Flyes"],
            "Shoulders": ["Overhead Press", "Lateral Raises", "Front Raises", "Face Pulls", "Arnold Press"],
            "Triceps": ["Tricep Pushdowns", "Skull Crushers", "Diamond Push-ups", "Overhead Extensions"]
        ]
        
        let pullSubcategories = [
            "Back": ["Pull-ups", "Rows", "Lat Pulldowns", "Deadlifts", "Face Pulls"],
            "Biceps": ["Curls", "Hammer Curls", "Preacher Curls", "Concentration Curls"],
            "Rear Delts": ["Reverse Flyes", "Face Pulls", "Band Pull-aparts"]
        ]
        
        let legsSubcategories = [
            "Quads": ["Squats", "Leg Press", "Lunges", "Leg Extensions", "Step-ups"],
            "Hamstrings": ["Romanian Deadlifts", "Leg Curls", "Good Mornings", "Glute Bridges"],
            "Calves": ["Calf Raises", "Jump Rope", "Box Jumps"]
        ]
        
        let coreSubcategories = [
            "Abs": ["Crunches", "Planks", "Russian Twists", "Leg Raises"],
            "Obliques": ["Side Planks", "Woodchoppers", "Bicycle Crunches"],
            "Lower Back": ["Superman", "Back Extensions", "Bird Dogs"]
        ]
        
        let cardioSubcategories = [
            "HIIT": ["Sprint Intervals", "Circuit Training", "Tabata"],
            "Steady State": ["Jogging", "Cycling", "Swimming", "Rowing"],
            "Recovery": ["Walking", "Light Cycling", "Stretching"]
        ]
        
        let flexibilitySubcategories = [
            "Static": ["Forward Fold", "Downward Dog", "Pigeon Pose", "Child's Pose"],
            "Dynamic": ["Arm Circles", "Leg Swings", "Hip Circles", "Cat-Cow"],
            "Mobility": ["Shoulder Mobility", "Hip Mobility", "Ankle Mobility"]
        ]
        
        // Create and link subcategories
        func createSubcategories(_ dict: [String: [String]], for category: WorkoutCategory) {
            for (group, exercises) in dict {
                for exercise in exercises {
                    let subcategory = WorkoutSubcategory(name: exercise)
                    subcategory.category = category
                    category.subcategories?.append(subcategory)
                }
            }
        }
        
        createSubcategories(pushSubcategories, for: push)
        createSubcategories(pullSubcategories, for: pull)
        createSubcategories(legsSubcategories, for: legs)
        createSubcategories(coreSubcategories, for: core)
        createSubcategories(cardioSubcategories, for: cardio)
        createSubcategories(flexibilitySubcategories, for: flexibility)
        
        return [push, pull, legs, core, cardio, flexibility]
    }
    
    // Get categories for a specific workout type
    static func categoriesForType(_ type: WorkoutType, from allCategories: [WorkoutCategory]) -> [WorkoutCategory] {
        return allCategories.filter { $0.workoutType == type }
    }
}

@Model
final class WorkoutSubcategory: Codable {
    var id: UUID
    var name: String
    @Relationship var category: WorkoutCategory?
    @Relationship(deleteRule: .cascade) var workouts: [Workout]?
    
    enum CodingKeys: String, CodingKey {
        case id, name
    }
    
    init(name: String, category: WorkoutCategory? = nil) {
        self.id = UUID()
        self.name = name
        self.category = category
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }
} 