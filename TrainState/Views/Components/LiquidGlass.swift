import SwiftUI

// MARK: - GlassEffectContainer Wrapper

/// Wraps content in GlassEffectContainer on iOS 26+ for improved glass rendering performance.
/// Use when multiple glass cards coexist (e.g. in a ScrollView) to avoid staggered "load in" appearance.
struct GlassEffectContainerWrapper<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

// MARK: - Defer Until Active Modifier

// MARK: - Glass Card Modifier

/// Reusable modifier for Liquid Glass cards with iOS 26+ fallback.
/// Use on any card-style view for consistent glass appearance.
struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat
    var isInteractive: Bool

    init(cornerRadius: CGFloat = ViewConstants.cardCornerRadius, isInteractive: Bool = false) {
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(colorScheme == .dark
                        ? Color(.secondarySystemBackground)
                        : Color(.systemBackground))
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.28 : 0.08),
                        radius: colorScheme == .dark ? 14 : 10,
                        x: 0,
                        y: colorScheme == .dark ? 5 : 3
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        colorScheme == .dark
                            ? Color.white.opacity(0.12)
                            : Color.black.opacity(0.04),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    /// Applies Liquid Glass styling on iOS 26+, material fallback on earlier versions.
    func glassCard(cornerRadius: CGFloat = ViewConstants.cardCornerRadius, isInteractive: Bool = false) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, isInteractive: isInteractive))
    }

    /// Wraps content in GlassEffectContainer on iOS 26+ to improve glass rendering performance
    /// and avoid staggered "load in" when multiple glass elements appear together.
    func glassEffectContainer(spacing: CGFloat = 16) -> some View {
        GlassEffectContainerWrapper(spacing: spacing) { self }
    }

}

#Preview {
    VStack(spacing: 16) {
        Text("Glass Preview")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .glassCard()

        Text("Secondary card")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .glassCard(isInteractive: false)
    }
    .padding()
    .glassEffectContainer(spacing: 16)
}
