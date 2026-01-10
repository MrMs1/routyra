//
//  PlanExerciseGroup.swift
//  Routyra
//
//  Represents a group of exercises within a plan day.
//  All exercises in a group share the same set count and are performed back-to-back.
//

import Foundation
import SwiftData

@Model
final class PlanExerciseGroup {
    /// Unique identifier.
    var id: UUID

    /// Parent plan day (relationship).
    var planDay: PlanDay?

    /// Display order within the plan day (0-indexed).
    /// Used alongside ungrouped exercises' orderIndex for unified ordering.
    var orderIndex: Int

    /// Number of rounds (sets per exercise) for this group.
    var setCount: Int

    /// Rest time after each round in seconds (optional).
    var roundRestSeconds: Int?

    /// Exercises belonging to this group.
    /// Uses .nullify to allow exercises to become ungrouped when group is deleted.
    @Relationship(deleteRule: .nullify, inverse: \PlanExercise.group)
    var exercises: [PlanExercise]

    // MARK: - Initialization

    /// Creates a new exercise group.
    /// - Parameters:
    ///   - orderIndex: Display order within the day.
    ///   - setCount: Number of rounds.
    ///   - roundRestSeconds: Rest time after each round (optional).
    init(
        orderIndex: Int,
        setCount: Int,
        roundRestSeconds: Int? = nil
    ) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.setCount = setCount
        self.roundRestSeconds = roundRestSeconds
        self.exercises = []
    }

    // MARK: - Computed Properties

    /// Exercises sorted by their group order index.
    var sortedExercises: [PlanExercise] {
        exercises.sorted { ($0.groupOrderIndex ?? 0) < ($1.groupOrderIndex ?? 0) }
    }

    /// Number of exercises in this group.
    var exerciseCount: Int {
        exercises.count
    }

    /// Localized display name for the group.
    @MainActor
    var displayName: String {
        L10n.tr("group_label")
    }

    /// Whether this group is valid (has at least 2 exercises).
    var isValid: Bool {
        exercises.count >= 2
    }

    /// Summary string for display (e.g., "Group • 3 rounds").
    @MainActor
    var summary: String {
        let roundsLabel = L10n.tr("group_set_count", setCount)
        if let rest = roundRestSeconds, rest > 0 {
            let restLabel = formatRestTime(rest)
            return "\(displayName) • \(roundsLabel) • \(restLabel)"
        }
        return "\(displayName) • \(roundsLabel)"
    }

    // MARK: - Methods

    /// Adds an exercise to this group.
    /// Assigns the next available groupOrderIndex.
    func addExercise(_ exercise: PlanExercise) {
        let nextIndex = (exercises.compactMap(\.groupOrderIndex).max() ?? -1) + 1
        exercise.groupOrderIndex = nextIndex
        exercises.append(exercise)
    }

    /// Removes an exercise from this group.
    /// Clears the exercise's group-related properties.
    func removeExercise(_ exercise: PlanExercise) {
        exercises.removeAll { $0.id == exercise.id }
        exercise.groupOrderIndex = nil
        reindexExercises()
    }

    /// Reindexes exercises' group order after changes.
    func reindexExercises() {
        for (index, exercise) in sortedExercises.enumerated() {
            exercise.groupOrderIndex = index
        }
    }

    /// Updates the set count for this group.
    /// Syncs the plannedSetCount to all exercises and adjusts their plannedSets.
    func updateSetCount(_ count: Int) {
        self.setCount = count
        for exercise in exercises {
            exercise.plannedSetCount = count
            // Adjust plannedSets count to match
            adjustExercisePlannedSets(exercise, targetCount: count)
        }
    }

    /// Updates the round rest time.
    func updateRestSeconds(_ seconds: Int?) {
        self.roundRestSeconds = seconds
    }

    // MARK: - Private Helpers

    /// Adjusts an exercise's plannedSets array to match the target count.
    private func adjustExercisePlannedSets(_ exercise: PlanExercise, targetCount: Int) {
        let currentCount = exercise.plannedSets.count

        if currentCount < targetCount {
            // Add placeholder sets
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

    /// Formats rest time in seconds to a readable string.
    private func formatRestTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 {
            return secs > 0 ? String(format: "%d:%02d", minutes, secs) : "\(minutes)m"
        }
        return "\(secs)s"
    }
}
