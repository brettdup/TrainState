import Foundation
import HealthKit

class HealthManager: ObservableObject {
    static let shared = HealthManager()
    private let healthStore = HKHealthStore()
    
    @Published var sleepData: [SleepData] = []
    @Published var recoveryScore: Double = 0.0
    @Published var stressLevel: Double = 0.0
    
    private init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchSleepData(for date: Date) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
            guard let samples = samples as? [HKCategorySample], error == nil else { return }
            
            let sleepData = samples.map { sample -> SleepData in
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                return SleepData(
                    startTime: sample.startDate,
                    endTime: sample.endDate,
                    duration: duration,
                    quality: self?.calculateSleepQuality(from: sample) ?? 0.0
                )
            }
            
            DispatchQueue.main.async {
                self?.sleepData = sleepData
            }
        }
        
        healthStore.execute(query)
    }
    
    func calculateRecoveryScore() {
        // Fetch necessary data for recovery calculation
        fetchHeartRateVariability { [weak self] hrv in
            guard let self = self else { return }
            self.fetchRestingHeartRate { restingHR in
                self.fetchSleepData(for: Date())
                // Calculate recovery score based on multiple factors
                let score = self.calculateRecoveryScore(
                    hrv: hrv,
                    restingHR: restingHR,
                    sleepData: self.sleepData
                )
                
                DispatchQueue.main.async {
                    self.recoveryScore = score
                }
            }
        }
    }
    
    func calculateStressLevel() {
        // Fetch necessary data for stress calculation
        fetchHeartRateVariability { [weak self] hrv in
            guard let self = self else { return }
            self.fetchRestingHeartRate { restingHR in
                // Calculate stress level based on HRV and resting heart rate
                let stressLevel = self.calculateStressLevel(
                    hrv: hrv,
                    restingHR: restingHR
                )
                
                DispatchQueue.main.async {
                    self.stressLevel = stressLevel
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func calculateSleepQuality(from sample: HKCategorySample) -> Double {
        // Implement sleep quality calculation based on sleep stages and duration
        // This is a simplified version - you might want to make it more sophisticated
        let duration = sample.endDate.timeIntervalSince(sample.startDate)
        let hours = duration / 3600
        
        // Basic quality calculation based on duration
        if hours >= 7 && hours <= 9 {
            return 1.0
        } else if hours >= 6 && hours < 7 {
            return 0.8
        } else if hours > 9 && hours <= 10 {
            return 0.7
        } else {
            return 0.5
        }
    }
    
    private func calculateRecoveryScore(hrv: Double, restingHR: Double, sleepData: [SleepData]) -> Double {
        // Implement recovery score calculation
        // This is a simplified version - you might want to make it more sophisticated
        let sleepScore = sleepData.reduce(0.0) { $0 + $1.quality } / Double(max(1, sleepData.count))
        let hrvScore = min(1.0, hrv / 100.0) // Normalize HRV
        let restingHRScore = 1.0 - min(1.0, (restingHR - 40) / 60) // Normalize resting HR
        
        return (sleepScore * 0.4 + hrvScore * 0.3 + restingHRScore * 0.3)
    }
    
    private func calculateStressLevel(hrv: Double, restingHR: Double) -> Double {
        // Implement stress level calculation
        // This is a simplified version - you might want to make it more sophisticated
        let hrvScore = 1.0 - min(1.0, hrv / 100.0)
        let restingHRScore = min(1.0, (restingHR - 40) / 60)
        
        return (hrvScore * 0.6 + restingHRScore * 0.4)
    }
    
    // MARK: - Data Fetching Methods
    
    private func fetchHeartRateVariability(completion: @escaping (Double) -> Void) {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -1, to: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: hrvType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { _, result, error in
            guard let result = result, let average = result.averageQuantity() else {
                completion(0.0)
                return
            }
            
            let hrv = average.doubleValue(for: HKUnit.secondUnit(with: .milli))
            completion(hrv)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchRestingHeartRate(completion: @escaping (Double) -> Void) {
        guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .day, value: -1, to: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: restingHRType,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { _, result, error in
            guard let result = result, let average = result.averageQuantity() else {
                completion(0.0)
                return
            }
            
            let restingHR = average.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            completion(restingHR)
        }
        
        healthStore.execute(query)
    }
}

// MARK: - Data Models

struct SleepData: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let quality: Double
} 