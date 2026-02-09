import SwiftUI
import SwiftData
import RevenueCatUI

struct AddWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query private var workouts: [Workout]
    @Query(sort: \WorkoutSubcategory.name) private var allSubcategories: [WorkoutSubcategory]
    @Query(sort: \SubcategoryExercise.name) private var exerciseTemplates: [SubcategoryExercise]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var type: WorkoutType = .other
    @State private var date = Date()
    @State private var durationMinutes = 30.0
    @State private var distanceKilometers = 0.0
    @State private var workoutRating: Double?
    @State private var notes = ""
    @State private var selectedCategories: [WorkoutCategory] = []
    @State private var selectedSubcategories: [WorkoutSubcategory] = []
    @State private var exerciseEntries: [ExerciseLogEntry] = []
    @State private var strengthEntryMode: StrengthEntryMode = .manual
    @State private var showingLiveStrengthSession = false
    @State private var showingCategoryPicker = false
    @State private var activeExerciseSelection: ExerciseEditorSelection?
    @State private var showingPaywall = false
    @State private var isSaving = false
    @State private var showingExerciseLinkAlert = false

    private let quickDurations: [Double] = [15, 30, 45, 60, 90, 120]
    private var durationBinding: Binding<Double> {
        Binding(
            get: { durationMinutes },
            set: { durationMinutes = min(max($0, 0), 600) }
        )
    }
    private var distanceBinding: Binding<Double> {
        Binding(
            get: { distanceKilometers },
            set: { distanceKilometers = min(max($0, 0), 200) }
        )
    }
    private var workoutRatingBinding: Binding<Double> {
        Binding(
            get: { workoutRating ?? 5.0 },
            set: { workoutRating = min(max($0, 0), 10) }
        )
    }
    private var canAddWorkout: Bool {
        guard purchaseManager.hasCompletedInitialPremiumCheck else { return true }
        return purchaseManager.hasActiveSubscription || workouts.count < PremiumLimits.freeWorkoutLimit
    }
    private var showsDistance: Bool {
        [.running, .cycling, .swimming].contains(type)
    }
    private var isStrengthSessionType: Bool {
        type == .strength
    }
    private var availableExerciseSubcategories: [WorkoutSubcategory] {
        if !selectedSubcategories.isEmpty { return selectedSubcategories }
        return allSubcategories.filter { $0.category?.workoutType == type || $0.category?.workoutType == nil }
    }
    private var quickAddOptions: [ExerciseQuickAddOption] {
        var options: [ExerciseQuickAddOption] = []
        for subcategory in availableExerciseSubcategories {
            let templates = exerciseTemplates
                .filter { $0.subcategory?.id == subcategory.id }
                .sorted { $0.orderIndex < $1.orderIndex }
            if templates.isEmpty {
                options.append(ExerciseQuickAddOption(name: subcategory.name, subcategoryID: subcategory.id))
            } else {
                options.append(contentsOf: templates.map {
                    ExerciseQuickAddOption(name: $0.name, subcategoryID: subcategory.id)
                })
            }
        }
        return options
    }
    private var trackedExerciseCount: Int {
        exerciseEntries.filter { !$0.trimmedName.isEmpty }.count
    }
    private var completedExerciseDetailsCount: Int {
        exerciseEntries.filter {
            !$0.trimmedName.isEmpty &&
            $0.sets != nil &&
            $0.reps != nil &&
            $0.weight != nil
        }.count
    }
    private var suggestedQuickAddOptions: [ExerciseQuickAddOption] {
        var seen: Set<String> = []
        let existing = Set(
            exerciseEntries
                .map(\.trimmedName)
                .filter { !$0.isEmpty }
                .map { $0.lowercased() }
        )

        return quickAddOptions.compactMap { option in
            let key = "\(option.subcategoryID.uuidString)-\(option.name.lowercased())"
            guard !seen.contains(key), !existing.contains(option.name.lowercased()) else { return nil }
            seen.insert(key)
            return option
        }
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
                        if isStrengthSessionType {
                            strengthModeCard
                        }
                        if !isStrengthSessionType || strengthEntryMode == .manual {
                            durationCard
                        }
                        if showsDistance { distanceCard }
                        ratingCard
                        categoriesCard
                        if !isStrengthSessionType || strengthEntryMode == .manual {
                            exercisesCard
                        } else {
                            liveSessionInfoCard
                        }
                        notesCard
                        saveButton
                    }
                    .glassEffectContainer(spacing: 20)
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
        .sheet(item: $activeExerciseSelection) { selection in
            if let index = exerciseEntries.firstIndex(where: { $0.id == selection.id }) {
                ExerciseEditorSheetView(
                    entry: $exerciseEntries[index],
                    availableSubcategories: availableExerciseSubcategories,
                    availableOptions: quickAddOptions,
                    onDelete: {
                        exerciseEntries.removeAll { $0.id == selection.id }
                    }
                )
            } else {
                EmptyView()
            }
        }
        .alert("Link Exercises to Subcategories", isPresented: $showingExerciseLinkAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Each exercise must be linked to a subcategory before saving.")
        }
        .fullScreenCover(isPresented: $showingLiveStrengthSession) {
            LiveStrengthSessionView(
                typeTintColor: type.tintColor,
                availableSubcategories: availableExerciseSubcategories,
                quickAddOptions: quickAddOptions,
                initialEntries: exerciseEntries
            ) { completedEntries, startedAt, duration in
                exerciseEntries = completedEntries
                date = startedAt
                durationMinutes = duration / 60.0
                saveStrengthWorkout(startDate: startedAt, duration: duration, entries: completedEntries)
            } onCancel: { draftEntries in
                exerciseEntries = draftEntries
            }
        }
        .onChange(of: type) { _, _ in
            selectedCategories.removeAll()
            selectedSubcategories.removeAll()
            let allowedIDs = Set(availableExerciseSubcategories.map(\.id))
            exerciseEntries = exerciseEntries.map {
                var entry = $0
                if let id = entry.subcategoryID, !allowedIDs.contains(id) {
                    entry.subcategoryID = nil
                }
                return entry
            }
            if type == .strength && exerciseEntries.isEmpty {
                exerciseEntries = [defaultExerciseEntry()]
            }
            if type != .strength {
                strengthEntryMode = .manual
            }
        }
        .onAppear {
            if type == .strength && exerciseEntries.isEmpty {
                exerciseEntries = [defaultExerciseEntry()]
            }
        }
        .onChange(of: activeExerciseSelection) { _, newValue in
            if newValue == nil {
                exerciseEntries.removeAll { $0.isEmpty }
            }
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

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 10)], spacing: 10) {
                ForEach(quickDurations, id: \.self) { mins in
                    Button {
                        durationMinutes = mins
                    } label: {
                        Text("\(Int(mins)) min")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
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

            HStack(spacing: 8) {
                TextField(
                    "Duration",
                    value: durationBinding,
                    format: .number.precision(.fractionLength(0...2))
                )
                .keyboardType(.decimalPad)
                .font(.title3.weight(.semibold))

                Text("min")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var strengthModeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Strength Mode")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Strength Mode", selection: $strengthEntryMode) {
                ForEach(StrengthEntryMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var liveSessionInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Strength Session")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Use a dedicated live screen so the session can't be dismissed by accident. You can leave and return to the app while it runs.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

            HStack(spacing: 8) {
                TextField(
                    "Distance",
                    value: distanceBinding,
                    format: .number.precision(.fractionLength(0...3))
                )
                .keyboardType(.decimalPad)
                .font(.title3.weight(.semibold))

                Text("km")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()
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

    private var ratingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workout Rating")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if workoutRating == nil {
                Button {
                    workoutRating = 5.0
                } label: {
                    Label("Add Rating", systemImage: "star")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(type.tintColor.opacity(0.18))
                        )
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(String(format: "%.1f / 10", workoutRating ?? 0))
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Button("Clear") {
                            workoutRating = nil
                        }
                        .font(.caption.weight(.semibold))
                    }

                    Slider(value: workoutRatingBinding, in: 0...10, step: 0.5)
                        .tint(type.tintColor)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(cornerRadius: 32)
    }

    private var exercisesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Exercises")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    addAndEditNewExercise()
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(type.tintColor.opacity(0.18))
                        )
                }
                .buttonStyle(.plain)
            }

            HStack {
                Text("\(trackedExerciseCount) exercise\(trackedExerciseCount == 1 ? "" : "s") logged")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(completedExerciseDetailsCount) with full sets/reps/weight")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !suggestedQuickAddOptions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(suggestedQuickAddOptions.prefix(10)), id: \.id) { option in
                            Button {
                                addExercise(from: option)
                            } label: {
                                Text(option.name)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(type.tintColor.opacity(0.18))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if exerciseEntries.isEmpty {
                Text("Add sets/reps/weight to track lifts like Bench Press and calculate personal bests.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(exerciseEntries) { entry in
                        Button {
                            activeExerciseSelection = ExerciseEditorSelection(id: entry.id)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.trimmedName.isEmpty ? "Unnamed exercise" : entry.trimmedName)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    if let summary = exerciseSummary(for: entry) {
                                        Text(summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.04))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if quickAddOptions.isEmpty {
                Text("Select workout subcategories to unlock quick-add exercise chips.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
            if isStrengthSessionType && strengthEntryMode == .live {
                showingLiveStrengthSession = true
                return
            }
            guard !hasUnlinkedExercises(exerciseEntries) else {
                showingExerciseLinkAlert = true
                return
            }
            isSaving = true
            persistExerciseTemplates(from: exerciseEntries)
            let workout = Workout(
                type: type,
                startDate: date,
                duration: durationMinutes * 60,
                distance: showsDistance && distanceKilometers > 0 ? distanceKilometers : nil,
                rating: workoutRating,
                notes: notes.isEmpty ? nil : notes,
                categories: selectedCategories,
                subcategories: selectedSubcategories,
                exercises: exerciseEntries
                    .enumerated()
                    .compactMap { index, entry in
                        let name = entry.trimmedName
                        guard !name.isEmpty else { return nil }
                        let linkedSubcategory = allSubcategories.first { $0.id == entry.subcategoryID }
                        return WorkoutExercise(
                            name: name,
                            sets: entry.sets,
                            reps: entry.reps,
                            weight: entry.weight,
                            orderIndex: index,
                            subcategory: linkedSubcategory
                        )
                    }
            )
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
        if isStrengthSessionType {
            return strengthEntryMode == .live ? "Start Live Session" : "Save Workout"
        }
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

    private func saveWorkout(_ workout: Workout) {
        modelContext.insert(workout)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            isSaving = false
        }
    }

    private func saveStrengthWorkout(startDate: Date, duration: TimeInterval, entries: [ExerciseLogEntry]) {
        guard !hasUnlinkedExercises(entries) else {
            showingExerciseLinkAlert = true
            return
        }
        guard !isSaving else { return }
        isSaving = true
        persistExerciseTemplates(from: entries)
        let workout = Workout(
            type: .strength,
            startDate: startDate,
            duration: duration,
            distance: nil,
            rating: workoutRating,
            notes: notes.isEmpty ? nil : notes,
            categories: selectedCategories,
            subcategories: selectedSubcategories,
            exercises: entries.enumerated().compactMap { index, entry in
                let name = entry.trimmedName
                guard !name.isEmpty else { return nil }
                let linkedSubcategory = allSubcategories.first { $0.id == entry.subcategoryID }
                return WorkoutExercise(
                    name: name,
                    sets: entry.sets,
                    reps: entry.reps,
                    weight: entry.weight,
                    orderIndex: index,
                    subcategory: linkedSubcategory
                )
            }
        )
        saveWorkout(workout)
    }

    private func hasUnlinkedExercises(_ entries: [ExerciseLogEntry]) -> Bool {
        entries.contains { !$0.trimmedName.isEmpty && $0.subcategoryID == nil }
    }

    private func addAndEditNewExercise() {
        let newEntry = defaultExerciseEntry()
        exerciseEntries.append(newEntry)
        activeExerciseSelection = ExerciseEditorSelection(id: newEntry.id)
    }

    private func addExercise(from option: ExerciseQuickAddOption) {
        var entry = ExerciseLogEntry(name: option.name, subcategoryID: option.subcategoryID)
        if let recentMatch = exerciseEntries.last(where: { $0.subcategoryID == option.subcategoryID }) {
            entry.sets = recentMatch.sets
            entry.reps = recentMatch.reps
        }
        exerciseEntries.append(entry)
    }

    private func exerciseSummary(for entry: ExerciseLogEntry) -> String? {
        let setsText = entry.sets.map { "\($0)x" }
        let repsText = entry.reps.map { "\($0)" }
        let weightText: String? = {
            guard let w = entry.weight, w > 0 else { return nil }
            return String(format: "%.1f kg", w)
        }()

        let primary = [setsText, repsText].compactMap { $0 }.joined(separator: " ")
        let withWeight: String
        if let weightText {
            withWeight = primary.isEmpty ? weightText : "\(primary) · \(weightText)"
        } else {
            withWeight = primary
        }

        return withWeight.isEmpty ? nil : withWeight
    }

    private func persistExerciseTemplates(from entries: [ExerciseLogEntry]) {
        var insertedKeys: Set<String> = []
        for entry in entries {
            let name = entry.trimmedName
            guard !name.isEmpty, let subcategoryID = entry.subcategoryID else { continue }

            let key = "\(subcategoryID.uuidString)|\(name.lowercased())"
            guard !insertedKeys.contains(key) else { continue }

            let exists = exerciseTemplates.contains {
                $0.subcategory?.id == subcategoryID &&
                $0.name.caseInsensitiveCompare(name) == .orderedSame
            }
            guard !exists,
                  let subcategory = allSubcategories.first(where: { $0.id == subcategoryID }) else { continue }

            let order = exerciseTemplates.filter { $0.subcategory?.id == subcategoryID }.count
            let template = SubcategoryExercise(name: name, subcategory: subcategory, orderIndex: order)
            modelContext.insert(template)
            insertedKeys.insert(key)
        }
        if modelContext.hasChanges {
            try? modelContext.save()
        }
    }

    private func defaultExerciseEntry() -> ExerciseLogEntry {
        guard let firstSubcategory = availableExerciseSubcategories.first else { return ExerciseLogEntry() }
        let templates = quickAddOptions.filter { $0.subcategoryID == firstSubcategory.id }.map(\.name)
        return ExerciseLogEntry(
            name: templates.first ?? "",
            subcategoryID: firstSubcategory.id
        )
    }
}

private enum StrengthEntryMode: String, CaseIterable {
    case manual
    case live

    var title: String {
        switch self {
        case .manual: return "Manual"
        case .live: return "Live"
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
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
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
        .modelContainer(for: [Workout.self, WorkoutCategory.self, WorkoutSubcategory.self, WorkoutExercise.self, SubcategoryExercise.self], inMemory: true)
}
