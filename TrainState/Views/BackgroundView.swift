import SwiftUI

struct BackgroundView: View {
    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.red.opacity(0.35),
                    Color.orange.opacity(0.30),
                    Color.yellow.opacity(0.25),
                    Color.green.opacity(0.25),
                    Color.cyan.opacity(0.28),
                    Color.blue.opacity(0.32),
                    Color.pink.opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
            .ignoresSafeArea()

            AngularGradient(
                colors: [
                    Color.red.opacity(0.35),
                    Color.orange.opacity(0.28),
                    Color.yellow.opacity(0.25),
                    Color.green.opacity(0.25),
                    Color.cyan.opacity(0.28),
                    Color.blue.opacity(0.32),
                    Color.pink.opacity(0.35),
                    Color.red.opacity(0.35)
                ],
                center: .center
            )
            .blendMode(.plusLighter)
            .opacity(0.4)
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.white.opacity(0.35), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 420
            )
            .blendMode(.screen)
            .ignoresSafeArea()

            Circle()
                .fill(Color.pink.opacity(0.30))
                .frame(width: 420, height: 420)
                .blur(radius: 140)
                .offset(x: -180, y: -220)

            Circle()
                .fill(Color.cyan.opacity(0.28))
                .frame(width: 360, height: 360)
                .blur(radius: 120)
                .offset(x: 200, y: 160)

            Circle()
                .fill(Color.orange.opacity(0.26))
                .frame(width: 320, height: 320)
                .blur(radius: 120)
                .offset(x: -120, y: 240)

            Circle()
                .fill(Color.blue.opacity(0.25))
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .offset(x: 160, y: -180)
        }
    }
}

// Preview provider for SwiftUI canvas
struct BackgroundView_Previews: PreviewProvider {
  static var previews: some View {
    BackgroundView()
  }
}
