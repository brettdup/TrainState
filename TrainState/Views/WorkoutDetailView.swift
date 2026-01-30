import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var workout: Workout
    @State private var showingCategoryPicker = false
    @State private var selectedCategories: [WorkoutCategory] = []
    @State private var selectedSubcategories: [WorkoutSubcategory] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerView
                statsCard
                categoriesCard
                if !selectedSubcategories.isEmpty {
                    subcategoriesCard
                }
                if let notes = workout.notes, !notes.isEmpty {
                    notesCard(notes)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showingCategoryPicker, onDismiss: applyCategorySelection) {
            CategoryAndSubcategorySelectionView(
                selectedCategories: $selectedCategories,
                selectedSubcategories: $selectedSubcategories,
                workoutType: workout.type
            )
        }
        .onAppear {
            selectedCategories = workout.categories ?? []
            selectedSubcategories = workout.subcategories ?? []
        }
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: workout.type.systemImage)
                .font(.title2)
                .foregroundStyle(workout.type.tintColor)
                .frame(width: 32, height: 32)
                .background(workout.type.tintColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.type.rawValue)
                    .font(.title3.weight(.semibold))
                Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        return formatter.string(from: duration) ?? "0m"
    }

    private func applyCategorySelection() {
        workout.categories = selectedCategories
        workout.subcategories = selectedSubcategories
        try? modelContext.save()
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if workout.duration > 0 {
                    StatTile(title: "Duration", value: formattedDuration(workout.duration))
                }
                if let distance = workout.distance, distance > 0 {
                    StatTile(title: "Distance", value: String(format: "%.1f km", distance))
                }
                if let calories = workout.calories, calories > 0 {
                    StatTile(title: "Calories", value: "\(Int(calories)) kcal")
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Categories")
                    .font(.headline)
                Spacer()
                Button("Edit") {
                    showingCategoryPicker = true
                }
                .font(.caption)
            }
            if selectedCategories.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(selectedCategories) { category in
                        CategoryChipView(title: category.name)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var subcategoriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subcategories")
                .font(.headline)
            FlowLayout(spacing: 6) {
                ForEach(selectedSubcategories) { subcategory in
                    CategoryChipView(title: subcategory.name)
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func notesCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            Text(text)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct CategoryChipView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: Workout.self, configurations: config)
    let workout = Workout(type: .running, startDate: .now, duration: 2700, distance: 5.2)
    container.mainContext.insert(workout)
    return NavigationStack {
        WorkoutDetailView(workout: workout)
    }
    .modelContainer(container)
}
