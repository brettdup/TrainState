import SwiftUI

struct MainTabView: View {
    @StateObject private var purchaseManager = PurchaseManager.shared

    var body: some View {
        TabView {
            WorkoutListView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            if purchaseManager.hasActiveSubscription {
                AnalyticsView()
                    .tabItem {
                        Label("Analytics", systemImage: "chart.bar")
                    }
            }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, UserSettings.self], inMemory: true)
}
