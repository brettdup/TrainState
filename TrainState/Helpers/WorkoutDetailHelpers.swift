import Foundation
import SwiftUI

// MARK: - Workout Type Helper
struct WorkoutTypeHelper {
    static func iconForType(_ type: WorkoutType) -> String {
        switch type {
        case .strength: "figure.strengthtraining.traditional"
        case .cardio: "heart.fill"
        case .yoga: "figure.yoga"
        case .running: "figure.run"
        case .cycling: "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .other: "ellipsis"
        }
    }

    static func colorForType(_ type: WorkoutType) -> Color {
        switch type {
        case .strength: .purple
        case .cardio: .red
        case .yoga: .mint
        case .running: .blue
        case .cycling: .green
        case .swimming: .cyan
        case .other: .purple
        }
    }
}

// MARK: - Duration Format Helper
struct DurationFormatHelper {
    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Date Format Helper
struct DateFormatHelper {
    static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    static func friendlyDateTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today, \(formattedTime(date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(formattedTime(date))"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let weekday = DateFormatter().weekdaySymbols[calendar.component(.weekday, from: date) - 1]
            return "\(weekday), \(formattedTime(date))"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            return dateFormatter.string(from: date)
        }
    }
    
    private static func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
} 
