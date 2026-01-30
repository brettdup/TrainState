import SwiftUI

/// Placeholder view shown when RevenueCat offerings are unavailable.
/// Provides a dismiss option for sheet presentation.
struct PaywallPlaceholderView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Premium")
                    .font(.title2.weight(.semibold))

                Text("Upgrade to unlock unlimited workouts, categories, and analytics.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onDismiss()
                    }
                }
            }
        }
    }
}
