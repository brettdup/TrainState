import SwiftUI
import SwiftData
import MapKit

// MARK: - Header Card
struct WorkoutDetailHeaderCard: View {
    let workout: Workout
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                    Image(systemName: WorkoutTypeHelper.iconForType(workout.type))
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(workout.type.rawValue)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(DateFormatHelper.friendlyDateTime(workout.startDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.secondary.opacity(0.08))
                .padding(.horizontal, 20)
            
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text(DateFormatHelper.formattedDate(workout.startDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.07), radius: 12, y: 6)
        )
        .padding(.horizontal, 12)
    }
}

// MARK: - Info Card
struct WorkoutDetailInfoCard: View {
    let workout: Workout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Image(systemName: WorkoutTypeHelper.iconForType(workout.type))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.blue)
                Text(workout.type.rawValue)
                    .font(.title3.weight(.semibold))
                Spacer()
            }
            
            Divider().background(Color.secondary.opacity(0.08))
            
            HStack(spacing: 16) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
                Text(DurationFormatHelper.formatDuration(workout.duration))
                    .font(.body.weight(.medium))
                Spacer()
            }
            
            if let calories = workout.calories {
                HStack(spacing: 16) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(Int(calories)) cal")
                        .font(.body.weight(.medium))
                    Spacer()
                }
            }
            
            if let distance = workout.distance {
                HStack(spacing: 16) {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(.green)
                    Text(String(format: "%.1f km", distance / 1000))
                        .font(.body.weight(.medium))
                    Spacer()
                }
            }
            
            HStack(spacing: 16) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text(DateFormatHelper.formattedDate(workout.startDate))
                    .font(.body.weight(.medium))
                Spacer()
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.07), radius: 12, y: 6)
        )
        .padding(.horizontal, 12)
    }
}

// MARK: - Categories Card
struct WorkoutDetailCategoriesCard: View {
    @Bindable var workout: Workout
    let onEditTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Categories & Subcategories")
                    .font(.title3.weight(.semibold))
                Spacer()
                if !(workout.categories?.isEmpty ?? true) || !(workout.subcategories?.isEmpty ?? true) {
                    EditCategoriesButton(action: onEditTapped)
                }
            }
            
            if (workout.categories?.isEmpty ?? true) && (workout.subcategories?.isEmpty ?? true) {
                AddCategoriesButton(action: onEditTapped)
            } else {
                if let categories = workout.categories, !categories.isEmpty {
                    CategorySection(categories: categories)
                }
                if let subcategories = workout.subcategories, !subcategories.isEmpty {
                    SubcategorySection(subcategories: subcategories)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.07), radius: 12, y: 6)
        )
        .padding(.horizontal, 12)
    }
}

// MARK: - Notes Card
struct WorkoutDetailNotesCard: View {
    let notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notes")
                .font(.headline)
            Text(notes)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.07), radius: 12, y: 6)
        )
        .padding(.horizontal, 12)
    }
}

// MARK: - Supporting Components
private struct EditCategoriesButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.85), Color.blue.opacity(0.65)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                    )
                    .shadow(color: .blue.opacity(0.18), radius: 8, y: 3)
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .blue.opacity(0.18), radius: 2, y: 1)
            }
            .contentShape(Circle())
            .accessibilityLabel("Edit Categories")
        }
        .buttonStyle(.plain)
        .padding(.trailing, 2)
    }
}

private struct AddCategoriesButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                Text("Add Categories")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: .blue.opacity(0.08), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

private struct CategorySection: View {
    let categories: [WorkoutCategory]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories")
                .font(.headline)
                .foregroundStyle(.secondary)
            WrappingHStackLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(categories, id: \.id) { category in
                    CategoryChip(category: category)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}

private struct SubcategorySection: View {
    let subcategories: [WorkoutSubcategory]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subcategories")
                .font(.headline)
                .foregroundStyle(.secondary)
            WrappingHStackLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(subcategories, id: \.id) { subcategory in
                    SubcategoryChip(subcategory: subcategory)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Running Map and Stats Card
struct RunningMapAndStatsCard: View {
    let route: [CLLocation]
    let duration: TimeInterval
    let distance: Double?

    // Use mock route if real route is empty
    private var displayRoute: [CLLocation] {
        route.isEmpty ? RunningMapAndStatsCard.mockRoute : route
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Route Map & Splits")
                .font(.headline)
            Text("Route points: \(displayRoute.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            RouteMapView(route: displayRoute)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(radius: 6)
            if let pace = averagePaceString {
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundColor(.blue)
                    Text("Avg Pace: \(pace)")
                        .font(.body.weight(.medium))
                }
            }
            if !splits.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Splits")
                        .font(.subheadline.weight(.semibold))
                    ForEach(Array(splits.enumerated()), id: \.0) { (i, split) in
                        Text("\(i+1) km: \(split)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.07), radius: 12, y: 6)
        )
        .padding(.horizontal, 12)
    }

    // Average pace as min/km
    private var averagePaceString: String? {
        guard let distance = distance, distance > 0 else { return nil }
        let pace = duration / distance * 1000 // seconds per km
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d min/km", minutes, seconds)
    }

    // Splits per km
    private var splits: [String] {
        guard let distance = distance, distance > 0 else { return [] }
        var splits: [String] = []
        var splitStartTime = displayRoute.first?.timestamp ?? Date()
        var accumulatedDistance: Double = 0
        for i in 1..<displayRoute.count {
            let d = displayRoute[i].distance(from: displayRoute[i-1])
            accumulatedDistance += d
            if accumulatedDistance >= 1000 {
                let splitEndTime = displayRoute[i].timestamp
                let splitDuration = splitEndTime.timeIntervalSince(splitStartTime)
                let min = Int(splitDuration) / 60
                let sec = Int(splitDuration) % 60
                splits.append(String(format: "%d:%02d", min, sec))
                splitStartTime = splitEndTime
                accumulatedDistance = 0
            }
        }
        return splits
    }

    // Mock route for demo/testing
    static var mockRoute: [CLLocation] {
        let base = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let points = (0..<20).map { i -> CLLocation in
            let lat = base.latitude + Double(i) * 0.001
            let lon = base.longitude + sin(Double(i) * .pi / 10) * 0.002
            return CLLocation(latitude: lat, longitude: lon)
        }
        // Add timestamps for splits
        let startTime = Date()
        return points.enumerated().map { (i, loc) in
            CLLocation(coordinate: loc.coordinate, altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 2, timestamp: startTime.addingTimeInterval(Double(i) * 60))
        }
    }
} 