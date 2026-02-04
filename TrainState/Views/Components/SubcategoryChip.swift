import SwiftUI

struct SubcategoryChip: View {
    let subcategory: WorkoutSubcategory
    
    var body: some View {
        // Use the parent category's color if available, otherwise default to blue
        let color = Color(hex: subcategory.category?.color ?? "") ?? .blue
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
                // Frosted glass effect using native SwiftUI materials
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                
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

#Preview {
    let strength = WorkoutCategory(name: "Strength", color: "#34C759", workoutType: .strength)
    let chest = WorkoutSubcategory(name: "Chest", category: strength)
    return SubcategoryChip(subcategory: chest)
        .padding()
}
