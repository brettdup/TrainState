import Foundation
import SwiftData

/// Manager responsible for initializing default data when the app is first launched
class DataInitializationManager {
    static let shared = DataInitializationManager()
    
    private init() {}
    
    /// Initializes default categories and subcategories if they don't exist
    /// This should be called on app startup or after onboarding
    func initializeDefaultDataIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<WorkoutCategory>()
        
        do {
            let existingCategories = try context.fetch(descriptor)
            
            // Only initialize if no categories exist
            if existingCategories.isEmpty {
                print("No categories found. Initializing default categories...")
                createDefaultCategories(context: context)
            } else {
                print("Categories already exist (\(existingCategories.count) found). Skipping initialization.")
            }
        } catch {
            print("Error checking existing categories: \(error)")
            // If we can't check, try to create anyway (will be ignored if duplicates)
            createDefaultCategories(context: context)
        }
    }
    
    /// Creates all default categories and their subcategories
    private func createDefaultCategories(context: ModelContext) {
        let defaultCategories = WorkoutCategory.createDefaultCategories()
        
        for category in defaultCategories {
            context.insert(category)
            
            // Ensure subcategories are also inserted
            if let subcategories = category.subcategories {
                for subcategory in subcategories {
                    context.insert(subcategory)
                }
            }
        }
        
        do {
            try context.save()
            print("Successfully created \(defaultCategories.count) default categories with subcategories")
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