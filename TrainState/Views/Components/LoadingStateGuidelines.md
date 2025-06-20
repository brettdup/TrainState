# Loading State Guidelines for TrainState

## Overview

This document outlines the standards and best practices for implementing loading states across the TrainState app to ensure consistent and delightful user experiences.

## Core Principles

### 1. **Always Show Feedback**

- Every async operation should provide immediate visual feedback
- Users should never wonder if their action was registered
- Loading states should appear within 100ms of user interaction

### 2. **Progressive Disclosure**

- Start with simple loading indicators
- Add more detail for longer operations (progress, status messages)
- Provide context about what's happening

### 3. **Graceful Degradation**

- Handle errors elegantly with retry options
- Provide fallback content when possible
- Never leave users in a broken state

## Loading State Hierarchy

### Quick Operations (< 2 seconds)

- **Use**: `InlineLoadingView` or button loading states
- **Example**: Saving settings, quick API calls

```swift
LoadingButton(
    title: "Save Settings",
    isLoading: isSaving,
    action: saveSettings
)
```

### Medium Operations (2-10 seconds)

- **Use**: `LoadingCard` or `StateView(.loading)`
- **Example**: Loading workout list, syncing data

```swift
if isLoading {
    LoadingCard(message: "Loading workouts...")
} else {
    WorkoutListContent()
}
```

### Long Operations (> 10 seconds)

- **Use**: `AnimatedLoadingView` with progress
- **Example**: HealthKit import, CloudKit backup

```swift
AnimatedLoadingView(
    title: "Importing HealthKit Data",
    subtitle: "This may take a few minutes...",
    progress: importProgress
)
```

### Full-Screen Operations

- **Use**: `LoadingOverlay` or navigation to dedicated loading view
- **Example**: App initialization, major data migrations

```swift
.loadingOverlay(
    isLoading: isInitializing,
    message: "Setting up your workspace..."
)
```

## Component Guide

### Loading Overlay

```swift
// Basic usage
.loadingOverlay(isLoading: isLoading)

// With custom message
.loadingOverlay(
    isLoading: isLoading,
    message: "Syncing with iCloud..."
)

// Without background dimming
.loadingOverlay(
    isLoading: isLoading,
    message: "Saving...",
    showBackground: false
)
```

### StateView for Different States

```swift
// Loading state
StateView(state: .loading("Fetching data..."))

// Empty state
StateView(state: .empty(
    "No workouts found",
    "Add your first workout to get started"
))

// Error state with retry
StateView(state: .error(
    "Connection failed",
    "Check your internet connection and try again",
    { retryAction() }
))

// Success state
StateView(state: .success(
    "Import complete!",
    "Successfully imported 247 workouts"
))
```

### LoadingButton for Actions

```swift
LoadingButton(
    title: "Backup to iCloud",
    isLoading: isBackingUp,
    action: startBackup
)
```

## Implementation Checklist

### For Every Async Operation:

- [ ] **Immediate Feedback**: Loading state appears instantly
- [ ] **Clear Messaging**: User knows what's happening
- [ ] **Progress Indication**: For operations > 5 seconds
- [ ] **Error Handling**: Graceful failure with retry options
- [ ] **Success Feedback**: Confirmation when complete
- [ ] **Disable Interactions**: Prevent multiple submissions
- [ ] **Accessibility**: VoiceOver announcements for state changes

### Code Pattern:

```swift
@State private var isLoading = false
@State private var errorMessage: String?

private func performAction() {
    isLoading = true
    errorMessage = nil

    Task {
        do {
            try await someAsyncOperation()
            // Success feedback
            await MainActor.run {
                isLoading = false
                // Show success state or navigate
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
```

## Specific Use Cases

### CloudKit Operations

```swift
// Backup creation
AnimatedLoadingView(
    title: "Creating backup",
    subtitle: "Preparing your data for iCloud...",
    progress: backupProgress
)

// Backup deletion
.loadingOverlay(
    isLoading: isDeletingBackups,
    message: "Deleting backups..."
)
```

### HealthKit Integration

```swift
// Import process
AnimatedLoadingView(
    title: "Importing workouts",
    subtitle: "Reading data from Apple Health...",
    progress: importProgress,
    gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
)
```

### Network Operations

```swift
// List loading
if isLoading {
    LoadingCard(message: "Loading workouts...")
} else if workouts.isEmpty {
    StateView(state: .empty("No workouts", "Add your first workout"))
} else {
    ForEach(workouts) { workout in
        WorkoutRow(workout: workout)
    }
}
```

## Animation Guidelines

### Timing

- **Appearance**: 0.2s ease-out
- **Progress**: 0.3s spring animation
- **Completion**: 0.5s with celebration (for long operations)

### Visual Elements

- **Pulse effects** for ongoing operations
- **Progress rings** for measured progress
- **Particle effects** for successful completion
- **Color coding** for different states (blue=loading, green=success, red=error)

## Testing Checklist

- [ ] All loading states are visually consistent
- [ ] Loading appears within 100ms of user action
- [ ] Progress updates smoothly and accurately
- [ ] Error states provide clear next steps
- [ ] Success states feel celebratory but not intrusive
- [ ] VoiceOver announces state changes
- [ ] Loading states work in both light and dark mode

## Common Patterns

### List Loading with Pull-to-Refresh

```swift
List {
    if isLoading && workouts.isEmpty {
        LoadingCard(message: "Loading workouts...")
    } else {
        ForEach(workouts) { workout in
            WorkoutRow(workout: workout)
        }
    }
}
.refreshable {
    await refreshWorkouts()
}
```

### Form Submission

```swift
VStack {
    // Form fields...

    LoadingButton(
        title: "Create Workout",
        isLoading: isCreating,
        action: createWorkout
    )
    .disabled(!isFormValid)
}
.loadingOverlay(
    isLoading: isCreating,
    message: "Creating workout...",
    showBackground: false
)
```

### Progressive Loading

```swift
VStack {
    if authStatus == .loading {
        InlineLoadingView(message: "Checking permissions...")
    } else if authStatus == .denied {
        StateView(state: .error(
            "Permission Required",
            "Enable HealthKit access in Settings",
            openSettings
        ))
    } else {
        WorkoutContent()
    }
}
```

Remember: Great loading states make users feel confident and informed, not anxious or confused!
