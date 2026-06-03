import SwiftUI

struct ExerciseSetInlineRow: View {
    @Binding var setEntry: ExerciseSetEntry
    let setIndex: Int
    let measurementSystem: MeasurementSystem
    let showsCompletion: Bool
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    var onStartRest: (() -> Void)?

    @State private var presentedMetric: SetMetricStepperSheet.Metric?

    private var weightUnitLabel: String {
        MeasurementFormatting.weightUnitLabel(for: measurementSystem)
    }

    private var weightDisplayText: String {
        let display = MeasurementFormatting.displayWeightFromStorage(setEntry.weight, system: measurementSystem)
        return MeasurementFormatting.displayWeight(display, system: measurementSystem)
    }

    var body: some View {
        HStack(spacing: 12) {
            if showsCompletion {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        setEntry.isCompleted.toggle()
                    }
                    HapticManager.lightImpact()
                } label: {
                    Image(systemName: setEntry.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(setEntry.isCompleted ? Color.green : Color.secondary)
                        .imageScale(.large)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: setEntry.isCompleted)
                }
                .buttonStyle(.plain)
            }

            Text("Set \(setIndex + 1)")
                .font(.subheadline.weight(.semibold))
                .frame(width: 52, alignment: .leading)

            Spacer(minLength: 4)

            Button {
                HapticManager.lightImpact()
                presentedMetric = .reps
            } label: {
                SetMetricCapsuleButton(
                    label: "Reps",
                    value: "\(setEntry.reps)",
                    minWidth: 62,
                    valueMinWidth: 14
                )
            }
            .buttonStyle(.plain)

            Button {
                HapticManager.lightImpact()
                presentedMetric = .weight
            } label: {
                SetMetricCapsuleButton(
                    label: weightUnitLabel,
                    value: weightDisplayText,
                    minWidth: 78,
                    valueMinWidth: 36
                )
            }
            .buttonStyle(.plain)

            if let onStartRest {
                Button(action: onStartRest) {
                    Image(systemName: "timer")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .sheet(item: $presentedMetric) { metric in
            SetMetricStepperSheet(
                metric: metric,
                measurementSystem: measurementSystem,
                reps: $setEntry.reps,
                weight: $setEntry.weight
            )
            .presentationDetents([.fraction(0.35), .medium])
            .presentationDragIndicator(.visible)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
    }
}
