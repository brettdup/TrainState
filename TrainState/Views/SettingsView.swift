import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    Text("iCloud: Not configured")
                        .foregroundStyle(.secondary)
                }

                Section("Preferences") {
                    Toggle("Show Onboarding", isOn: $hasCompletedOnboarding.inverse)
                }

                Section("Data") {
                    Button("Reset All Workouts", role: .destructive) {
                        resetWorkouts()
                    }
                }

                Section("Premium") {
                    NavigationLink("Premium", destination: PremiumView())
                    NavigationLink("Subscription Info", destination: SubscriptionInfoView())
                }

                Section("Developer") {
                    NavigationLink("Developer Options", destination: DeveloperOptionsView())
                }

                Section("Legal") {
                    NavigationLink("Terms of Use", destination: TermsOfUseView())
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func resetWorkouts() {
        let descriptor = FetchDescriptor<Workout>()
        let workouts = (try? modelContext.fetch(descriptor)) ?? []
        workouts.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}

private extension Binding where Value == Bool {
    var inverse: Binding<Bool> {
        Binding<Bool>(
            get: { !wrappedValue },
            set: { wrappedValue = !$0 }
        )
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Workout.self], inMemory: true)
}
