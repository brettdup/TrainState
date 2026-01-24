import SwiftUI

/// Semantic color system following Pocket Casts patterns
/// All colors adapt to light/dark mode automatically
struct ThemeColor {
    // MARK: - Primary UI Colors (Backgrounds & Surfaces)
    static func primaryUi01() -> Color {
        Color(.systemBackground)
    }
    
    static func primaryUi02() -> Color {
        Color(.secondarySystemBackground)
    }
    
    static func primaryUi03() -> Color {
        Color(.tertiarySystemBackground)
    }
    
    static func primaryUi04() -> Color {
        Color(.quaternarySystemFill)
    }
    
    static func primaryUi05() -> Color {
        Color(.separator)
    }
    
    // MARK: - Primary Text Colors
    static func primaryText01() -> Color {
        Color(.label)
    }
    
    static func primaryText02() -> Color {
        Color(.secondaryLabel)
    }
    
    // MARK: - Primary Icon Colors
    static func primaryIcon01() -> Color {
        Color.accentColor
    }
    
    static func primaryIcon02() -> Color {
        Color(.secondaryLabel)
    }
    
    static func primaryIcon03() -> Color {
        Color(.tertiaryLabel)
    }
    
    // MARK: - Interactive Colors
    static func primaryInteractive01() -> Color {
        Color.accentColor
    }
    
    static func primaryInteractive02() -> Color {
        Color.accentColor
    }
    
    // MARK: - Support Colors (Semantic)
    static func support01() -> Color {
        Color.green
    }
    
    static func support02() -> Color {
        Color.green
    }
    
    static func support03() -> Color {
        Color.blue
    }
    
    static func support04() -> Color {
        Color.blue
    }
    
    static func support05() -> Color {
        Color.red
    }
    
    static func support06() -> Color {
        Color.orange
    }
    
    static func support07() -> Color {
        Color.purple
    }
    
    static func support08() -> Color {
        Color.pink
    }
    
    // MARK: - Workout Type Colors
    static func workoutRunning() -> Color {
        Color.blue
    }
    
    static func workoutStrength() -> Color {
        Color.purple
    }
    
    static func workoutOther() -> Color {
        Color.gray
    }
}
