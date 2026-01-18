//
//  GroupService.swift
//  Routyra
//
//  Service for managing exercise groups.
//  Handles group creation, dissolution, set count synchronization, and workout expansion.
//

import Foundation
import SwiftData

// MARK: - Set Count Resolution

/// Options for resolving set count mismatches when creating a group.
enum SetCountResolution {
    /// Use the maximum set count from all exercises.
    case maximum
    /// Use the minimum set count from all exercises.
    case minimum
    /// Use a manually specified value.
    case manual(Int)
}

// MARK: - Group Service

/// Service for managing exercise groups.
enum GroupService {

    // MARK: - Plan Group Management

    /// Creates a new exercise group from selected exercises.
    /// - Parameters:
    ///   - planDay: The plan day to add the group to.
    ///   - exercises: The exercises to group (must be 2+).
    ///   - setCount: The set count for the group.
    ///   - roundRestSeconds: Rest time after each round (optional).
    ///   - modelContext: The model context.
    /// - Returns: The created group, or nil if less than 2 exercises.
    @MainActor
    static func createGroup(
        in planDay: PlanDay,
        exercises: [PlanExercise],
        setCount: Int,
        roundRestSeconds: Int? = nil,
        modelContext: ModelContext
    ) -> PlanExerciseGroup? {
        guard exercises.count >= 2 else { return nil }

        // Keep input order (caller may pass selection order). De-dupe defensively.
        var seen: Set<UUID> = []
        let orderedExercises = exercises.filter { seen.insert($0.id).inserted }

        // Determine orderIndex from the minimum of selected exercises
        let minOrderIndex = orderedExercises.map(\.orderIndex).min() ?? 0

        // Create the group
        let group = PlanExerciseGroup(
            orderIndex: minOrderIndex,
            setCount: setCount,
            roundRestSeconds: roundRestSeconds
        )

        // Add group to plan day
        planDay.exerciseGroups.append(group)
        modelContext.insert(group)

        // Assign group order based on provided order (e.g. selection order)
        for (index, exercise) in orderedExercises.enumerated() {
            exercise.group = group
            exercise.groupOrderIndex = index
            exercise.plannedSetCount = setCount

            // Sync planned sets count
            syncExercisePlannedSets(exercise, targetCount: setCount)

            group.exercises.append(exercise)
        }

        return group
    }

    /// Dissolves a group, returning exercises to ungrouped state.
    /// - Parameters:
    ///   - group: The group to dissolve.
    ///   - planDay: The plan day containing the group.
    ///   - modelContext: The model context.
    @MainActor
    static func dissolveGroup(
        _ group: PlanExerciseGroup,
        in planDay: PlanDay,
        modelContext: ModelContext
    ) {
        // Reassign orderIndex to exercises based on group position
        let baseOrderIndex = group.orderIndex
        for (index, exercise) in group.sortedExercises.enumerated() {
            exercise.orderIndex = baseOrderIndex + index
            exercise.group = nil
            exercise.groupOrderIndex = nil
        }

        // Reindex remaining exercises to maintain order
        reindexExercisesAfterDissolve(in: planDay, startingFrom: baseOrderIndex + group.exerciseCount)

        // Remove group from plan day and delete
        group.exercises.removeAll()
        planDay.exerciseGroups.removeAll { $0.id == group.id }
        modelContext.delete(group)
    }

    /// Removes an exercise from a group.
    /// Auto-dissolves the group if less than 2 exercises remain.
    /// - Parameters:
    ///   - exercise: The exercise to remove.
    ///   - group: The group containing the exercise.
    ///   - planDay: The plan day.
    ///   - modelContext: The model context.
    @MainActor
    static func removeExerciseFromGroup(
        _ exercise: PlanExercise,
        group: PlanExerciseGroup,
        in planDay: PlanDay,
        modelContext: ModelContext
    ) {
        // Remove exercise from group
        group.removeExercise(exercise)
        exercise.group = nil
        exercise.groupOrderIndex = nil

        // Auto-dissolve if less than 2 exercises remain
        if group.exercises.count < 2 {
            dissolveGroup(group, in: planDay, modelContext: modelContext)
        }
    }

    /// Updates the set count for a group.
    /// Syncs the plannedSetCount to all exercises and adjusts their plannedSets.
    /// - Parameters:
    ///   - group: The group to update.
    ///   - setCount: The new set count.
    static func updateGroupSetCount(_ group: PlanExerciseGroup, to setCount: Int) {
        group.setCount = setCount
        for exercise in group.exercises {
            exercise.plannedSetCount = setCount
            syncExercisePlannedSets(exercise, targetCount: setCount)
        }
    }

    /// Resolves set count from exercises based on the resolution strategy.
    /// - Parameters:
    ///   - exercises: The exercises to analyze.
    ///   - resolution: The resolution strategy.
    /// - Returns: The resolved set count.
    static func resolveSetCount(
        exercises: [PlanExercise],
        resolution: SetCountResolution
    ) -> Int {
        let counts = exercises.map(\.effectiveSetCount)
        switch resolution {
        case .maximum:
            return counts.max() ?? 3
        case .minimum:
            return counts.min() ?? 1
        case .manual(let count):
            return max(1, count)
        }
    }

    /// Checks if exercises have mismatched set counts.
    /// - Parameter exercises: The exercises to check.
    /// - Returns: True if set counts differ.
    static func hasSetCountMismatch(_ exercises: [PlanExercise]) -> Bool {
        let counts = Set(exercises.map(\.effectiveSetCount))
        return counts.count > 1
    }

    // MARK: - Workout Group Expansion

    /// Expands a plan exercise group to a workout exercise group.
    /// - Parameters:
    ///   - planGroup: The plan group to expand.
    ///   - workoutDay: The workout day.
    ///   - modelContext: The model context.
    /// - Returns: The created workout group.
    @MainActor
    static func expandGroupToWorkout(
        planGroup: PlanExerciseGroup,
        workoutDay: WorkoutDay,
        modelContext: ModelContext
    ) -> WorkoutExerciseGroup {
        let workoutGroup = WorkoutExerciseGroup(
            orderIndex: planGroup.orderIndex,
            setCount: planGroup.setCount,
            roundRestSeconds: planGroup.roundRestSeconds
        )

        workoutDay.exerciseGroups.append(workoutGroup)
        modelContext.insert(workoutGroup)

        return workoutGroup
    }

    /// Adds an entry to a workout group.
    /// - Parameters:
    ///   - entry: The entry to add.
    ///   - group: The workout group.
    ///   - groupOrderIndex: The order within the group.
    static func addEntryToGroup(
        _ entry: WorkoutExerciseEntry,
        group: WorkoutExerciseGroup,
        groupOrderIndex: Int
    ) {
        entry.group = group
        entry.groupOrderIndex = groupOrderIndex
        group.entries.append(entry)
    }

    // MARK: - Round Progress (Workout)

    /// Gets the current round number for a workout group.
    /// - Parameter group: The workout group.
    /// - Returns: Current round (1-indexed).
    static func getCurrentRound(for group: WorkoutExerciseGroup) -> Int {
        group.activeRound
    }

    /// Checks if a specific round is complete.
    /// - Parameters:
    ///   - group: The workout group.
    ///   - round: The round number (1-indexed).
    /// - Returns: True if all entries have at least that many completed sets.
    static func isRoundComplete(for group: WorkoutExerciseGroup, round: Int) -> Bool {
        guard !group.entries.isEmpty else { return false }
        return group.entries.allSatisfy { $0.completedSetsCount >= round }
    }

    /// Gets the next entry to focus on within a group.
    /// - Parameters:
    ///   - currentEntry: The current entry (optional).
    ///   - group: The workout group.
    /// - Returns: The next entry that needs a set logged, or nil if round is complete.
    static func getNextEntryInGroup(
        after currentEntry: WorkoutExerciseEntry?,
        in group: WorkoutExerciseGroup
    ) -> WorkoutExerciseEntry? {
        let activeRound = group.activeRound
        let sorted = group.sortedEntries

        // If current entry is provided, try to find next in group order
        if let current = currentEntry,
           let currentIndex = sorted.firstIndex(where: { $0.id == current.id }) {
            // Look for next entry that hasn't completed the active round
            for i in (currentIndex + 1)..<sorted.count {
                if sorted[i].completedSetsCount < activeRound {
                    return sorted[i]
                }
            }
            // Wrap around to beginning
            for i in 0..<currentIndex {
                if sorted[i].completedSetsCount < activeRound {
                    return sorted[i]
                }
            }
        }

        // Fallback: return first entry that needs the active round
        return sorted.first { $0.completedSetsCount < activeRound }
    }

    /// Determines if rest timer should be started after logging a set.
    /// Rest is only shown after completing a full round.
    /// - Parameters:
    ///   - entry: The entry where set was just logged.
    ///   - group: The workout group.
    /// - Returns: True if the round just completed.
    static func shouldShowRestAfterSet(
        for entry: WorkoutExerciseEntry,
        in group: WorkoutExerciseGroup
    ) -> Bool {
        // Check if completing this set finished the round
        let prevRoundsCompleted = group.entries
            .filter { $0.id != entry.id }
            .map(\.completedSetsCount)
            .min() ?? 0

        let currentRoundsCompleted = min(prevRoundsCompleted, entry.completedSetsCount)

        // If all entries now have at least activeRound sets, round is complete
        return group.entries.allSatisfy { $0.completedSetsCount >= group.activeRound }
    }

    // MARK: - Private Helpers

    /// Syncs an exercise's plannedSets array to match the target count.
    private static func syncExercisePlannedSets(_ exercise: PlanExercise, targetCount: Int) {
        let currentCount = exercise.plannedSets.count

        if currentCount < targetCount {
            // Add placeholder sets based on last set
            let lastSet = exercise.sortedPlannedSets.last
            for _ in currentCount..<targetCount {
                exercise.createPlannedSet(
                    metricType: exercise.metricType,
                    weight: lastSet?.targetWeight,
                    reps: lastSet?.targetReps,
                    durationSeconds: lastSet?.targetDurationSeconds,
                    distanceMeters: lastSet?.targetDistanceMeters,
                    restTimeSeconds: lastSet?.restTimeSeconds
                )
            }
        } else if currentCount > targetCount {
            // Remove excess sets from the end
            let sorted = exercise.sortedPlannedSets
            for i in targetCount..<currentCount {
                if i < sorted.count {
                    exercise.removePlannedSet(sorted[i])
                }
            }
        }
    }

    /// Reindexes exercises after dissolving a group to maintain proper order.
    private static func reindexExercisesAfterDissolve(in planDay: PlanDay, startingFrom: Int) {
        // Get all ungrouped exercises with orderIndex >= startingFrom
        let affectedExercises = planDay.exercises
            .filter { !$0.isGrouped && $0.orderIndex >= startingFrom }
            .sorted { $0.orderIndex < $1.orderIndex }

        // Shift their indices up by the number of freed indices
        for exercise in affectedExercises {
            // This is handled by the caller, no additional shift needed
            // Exercises already have correct relative positions
        }
    }
}
