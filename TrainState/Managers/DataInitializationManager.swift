import Foundation
import SwiftData

/// Manager responsible for initializing default data when the app is first launched
class DataInitializationManager {
    static let shared = DataInitializationManager()
    
    private init() {}
    
    /// Initializes default categories and subcategories if they don't exist
    /// This should be called on app startup or after onboarding
    func initializeDefaultDataIfNeeded(context: ModelContext) {
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        var userSettings: UserSettings? = nil
        do {
            let settings = try context.fetch(settingsDescriptor)
            userSettings = settings.first
        } catch {
            print("Error fetching user settings: \(error)")
        }
        
        if let userSettings = userSettings, userSettings.hasInitializedDefaultCategories {
            print("Default categories already initialized. Skipping.")
            return
        }
        
        let descriptor = FetchDescriptor<WorkoutCategory>()
        do {
            let existingCategories = try context.fetch(descriptor)
            if existingCategories.isEmpty {
                print("No categories found. Initializing default categories...")
                createDefaultCategories(context: context)
                if let userSettings = userSettings {
                    userSettings.hasInitializedDefaultCategories = true
                    try? context.save()
                }
            } else {
                print("Categories already exist (\(existingCategories.count) found). Skipping initialization.")
                if let userSettings = userSettings {
                    userSettings.hasInitializedDefaultCategories = true
                    try? context.save()
                }
            }
        } catch {
            print("Error checking existing categories: \(error)")
            createDefaultCategories(context: context)
            if let userSettings = userSettings {
                userSettings.hasInitializedDefaultCategories = true
                try? context.save()
            }
        }
    }
    
    /// Creates all default categories and their subcategories
    private func createDefaultCategories(context: ModelContext) {
        let defaultCategories = WorkoutCategory.createDefaultCategories()
        let descriptor = FetchDescriptor<WorkoutCategory>()
        let existingCategories = (try? context.fetch(descriptor)) ?? []
        for category in defaultCategories {
            // Check for duplicate by name and workoutType
            let duplicate = existingCategories.contains { $0.name.caseInsensitiveCompare(category.name) == .orderedSame && $0.workoutType == category.workoutType }
            if !duplicate {
                context.insert(category)
                if let subcategories = category.subcategories {
                    for subcategory in subcategories {
                        context.insert(subcategory)
                    }
                }
            }
        }
        do {
            try context.save()
            print("Successfully created default categories with subcategories (deduplicated)")
        } catch {
            print("Error saving default categories: \(error)")
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