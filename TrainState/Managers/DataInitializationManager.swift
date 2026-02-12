import Foundation
import SwiftData

/// Manager responsible for initializing default data when the app is first launched
class DataInitializationManager {
    static let shared = DataInitializationManager()
    
    private init() {}

    private let minimumDefaultExercisesPerSubcategory = 5
    
    private struct DefaultCategorySeed {
        let name: String
        let color: String
        let workoutType: WorkoutType
        let subcategories: [String]
    }

    private let defaultCategorySeeds: [DefaultCategorySeed] = [
        // Strength split matching the "real phone" experience.
        DefaultCategorySeed(
            name: "Push",
            color: "#FF6B6B",
            workoutType: .strength,
            subcategories: ["Chest", "Shoulders", "Triceps"]
        ),
        DefaultCategorySeed(
            name: "Pull",
            color: "#4ECDC4",
            workoutType: .strength,
            subcategories: ["Back", "Biceps", "Rear Delts"]
        ),
        DefaultCategorySeed(
            name: "Legs",
            color: "#45B7D1",
            workoutType: .strength,
            subcategories: ["Quads", "Hamstrings", "Calves"]
        ),

        // Cardio / conditioning.
        DefaultCategorySeed(
            name: "Intervals",
            color: "#FF8C42",
            workoutType: .cardio,
            subcategories: ["HIIT", "Steady State"]
        ),
        DefaultCategorySeed(
            name: "Endurance",
            color: "#45B7D1",
            workoutType: .running,
            subcategories: ["Easy Run", "Tempo"]
        ),

        // Skill / movement categories.
        DefaultCategorySeed(
            name: "Flow",
            color: "#A66CFF",
            workoutType: .yoga,
            subcategories: ["Vinyasa", "Mobility"]
        ),
        DefaultCategorySeed(
            name: "Long Ride",
            color: "#2EC4B6",
            workoutType: .cycling,
            subcategories: ["Road", "Indoor"]
        ),
        DefaultCategorySeed(
            name: "Laps",
            color: "#3A86FF",
            workoutType: .swimming,
            subcategories: ["Freestyle", "Drills"]
        ),

        // General-purpose / recovery.
        DefaultCategorySeed(
            name: "General Fitness",
            color: "#8D99AE",
            workoutType: .other,
            subcategories: ["Warmup", "Recovery"]
        )
    ]

    private let defaultExerciseTemplatesBySubcategory: [String: [String]] = [
        "chest": [
            "Barbell Bench Press",
            "Incline Dumbbell Press",
            "Decline Press",
            "Chest Fly",
            "Push-Up"
        ],
        "shoulders": [
            "Overhead Press",
            "Lateral Raise",
            "Front Raise",
            "Rear Delt Fly",
            "Arnold Press"
        ],
        "back": [
            "Pull-Up",
            "Bent-Over Row",
            "Lat Pulldown",
            "Seated Cable Row",
            "Single-Arm Dumbbell Row"
        ],
        "biceps": [
            "Barbell Curl",
            "Hammer Curl",
            "Incline Dumbbell Curl",
            "Preacher Curl",
            "Cable Curl"
        ],
        "hiit": [
            "Sprint Intervals",
            "Bike Intervals",
            "Row Intervals",
            "Jump Rope Intervals",
            "Burpee Intervals"
        ],
        "steady state": [
            "Jog",
            "Brisk Walk",
            "Elliptical",
            "Stair Climber",
            "Easy Cycle"
        ],
        "vinyasa": [
            "Sun Salutation A",
            "Sun Salutation B",
            "Warrior Flow",
            "Balance Flow",
            "Core Flow"
        ],
        "mobility": [
            "Hip Mobility",
            "Thoracic Rotation",
            "Ankle Mobility",
            "Shoulder Mobility",
            "Hamstring Mobility"
        ],
        "road": [
            "Endurance Ride",
            "Tempo Ride",
            "Hill Repeats",
            "Cadence Drills",
            "Recovery Ride"
        ],
        "indoor": [
            "Trainer Endurance",
            "Sweet Spot Intervals",
            "Spin Bike Tempo",
            "High Cadence Blocks",
            "Recovery Spin"
        ],
        "freestyle": [
            "Freestyle Easy",
            "Freestyle Tempo",
            "Freestyle Intervals",
            "Freestyle Pull Set",
            "Freestyle Endurance"
        ],
        "drills": [
            "Kickboard Set",
            "Pull Buoy Set",
            "Catch-Up Drill",
            "Finger Drag Drill",
            "Breathing Drill"
        ],
        "easy run": [
            "Recovery Run",
            "Base Run",
            "Easy Treadmill Run",
            "Conversation Pace Run",
            "Zone 2 Run"
        ],
        "tempo": [
            "Tempo Run",
            "Threshold Intervals",
            "Progression Run",
            "Cruise Intervals",
            "Lactate Threshold Run"
        ],
        "warmup": [
            "Dynamic Warmup",
            "Activation Circuit",
            "Joint Prep",
            "Light Cardio Warmup",
            "Movement Prep"
        ],
        "recovery": [
            "Cooldown Walk",
            "Light Mobility",
            "Easy Cycle Recovery",
            "Stretch Session",
            "Breathing Session"
        ]
    ]

    /// Ensures every workout type has starter categories/subcategories.
    func initializeDefaultDataIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutCategory>()

        do {
            let existingCategories = try context.fetch(descriptor)
            let existingTypes = Set(existingCategories.compactMap(\.workoutType))
            let missingTypes = WorkoutType.allCases.filter { !existingTypes.contains($0) }
            guard !missingTypes.isEmpty else { return }

            var didInsert = false

            for workoutType in missingTypes {
                let seedsForType = defaultCategorySeeds.filter { $0.workoutType == workoutType }
                for seed in seedsForType {
                    let category = WorkoutCategory(
                        name: seed.name,
                        color: seed.color,
                        workoutType: seed.workoutType
                    )
                    context.insert(category)

                    for subcategoryName in seed.subcategories {
                        let subcategory = WorkoutSubcategory(name: subcategoryName, category: category)
                        context.insert(subcategory)
                    }

                    didInsert = true
                }
            }

            if didInsert {
                try context.save()
                print("Initialized default categories for missing workout types")
            }
        } catch {
            print("Error initializing default categories: \(error)")
        }
    }

    /// Ensures each subcategory has at least a starter set of exercise templates.
    func initializeDefaultExerciseTemplatesIfNeeded(context: ModelContext) {
        do {
            let subcategories = try context.fetch(FetchDescriptor<WorkoutSubcategory>())
            guard !subcategories.isEmpty else { return }

            let existingTemplates = try context.fetch(FetchDescriptor<SubcategoryExercise>())
            var templatesBySubcategoryID: [UUID: [SubcategoryExercise]] = [:]
            for template in existingTemplates {
                guard let subcategoryID = template.subcategory?.id else { continue }
                templatesBySubcategoryID[subcategoryID, default: []].append(template)
            }

            var didInsert = false

            for subcategory in subcategories {
                let existing = templatesBySubcategoryID[subcategory.id] ?? []
                var existingNames = Set(existing.map { normalizedTemplateName($0.name) })
                var totalCount = existing.count
                var orderIndex = (existing.map(\.orderIndex).max() ?? -1) + 1

                let defaults = defaultTemplates(for: subcategory.name)
                var candidateIndex = 0

                while totalCount < minimumDefaultExercisesPerSubcategory {
                    let candidateName: String
                    if candidateIndex < defaults.count {
                        candidateName = defaults[candidateIndex]
                    } else {
                        candidateName = "\(subcategory.name) Exercise \(candidateIndex - defaults.count + 1)"
                    }
                    candidateIndex += 1

                    let normalizedCandidate = normalizedTemplateName(candidateName)
                    guard !normalizedCandidate.isEmpty, !existingNames.contains(normalizedCandidate) else {
                        continue
                    }

                    let template = SubcategoryExercise(
                        name: candidateName,
                        subcategory: subcategory,
                        orderIndex: orderIndex
                    )
                    context.insert(template)
                    existingNames.insert(normalizedCandidate)
                    totalCount += 1
                    orderIndex += 1
                    didInsert = true
                }
            }

            if didInsert {
                try context.save()
                print("Initialized default exercise templates for subcategories")
            }
        } catch {
            print("Error initializing default exercise templates: \(error)")
        }
    }
    

    
    /// Creates default user settings if they don't exist
    func initializeDefaultUserSettingsIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<UserSettings>()
        
        do {
            let existingSettings = try context.fetch(descriptor)
            
            if existingSettings.isEmpty {
                let defaultSettings = UserSettings()
                context.insert(defaultSettings)
                try context.save()
                print("Created default user settings")
            }
        } catch {
            print("Error initializing user settings: \(error)")
        }
    }
    
    /// Main initialization method that sets up all default data
    func initializeAppData(context: ModelContext) {
        initializeDefaultDataIfNeeded(context: context)
        initializeDefaultExerciseTemplatesIfNeeded(context: context)
        initializeDefaultUserSettingsIfNeeded(context: context)
    }

    private func defaultTemplates(for subcategoryName: String) -> [String] {
        let normalizedName = normalizedTemplateName(subcategoryName)
        if let exact = defaultExerciseTemplatesBySubcategory[normalizedName] {
            return exact
        }

        if normalizedName.contains("chest") { return defaultExerciseTemplatesBySubcategory["chest"] ?? [] }
        if normalizedName.contains("shoulder") { return defaultExerciseTemplatesBySubcategory["shoulders"] ?? [] }
        if normalizedName.contains("back") { return defaultExerciseTemplatesBySubcategory["back"] ?? [] }
        if normalizedName.contains("bicep") { return defaultExerciseTemplatesBySubcategory["biceps"] ?? [] }
        if normalizedName.contains("tempo") { return defaultExerciseTemplatesBySubcategory["tempo"] ?? [] }
        if normalizedName.contains("run") { return defaultExerciseTemplatesBySubcategory["easy run"] ?? [] }
        if normalizedName.contains("recovery") { return defaultExerciseTemplatesBySubcategory["recovery"] ?? [] }
        if normalizedName.contains("warm") { return defaultExerciseTemplatesBySubcategory["warmup"] ?? [] }

        return [
            "\(subcategoryName) Variation 1",
            "\(subcategoryName) Variation 2",
            "\(subcategoryName) Variation 3",
            "\(subcategoryName) Variation 4",
            "\(subcategoryName) Variation 5"
        ]
    }

    private func normalizedTemplateName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
