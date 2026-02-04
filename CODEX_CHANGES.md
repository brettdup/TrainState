# Codex Changes

## Rules
- Keep this file in the repo root and update it with each Codex change.
- If this file is missing, recreate it before completing work.

## 2026-02-04
- Fixed Liquid Glass card styling in `TrainState/Views/Components/LiquidGlass.swift` by adding optional interactive glass support and switching the pre-iOS-26 fallback to `ultraThinMaterial`.
- Wrapped multi-card scroll stacks with `GlassEffectContainer` via `.glassEffectContainer(...)` in:
  - `TrainState/Views/AddWorkoutView.swift`
  - `TrainState/Views/EditWorkoutView.swift`
  - `TrainState/Views/WorkoutDetailView.swift`
  - `TrainState/Views/SettingsView.swift`
- Goal: improve consistency/performance of Liquid Glass rendering and reduce staggered card load behavior.
- Rule update: confirm the changes log exists; create it if missing.
- Made Liquid Glass cards interactive by default in `TrainState/Views/Components/LiquidGlass.swift` so card surfaces feel more reactive.
