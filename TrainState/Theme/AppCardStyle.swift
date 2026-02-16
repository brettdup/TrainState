import SwiftUI

/// Reusable card styling to keep visual language consistent across the app.
struct AppCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = ViewConstants.cardCornerRadius
    var shadowOpacity: Double = 0.12
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.62))
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.72),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.05), radius: 4, y: 2)
    }
}

extension View {
    func appCard(padding: CGFloat = 16) -> some View {
        modifier(AppCardStyle(padding: padding))
    }
}
