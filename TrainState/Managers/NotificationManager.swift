import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
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
