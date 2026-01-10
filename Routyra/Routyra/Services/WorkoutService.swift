//
//  WorkoutService.swift
//  Routyra
//
//  Service for managing workout days and entries.
//  Handles workout creation, entry management, and set operations.
//

import Foundation
import SwiftData

/// Service for workout day management.
enum WorkoutService {
    // MARK: - WorkoutDay Management

    /// Gets or creates a workout day for the given date and profile.
    /// Enforces the "1 workout per day per profile" constraint.
    /// - Parameters:
    ///   - profileId: The owner profile ID.
    ///   - date: The date for the workout (will be normalized).
    ///   - mode: The workout mode (free or routine).
    ///   - routinePresetId: Routine preset ID (required for routine mode).
    ///   - routineDayId: Routine day ID (required for routine mode).
    ///   - modelContext: The SwiftData model context.
    /// - Returns: The workout day (existing or newly created).
    @MainActor
    static func getOrCreateWorkoutDay(
        profileId: UUID,
        date: Date,
        mode: WorkoutMode = .free,
        routinePresetId: UUID? = nil,
        routineDayId: UUID? = nil,
        modelContext: ModelContext
    ) -> WorkoutDay {
        let normalizedDate = DateUtilities.startOfDay(date)

        // Try to find existing workout for this date
        if let existing = getWorkoutDay(profileId: profileId, date: normalizedDate, modelContext: modelContext) {
            return existing
        }

        // Create new workout day
        let workoutDay = WorkoutDay(
            profileId: profileId,
            date: normalizedDate,
            mode: mode,
            routinePresetId: routinePresetId,
            routineDayId: routineDayId
        )
        modelContext.insert(workoutDay)

        return workoutDay
    }

    /// Gets the workout day for a specific date.
    /// - Parameters:
    ///   - profileId: The owner profile ID.
    ///   - date: The date to look up.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: The workout day if it exists, nil otherwise.
    @MainActor
    static func getWorkoutDay(
        profileId: UUID,
        date: Date,
        modelContext: ModelContext
    ) -> WorkoutDay? {
        let normalizedDate = DateUtilities.startOfDay(date)

        var descriptor = FetchDescriptor<WorkoutDay>(
            predicate: #Predicate<WorkoutDay> { workout in
                workout.profileId == profileId && workout.date == normalizedDate
            }
        )
        descriptor.fetchLimit = 1

        do {
            let results = try modelContext.fetch(descriptor)
            return results.first
        } catch {
            print("Error fetching workout day: \(error)")
            return nil
        }
    }

    /// Gets today's workout day for the profile.
    /// - Parameters:
    ///   - profileId: The owner profile ID.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Today's workout day if it exists, nil otherwise.
    @MainActor
    static func getTodayWorkout(profileId: UUID, modelContext: ModelContext) -> WorkoutDay? {
        getWorkoutDay(profileId: profileId, date: Date(), modelContext: modelContext)
    }

    /// Checks if today's workout is linked to the specified plan day.
    /// - Parameters:
    ///   - profileId: The owner profile ID.
    ///   - planDayId: The plan day ID to check.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: The linked workout day if found, nil otherwise.
    @MainActor
    static func getTodayWorkoutLinkedToPlanDay(
        profileId: UUID,
        planDayId: UUID,
        modelContext: ModelContext
    ) -> WorkoutDay? {
        guard let todayWorkout = getTodayWorkout(profileId: profileId, modelContext: modelContext) else {
            return nil
        }

        guard todayWorkout.mode == .routine,
              todayWorkout.routineDayId == planDayId else {
            return nil
        }

        return todayWorkout
    }

    // MARK: - Exercise Entry Management

    /// Adds a new exercise entry to a workout day.
    /// - Parameters:
    ///   - workoutDay: The workout day to add to.
    ///   - exerciseId: The exercise definition ID.
    ///   - metricType: The metric type for sets in this entry.
    ///   - plannedSetCount: Number of planned sets (0 for no target).
    ///   - source: How the entry was added (routine or free).
    /// - Returns: The created entry.
    @discardableResult
    static func addEntry(
        to workoutDay: WorkoutDay,
        exerciseId: UUID,
        metricType: SetMetricType = .weightReps,
        plannedSetCount: Int = 0,
        source: EntrySource = .free
    ) -> WorkoutExerciseEntry {
        let nextOrder = (workoutDay.entries.map(\.orderIndex).max() ?? -1) + 1

        let entry = WorkoutExerciseEntry(
            exerciseId: exerciseId,
            orderIndex: nextOrder,
            metricType: metricType,
            source: source,
            plannedSetCount: plannedSetCount
        )

        workoutDay.addEntry(entry)
        return entry
    }

    /// Removes an exercise entry from a workout day.
    /// - Parameters:
    ///   - entry: The entry to remove.
    ///   - workoutDay: The workout day to remove from.
    static func removeEntry(_ entry: WorkoutExerciseEntry, from workoutDay: WorkoutDay) {
        workoutDay.removeEntry(entry)
    }

    /// Reorders entries in a workout day.
    /// - Parameters:
    ///   - workoutDay: The workout day.
    ///   - fromIndex: The current index.
    ///   - toIndex: The new index.
    static func reorderEntries(in workoutDay: WorkoutDay, from fromIndex: Int, to toIndex: Int) {
        var entries = workoutDay.sortedEntries
        guard fromIndex < entries.count && toIndex < entries.count else { return }

        let entry = entries.remove(at: fromIndex)
        entries.insert(entry, at: toIndex)

        // Update order indices
        for (index, entry) in entries.enumerated() {
            entry.orderIndex = index
        }

        workoutDay.touch()
    }

    // MARK: - Set Management

    /// Logs a new set for an exercise entry.
    /// - Parameters:
    ///   - entry: The exercise entry.
    ///   - weight: Weight in kg.
    ///   - reps: Number of repetitions.
    ///   - isCompleted: Whether the set is completed (default true for logging).
    /// - Returns: The created set.
    @discardableResult
    static func logSet(
        for entry: WorkoutExerciseEntry,
        weight: Decimal,
        reps: Int,
        isCompleted: Bool = true
    ) -> WorkoutSet {
        let set = entry.createSet(weight: weight, reps: reps, isCompleted: isCompleted)
        return set
    }

    /// Logs a set using Double for weight (UI convenience).
    @discardableResult
    static func logSet(
        for entry: WorkoutExerciseEntry,
        weightDouble: Double,
        reps: Int,
        isCompleted: Bool = true
    ) -> WorkoutSet {
        logSet(for: entry, weight: Decimal(weightDouble), reps: reps, isCompleted: isCompleted)
    }

    /// Logs a bodyweight reps set (no weight, just reps).
    @discardableResult
    static func logBodyweightSet(
        for entry: WorkoutExerciseEntry,
        reps: Int,
        isCompleted: Bool = true
    ) -> WorkoutSet {
        let set = entry.createSet(
            weight: nil,
            reps: reps,
            durationSeconds: nil,
            distanceMeters: nil,
            isCompleted: isCompleted
        )
        return set
    }

    /// Logs a time/distance set (for cardio exercises).
    @discardableResult
    static func logTimeDistanceSet(
        for entry: WorkoutExerciseEntry,
        durationSeconds: Int,
        distanceMeters: Double? = nil,
        isCompleted: Bool = true
    ) -> WorkoutSet {
        let set = entry.createSet(
            weight: nil,
            reps: nil,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            isCompleted: isCompleted
        )
        return set
    }

    /// Logs a completion-only set (no metrics, just marked as done).
    @discardableResult
    static func logCompletionSet(
        for entry: WorkoutExerciseEntry,
        isCompleted: Bool = true
    ) -> WorkoutSet {
        let set = entry.createSet(
            weight: nil,
            reps: nil,
            durationSeconds: nil,
            distanceMeters: nil,
            isCompleted: isCompleted
        )
        return set
    }

    /// Generic log set for any metric type.
    @discardableResult
    static func logSet(
        for entry: WorkoutExerciseEntry,
        weight: Decimal? = nil,
        reps: Int? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Double? = nil,
        isCompleted: Bool = true
    ) -> WorkoutSet {
        let set = entry.createSet(
            weight: weight,
            reps: reps,
            durationSeconds: durationSeconds,
            distanceMeters: distanceMeters,
            isCompleted: isCompleted
        )
        return set
    }

    /// Marks a set as completed.
    /// - Parameters:
    ///   - set: The set to complete.
    ///   - weight: Optional new weight (updates if provided).
    ///   - reps: Optional new reps (updates if provided).
    static func completeSet(_ set: WorkoutSet, weight: Decimal? = nil, reps: Int? = nil) {
        if let weight = weight {
            set.weight = weight
        }
        if let reps = reps {
            set.reps = reps
        }
        set.complete()
    }

    /// Marks a set as not completed (undo).
    /// - Parameter set: The set to uncomplete.
    static func uncompleteSet(_ set: WorkoutSet) {
        set.uncomplete()
    }

    /// Soft-deletes a set.
    /// - Parameter set: The set to delete.
    static func deleteSet(_ set: WorkoutSet) {
        set.softDelete()
    }

    /// Restores a soft-deleted set.
    /// - Parameter set: The set to restore.
    static func restoreSet(_ set: WorkoutSet) {
        set.restore()
    }

    /// Updates a set's weight and reps.
    /// - Parameters:
    ///   - set: The set to update.
    ///   - weight: New weight.
    ///   - reps: New reps.
    static func updateSet(_ set: WorkoutSet, weight: Decimal, reps: Int) {
        set.update(weight: weight, reps: reps)
    }

    // MARK: - Validation

    /// Validates set input based on metric type.
    /// - Parameters:
    ///   - metricType: The metric type of the set.
    ///   - weight: Weight value (for weightReps type).
    ///   - reps: Reps value (for weightReps and bodyweightReps types).
    ///   - durationSeconds: Duration in seconds (for timeDistance type).
    ///   - distanceMeters: Distance in meters (optional, for timeDistance type).
    /// - Returns: true if input is valid, false otherwise.
    static func validateSetInput(
        metricType: SetMetricType,
        weight: Double,
        reps: Int,
        durationSeconds: Int = 0,
        distanceMeters: Double? = nil
    ) -> Bool {
        switch metricType {
        case .weightReps:
            return weight > 0 && reps > 0
        case .bodyweightReps:
            return reps > 0
        case .timeDistance:
            return durationSeconds > 0
        case .completion:
            return true
        }
    }

    // MARK: - Placeholder Set Creation Strategy
    //
    // Decision: We use LAZY set creation by default.
    //
    // Rationale:
    // - Simpler data model with fewer database writes
    // - Sets are only created when user actually logs them
    // - Planned set count is tracked at the entry level
    // - Works well with the completion logic (completedSetsCount >= plannedSetCount)
    //
    // Alternative approach (pre-create placeholder sets):
    // - Call entry.createPlaceholderSets() when expanding routine to workout
    // - Each placeholder set has isCompleted = false
    // - User completes sets in order, updating weight/reps
    //
    // The lazy approach is preferred for a workout logger where users might
    // not complete all planned sets, and we don't want empty placeholder data.

    // MARK: - Workout Statistics

    /// Gets statistics for a workout day.
    /// - Parameter workoutDay: The workout day.
    /// - Returns: A tuple of (completedSets, totalVolume, exerciseCount).
    static func getStatistics(for workoutDay: WorkoutDay) -> (sets: Int, volume: Decimal, exercises: Int) {
        (
            sets: workoutDay.totalCompletedSets,
            volume: workoutDay.totalVolume,
            exercises: workoutDay.totalExercisesWithSets
        )
    }

    /// Calculates the estimated one-rep max using the Epley formula.
    /// - Parameters:
    ///   - weight: The weight lifted.
    ///   - reps: The number of reps performed.
    /// - Returns: The estimated 1RM, or 0 if inputs are invalid.
    static func epleyOneRM(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        return weight * (1 + Double(reps) / 30.0)
    }

    // MARK: - Last Workout Lookup

    /// Gets the sets from the most recent workout for a specific exercise.
    /// - Parameters:
    ///   - profileId: The owner profile ID.
    ///   - exerciseId: The exercise ID to find.
    ///   - excludeDate: Optional date to exclude (e.g., current workout date).
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Array of (weight, reps) tuples if found, nil otherwise.
    @MainActor
    static func getLastWorkoutSets(
        profileId: UUID,
        exerciseId: UUID,
        excludeDate: Date? = nil,
        modelContext: ModelContext
    ) -> [(weight: Double, reps: Int)]? {
        // Fetch all workout days, sorted by date descending
        var descriptor = FetchDescriptor<WorkoutDay>(
            predicate: #Predicate<WorkoutDay> { workout in
                workout.profileId == profileId
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 30  // Look through recent workouts only

        do {
            let workoutDays = try modelContext.fetch(descriptor)

            // Normalize exclude date if provided
            let normalizedExcludeDate = excludeDate.map { DateUtilities.startOfDay($0) }

            for workoutDay in workoutDays {
                // Skip excluded date
                if let excludeDate = normalizedExcludeDate,
                   DateUtilities.isSameDay(workoutDay.date, excludeDate) {
                    continue
                }

                // Find matching entry
                for entry in workoutDay.sortedEntries {
                    if entry.exerciseId == exerciseId {
                        // Get active sets (non-deleted) with valid data
                        let activeSets = entry.sortedSets
                            .filter { ($0.weight ?? 0) > 0 || ($0.reps ?? 0) > 0 }

                        if activeSets.isEmpty {
                            continue
                        }

                        // Return the sets
                        return activeSets.map { set in
                            (weight: set.weightDouble, reps: set.reps ?? 0)
                        }
                    }
                }
            }

            return nil
        } catch {
            print("Error fetching last workout sets: \(error)")
            return nil
        }
    }

    /// Gets all workout history for an exercise as WorkoutCopyCandidate array.
    /// - Parameters:
    ///   - profileId: The owner profile ID.
    ///   - exerciseId: The exercise ID to find.
    ///   - limit: Maximum number of candidates to return.
    ///   - excludeDate: Optional date to exclude (e.g., current workout date).
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Array of WorkoutCopyCandidate sorted by date descending.
    @MainActor
    static func getWorkoutHistorySets(
        profileId: UUID,
        exerciseId: UUID,
        limit: Int = 20,
        excludeDate: Date? = nil,
        modelContext: ModelContext
    ) -> [WorkoutCopyCandidate] {
        // Fetch all workout days, sorted by date descending
        var descriptor = FetchDescriptor<WorkoutDay>(
            predicate: #Predicate<WorkoutDay> { workout in
                workout.profileId == profileId
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 100  // Look through more workouts for history

        var candidates: [WorkoutCopyCandidate] = []

        do {
            let workoutDays = try modelContext.fetch(descriptor)

            // Normalize exclude date if provided
            let normalizedExcludeDate = excludeDate.map { DateUtilities.startOfDay($0) }

            for workoutDay in workoutDays {
                // Check limit
                if candidates.count >= limit {
                    break
                }

                // Skip excluded date
                if let excludeDate = normalizedExcludeDate,
                   DateUtilities.isSameDay(workoutDay.date, excludeDate) {
                    continue
                }

                // Find matching entry
                for entry in workoutDay.sortedEntries {
                    if entry.exerciseId == exerciseId {
                        // Get active sets (non-deleted) with valid data
                        let activeSets = entry.sortedSets
                            .filter { ($0.weight ?? 0) > 0 || ($0.reps ?? 0) > 0 }

                        if activeSets.isEmpty {
                            continue
                        }

                        // Create candidate
                        let sets = activeSets.map { set in
                            CopyableSetData(
                                weight: set.weightDouble,
                                reps: set.reps ?? 0,
                                restTimeSeconds: set.restTimeSeconds
                            )
                        }

                        candidates.append(WorkoutCopyCandidate(
                            workoutDate: workoutDay.date,
                            sets: sets
                        ))
                    }
                }
            }

            return candidates
        } catch {
            print("Error fetching workout history sets: \(error)")
            return []
        }
    }
}
