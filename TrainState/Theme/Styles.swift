import SwiftUI

// MARK: - View Constants Access
extension View {
    /// Apply default theme settings (background and text color)
    func applyDefaultThemeOptions(backgroundStyle: Color = ThemeColor.primaryUi01()) -> some View {
        self
            .background(backgroundStyle.ignoresSafeArea())
            .foregroundColor(ThemeColor.primaryText01())
    }
}

// MARK: - Text Modifiers
struct PrimaryText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(ThemeColor.primaryText01())
    }
}

struct SecondaryText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(ThemeColor.primaryText02())
    }
}

extension Text {
    func textStyle<Style: ViewModifier>(_ style: Style) -> some View {
        ModifiedContent(content: self, modifier: style)
    }
}

// MARK: - Button Styles

/// Primary button style with accent color background
struct RoundedButtonStyle: ButtonStyle {
    let textColor: Color
    let backgroundColor: Color
    let borderColor: Color?
    
    init(textColor: Color = .white, backgroundColor: Color = ThemeColor.primaryInteractive01(), borderColor: Color? = nil) {
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .applyButtonFont()
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .cornerRadius(ViewConstants.buttonCornerRadius)
            .applyButtonEffect(isPressed: configuration.isPressed)
            .contentShape(Rectangle())
            .modify {
                if let borderColor {
                    $0.overlay {
                        RoundedRectangle(cornerRadius: ViewConstants.buttonCornerRadius)
                            .stroke(borderColor, lineWidth: ViewConstants.buttonStrokeWidth)
                    }
                } else {
                    $0
                }
            }
    }
}

/// Secondary button with border
struct BorderButtonStyle: ButtonStyle {
    let textColor: Color
    let backgroundColor: Color
    let strokeColor: Color
    
    init(textColor: Color = ThemeColor.primaryInteractive01(), backgroundColor: Color = ThemeColor.primaryUi01(), strokeColor: Color = ThemeColor.primaryInteractive01()) {
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .applyButtonFont()
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .cornerRadius(ViewConstants.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: ViewConstants.buttonCornerRadius)
                    .stroke(strokeColor, lineWidth: ViewConstants.buttonStrokeWidth)
            )
            .applyButtonEffect(isPressed: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Simple text button with no background
struct SimpleTextButtonStyle: ButtonStyle {
    let textColor: Color
    let style: Font.TextStyle
    let weight: Font.Weight
    let size: Double
    
    init(textColor: Color = ThemeColor.primaryInteractive01(), size: Double = 18, style: Font.TextStyle = .body, weight: Font.Weight = .semibold) {
        self.textColor = textColor
        self.size = size
        self.style = style
        self.weight = weight
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .applyButtonFont(size: size, style: style, weight: weight)
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .padding()
            .applyButtonEffect(isPressed: configuration.isPressed)
            .cornerRadius(ViewConstants.buttonCornerRadius)
            .contentShape(Rectangle())
    }
}


// MARK: - Button Modifiers
extension View {
    /// Adds a subtle spring effect when the `isPressed` value is changed
    /// This should be used from a `ButtonStyle` and passing in `configuration.isPressed`
    func applyButtonEffect(isPressed: Bool, enableHaptic: Bool = true, scaleEffectNumber: Double = 0.98) -> some View {
        self
            .scaleEffect(isPressed ? scaleEffectNumber : 1.0, anchor: .center)
            .animation(.interpolatingSpring(stiffness: 350, damping: 10, initialVelocity: 10), value: isPressed)
            .onChange(of: isPressed) { pressed in
                guard enableHaptic, pressed else { return }
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
    }
    
    func applyButtonFont(size: Double = 18,
                         style: Font.TextStyle = .body,
                         weight: Font.Weight = .semibold) -> some View {
        self.font(size: size,
                  style: style,
                  weight: weight,
                  maxSizeCategory: .extraExtraLarge)
    }
}

// MARK: - Global Padding Modifier
extension View {
    /// Applies horizontal padding to content (use this for ScrollView content, not List content)
    /// List content should use .listStyle(.insetGrouped) which automatically aligns with navigation bars
    func contentHorizontalPadding() -> some View {
        self.padding(.horizontal, ViewConstants.paddingStandard)
    }
}

// MARK: - Helper Extension
extension View {
    @ViewBuilder
    func modify<Content: View>(@ViewBuilder _ transform: (Self) -> Content) -> some View {
        transform(self)
    }
}
