import Foundation
import SwiftData

@Model
final class WorkoutCategory {
    var id: UUID = UUID()
    var name: String = ""
    var color: String = "#FF0000" // Store as hex string
    var workoutType: WorkoutType?
    
    // SwiftData relationships - CloudKit compatible
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSubcategory.category)
    var subcategories: [WorkoutSubcategory]? = []
    var workouts: [Workout]? = []
    
    init(name: String = "", color: String = "#FF0000", workoutType: WorkoutType? = nil) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.workoutType = workoutType
        self.subcategories = []
    }
    
    // Helper methods to maintain relationship integrity
    func addSubcategory(_ subcategory: WorkoutSubcategory) {
        if subcategories == nil { self.subcategories = [] }
        if !(subcategories?.contains(where: { $0.id == subcategory.id }) ?? false) {
            subcategories?.append(subcategory)
            subcategory.category = self
        }
    }
    
    func removeSubcategory(_ subcategory: WorkoutSubcategory) {
        subcategories?.removeAll { $0.id == subcategory.id }
        if subcategory.category?.id == self.id {
            subcategory.category = nil
        }
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
        let running = WorkoutCategory(name: "Running", color: "#039BE5", workoutType: .running)
        
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

        let runningSubcategories = [
            "Tempo": ["Tempo Run", "Easy Run", "Long Run", "Interval Run"],
        ]

        // Create and link subcategories
        func createSubcategories(_ dict: [String: [String]], for category: WorkoutCategory) {
            for (_, exercises) in dict {
                for exercise in exercises {
                    let subcategory = WorkoutSubcategory(name: exercise)
                    subcategory.category = category
                    if category.subcategories == nil { category.subcategories = [] }
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
        createSubcategories(runningSubcategories, for: running)
        
        return [push, pull, legs, core, cardio, flexibility, running]
    }
    
    // Get categories for a specific workout type
    static func categoriesForType(_ type: WorkoutType, from allCategories: [WorkoutCategory]) -> [WorkoutCategory] {
        return allCategories.filter { $0.workoutType == type }
    }
} 