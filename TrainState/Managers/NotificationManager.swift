import Foundation
import UserNotifications

struct HealthKitWorkoutImportNotificationDetail {
    let workoutName: String
    let startDate: Date
    let duration: TimeInterval
    let distanceKilometers: Double?
    let calories: Double?
}

class NotificationManager {
    static let shared = NotificationManager()
    static let healthKitImportNotificationsEnabledKey = "healthKitImportNotificationsEnabled"
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleWorkoutReminder(at time: Date) {
        let center = UNUserNotificationCenter.current()
        
        // Remove any existing workout reminders
        center.removePendingNotificationRequests(withIdentifiers: ["workoutReminder"])
        
        // Create the notification content
        let content = UNMutableNotificationContent()
        content.title = "Time to Work Out!"
        content.body = "Don't forget your daily workout. Stay consistent and achieve your fitness goals!"
        content.sound = .default
        
        // Create the date components for the trigger
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        // Create the trigger
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        // Create the request
        let request = UNNotificationRequest(
            identifier: "workoutReminder",
            content: content,
            trigger: trigger
        )
        
        // Schedule the notification
        center.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelWorkoutReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["workoutReminder"])
    }

    func sendHealthKitWorkoutImportNotification(
        mergedCount: Int,
        importedCount: Int,
        workoutDetails: [HealthKitWorkoutImportNotificationDetail] = []
    ) {
        guard healthKitImportNotificationsEnabled else { return }

        let totalCount = mergedCount + importedCount
        guard totalCount > 0 else { return }

        checkNotificationStatus { authorized in
            guard authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = self.healthKitImportNotificationTitle(
                mergedCount: mergedCount,
                importedCount: importedCount
            )
            content.body = self.healthKitImportNotificationBody(
                mergedCount: mergedCount,
                importedCount: importedCount,
                workoutDetails: workoutDetails
            )
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "healthKitWorkoutImport-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    print("Error sending HealthKit import notification: \(error.localizedDescription)")
                }
            }
        }
    }

    private var healthKitImportNotificationsEnabled: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Self.healthKitImportNotificationsEnabledKey) != nil else {
            return true
        }
        return defaults.bool(forKey: Self.healthKitImportNotificationsEnabledKey)
    }

    private func healthKitImportNotificationTitle(mergedCount: Int, importedCount: Int) -> String {
        if mergedCount > 0 && importedCount > 0 {
            return "Workouts updated"
        }
        if mergedCount > 0 {
            return mergedCount == 1 ? "Workout merged" : "Workouts merged"
        }
        return importedCount == 1 ? "Workout imported" : "Workouts imported"
    }

    private func healthKitImportNotificationBody(
        mergedCount: Int,
        importedCount: Int,
        workoutDetails: [HealthKitWorkoutImportNotificationDetail]
    ) -> String {
        let totalCount = mergedCount + importedCount
        if totalCount == 1, let detail = workoutDetails.first {
            let summary = healthKitWorkoutSummary(for: detail)
            if mergedCount == 1 {
                return "Updated your manual \(detail.workoutName.lowercased()) with \(summary) from Apple Health."
            }
            return "\(detail.workoutName) imported from Apple Health: \(summary)."
        }

        if let detail = workoutDetails.first {
            let actionSummary = healthKitMultiWorkoutActionSummary(mergedCount: mergedCount, importedCount: importedCount)
            return "\(actionSummary) Latest: \(detail.workoutName), \(healthKitWorkoutSummary(for: detail))."
        }

        if mergedCount > 0 && importedCount > 0 {
            return "\(mergedCount) merged with manual workouts and \(importedCount) imported from Apple Health."
        }
        if mergedCount > 0 {
            return mergedCount == 1
                ? "Your manual workout was updated with Apple Health time and metrics."
                : "\(mergedCount) manual workouts were updated with Apple Health time and metrics."
        }
        return importedCount == 1
            ? "A workout was imported from Apple Health."
            : "\(importedCount) workouts were imported from Apple Health."
    }

    private func healthKitMultiWorkoutActionSummary(mergedCount: Int, importedCount: Int) -> String {
        if mergedCount > 0 && importedCount > 0 {
            return "\(mergedCount) merged and \(importedCount) imported from Apple Health."
        }
        if mergedCount > 0 {
            return mergedCount == 1
                ? "1 workout merged from Apple Health."
                : "\(mergedCount) workouts merged from Apple Health."
        }
        return importedCount == 1
            ? "1 workout imported from Apple Health."
            : "\(importedCount) workouts imported from Apple Health."
    }

    private func healthKitWorkoutSummary(for detail: HealthKitWorkoutImportNotificationDetail) -> String {
        var parts: [String] = []
        parts.append(formatDuration(detail.duration))

        if let distanceKilometers = detail.distanceKilometers, distanceKilometers > 0 {
            parts.append(String(format: "%.2f km", distanceKilometers))
        }

        if let calories = detail.calories, calories > 0 {
            parts.append("\(Int(calories.rounded())) kcal")
        }

        parts.append(detail.startDate.formatted(date: .abbreviated, time: .shortened))
        return parts.joined(separator: " · ")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = max(1, Int((duration / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours) hr \(minutes) min"
        }
        if hours > 0 {
            return "\(hours) hr"
        }
        return "\(minutes) min"
    }
    
    func checkNotificationStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }

    func refreshSmartConsistencyReminder(workoutDates: [Date]) {
        let sortedDates = workoutDates.sorted()
        guard sortedDates.count >= 3 else { return }

        checkNotificationStatus { authorized in
            guard authorized else { return }

            let reminderDate = self.predictedReminderDate(from: sortedDates)
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: ["smartWorkoutReminder"])

            let content = UNMutableNotificationContent()
            content.title = "Stay on track"
            content.body = "You are close to your routine window. Log a workout to keep momentum."
            content.sound = .default

            let triggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(
                identifier: "smartWorkoutReminder",
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error {
                    print("Error scheduling smart reminder: \(error.localizedDescription)")
                }
            }
        }
    }

    private func predictedReminderDate(from sortedDates: [Date]) -> Date {
        let recentDates = Array(sortedDates.suffix(8))
        let intervals = zip(recentDates.dropFirst(), recentDates).map { newer, older in
            newer.timeIntervalSince(older)
        }
        let averageInterval = intervals.reduce(0, +) / Double(max(intervals.count, 1))
        let clampedDays = min(max(averageInterval / 86_400, 1), 3)

        let calendar = Calendar.current
        let recentHours = recentDates.map { calendar.component(.hour, from: $0) }
        let recentMinutes = recentDates.map { calendar.component(.minute, from: $0) }
        let targetHour = Int((Double(recentHours.reduce(0, +)) / Double(recentHours.count)).rounded())
        let targetMinute = Int((Double(recentMinutes.reduce(0, +)) / Double(recentMinutes.count)).rounded())

        let baseDate = recentDates.last?.addingTimeInterval(clampedDays * 86_400) ?? Date().addingTimeInterval(86_400)
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = min(max(targetHour, 6), 22)
        components.minute = min(max(targetMinute, 0), 59)

        let scheduled = calendar.date(from: components) ?? baseDate
        if scheduled <= Date() {
            return calendar.date(byAdding: .day, value: 1, to: scheduled) ?? Date().addingTimeInterval(86_400)
        }
        return scheduled
    }
}
