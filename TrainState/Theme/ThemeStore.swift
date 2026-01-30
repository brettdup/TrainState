import SwiftUI

/// Theme mode matching Habit Tracker.
enum AppThemeMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Accent color options matching Habit Tracker.
enum AppAccentColor: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case purple = "Purple"
    case green = "Green"
    case orange = "Orange"
    case pink = "Pink"
    case teal = "Teal"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .green: return .green
        case .orange: return .orange
        case .pink: return .pink
        case .teal: return .teal
        }
    }
}
