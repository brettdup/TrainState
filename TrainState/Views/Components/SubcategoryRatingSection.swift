import SwiftUI

struct SubcategoryRatingSection: View {
    let title: String
    let subcategories: [WorkoutSubcategory]
    @Binding var ratingsBySubcategoryID: [UUID: Int]
    let tintColor: Color
    var showsBodyPartIcons: Bool = false
    let onEditRating: (WorkoutSubcategory) -> Void

    var body: some View {
        Section(title) {
            if subcategories.isEmpty {
                Text("Add subcategories to rate how hard each area was worked.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(subcategories) { subcategory in
                    subcategoryRatingRow(for: subcategory)
                }
            }
        }
    }

    private func subcategoryRatingRow(for subcategory: WorkoutSubcategory) -> some View {
        Button {
            onEditRating(subcategory)
        } label: {
            RatingPickerRow(
                title: subcategory.name,
                rating: ratingsBySubcategoryID[subcategory.id],
                placeholder: "Add",
                tintColor: tintColor,
                systemImage: showsBodyPartIcons ? bodyPartIcon(for: subcategory.name) : "gauge.medium"
            )
        }
        .buttonStyle(.plain)
    }

    private func bodyPartIcon(for name: String) -> String {
        let lowercased = name.lowercased()

        if lowercased.contains("chest") || lowercased.contains("pec") {
            return "figure.strengthtraining.traditional"
        }

        if lowercased.contains("back") || lowercased.contains("lat") || lowercased.contains("trap") {
            return "figure.strengthtraining.functional"
        }

        if lowercased.contains("shoulder") || lowercased.contains("delt") {
            return "figure.arms.open"
        }

        if lowercased.contains("bicep") || lowercased.contains("tricep") || lowercased.contains("arm") {
            return "dumbbell.fill"
        }

        if lowercased.contains("quad") || lowercased.contains("hamstring") || lowercased.contains("leg") {
            return "figure.strengthtraining.traditional"
        }

        if lowercased.contains("glute") || lowercased.contains("calf") {
            return "figure.walk"
        }

        if lowercased.contains("core") || lowercased.contains("ab") || lowercased.contains("oblique") {
            return "figure.core.training"
        }

        return "figure.strengthtraining.traditional"
    }
}
