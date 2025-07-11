import SwiftUI

struct BackgroundView: View {
  // Customizable properties
  var gradientColors: [Color] = [
    Color(red: 0.7, green: 1.0, blue: 0.78),  // Soft green
    Color(red: 0.7, green: 0.85, blue: 0.70),  // Soft blue
  ]
  var opacity: Double = 0.9

  var body: some View {
    LinearGradient(
      gradient: Gradient(colors: gradientColors),
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .opacity(opacity)
    .ignoresSafeArea()
  }
}

// Preview provider for SwiftUI canvas
struct BackgroundView_Previews: PreviewProvider {
  static var previews: some View {
    BackgroundView()
  }
}
