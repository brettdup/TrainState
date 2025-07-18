import SwiftUI

extension Animation {
    // High-performance animations for common UI interactions
    static var smooth: Animation {
        .interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)
    }
    
    static var quick: Animation {
        .interactiveSpring(response: 0.2, dampingFraction: 0.9, blendDuration: 0)
    }
    
    static var gentle: Animation {
        .interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    }
    
    static var snappy: Animation {
        .interactiveSpring(response: 0.25, dampingFraction: 0.7, blendDuration: 0)
    }
    
    // Performance-optimized alternatives to common easing curves
    static var fastEaseInOut: Animation {
        .easeInOut(duration: 0.15)
    }
    
    static var microTransition: Animation {
        .easeInOut(duration: 0.1)
    }
}

// Extension for view-level performance optimizations
extension View {
    // Optimized animation modifier that reduces recomputation
    func smoothAnimation<V: Equatable>(value: V) -> some View {
        self.animation(.smooth, value: value)
    }
    
    func quickAnimation<V: Equatable>(value: V) -> some View {
        self.animation(.quick, value: value)
    }
    
    // Performance-optimized scale effect for buttons
    func performantScale(isPressed: Bool) -> some View {
        self
            .scaleEffect(isPressed ? 0.94 : 1.0)
            .animation(.quick, value: isPressed)
    }
    
    // Optimized opacity changes
    func performantOpacity(isVisible: Bool) -> some View {
        self
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(.fastEaseInOut, value: isVisible)
    }
    
    // Memory-efficient animation that only animates when needed
    func conditionalAnimation<V: Equatable>(_ animation: Animation, value: V, condition: Bool) -> some View {
        self.animation(condition ? animation : nil, value: value)
    }
}

// Performance-optimized transition for common use cases
extension AnyTransition {
    static var performantScale: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }
    
    static var performantSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}