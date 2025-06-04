import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userSettings: [UserSettings]
    @State private var isNotificationAuthorized = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @Query private var categories: [WorkoutCategory]
    @Query private var subcategories: [WorkoutSubcategory]
    @Query private var workouts: [Workout]
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - App Settings
                if let settings = userSettings.first {
                    Section {
                        Toggle("Dark Mode", isOn: Binding(
                            get: { settings.darkModeEnabled },
                            set: { settings.darkModeEnabled = $0 }
                        ))
                        .tint(.blue)
                        
                        Picker("Measurement System", selection: Binding(
                            get: { settings.measurementSystem },
                            set: { settings.measurementSystem = $0 }
                        )) {
                            Text("Metric").tag(MeasurementSystem.metric)
                            Text("Imperial").tag(MeasurementSystem.imperial)
                        }
                    } header: {
                        Text("App Settings")
                    } footer: {
                        Text("Choose your preferred measurement system for tracking workouts")
                    }
                    
                    // MARK: - Notifications
                    Section {
                        Toggle("Enable Notifications", isOn: Binding(
                            get: { settings.notificationEnabled },
                            set: { newValue in
                                settings.notificationEnabled = newValue
                                if newValue {
                                    NotificationManager.shared.requestAuthorization()
                                } else {
                                    NotificationManager.shared.cancelWorkoutReminder()
                                }
                            }
                        ))
                        .tint(.blue)
                        
                        if settings.notificationEnabled {
                            DatePicker("Reminder Time", selection: Binding(
                                get: { settings.notificationTime ?? Date() },
                                set: { newValue in
                                    settings.notificationTime = newValue
                                    NotificationManager.shared.scheduleWorkoutReminder(at: newValue)
                                }
                            ), displayedComponents: .hourAndMinute)
                        }
                    } header: {
                        Text("Notifications")
                    } footer: {
                        Text("Set up workout reminders to help you stay on track")
                    }
                }
                
                // MARK: - Workout Organization
                Section {
                    NavigationLink {
                        CategoriesManagementView()
                    } label: {
                        Label("Manage Categories", systemImage: "folder")
                    }
                    
                    NavigationLink {
                        HealthSettingsView()
                    } label: {
                        Label("Health Integration", systemImage: "heart")
                    }
                } header: {
                    Text("Workout Organization")
                } footer: {
                    Text("Organize your workouts and sync with Apple Health")
                }

                // MARK: - Backup & Restore
                BackupRestoreView()
                
                // MARK: - Quick Stats
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Workouts")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(workouts.count)")
                                .font(.title2)
                                .bold()
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Categories")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(categories.count)")
                                .font(.title2)
                                .bold()
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Subcategories")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(subcategories.count)")
                                .font(.title2)
                                .bold()
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Quick Stats")
                }
                
                // MARK: - About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/yourusername/TrainState")!) {
                        HStack {
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("About")
                }
                
                // MARK: - Developer Options
                DeveloperOptionsView()
            }
            .navigationTitle("Settings")
            .onAppear {
                NotificationManager.shared.checkNotificationStatus { authorized in
                    isNotificationAuthorized = authorized
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserSettings.self, WorkoutCategory.self, WorkoutSubcategory.self], inMemory: true)
} 

