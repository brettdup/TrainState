import SwiftUI
import SwiftData
import RevenueCatUI

struct CategoriesManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WorkoutCategory.name) private var categories: [WorkoutCategory]
    @Query(sort: \WorkoutSubcategory.name) private var subcategories: [WorkoutSubcategory]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var expandedCategoryId: UUID?
    @State private var showingAddSubcategory = false
    @State private var newSubcategoryName = ""
    @State private var subcategoryParentCategory: WorkoutCategory?
    @State private var showingPaywall = false

    private func canAddSubcategory(to category: WorkoutCategory) -> Bool {
        guard purchaseManager.hasCompletedInitialPremiumCheck else { return true }
        return purchaseManager.hasActiveSubscription || subcategoriesFor(category).count < PremiumLimits.freeSubcategoryPerCategoryLimit
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.4 : 0.2),
                    Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Subcategories are linked to their parent category. Tap a category to add or view subcategories.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(categories) { category in
                        DisclosureGroup(isExpanded: Binding(
                            get: { expandedCategoryId == category.id },
                            set: { expandedCategoryId = $0 ? category.id : nil }
                        )) {
                            ForEach(subcategoriesFor(category)) { sub in
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.turn.down.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(sub.name)
                                        .font(.subheadline)
                                }
                                .padding(.vertical, 4)
                            }
                            Button {
                                if canAddSubcategory(to: category) {
                                    subcategoryParentCategory = category
                                    newSubcategoryName = ""
                                    showingAddSubcategory = true
                                } else {
                                    Task {
                                        await purchaseManager.loadProducts()
                                        await purchaseManager.updatePurchasedProducts()
                                        showingPaywall = true
                                    }
                                }
                            } label: {
                                Label("Add Subcategory", systemImage: "plus.circle")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.plain)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: category.color) ?? .gray)
                                    .frame(width: 10, height: 10)
                                Text(category.name)
                                    .font(.headline)
                            }
                        }
                        .padding(20)
                        .glassCard(cornerRadius: 32)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Categories")
        .sheet(isPresented: $showingAddSubcategory) {
            addSubcategorySheet
        }
        .sheet(isPresented: $showingPaywall) {
            if let offering = purchaseManager.offerings?.current {
                PaywallView(offering: offering)
            } else {
                PaywallPlaceholderView(onDismiss: { showingPaywall = false })
            }
        }
    }

    private func subcategoriesFor(_ category: WorkoutCategory) -> [WorkoutSubcategory] {
        subcategories.filter { $0.category?.id == category.id }
    }

    private var addSubcategorySheet: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.accentColor.opacity(colorScheme == .dark ? 0.4 : 0.2),
                        Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                        Color(.systemBackground)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Subcategory name", text: $newSubcategoryName)
                            .textFieldStyle(.plain)
                            .padding(20)
                            .glassCard(cornerRadius: 32)
                        if let cat = subcategoryParentCategory {
                            Label("Will be linked to \(cat.name)", systemImage: "link")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("New Subcategory")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAddSubcategory = false
                        subcategoryParentCategory = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addSubcategory()
                    }
                    .disabled(newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func addSubcategory() {
        let name = newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let category = subcategoryParentCategory else { return }
        let sub = WorkoutSubcategory(name: name, category: category)
        modelContext.insert(sub)
        try? modelContext.save()
        newSubcategoryName = ""
        showingAddSubcategory = false
        subcategoryParentCategory = nil
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: WorkoutCategory.self, WorkoutSubcategory.self, configurations: config)
    let context = container.mainContext

    let push = WorkoutCategory(name: "Push", color: "#FF6B6B", workoutType: .strength)
    let legs = WorkoutCategory(name: "Legs", color: "#45B7D1", workoutType: .strength)
    context.insert(push)
    context.insert(legs)

    let benchPress = WorkoutSubcategory(name: "Bench Press", category: push)
    context.insert(benchPress)
    let squat = WorkoutSubcategory(name: "Squat", category: legs)
    context.insert(squat)

    return NavigationStack {
        CategoriesManagementView()
    }
    .modelContainer(container)
}
