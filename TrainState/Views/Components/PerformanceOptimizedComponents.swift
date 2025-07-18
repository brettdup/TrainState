import SwiftUI

// Performance-optimized button style for frequent use
struct LightweightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.7, blendDuration: 0), value: configuration.isPressed)
    }
}

// Memory-efficient view for handling large lists
struct OptimizedListView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .drawingGroup() // Flatten view hierarchy for better performance
    }
}

// Performance-optimized card view
struct PerformantCardView<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(color: .primary.opacity(0.06), radius: 4, x: 0, y: 2)
            )
    }
}

// Optimized gradient background that doesn't recalculate
struct StaticGradientBackground: View {
    let gradient: LinearGradient
    
    init(colors: [Color], startPoint: UnitPoint = .topLeading, endPoint: UnitPoint = .bottomTrailing) {
        self.gradient = LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
    }
    
    var body: some View {
        gradient
            .ignoresSafeArea()
    }
}

// Performance-optimized text with reduced recomputation
struct OptimizedText: View {
    let text: String
    let font: Font
    let color: Color
    
    init(_ text: String, font: Font = .body, color: Color = .primary) {
        self.text = text
        self.font = font
        self.color = color
    }
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// Lightweight icon view
struct OptimizedIcon: View {
    let systemName: String
    let size: CGFloat
    let color: Color
    
    init(_ systemName: String, size: CGFloat = 16, color: Color = .primary) {
        self.systemName = systemName
        self.size = size
        self.color = color
    }
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size))
            .foregroundColor(color)
    }
}

// Performance-optimized spacer
struct OptimizedSpacer: View {
    let minLength: CGFloat?
    
    init(minLength: CGFloat? = nil) {
        self.minLength = minLength
    }
    
    var body: some View {
        if let minLength = minLength {
            Spacer(minLength: minLength)
        } else {
            Spacer()
        }
    }
}

// View modifier for performance optimization
extension View {
    func optimizeForPerformance() -> some View {
        self
            .clipped()
            .drawingGroup()
    }
    
    func lightweightShadow(color: Color = .primary.opacity(0.1), radius: CGFloat = 4, x: CGFloat = 0, y: CGFloat = 2) -> some View {
        self.shadow(color: color, radius: radius, x: x, y: y)
    }
    
    func performantBackground<S: ShapeStyle>(_ style: S, in shape: some Shape = RoundedRectangle(cornerRadius: 12)) -> some View {
        self.background(shape.fill(style))
    }
}