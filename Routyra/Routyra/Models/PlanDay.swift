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

    /// Whether this day is a rest day (no exercises).
    var isRestDay: Bool = false

    /// Optional note for this day.
    var note: String?

    /// Exercise items for this day.
    @Relationship(deleteRule: .cascade, inverse: \PlanExercise.planDay)
    var exercises: [PlanExercise]

    /// Exercise groups for this day (supersets/giant sets).
    @Relationship(deleteRule: .cascade, inverse: \PlanExerciseGroup.planDay)
    var exerciseGroups: [PlanExerciseGroup]

    // MARK: - Initialization

    /// Creates a new plan day.
    /// - Parameters:
    ///   - dayIndex: Day number (1-indexed).
    ///   - name: Optional display name.
    ///   - note: Optional note.
    ///   - isRestDay: Whether this day is a rest day (defaults to false).
    init(dayIndex: Int, name: String? = nil, note: String? = nil, isRestDay: Bool = false) {
        self.id = UUID()
        self.dayIndex = dayIndex
        self.name = name
        self.isRestDay = isRestDay
        self.note = note
        self.exercises = []
        self.exerciseGroups = []
    }

    // MARK: - Computed Properties

    /// Display name, falling back to "Day N" if not set.
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        if isRestDay {
            return L10n.tr("rest_day")
        }
        return L10n.tr("day_label", dayIndex)
    }

    /// Full title including day number and name.
    var fullTitle: String {
        if let name = name, !name.isEmpty {
            return L10n.tr("day_label_with_name", dayIndex, name)
        }
        if isRestDay {
            return L10n.tr("day_label_with_name", dayIndex, L10n.tr("rest_day"))
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
        if isRestDay {
            return L10n.tr("rest_day")
        }
        return L10n.tr("plan_day_summary", exerciseCount, totalPlannedSets)
    }

    // MARK: - Methods

    /// Adds an exercise to this day.
    func addExercise(_ exercise: PlanExercise) {
        exercises.append(exercise)
    }

    /// Creates and adds a new exercise.
    @discardableResult
    func createExercise(exerciseId: UUID, metricType: SetMetricType = .weightReps, plannedSetCount: Int = 3) -> PlanExercise {
        let nextOrder = (exercises.map(\.orderIndex).max() ?? -1) + 1
        let exercise = PlanExercise(
            exerciseId: exerciseId,
            orderIndex: nextOrder,
            metricType: metricType,
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
            note: note,
            isRestDay: isRestDay
        )

        // Rest days don't copy exercises/sets.
        if isRestDay {
            return copy
        }

        for exercise in sortedExercises {
            let exerciseCopy = PlanExercise(
                exerciseId: exercise.exerciseId,
                orderIndex: exercise.orderIndex,
                metricType: exercise.metricType,
                plannedSetCount: exercise.plannedSetCount
            )
            // Copy planned sets (preserve all properties including metric type and time/distance)
            for plannedSet in exercise.sortedPlannedSets {
                let setCopy = PlannedSet(
                    orderIndex: plannedSet.orderIndex,
                    metricType: plannedSet.metricType,
                    targetWeight: plannedSet.targetWeight,
                    targetReps: plannedSet.targetReps,
                    targetDurationSeconds: plannedSet.targetDurationSeconds,
                    targetDistanceMeters: plannedSet.targetDistanceMeters,
                    restTimeSeconds: plannedSet.restTimeSeconds
                )
                exerciseCopy.addPlannedSet(setCopy)
            }
            copy.addExercise(exerciseCopy)
        }

        return copy
    }
}
