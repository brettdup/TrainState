import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userSettings: [UserSettings]
    
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
            
            AnalyticsView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar")
                }
            
            PremiumView()
                .tabItem {
                    Label("Premium", systemImage: "star.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(.blue)
        .onAppear {
            // Initialize default data on first app launch
            DataInitializationManager.shared.initializeAppData(context: modelContext)
        }
        .toolbarBackground(.clear, for: .tabBar)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Workout.self, UserSettings.self], inMemory: true)
} 