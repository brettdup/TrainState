import SwiftUI
import SwiftData
import RevenueCatUI

struct AddWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var workouts: [Workout]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var type: WorkoutType = .other
    @State private var date = Date()
    @State private var durationMinutes = 30.0
    @State private var distanceKilometers = 0.0
    @State private var notes = ""
    @State private var selectedCategories: [WorkoutCategory] = []
    @State private var selectedSubcategories: [WorkoutSubcategory] = []
    @State private var showingCategoryPicker = false
    @State private var showingDuplicateAlert = false
    @State private var showingPaywall = false
    @State private var isSaving = false
    @State private var pendingWorkout: Workout?

    private let quickDurations: [Double] = [15, 30, 45, 60, 90, 120]
    private var canAddWorkout: Bool {
        purchaseManager.hasActiveSubscription || workouts.count < PremiumLimits.freeWorkoutLimit
    }
    private var showsDistance: Bool {
        [.running, .cycling, .swimming].contains(type)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.accentColor.opacity(colorScheme == .dark ? 0.4 : 0.2),
                        Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.1),
                        Color(.systemBackground)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        typeCard
                        dateCard
                        durationCard
                        if showsDistance { distanceCard }
                        categoriesCard
                        notesCard
                        saveButton
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .alert("Duplicate Workout", isPresented: $showingDuplicateAlert) {
            Button("Save Anyway") {
                if let workout = pendingWorkout {
                    saveWorkout(workout)
                }
                pendingWorkout = nil
            }
            Button("Cancel", role: .cancel) {
                pendingWorkout = nil
            }
        } message: {
            Text("A similar workout already exists for this time.")
        }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryAndSubcategorySelectionView(
                selectedCategories: $selectedCategories,
                selectedSubcategories: $selectedSubcategories,
                workoutType: type
            )
        }
        .sheet(isPresented: $showingPaywall) {
            if let offering = purchaseManager.offerings?.current {
                PaywallView(offering: offering)
            } else {
                PaywallPlaceholderView(onDismiss: { showingPaywall = false })
            }
        }
        .onChange(of: type) { _, _ in
            selectedCategories.removeAll()
            selectedSubcategories.removeAll()
        }
    }

    private var typeCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workout Type")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(WorkoutType.allCases) { workoutType in
                    TypeOptionButton(
                        type: workoutType,
                        isSelected: type == workoutType
                    ) {
                        type = workoutType
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Date & Time")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            DatePicker("", selection: $date)
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Duration")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(quickDurations, id: \.self) { mins in
                        Button {
                            durationMinutes = mins
                        } label: {
                            Text("\(Int(mins)) min")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 32)
                                        .fill(durationMinutes == mins ? type.tintColor.opacity(0.2) : Color.primary.opacity(0.06))
                                )
                                .foregroundStyle(durationMinutes == mins ? type.tintColor : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                Text("\(Int(durationMinutes)) min")
                    .font(.title3.weight(.semibold))
                Spacer()
                Stepper("", value: $durationMinutes, in: 5...600, step: 5)
                    .labelsHidden()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var distanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Distance")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack {
                Text(String(format: "%.1f km", distanceKilometers))
                    .font(.title3.weight(.semibold))
                Spacer()
                Stepper("", value: $distanceKilometers, in: 0...200, step: 0.5)
                    .labelsHidden()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                showingCategoryPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(type.tintColor)
                    Text(categoriesSummary)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notes")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("Add notes (optional)", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var saveButton: some View {
        Button {
            guard !isSaving else { return }
            guard canAddWorkout else {
                Task {
                    await purchaseManager.loadProducts()
                    await purchaseManager.updatePurchasedProducts()
                    showingPaywall = true
                }
                return
            }
            isSaving = true
            let workout = Workout(
                type: type,
                startDate: date,
                duration: durationMinutes * 60,
                distance: showsDistance && distanceKilometers > 0 ? distanceKilometers : nil,
                notes: notes.isEmpty ? nil : notes,
                categories: selectedCategories,
                subcategories: selectedSubcategories
            )
            if isDuplicate(workout) {
                pendingWorkout = workout
                showingDuplicateAlert = true
                isSaving = false
                return
            }
            saveWorkout(workout)
        } label: {
            HStack(spacing: 12) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                }
                Text(saveButtonTitle)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(type.tintColor)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    private var saveButtonTitle: String {
        if isSaving { return "Saving..." }
        if !canAddWorkout { return "Upgrade to Add More" }
        return "Save Workout"
    }

    private var categoriesSummary: String {
        var parts: [String] = []
        if !selectedCategories.isEmpty {
            parts.append(selectedCategories.map(\.name).joined(separator: ", "))
        }
        if !selectedSubcategories.isEmpty {
            parts.append(selectedSubcategories.map(\.name).joined(separator: ", "))
        }
        return parts.isEmpty ? "Select Categories" : parts.joined(separator: " · ")
    }

    private func isDuplicate(_ workout: Workout) -> Bool {
        var countDescriptor = FetchDescriptor<Workout>()
        countDescriptor.fetchLimit = 2
        let existingCount = (try? modelContext.fetch(countDescriptor).count) ?? 0
        if existingCount < 2 { return false }
        let startOfDay = Calendar.current.startOfDay(for: workout.startDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { existing in
                existing.startDate >= startOfDay && existing.startDate < endOfDay
            }
        )
        let sameDayWorkouts = (try? modelContext.fetch(descriptor)) ?? []
        if sameDayWorkouts.isEmpty { return false }
        return sameDayWorkouts.contains { existing in
            guard existing.type == workout.type else { return false }
            if abs(existing.startDate.timeIntervalSince(workout.startDate)) > 60 { return false }
            if abs(existing.duration - workout.duration) > 60 { return false }
            if let existingDistance = existing.distance, let newDistance = workout.distance {
                if abs(existingDistance - newDistance) > 0.1 { return false }
            } else if (existing.distance != nil) || (workout.distance != nil) {
                return false
            }
            if (existing.notes ?? "") != (workout.notes ?? "") { return false }
            let existingCategoryIDs = Set((existing.categories ?? []).map(\.id))
            let newCategoryIDs = Set((workout.categories ?? []).map(\.id))
            if existingCategoryIDs != newCategoryIDs { return false }
            let existingSubcategoryIDs = Set((existing.subcategories ?? []).map(\.id))
            let newSubcategoryIDs = Set((workout.subcategories ?? []).map(\.id))
            if existingSubcategoryIDs != newSubcategoryIDs { return false }
            return true
        }
    }

    private func saveWorkout(_ workout: Workout) {
        modelContext.insert(workout)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            isSaving = false
        }
    }
}

// MARK: - Type Option Button
private struct TypeOptionButton: View {
    let type: WorkoutType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.systemImage)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected ? type.tintColor : .secondary)
                    .frame(height: 28)
                Text(type.rawValue)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(isSelected ? type.tintColor.opacity(0.15) : Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddWorkoutView()
        .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self], inMemory: true)
}
