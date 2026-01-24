import SwiftUI
import UIKit

/// Dynamic Type support following Pocket Casts patterns
extension View {
    /// Apply font with Dynamic Type support and maximum size limit
    func font(size: Double? = nil,
              style: Font.TextStyle,
              weight: Font.Weight = .regular,
              maxSizeCategory: UIContentSizeCategory = .extraExtraLarge) -> some View {
        return modifier(DynamicallyScalableFont(size: size, style: style, weight: weight, maxSizeCategory: maxSizeCategory))
    }
}

private struct DynamicallyScalableFont: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory
    
    var size: Double?
    var style: Font.TextStyle
    var weight: Font.Weight = .regular
    var maxSizeCategory: UIContentSizeCategory = .accessibilityExtraExtraExtraLarge
    
    func body(content: Content) -> some View {
        // Setup the metrics for the font style we'll scale with
        let metrics = UIFontMetrics(forTextStyle: style.UIFontTextStyle)
        let traits = sizeCategory.traitCollection
        let size = self.size ?? UIFont.pointSize(for: style.UIFontTextStyle, sizeCategory: UIContentSizeCategory.large)
        
        // Scale the given point size up to the largest size that we'll allow
        let maxPointSize = metrics.scaledValue(for: size, compatibleWith: UITraitCollection(preferredContentSizeCategory: maxSizeCategory))
        
        // Scale the point size to the current size category, then limit it to the maximum point size
        let scaledSize = min(maxPointSize, metrics.scaledValue(for: size, compatibleWith: traits))
        
        // Return the new calculated font
        return content.font(.system(size: scaledSize, weight: weight))
    }
}

// MARK: - Enums to map SwiftUI -> UIKit font types
private extension ContentSizeCategory {
    var traitCollection: UITraitCollection {
        UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory)
    }
    
    var UIContentSizeCategory: UIContentSizeCategory {
        switch self {
        case .extraSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .extraLarge: return .extraLarge
        case .extraExtraLarge: return .extraExtraLarge
        case .extraExtraExtraLarge: return .extraExtraExtraLarge
        case .accessibilityMedium: return .accessibilityMedium
        case .accessibilityLarge: return .accessibilityLarge
        case .accessibilityExtraLarge: return .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: return .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}

private extension Font.TextStyle {
    var UIFontTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
}

extension UIFont {
    /// Calculates the point size for a font style with the specified size category
    static func pointSize(for style: UIFont.TextStyle, sizeCategory: UIContentSizeCategory) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: sizeCategory)
        return UIFontDescriptor.preferredFontDescriptor(withTextStyle: style, compatibleWith: traits).pointSize
    }
}
