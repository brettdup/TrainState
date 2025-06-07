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
                    Section(header: Text("App Settings")) {
                        Toggle(isOn: Binding(
                            get: { settings.darkModeEnabled },
                            set: { settings.darkModeEnabled = $0 }
                        )) {
                            Label("Dark Mode", systemImage: "moon.fill")
                        }
                        Picker("Measurement System", selection: Binding(
                            get: { settings.measurementSystem },
                            set: { settings.measurementSystem = $0 }
                        )) {
                            Text("Metric").tag(MeasurementSystem.metric)
                            Text("Imperial").tag(MeasurementSystem.imperial)
                        }
                        .pickerStyle(.segmented)
                    }
                    // MARK: - Notifications
                    Section(header: Text("Notifications")) {
                        Toggle(isOn: Binding(
                            get: { settings.notificationEnabled },
                            set: { newValue in
                                settings.notificationEnabled = newValue
                                if newValue {
                                    NotificationManager.shared.requestAuthorization()
                                } else {
                                    NotificationManager.shared.cancelWorkoutReminder()
                                }
                            }
                        )) {
                            Label("Enable Notifications", systemImage: "bell")
                        }
                        if settings.notificationEnabled {
                            DatePicker(
                                "Reminder Time",
                                selection: Binding(
                                    get: { settings.notificationTime ?? Date() },
                                    set: { newValue in
                                        settings.notificationTime = newValue
                                        NotificationManager.shared.scheduleWorkoutReminder(at: newValue)
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                        }
                    }
                }
                // MARK: - Workout Organization
                Section(header: Text("Workout Organization")) {
                    NavigationLink(destination: CategoriesManagementView()) {
                        Label("Manage Categories", systemImage: "folder")
                    }
                    NavigationLink(destination: HealthSettingsView()) {
                        Label("Health Integration", systemImage: "heart")
                    }
                }
                // MARK: - Backup & Restore
                Section(header: Text("Backup & Restore")) {
                    BackupRestoreView()
                }
                // MARK: - Quick Stats
                Section(header: Text("Quick Stats")) {
                    HStack(spacing: 16) {
                        StatCard(icon: "figure.strengthtraining.traditional", value: "\(workouts.count)", color: .orange)
                        StatCard(icon: "folder", value: "\(categories.count)", color: .blue)
                        StatCard(icon: "square.grid.2x2", value: "\(subcategories.count)", color: .purple)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                // MARK: - About
                Section(header: Text("About")) {
                    HStack {
                        Label("Version", systemImage: "number")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.secondary)
                    }
                    Link(destination: URL(string: "https://github.com/yourusername/TrainState")!) {
                        Label("GitHub Repository", systemImage: "arrow.up.right.square")
                    }
                }
                // MARK: - Developer Options
                Section(header: Text("Developer Options")) {
                    DeveloperOptionsView()
                }
            }
            .listStyle(.insetGrouped)
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

