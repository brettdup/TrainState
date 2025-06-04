import SwiftUI

struct SubcategoryChip: View {
    let subcategory: WorkoutSubcategory
    
    var body: some View {
        let color = Color(hexString: subcategory.category?.color ?? "#007AFF") ?? .blue
        HStack(spacing: 6) {
            Image(systemName: "tag")
                .font(.caption2.weight(.semibold))
                .foregroundColor(color)
            Text(subcategory.name)
                .font(.subheadline.weight(.medium))
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            ZStack {
                // Frosted glass effect
                BlurView(style: .systemThinMaterial)
                
                // Subtle gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0.1),
                        color.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            color.opacity(0.3),
                            color.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: color.opacity(0.1), radius: 4, y: 2)
    }
}
