import Foundation
import SwiftData

/// Manager responsible for initializing default data when the app is first launched
class DataInitializationManager {
    static let shared = DataInitializationManager()
    
    private init() {}
    
    /// No longer initializes default categories - users create their own
    func initializeDefaultDataIfNeeded(context: ModelContext) {
        print("Default category initialization disabled - users will create their own categories")
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