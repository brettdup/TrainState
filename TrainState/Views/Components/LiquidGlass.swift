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
enum GlassCardProminence {
    case elevated
    case regular
}

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat
    var isInteractive: Bool
    var prominence: GlassCardProminence

    init(
        cornerRadius: CGFloat = ViewConstants.cardCornerRadius,
        isInteractive: Bool = false,
        prominence: GlassCardProminence = .elevated
    ) {
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
        self.prominence = prominence
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        colorScheme == .dark
                            ? Color.white.opacity(prominence == .elevated ? 0.14 : 0.08)
                            : Color.white.opacity(prominence == .elevated ? 0.94 : 0.66)
                    )
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.20 : 0.08),
                        radius: colorScheme == .dark ? (prominence == .elevated ? 9 : 7) : (prominence == .elevated ? 6 : 4),
                        x: 0,
                        y: colorScheme == .dark ? 3 : (prominence == .elevated ? 3 : 2)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        colorScheme == .dark
                            ? Color.white.opacity(prominence == .elevated ? 0.18 : 0.14)
                            : (prominence == .elevated ? Color.black.opacity(0.09) : Color.black.opacity(0.04)),
                        lineWidth: prominence == .elevated ? 0.8 : 0.6
                    )
            )
    }
}

extension View {
    /// Applies Liquid Glass styling on iOS 26+, material fallback on earlier versions.
    func glassCard(
        cornerRadius: CGFloat = ViewConstants.cardCornerRadius,
        isInteractive: Bool = false,
        prominence: GlassCardProminence = .elevated
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, isInteractive: isInteractive, prominence: prominence))
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
