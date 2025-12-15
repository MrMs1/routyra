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

    // MARK: - Exercise Entry Management

    /// Adds a new exercise entry to a workout day.
    /// - Parameters:
    ///   - workoutDay: The workout day to add to.
    ///   - exerciseId: The exercise definition ID.
    ///   - plannedSetCount: Number of planned sets (0 for no target).
    ///   - source: How the entry was added (routine or free).
    /// - Returns: The created entry.
    @discardableResult
    static func addEntry(
        to workoutDay: WorkoutDay,
        exerciseId: UUID,
        plannedSetCount: Int = 0,
        source: EntrySource = .free
    ) -> WorkoutExerciseEntry {
        let nextOrder = (workoutDay.entries.map(\.orderIndex).max() ?? -1) + 1

        let entry = WorkoutExerciseEntry(
            exerciseId: exerciseId,
            orderIndex: nextOrder,
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
}
