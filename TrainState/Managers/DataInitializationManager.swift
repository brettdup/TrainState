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
        )
    ]

    /// Initializes starter categories/subcategories for new installs so users can test quickly.
    func initializeDefaultDataIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutCategory>()

        do {
            let existingCategories = try context.fetch(descriptor)
            guard existingCategories.isEmpty else {
                return
            }

            for seed in defaultCategorySeeds {
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
            }

            try context.save()
            print("Initialized default categories for first launch")
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
