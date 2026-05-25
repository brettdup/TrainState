import SwiftUI
import UIKit

enum AppIconOption: String, CaseIterable, Identifiable {
    case current = "Current"
    case light = "AppIconLight"
    case dark = "AppIconDark"
    case clear = "AppIconClear"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .current: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        case .clear: "Clear"
        }
    }

    var iconName: String? {
        switch self {
        case .current: nil
        case .light, .dark, .clear: rawValue
        }
    }

    var previewImageName: String {
        switch self {
        case .current: "AppIconOriginalPreview"
        case .light: "AppIconLightPreview"
        case .dark: "AppIconDarkPreview"
        case .clear: "AppIconClearPreview"
        }
    }

    static func option(for iconName: String?) -> AppIconOption {
        guard let iconName else { return .current }
        return AppIconOption(rawValue: iconName) ?? .current
    }
}

@MainActor
final class AppIconManager {
    static let shared = AppIconManager()
    
    private init() {}
    
    func setAppIcon(_ option: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else {
            print("Alternate app icons are not supported on this device")
            return
        }

        guard UIApplication.shared.alternateIconName != option.iconName else {
            print("Icon is already set to \(option.displayName)")
            return
        }

        UIApplication.shared.setAlternateIconName(option.iconName) { error in
            if let error = error {
                print("Error setting alternate icon: \(error.localizedDescription)")
            } else {
                print("Successfully set app icon to: \(option.displayName)")
            }
        }
    }
    
    func getCurrentAppIcon() -> String? {
        let currentIcon = UIApplication.shared.alternateIconName
        print("Current app icon: \(currentIcon ?? "default")")
        return currentIcon
    }
    
    func resetToDefaultIcon() {
        setAppIcon(.current)
    }
    
    func getAvailableIcons() -> [AppIconOption] {
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let alternateIcons = icons["CFBundleAlternateIcons"] as? [String: Any] else {
            print("No alternate icons found in Info.plist")
            return [.current]
        }
        
        let alternateOptions = AppIconOption.allCases.filter { option in
            guard let iconName = option.iconName else { return false }
            return alternateIcons.keys.contains(iconName)
        }
        return [.current] + alternateOptions
    }
} 
