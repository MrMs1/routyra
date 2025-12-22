//
//  WorkoutExerciseEntry.swift
//  Routyra
//
//  Represents an exercise entry within a workout day.
//  Links a WorkoutDay to an Exercise definition, and contains the sets.
//

import Foundation
import SwiftData

@Model
final class WorkoutExerciseEntry {
    /// Unique identifier.
    var id: UUID

    /// Parent workout day (relationship).
    var workoutDay: WorkoutDay?

    /// Reference to the exercise definition.
    /// Using UUID instead of relationship to keep Exercise as a pure definition entity.
    var exerciseId: UUID

    /// Display order within the workout (0-indexed).
    var orderIndex: Int

    /// How this entry was added (from routine or freely added).
    var source: EntrySource

    /// Number of sets planned for this exercise (from routine or user-defined).
    /// 0 means no specific target.
    var plannedSetCount: Int

    /// The sets for this exercise entry.
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.entry)
    var sets: [WorkoutSet]

    /// Creation timestamp.
    var createdAt: Date

    // MARK: - Initialization

    /// Creates a new workout exercise entry.
    /// - Parameters:
    ///   - exerciseId: Reference to the exercise definition.
    ///   - orderIndex: Display order.
    ///   - source: How this entry was created.
    ///   - plannedSetCount: Target number of sets.
    init(
        exerciseId: UUID,
        orderIndex: Int,
        source: EntrySource = .free,
        plannedSetCount: Int = 0
    ) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.orderIndex = orderIndex
        self.source = source
        self.plannedSetCount = plannedSetCount
        self.sets = []
        self.createdAt = Date()
    }

    // MARK: - Computed Properties

    /// Non-deleted sets (excludes soft-deleted sets).
    var activeSets: [WorkoutSet] {
        sets.filter { !$0.isSoftDeleted }
    }

    /// Sets sorted by index.
    var sortedSets: [WorkoutSet] {
        activeSets.sorted { $0.setIndex < $1.setIndex }
    }

    /// Number of completed (non-deleted) sets.
    var completedSetsCount: Int {
        activeSets.filter { $0.isCompleted }.count
    }

    /// Total volume for completed sets.
    var totalVolume: Decimal {
        activeSets
            .filter { $0.isCompleted }
            .reduce(Decimal.zero) { $0 + $1.volume }
    }

    /// Whether all active sets are completed.
    /// True only if there are sets and all of them are completed.
    var isPlannedSetsCompleted: Bool {
        guard !activeSets.isEmpty else { return false }
        return activeSets.allSatisfy { $0.isCompleted }
    }

    /// Whether this entry has any completed sets.
    var hasCompletedSets: Bool {
        completedSetsCount > 0
    }

    /// The next set index for a new set.
    var nextSetIndex: Int {
        (activeSets.map(\.setIndex).max() ?? 0) + 1
    }

    // MARK: - Methods

    /// Adds a new set to this entry.
    func addSet(_ set: WorkoutSet) {
        sets.append(set)
    }

    /// Creates and adds a new set with the given weight and reps.
    /// - Parameters:
    ///   - weight: Weight in kg.
    ///   - reps: Number of repetitions.
    ///   - isCompleted: Whether the set is marked as completed.
    /// - Returns: The created set.
    @discardableResult
    func createSet(weight: Decimal, reps: Int, isCompleted: Bool = false) -> WorkoutSet {
        let set = WorkoutSet(
            setIndex: nextSetIndex,
            weight: weight,
            reps: reps,
            isCompleted: isCompleted
        )
        addSet(set)
        return set
    }

    /// Creates placeholder sets up to the planned count.
    /// Useful when expanding a routine to a workout.
    /// - Parameter defaultWeight: Default weight for placeholder sets.
    /// - Parameter defaultReps: Default reps for placeholder sets.
    func createPlaceholderSets(defaultWeight: Decimal = 0, defaultReps: Int = 0) {
        for i in 1...plannedSetCount where sortedSets.count < plannedSetCount {
            let set = WorkoutSet(
                setIndex: i,
                weight: defaultWeight,
                reps: defaultReps,
                isCompleted: false
            )
            addSet(set)
        }
    }
}
