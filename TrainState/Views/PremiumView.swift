import SwiftUI

struct PremiumView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Premium")
                .font(.largeTitle.weight(.semibold))
            Text("Unlock deeper analytics and custom category limits.")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Upgrade") { }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    PremiumView()
}
