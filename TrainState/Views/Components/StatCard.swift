import SwiftUI

struct StatCard: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
            
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.03), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    HStack {
        StatCard(icon: "dumbbell.fill", value: "5/15", color: .orange)
        StatCard(icon: "figure.run", value: "3/15", color: .blue)
        StatCard(icon: "calendar", value: "12", color: .purple)
    }
    .padding()
} 