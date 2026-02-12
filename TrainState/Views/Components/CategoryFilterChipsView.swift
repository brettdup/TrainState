import SwiftUI

/// Horizontal scrolling subcategory chips for filtering exercises.
/// - Single-select with an "All" chip to clear selection.
struct CategoryFilterChipsView: View {
    let subcategories: [WorkoutSubcategory]
    @Binding var selectedID: UUID?
    var tintColor: Color = .accentColor

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip to clear selection
                FilterChip(
                    label: "All",
                    isSelected: selectedID == nil,
                    tintColor: tintColor
                ) {
                    selectedID = nil
                }

                ForEach(subcategories) { subcategory in
                    let isSelected = selectedID == subcategory.id
                    FilterChip(
                        label: subcategory.name,
                        isSelected: isSelected,
                        tintColor: Color(hex: subcategory.category?.color ?? "") ?? tintColor
                    ) {
                        selectChip(subcategory.id)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func selectChip(_ id: UUID) {
        if selectedID == id {
            selectedID = nil
        } else {
            selectedID = id
        }
    }
}

/// Individual filter chip with selection styling
private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let tintColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? tintColor : Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedID: UUID?

        var body: some View {
            let strength = WorkoutCategory(name: "Strength", color: "#34C759", workoutType: .strength)
            let chest = WorkoutSubcategory(name: "Chest", category: strength)
            let back = WorkoutSubcategory(name: "Back", category: strength)
            let legs = WorkoutSubcategory(name: "Legs", category: strength)
            let shoulders = WorkoutSubcategory(name: "Shoulders", category: strength)

            return VStack(spacing: 20) {
                CategoryFilterChipsView(
                    subcategories: [chest, back, legs, shoulders],
                    selectedID: $selectedID,
                    tintColor: .orange
                )

                Text("Selected: \(selectedID?.uuidString.prefix(8) ?? "All")")
                    .font(.caption)
            }
            .padding()
        }
    }

    return PreviewWrapper()
}
