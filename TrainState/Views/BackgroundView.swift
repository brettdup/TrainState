import SwiftUI

struct BackgroundView: View {
    var body: some View {
        AppTheme.backgroundGradient
            .ignoresSafeArea()
    }
}

// Preview provider for SwiftUI canvas
struct BackgroundView_Previews: PreviewProvider {
  static var previews: some View {
    BackgroundView()
  }
}
