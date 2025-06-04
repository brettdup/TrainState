import SwiftUI
import Charts

struct HealthDashboardView: View {
    @StateObject private var healthManager = HealthManager.shared
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Sleep Section
                    SleepSectionView(sleepData: healthManager.sleepData)
                    
                    // Recovery Section
                    RecoverySectionView(recoveryScore: healthManager.recoveryScore)
                    
                    // Stress Section
                    StressSectionView(stressLevel: healthManager.stressLevel)
                }
                .padding()
            }
            .navigationTitle("Health Dashboard")
            .onAppear {
                healthManager.fetchSleepData(for: selectedDate)
                healthManager.calculateRecoveryScore()
                healthManager.calculateStressLevel()
            }
        }
    }
}

struct SleepSectionView: View {
    let sleepData: [SleepData]
    
    var totalSleepDuration: TimeInterval {
        sleepData.reduce(0) { $0 + $1.duration }
    }
    
    var averageSleepQuality: Double {
        sleepData.isEmpty ? 0 : sleepData.reduce(0) { $0 + $1.quality } / Double(sleepData.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sleep Analysis")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Sleep")
                        .font(.subheadline)
                    Text(formatDuration(totalSleepDuration))
                        .font(.title2)
                        .bold()
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Sleep Quality")
                        .font(.subheadline)
                    Text(String(format: "%.1f%%", averageSleepQuality * 100))
                        .font(.title2)
                        .bold()
                }
            }
            
            if !sleepData.isEmpty {
                Chart(sleepData) { data in
                    BarMark(
                        x: .value("Time", data.startTime),
                        y: .value("Duration", data.duration / 3600)
                    )
                    .foregroundStyle(Color.blue.opacity(0.8))
                }
                .frame(height: 100)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        return "\(hours)h \(minutes)m"
    }
}

struct RecoverySectionView: View {
    let recoveryScore: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recovery Status")
                .font(.headline)
            
            HStack {
                Text("Recovery Score")
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.0f%%", recoveryScore * 100))
                    .font(.title2)
                    .bold()
            }
            
            ProgressView(value: recoveryScore)
                .tint(recoveryScoreColor)
            
            Text(recoveryStatusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var recoveryScoreColor: Color {
        switch recoveryScore {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
    
    private var recoveryStatusText: String {
        switch recoveryScore {
        case 0.8...1.0: return "Fully recovered and ready for intense training"
        case 0.6..<0.8: return "Moderately recovered, consider moderate intensity"
        case 0.4..<0.6: return "Low recovery, focus on light activity"
        default: return "Poor recovery, prioritize rest"
        }
    }
}

struct StressSectionView: View {
    let stressLevel: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stress Level")
                .font(.headline)
            
            HStack {
                Text("Current Stress")
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.0f%%", stressLevel * 100))
                    .font(.title2)
                    .bold()
            }
            
            ProgressView(value: stressLevel)
                .tint(stressLevelColor)
            
            Text(stressStatusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var stressLevelColor: Color {
        switch stressLevel {
        case 0..<0.3: return .green
        case 0.3..<0.6: return .yellow
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
    
    private var stressStatusText: String {
        switch stressLevel {
        case 0..<0.3: return "Low stress level, optimal for training"
        case 0.3..<0.6: return "Moderate stress, consider recovery activities"
        case 0.6..<0.8: return "High stress, focus on stress management"
        default: return "Very high stress, prioritize rest and recovery"
        }
    }
}

#Preview {
    HealthDashboardView()
} 