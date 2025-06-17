import SwiftUI

struct CategoryChip: View {
    let category: WorkoutCategory
    
    var body: some View {
        let color = Color(hex: category.color) ?? .blue
        HStack(spacing: 6) {
            Image(systemName: "tag.fill")
                .font(.caption2.weight(.semibold))
                .foregroundColor(color)
            Text(category.name)
                .font(.subheadline.weight(.medium))
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
                .shadow(color: color.opacity(0.05), radius: 2, y: 1)
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    HStack {
        CategoryChip(category: WorkoutCategory(name: "Push", color: "#FF0000"))
        CategoryChip(category: WorkoutCategory(name: "Pull", color: "#00FF00"))
        CategoryChip(category: WorkoutCategory(name: "Legs", color: "#0000FF"))
    }
    .padding()
} 