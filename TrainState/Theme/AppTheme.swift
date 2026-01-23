import SwiftUI

enum AppTheme {
    // Core brand colors
    static let primary = Color("AccentColor", bundle: .main)
    static let accentBlue = Color(red: 0.24, green: 0.51, blue: 0.98)
    static let accentPurple = Color(red: 0.52, green: 0.33, blue: 0.95)
    static let accentMint = Color(red: 0.33, green: 0.83, blue: 0.71)
    
    // Gradients used across the app (light, native-friendly)
    static let heroGradient = LinearGradient(
        colors: [
            Color(.systemBackground),
            Color(.secondarySystemBackground)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(.systemBackground),
            Color(.systemBackground)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardGradient = LinearGradient(
        colors: [
            Color.white,
            Color.white
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Common corner radius
    static let cornerRadius: CGFloat = 20
}

