import SwiftUI
import UIKit

class AppIconManager {
    static let shared = AppIconManager()
    
    private init() {}
    
    func setAppIcon(for version: String) {
        guard UIApplication.shared.alternateIconName != version else {
            print("Icon is already set to \(version)")
            return
        }
        
        print("Attempting to set app icon to: \(version)")
        
        UIApplication.shared.setAlternateIconName(version) { error in
            if let error = error {
                print("Error setting alternate icon: \(error.localizedDescription)")
              
            } else {
                print("Successfully set app icon to: \(version)")
            }
        }
    }
    
    func getCurrentAppIcon() -> String? {
        let currentIcon = UIApplication.shared.alternateIconName
        print("Current app icon: \(currentIcon ?? "default")")
        return currentIcon
    }
    
    func resetToDefaultIcon() {
        print("Attempting to reset to default icon")
        
        UIApplication.shared.setAlternateIconName(nil) { error in
            if let error = error {
                print("Error resetting to default icon: \(error.localizedDescription)")
              
            } else {
                print("Successfully reset to default icon")
            }
        }
    }
    
    func getAvailableIcons() -> [String] {
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let alternateIcons = icons["CFBundleAlternateIcons"] as? [String: Any] else {
            print("No alternate icons found in Info.plist")
            return []
        }
        
        let iconNames = Array(alternateIcons.keys)
        print("Available alternate icons: \(iconNames)")
        return iconNames
    }
} 
