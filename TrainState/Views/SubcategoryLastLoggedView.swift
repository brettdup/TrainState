import SwiftUI
import SwiftData

struct SubcategoryLastLoggedView: View {
    @Query(sort: \WorkoutSubcategory.name) private var subcategories: [WorkoutSubcategory]

    var body: some View {
        List {
            if subcategories.isEmpty {
                Text("No subcategories yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(subcategories) { subcategory in
                    Text(subcategory.name)
                }
            }
        }
        .navigationTitle("Subcategories")
    }
}

#Preview {
    NavigationStack {
        SubcategoryLastLoggedView()
    }
    .modelContainer(for: [WorkoutSubcategory.self], inMemory: true)
}
