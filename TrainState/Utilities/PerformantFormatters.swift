import Foundation

// High-performance formatters with caching
enum PerformantFormatters {
    private static var durationCache: [TimeInterval: String] = [:]
    private static var dateCache: [Date: String] = [:]
    private static let cacheQueue = DispatchQueue(label: "formatter.cache", qos: .utility)
    
    // Cache capacity limits
    private static let maxCacheSize = 50
    
    static func formatDuration(_ duration: TimeInterval) -> String {
        let roundedDuration = round(duration / 60) * 60 // Round to nearest minute
        
        if let cached = durationCache[roundedDuration] {
            return cached
        }
        
        let hours = Int(roundedDuration) / 3600
        let minutes = Int(roundedDuration) / 60 % 60
        
        let result: String
        if hours > 0 {
            result = "\(hours)h \(minutes)m"
        } else {
            result = "\(minutes)m"
        }
        
        // Cache the result
        cacheQueue.async {
            if durationCache.count >= maxCacheSize {
                // Remove oldest entries by clearing half the cache
                let keysToRemove = Array(durationCache.keys.prefix(maxCacheSize / 2))
                for key in keysToRemove {
                    durationCache.removeValue(forKey: key)
                }
            }
            durationCache[roundedDuration] = result
        }
        
        return result
    }
    
    static func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let roundedDate = calendar.dateInterval(of: .minute, for: date)?.start ?? date
        
        if let cached = dateCache[roundedDate] {
            return cached
        }
        
        let now = Date()
        let result: String
        
        if calendar.isDateInToday(date) {
            result = "Today at \(formatTime(date))"
        } else if calendar.isDateInYesterday(date) {
            result = "Yesterday at \(formatTime(date))"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            result = "\(formatWeekday(date)) at \(formatTime(date))"
        } else {
            result = formatFullDate(date)
        }
        
        // Cache the result
        cacheQueue.async {
            if dateCache.count >= maxCacheSize {
                // Remove oldest entries by clearing half the cache
                let keysToRemove = Array(dateCache.keys.prefix(maxCacheSize / 2))
                for key in keysToRemove {
                    dateCache.removeValue(forKey: key)
                }
            }
            dateCache[roundedDate] = result
        }
        
        return result
    }
    
    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private static func formatWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private static func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
    
    // Clear cache when memory pressure occurs
    static func clearCache() {
        cacheQueue.async {
            durationCache.removeAll()
            dateCache.removeAll()
        }
    }
    
    // Quick format for simple use cases
    static func quickDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes)m"
    }
    
    static func quickDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}