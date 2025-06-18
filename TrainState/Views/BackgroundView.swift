import SwiftUI

struct BackgroundView: View {
    // Customizable properties
    var gradientColors: [Color] = [
        Color(red: 1.0, green: 0.7, blue: 0.7),     // Soft red
        Color(red: 1.0, green: 0.85, blue: 0.7),    // Soft orange
        Color(red: 1.0, green: 1.0, blue: 0.7),     // Soft yellow
        Color(red: 0.7, green: 1.0, blue: 0.7),     // Soft green
        Color(red: 0.7, green: 0.85, blue: 1.0),    // Soft blue
        Color(red: 0.85, green: 0.7, blue: 1.0),    // Soft indigo
        Color(red: 1.0, green: 0.7, blue: 0.85)     // Soft violet
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
