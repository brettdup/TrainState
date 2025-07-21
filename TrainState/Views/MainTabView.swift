import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userSettings: [UserSettings]
    @State private var hasInitialImportRun = false
    
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
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(.blue)
        .onAppear {
            print("[MainTab] MainTabView appeared")
            // Disable automatic import to prevent app freezing
            // Use manual sync button in WorkoutListView instead
        }
        .toolbarBackground(.clear, for: .tabBar)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Workout.self, UserSettings.self], inMemory: true)
} 