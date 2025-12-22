//
//  PlanDay.swift
//  Routyra
//
//  Represents a single day within a workout plan.
//  Contains exercises with planned sets.
//

import Foundation
import SwiftData

@Model
final class PlanDay {
    /// Unique identifier.
    var id: UUID

    /// Parent workout plan (relationship).
    var plan: WorkoutPlan?

    /// Day number within the plan (1-indexed for display, but used as order).
    var dayIndex: Int

    /// Optional display name (e.g., "Push", "Pull", "Legs", or "胸・肩").
    var name: String?

    /// Optional note for this day.
    var note: String?

    /// Exercise items for this day.
    @Relationship(deleteRule: .cascade, inverse: \PlanExercise.planDay)
    var exercises: [PlanExercise]

    // MARK: - Initialization

    /// Creates a new plan day.
    /// - Parameters:
    ///   - dayIndex: Day number (1-indexed).
    ///   - name: Optional display name.
    ///   - note: Optional note.
    init(dayIndex: Int, name: String? = nil, note: String? = nil) {
        self.id = UUID()
        self.dayIndex = dayIndex
        self.name = name
        self.note = note
        self.exercises = []
    }

    // MARK: - Computed Properties

    /// Display name, falling back to "Day N" if not set.
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        return L10n.tr("day_label", dayIndex)
    }

    /// Full title including day number and name.
    var fullTitle: String {
        if let name = name, !name.isEmpty {
            return L10n.tr("day_label_with_name", dayIndex, name)
        }
        return L10n.tr("day_label", dayIndex)
    }

    /// Exercises sorted by order index.
    var sortedExercises: [PlanExercise] {
        exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Number of exercises in this day.
    var exerciseCount: Int {
        exercises.count
    }

    /// Total planned sets across all exercises.
    var totalPlannedSets: Int {
        exercises.reduce(0) { $0 + $1.effectiveSetCount }
    }

    /// Summary string for collapsed view (e.g., "3種目 / 9セット").
    var summary: String {
        L10n.tr("plan_day_summary", exerciseCount, totalPlannedSets)
    }

    // MARK: - Methods

    /// Adds an exercise to this day.
    func addExercise(_ exercise: PlanExercise) {
        exercises.append(exercise)
    }

    /// Creates and adds a new exercise.
    @discardableResult
    func createExercise(exerciseId: UUID, plannedSetCount: Int = 3) -> PlanExercise {
        let nextOrder = (exercises.map(\.orderIndex).max() ?? -1) + 1
        let exercise = PlanExercise(
            exerciseId: exerciseId,
            orderIndex: nextOrder,
            plannedSetCount: plannedSetCount
        )
        addExercise(exercise)
        return exercise
    }

    /// Removes an exercise.
    func removeExercise(_ exercise: PlanExercise) {
        exercises.removeAll { $0.id == exercise.id }
    }

    /// Reindexes exercises after reordering.
    func reindexExercises() {
        for (index, exercise) in sortedExercises.enumerated() {
            exercise.orderIndex = index
        }
    }

    /// Creates a deep copy of this day (including exercises and their planned sets).
    /// - Parameter newDayIndex: Day index for the copy.
    /// - Returns: New PlanDay with copied exercises.
    func duplicate(newDayIndex: Int) -> PlanDay {
        let copy = PlanDay(
            dayIndex: newDayIndex,
            name: name,
            note: note
        )

        for exercise in sortedExercises {
            let exerciseCopy = PlanExercise(
                exerciseId: exercise.exerciseId,
                orderIndex: exercise.orderIndex,
                plannedSetCount: exercise.plannedSetCount
            )
            // Copy planned sets
            for plannedSet in exercise.sortedPlannedSets {
                let setCopy = PlannedSet(
                    orderIndex: plannedSet.orderIndex,
                    targetWeight: plannedSet.targetWeight,
                    targetReps: plannedSet.targetReps
                )
                exerciseCopy.addPlannedSet(setCopy)
            }
            copy.addExercise(exerciseCopy)
        }

        return copy
    }
}
