import SwiftUI
import SwiftData
import MapKit

// MARK: - Header Card
struct WorkoutDetailHeaderCard: View {
    let workout: Workout
    
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: WorkoutTypeHelper.iconForType(workout.type))
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.type.rawValue)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    Text(DateFormatHelper.friendlyDateTime(workout.startDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                HeaderStatChip(
                    icon: "clock.fill",
                    title: "Duration",
                    value: DurationFormatHelper.formatDuration(workout.duration)
                )
                
                if let distance = workout.distance {
                    HeaderStatChip(
                        icon: "figure.walk",
                        title: "Distance",
                        value: String(format: "%.1f km", distance / 1000)
                    )
                }
                
                if let calories = workout.calories {
                    HeaderStatChip(
                        icon: "flame.fill",
                        title: "Calories",
                        value: "\(Int(calories)) kcal"
                    )
                }
            }
            
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text(DateFormatHelper.formattedDate(workout.startDate))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(24)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let card = Group {
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
            }
        }
        card
            .padding(.horizontal, 16)
    }
}

private struct HeaderStatChip: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.9))
        )
    }
}

// MARK: - Info Card
struct WorkoutDetailInfoCard: View {
    let workout: Workout
    
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 18) {
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
        .padding(28)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let card = Group {
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
            }
        }
        card
            .padding(.horizontal, 16)
    }
}

// MARK: - Categories Card
struct WorkoutDetailCategoriesCard: View {
    @Bindable var workout: Workout
    let onEditTapped: () -> Void
    
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Categories")
                    .font(.headline)
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
        .padding(28)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let card = Group {
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
            }
        }
        card
            .padding(.horizontal, 16)
    }
}

// MARK: - Notes Card
struct WorkoutDetailNotesCard: View {
    let notes: String
    
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 14) {
            Text("Notes")
                .font(.headline)
                .foregroundStyle(.primary)
            Text(notes)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let card = Group {
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
            }
        }
        card
            .padding(.horizontal, 16)
    }
}

// MARK: - Supporting Components
private struct EditCategoriesButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            let label = Label("Edit", systemImage: "pencil")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            label
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private struct AddCategoriesButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            let label = Label("Add Categories", systemImage: "plus.circle")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            label
        }
        .buttonStyle(ScaleButtonStyle())
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
    @StateObject private var networkManager = NetworkManager.shared

    init(route: [CLLocation], duration: TimeInterval, distance: Double?) {
        self.route = route
        self.duration = duration
        self.distance = distance
    }

    // Use mock route if real route is empty
    private var displayRoute: [CLLocation] {
        route.isEmpty ? RunningMapAndStatsCard.mockRoute : route
    }

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Route & Splits")
                    .font(.headline)
                Spacer()
                if let pace = averagePaceString {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .foregroundColor(.blue)
                        Text(pace)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                    }
                }
            }

            if networkManager.isSafeToUseData {
                RouteMapView(route: displayRoute)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(radius: 6)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 220)
                    HStack(spacing: 8) {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.secondary)
                        Text("Map disabled on cellular to save data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .shadow(radius: 6)
            }

            if !splits.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Splits")
                        .font(.subheadline.weight(.semibold))
                    ForEach(Array(splits.enumerated()), id: \.0) { (i, split) in
                        HStack {
                            Text("\(i+1) km")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(split)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(24)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let card = Group {
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
            }
        }
        card
            .padding(.horizontal, 16)
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

// MARK: - Exercises Card
struct WorkoutDetailExercisesCard: View {
    let exercises: [WorkoutExercise]
    
    var body: some View {
        let content = VStack(alignment: .leading, spacing: 16) {
            Text("Exercises")
                .font(.title3.weight(.semibold))
            
            VStack(spacing: 12) {
                ForEach(exercises, id: \.id) { exercise in
                    ExerciseRow(exercise: exercise)
                }
            }
        }
        .padding(28)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let card = Group {
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            } else {
                content
                    .background(.ultraThinMaterial, in: shape)
            }
        }
        card
            .padding(.horizontal, 16)
    }
}

private struct ExerciseRow: View {
    let exercise: WorkoutExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            
            HStack(spacing: 16) {
                if let sets = exercise.sets {
                    Label("\(sets) sets", systemImage: "number")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let reps = exercise.reps {
                    Label("\(reps) reps", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let weight = exercise.weight {
                    Label(String(format: "%.1f kg", weight), systemImage: "scalemass")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
