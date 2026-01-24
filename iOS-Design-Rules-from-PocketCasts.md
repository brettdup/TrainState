# iOS Design Rules from Pocket Casts iOS

This document outlines the iOS design patterns, conventions, and best practices extracted from the Pocket Casts iOS repository.

## Table of Contents
1. [Theme System](#theme-system)
2. [Color System](#color-system)
3. [Typography](#typography)
4. [Spacing & Layout](#spacing--layout)
5. [Button Patterns](#button-patterns)
6. [View Modifiers & Components](#view-modifiers--components)
7. [Accessibility](#accessibility)
8. [Animation & Interaction](#animation--interaction)
9. [Best Practices](#best-practices)

---

## Theme System

### Theme Architecture
- **Central Theme Management**: Use a singleton `Theme` class that conforms to `ObservableObject`
- **Theme Types**: Support multiple themes (light, dark, extraDark, electric, classic, indigo, radioactive, rosé, contrastLight, contrastDark)
- **System Theme Support**: Respect system theme preferences with separate light/dark theme preferences
- **Theme Persistence**: Store theme preferences in UserDefaults or SettingsStore

### Theme Implementation Rules
```swift
// ✅ DO: Use shared theme instance
@EnvironmentObject var theme: Theme

// ✅ DO: Check theme state
Theme.isDarkTheme()

// ✅ DO: Support theme override for previews
init(previewTheme: ThemeType) {
    activeTheme = previewTheme
}

// ❌ DON'T: Hardcode colors
UIColor.white  // ❌
ThemeColor.primaryUi01()  // ✅
```

### Theme Change Handling
- **Notifications**: Post `themeChanged` notification when theme changes
- **Animated Transitions**: Use circular reveal animation for theme changes
- **Image Caching**: Clear image cache when switching to/from special themes (e.g., radioactive)

---

## Color System

### Semantic Color Naming
Use semantic color tokens organized by purpose:

#### Primary Colors
- **UI Colors**: `primaryUi01` through `primaryUi06` (backgrounds, surfaces)
- **Text Colors**: `primaryText01` (primary), `primaryText02` (secondary)
- **Icon Colors**: `primaryIcon01` (primary), `primaryIcon02` (secondary), `primaryIcon03` (tertiary)
- **Interactive Colors**: `primaryInteractive01`, `primaryInteractive02`, `primaryInteractive03`
- **Field Colors**: `primaryField01`, `primaryField02`, `primaryField03`

#### State Variants
- **Active States**: `primaryUi01Active`, `primaryUi02Active`
- **Selected States**: `primaryUi02Selected`, `primaryUi05Selected`
- **Hover States**: `primaryInteractive01Hover`
- **Disabled States**: `primaryInteractive01Disabled`

#### Secondary Colors
- **UI**: `secondaryUi01`, `secondaryUi02`
- **Text**: `secondaryText01`, `secondaryText02`
- **Icon**: `secondaryIcon01`, `secondaryIcon02`
- **Interactive**: `secondaryInteractive01`

#### Support Colors
- **Semantic Colors**: `support01` through `support10` (for status, alerts, etc.)
- **Contrast Colors**: `contrast01` through `contrast04`
- **Filter Colors**: `filter01` through `filter08` (for categories, tags)

### Color Usage Rules
```swift
// ✅ DO: Use theme-aware color methods
ThemeColor.primaryText01(for: theme.activeTheme)
AppTheme.color(for: .primaryText01, theme: theme)

// ✅ DO: Support theme override
ThemeColor.primaryUi01(for: themeOverride)

// ✅ DO: Use SwiftUI Color extension
theme.primaryText01  // Direct access via Theme extension

// ❌ DON'T: Use hardcoded colors
UIColor.white  // ❌
Color.blue  // ❌
```

### Color Theme Support
- **Multiple Themes**: Each color must support all theme variants (light, dark, extraDark, electric, etc.)
- **Theme-Specific Colors**: Some colors are theme-specific (e.g., podcast colors, player colors)
- **Auto-Generated**: Color definitions are auto-generated (marked with warning comments)

---

## Typography

### Dynamic Type Support
- **Always Use Dynamic Type**: All text must scale with user's accessibility settings
- **Font Metrics**: Use `UIFontMetrics` for proper scaling
- **Maximum Size Limits**: Cap font sizes at `.extraExtraLarge` or `.accessibilityExtraExtraExtraLarge` to prevent UI breaking

### Font Implementation
```swift
// ✅ DO: Use dynamic font with style
UIFont.font(with: .body, weight: .regular, maxSizeCategory: .extraExtraLarge)

// ✅ DO: Use SwiftUI font modifier
.font(size: 18, style: .body, weight: .semibold, maxSizeCategory: .extraExtraLarge)

// ✅ DO: Calculate point sizes for specific size categories
UIFont.pointSize(for: .body, sizeCategory: .large)

// ❌ DON'T: Use fixed font sizes
.font(.system(size: 18))  // ❌ (unless you have a good reason)
```

### Font Styles
- **Text Styles**: Use semantic text styles (`.largeTitle`, `.title`, `.headline`, `.body`, `.callout`, `.footnote`, `.caption`)
- **Weights**: Prefer system weights (`.regular`, `.medium`, `.semibold`, `.bold`)
- **Scaling**: Fonts scale relative to `.large` size category as baseline

### Scaled Metrics
```swift
// ✅ DO: Use ScaledMetricWithMaxSize for custom values
@ScaledMetricWithMaxSize(relativeTo: .body, maxSize: .accessibility2) var iconSize: CGFloat = 24
```

---

## Spacing & Layout

### View Constants
```swift
public enum ViewConstants {
    static let cornerRadius: CGFloat = 5
    static let buttonCornerRadius = 10.0
    static let buttonStrokeWidth = 2.0
}
```

### Common Spacing Values
- **Standard Padding**: Use system padding (typically 16pt)
- **Compact Spacing**: 8-10pt for tight layouts
- **Standard Spacing**: 16pt for VStack/HStack spacing
- **Large Spacing**: 22pt for section spacing

### Corner Radius Guidelines
- **Standard Elements**: 5pt (`ViewConstants.cornerRadius`)
- **Buttons**: 10pt (`ViewConstants.buttonCornerRadius`)
- **Cards/Containers**: 8-12pt
- **Circular Elements**: `bounds.height / 2` for perfect circles
- **Switches**: 16pt (circular style)

### Layout Rules
```swift
// ✅ DO: Use consistent spacing
VStack(spacing: 16) { ... }
HStack(spacing: 10) { ... }

// ✅ DO: Use standard padding
.padding()  // System default (16pt)
.padding(.horizontal)
.padding(.vertical, 8)

// ✅ DO: Use corner radius constants
.cornerRadius(ViewConstants.cornerRadius)
.cornerRadius(ViewConstants.buttonCornerRadius)
```

---

## Button Patterns

### Button Styles

#### Primary Button (`RoundedButtonStyle`)
- **Background**: `primaryInteractive01`
- **Text Color**: `primaryInteractive02` (or customizable)
- **Corner Radius**: `ViewConstants.buttonCornerRadius` (10pt)
- **Height**: 44pt (minimum touch target)
- **Effect**: Scale to 0.98 on press with spring animation

#### Secondary Button (`BorderButton`)
- **Background**: `primaryUi01`
- **Text Color**: `primaryInteractive01`
- **Border**: `primaryInteractive01` with `buttonStrokeWidth` (2pt)
- **Corner Radius**: `ViewConstants.buttonCornerRadius`

#### Dark Button (`RoundedDarkButton`)
- **Background**: `primaryText01`
- **Text Color**: `primaryUi01`
- **Use Case**: Inverted color scheme for emphasis

#### Stroke Button (`StrokeButton`)
- **Customizable**: Text color, background, stroke color
- **Border Width**: `ViewConstants.buttonStrokeWidth`

#### Simple Text Button (`SimpleTextButtonStyle`)
- **No Background**: Text-only button
- **Customizable**: Size, text color, style, weight

### Button Implementation Rules
```swift
// ✅ DO: Use button styles
Button("Action") { }
    .buttonStyle(RoundedButtonStyle(theme: theme))

// ✅ DO: Apply button effects
.applyButtonEffect(isPressed: configuration.isPressed)

// ✅ DO: Use button font modifier
.applyButtonFont(size: 18, style: .body, weight: .semibold)

// ✅ DO: Set minimum height
.frame(height: 44)

// ❌ DON'T: Create custom button without using styles
Button("Action") {
    // Custom implementation
}
```

### Button Effects
- **Press Animation**: Scale to 0.98 with spring animation (stiffness: 350, damping: 10)
- **Haptic Feedback**: Use `.rigid` impact feedback on press
- **Content Shape**: Use `.contentShape(Rectangle())` for full button tappable area

---

## View Modifiers & Components

### Theme Modifiers
```swift
// ✅ DO: Apply default theme settings
.applyDefaultThemeOptions(backgroundOverride: .primaryUi01)

// ✅ DO: Use text style modifiers
.textStyle(PrimaryText())
.textStyle(SecondaryText())

// ✅ DO: Hide list row separators when needed
.hideListRowSeperators()
```

### Text Field Modifiers
```swift
// ✅ DO: Use themed text field
.themedTextField(style: .primaryUi02, hasErrored: false)

// ✅ DO: Use required field style
.requiredStyle(hasErrored: hasErrored)

// ✅ DO: Apply required input modifier
.required(hasErrored)
```

### Divider Component
```swift
// ✅ DO: Use themed divider
ThemedDivider()
// Uses ThemeColor.primaryUi05 for divider color
```

### Modal Components
```swift
// ✅ DO: Add modal top pill indicator
ModalTopPill(fillColor: .white)
// Size: 60x4pt, corner radius: 10pt, opacity: 0.2
```

---

## Accessibility

### Dynamic Type
- **Always Support**: All text must scale with Dynamic Type
- **Maximum Limits**: Cap sizes to prevent UI breaking
- **Test**: Test with largest accessibility sizes

### Color Contrast
- **High Contrast Themes**: Provide `contrastLight` and `contrastDark` themes
- **WCAG Compliance**: Ensure sufficient contrast ratios
- **Color Blindness**: Don't rely solely on color for information

### Accessibility Labels
- **Semantic Labels**: Provide meaningful accessibility labels
- **Button Labels**: Use descriptive action labels
- **State Announcements**: Announce state changes to VoiceOver

### Reduced Motion
```swift
// ✅ DO: Respect reduced motion preference
.reducedAnimation(animation: .default, value: someValue)
.reducedTransition(transition: .opacity)
```

---

## Animation & Interaction

### Button Press Animation
```swift
// Standard button press effect
.scaleEffect(isPressed ? 0.98 : 1.0, anchor: .center)
.animation(.interpolatingSpring(stiffness: 350, damping: 10, initialVelocity: 10), value: isPressed)
```

### Haptic Feedback
- **Button Press**: Use `.rigid` impact feedback
- **Timing**: Trigger on press, not release
- **Configurable**: Allow disabling haptics when needed

### Theme Transition
- **Circular Reveal**: Use circular mask animation for theme changes
- **Duration**: 0.4 seconds
- **Easing**: `.easeIn` timing function
- **Origin**: Animate from the theme selector button

### Animation Best Practices
- **Spring Animations**: Use spring animations for natural feel
- **Consistent Timing**: Use consistent animation durations
- **Respect Preferences**: Honor reduced motion settings

---

## Best Practices

### Code Organization
1. **Theme System**: Centralize all theme logic in `Theme` class
2. **Color System**: Use semantic color tokens, never hardcode colors
3. **View Modifiers**: Create reusable view modifiers for common patterns
4. **Constants**: Define spacing and sizing constants in `ViewConstants`

### SwiftUI Patterns
```swift
// ✅ DO: Use @EnvironmentObject for theme
@EnvironmentObject var theme: Theme

// ✅ DO: Use ViewModifier for reusable styling
struct ThemedTextField: ViewModifier { ... }

// ✅ DO: Use ButtonStyle for button variants
struct RoundedButtonStyle: ButtonStyle { ... }

// ✅ DO: Use @ViewBuilder for conditional content
@ViewBuilder func conditionalContent() -> some View { ... }
```

### UIKit Integration
- **Themeable Views**: Create `ThemeableView` base class for UIKit components
- **Theme Updates**: Subscribe to theme change notifications
- **Color Application**: Apply theme colors in `updateColors()` method

### Testing
- **Theme Previews**: Create preview themes for SwiftUI previews
- **Multiple Themes**: Test all theme variants
- **Accessibility**: Test with Dynamic Type and VoiceOver
- **Dark Mode**: Always test light and dark themes

### Performance
- **Image Caching**: Clear caches when theme changes affect images
- **Color Lookup**: Cache color lookups when possible
- **View Updates**: Minimize view updates on theme change

### Migration Guidelines
- **Gradual Migration**: Migrate UIKit views to SwiftUI gradually
- **Shared Components**: Create shared components for both frameworks
- **Theme Bridge**: Use `ThemeColor` as bridge between UIKit and SwiftUI

---

## Summary Checklist

When creating new UI components:

- [ ] Use semantic color tokens from `ThemeColor` or `AppTheme`
- [ ] Support all theme variants (light, dark, etc.)
- [ ] Implement Dynamic Type support with maximum size limits
- [ ] Use `ViewConstants` for spacing and corner radius
- [ ] Apply appropriate button styles from `Styles.swift`
- [ ] Add haptic feedback for button interactions
- [ ] Test with accessibility features (VoiceOver, Dynamic Type)
- [ ] Support reduced motion preferences
- [ ] Use view modifiers for reusable styling patterns
- [ ] Follow consistent spacing guidelines (8, 10, 16, 22pt)
- [ ] Ensure minimum touch targets (44x44pt)
- [ ] Test with all theme variants
- [ ] Provide meaningful accessibility labels

---

## References

Key files in Pocket Casts iOS:
- `Theme.swift` - Theme management
- `ThemeColor.swift` - Color definitions
- `AppTheme.swift` - App-specific color helpers
- `ThemeStyle.swift` - Style enum
- `Styles.swift` - SwiftUI view modifiers and button styles
- `Theme+Color.swift` - SwiftUI Color extensions
- `UIFont+FontStyle.swift` - Typography system
- `Themeable+SwiftUI.swift` - View constants and extensions

---

*This document is based on patterns extracted from the Pocket Casts iOS repository. Use these as guidelines and adapt them to your project's specific needs.*
