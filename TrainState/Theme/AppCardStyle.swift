import SwiftUI

/// Reusable card styling to keep visual language consistent across the app.
struct AppCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = AppTheme.cornerRadius
    var shadowOpacity: Double = 0.12
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.12) : Color(.separator),
                        lineWidth: 0.6
                    )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : shadowOpacity), radius: 6, y: 4)
    }
}

extension View {
    func appCard(padding: CGFloat = 16) -> some View {
        modifier(AppCardStyle(padding: padding))
    }
}
