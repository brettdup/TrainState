import SwiftUI

/// Scale button style following Pocket Casts patterns
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .applyButtonEffect(isPressed: configuration.isPressed)
    }
}

#Preview {
    Button {
    } label: {
        Label("Scaled Button", systemImage: "sparkles")
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.2))
            )
    }
    .buttonStyle(ScaleButtonStyle())
    .padding()
}
