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
} 