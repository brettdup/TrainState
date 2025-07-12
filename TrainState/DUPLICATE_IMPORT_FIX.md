# Duplicate Workout Import Fix

## Problem
The app was constantly importing duplicate workouts from HealthKit, causing the phone to overheat due to:
1. **Continuous import loops** - Pull-to-refresh always triggered full HealthKit imports
2. **No duplicate prevention** - The app didn't check if workouts were already imported
3. **Concurrent imports** - Multiple import operations could run simultaneously
4. **No rate limiting** - Users could trigger imports too frequently

## Root Causes
1. **WorkoutListView.refreshData()** - Always called `HealthKitManager.importWorkoutsToCoreData()` without checking for new workouts
2. **HealthKitManager** - Had basic duplicate prevention but could be bypassed
3. **No import frequency limits** - Users could spam refresh/import buttons
4. **Route processing overhead** - Processing GPS routes for all workouts, even duplicates

## Fixes Implemented

### 1. Smart Refresh Logic (WorkoutListView.swift)
- **Time-based rate limiting**: Prevents refreshes more frequent than 30 seconds
- **Import frequency check**: Prevents HealthKit imports more frequent than 5 minutes
- **New workout detection**: Only imports if there are actually new workouts in HealthKit
- **Concurrent refresh prevention**: Prevents multiple refresh operations from running simultaneously

### 2. Enhanced Duplicate Prevention (HealthKitManager.swift)
- **Concurrent import prevention**: Static flag prevents multiple import operations
- **Improved fuzzy matching**: More granular duplicate detection using:
  - 10-second time buckets (vs 5-second)
  - 10-second duration buckets (vs 5-second)
  - 10-calorie buckets
  - 50-meter distance buckets
- **Better logging**: Tracks added vs skipped workouts
- **Conditional route processing**: Only processes GPS routes for new workouts

### 3. Performance Optimizations
- **Reduced route processing**: Max 500 GPS points per route (vs 1000)
- **Fewer concurrent tasks**: Max 2 concurrent route fetches (vs 3)
- **More frequent saves**: Save every 10 workouts (vs 20)
- **Memory management**: Better task yielding and memory cleanup

### 4. Rate Limiting (HealthSettingsView.swift)
- **2-minute import cooldown**: Prevents rapid successive imports
- **User feedback**: Clear error messages when rate limited
- **Import tracking**: Tracks last import time to enforce limits

## Key Changes

### WorkoutListView.swift
```swift
// Added rate limiting and smart refresh
private func refreshData() async {
    guard !isRefreshing else { return }
    
    // 30-second refresh rate limit
    if let lastRefresh = lastRefreshTime,
       Date().timeIntervalSince(lastRefresh) < 30 { return }
    
    // 5-minute import rate limit
    let timeSinceLastImport = lastImportDate?.timeIntervalSinceNow ?? -3600
    if timeSinceLastImport > -300 { return }
    
    // Check for new workouts before importing
    let hasNewWorkouts = await checkForNewWorkouts()
    if !hasNewWorkouts { return }
    
    // Perform import only if needed
    try await HealthKitManager.shared.importWorkoutsToCoreData(context: modelContext)
}
```

### HealthKitManager.swift
```swift
// Added concurrent import prevention
static var isImporting = false
guard !isImporting else { return }
isImporting = true
defer { isImporting = false }

// Enhanced duplicate detection
struct FuzzyKey: Hashable {
    let type: WorkoutType
    let startBucket: Int      // 10-second buckets
    let durationBucket: Int   // 10-second buckets
    let caloriesBucket: Int?  // 10-calorie buckets
    let distanceBucket: Int?  // 50-meter buckets
}

// Conditional route processing
if newWorkoutsAdded > 0 {
    // Only process routes for new workouts
    await processRoutes(for: runningWorkoutsToRoute)
}
```

## Benefits
1. **Prevents overheating** - Eliminates continuous import loops
2. **Better performance** - Reduces unnecessary processing
3. **User experience** - Clear feedback and reasonable rate limits
4. **Battery life** - Significantly reduces CPU and memory usage
5. **Data integrity** - Better duplicate prevention

## Testing
- Test pull-to-refresh rate limiting
- Test import frequency limits
- Verify duplicate prevention works
- Check that new workouts are still imported correctly
- Monitor CPU usage and battery drain

## Future Improvements
- Add background refresh with smart timing
- Implement incremental sync (only fetch recent workouts)
- Add import progress indicators
- Consider caching HealthKit workout metadata 