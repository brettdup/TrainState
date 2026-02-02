import Foundation
import SwiftData

/// Manager responsible for initializing default data when the app is first launched
class DataInitializationManager {
    static let shared = DataInitializationManager()
    
    private init() {}
    
    private struct DefaultCategorySeed {
        let name: String
        let color: String
        let workoutType: WorkoutType
        let subcategories: [String]
    }

    private let defaultCategorySeeds: [DefaultCategorySeed] = [
        DefaultCategorySeed(
            name: "Push",
            color: "#FF6B6B",
            workoutType: .strength,
            subcategories: ["Chest", "Shoulders"]
        ),
        DefaultCategorySeed(
            name: "Intervals",
            color: "#FF8C42",
            workoutType: .cardio,
            subcategories: ["HIIT", "Steady State"]
        ),
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
        DefaultCategorySeed(
            name: "Pull",
            color: "#4ECDC4",
            workoutType: .strength,
            subcategories: ["Back", "Biceps"]
        ),
        DefaultCategorySeed(
            name: "Endurance",
            color: "#45B7D1",
            workoutType: .running,
            subcategories: ["Easy Run", "Tempo"]
        ),
        DefaultCategorySeed(
            name: "General Fitness",
            color: "#8D99AE",
            workoutType: .other,
            subcategories: ["Warmup", "Recovery"]
        )
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
        initializeDefaultUserSettingsIfNeeded(context: context)
    }
} 
