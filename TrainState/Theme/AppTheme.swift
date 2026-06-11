import SwiftUI

/// App theme following Pocket Casts design patterns
/// Use ThemeColor for semantic colors instead of hardcoded values
enum AppTheme {
    // MARK: - Legacy Support (deprecated - use ThemeColor instead)
    static let primary = Color("AccentColor", bundle: .main)
    static let accentBlue = ThemeColor.workoutRunning()
    static let accentPurple = ThemeColor.workoutStrength()
    static let accentMint = ThemeColor.support02()
    
    // MARK: - Corner Radius (use ViewConstants instead)
    @available(*, deprecated, message: "Use ViewConstants.cornerRadius or ViewConstants.cardCornerRadius instead")
    static let cornerRadius: CGFloat = ViewConstants.cardCornerRadius
}
