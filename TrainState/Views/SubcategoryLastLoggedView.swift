import SwiftUI
import SwiftData

struct SubcategoryLastLoggedView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WorkoutSubcategory.name) private var subcategories: [WorkoutSubcategory]

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
                LazyVStack(spacing: 16) {
                    if subcategories.isEmpty {
                        Text("No subcategories yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .glassCard(cornerRadius: 32)
                    } else {
                        ForEach(subcategories) { subcategory in
                            HStack {
                                Text(subcategory.name)
                                    .font(.body)
                                Spacer()
                            }
                            .padding(20)
                            .glassCard(cornerRadius: 32)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
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
