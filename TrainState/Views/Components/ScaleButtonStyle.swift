import SwiftUI

/// Scale button style following Pocket Casts patterns
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .applyButtonEffect(isPressed: configuration.isPressed)
    }
} 