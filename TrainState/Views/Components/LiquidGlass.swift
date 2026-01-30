import SwiftUI

/// Reusable modifier for Liquid Glass cards with iOS 26+ fallback.
/// Use on any card-style view for consistent glass appearance.
struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 32) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26, *) {
                content
                    .glassEffect(.regular.tint(.white.opacity(0.22)), in: .rect(cornerRadius: cornerRadius))
            } else {
                content
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
                            .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.06), radius: 10, x: 0, y: 3)
                    )
            }
        }
    }
}

extension View {
    /// Applies Liquid Glass styling on iOS 26+, material fallback on earlier versions.
    func glassCard(cornerRadius: CGFloat = 32) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}
