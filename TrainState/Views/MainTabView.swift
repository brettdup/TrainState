import SwiftUI
import SwiftData
import Foundation

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userSettings: [UserSettings]
    @State private var hasInitialImportRun = false
    
    var body: some View {
        ZStack {
            BackgroundView()
            
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
        }
        .tint(AppTheme.accentBlue)
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