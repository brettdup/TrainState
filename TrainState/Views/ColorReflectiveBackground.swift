import SwiftUI

struct ColorReflectiveBackground: View {
    var body: some View {
        ZStack {
            // Layered gradients for depth and color
            LinearGradient(colors: [.pink.opacity(0.3), .blue.opacity(0.2)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .blur(radius: 60)
                .offset(x: -100, y: -100)

            RadialGradient(colors: [.purple.opacity(0.25), .clear],
                           center: .center, startRadius: 50, endRadius: 300)
                .blur(radius: 80)
                .offset(x: 120, y: 100)

            AngularGradient(gradient: Gradient(colors: [
                .mint.opacity(0.3),
                .yellow.opacity(0.2),
                .orange.opacity(0.3)
            ]), center: .center)
                .blur(radius: 100)
                .blendMode(.plusLighter)
                .opacity(0.4)
        }
        .ignoresSafeArea()
    }
} 