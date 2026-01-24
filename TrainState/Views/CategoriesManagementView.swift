import SwiftUI
import SwiftData

struct CategoriesManagementView: View {
    @Query(sort: \WorkoutCategory.name) private var categories: [WorkoutCategory]

    var body: some View {
        List {
            if categories.isEmpty {
                Text("No categories yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(categories) { category in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.headline)
                        Text("\(category.subcategories?.count ?? 0) subcategories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Categories")
    }
}

#Preview {
    NavigationStack {
        CategoriesManagementView()
    }
    .modelContainer(for: [WorkoutCategory.self, WorkoutSubcategory.self], inMemory: true)
}
