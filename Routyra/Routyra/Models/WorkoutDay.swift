//
//  WorkoutDay.swift
//  Routyra
//
//  Represents one day's workout. Enforces 1 workout per local date per profile.
//  Contains exercise entries which contain sets.
//

import Foundation
import SwiftData

@Model
final class WorkoutDay {
    /// Unique identifier.
    var id: UUID

    /// Owner profile ID.
    var profileId: UUID

    /// The date of this workout (normalized to local start-of-day).
    /// This ensures we can query by date reliably.
    var date: Date

    /// Whether this workout is in free mode or routine mode.
    var mode: WorkoutMode

    /// If mode == .routine, the ID of the routine preset being used.
    var routinePresetId: UUID?

    /// If mode == .routine, the ID of the specific routine day being followed.
    var routineDayId: UUID?

    /// Exercise entries for this workout day.
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExerciseEntry.workoutDay)
    var entries: [WorkoutExerciseEntry]

    /// Exercise groups for this workout (supersets/giant sets).
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExerciseGroup.workoutDay)
    var exerciseGroups: [WorkoutExerciseGroup]

    /// Creation timestamp.
    var createdAt: Date

    /// Last update timestamp.
    var updatedAt: Date

    // MARK: - Initialization

    /// Creates a new workout day.
    /// - Parameters:
    ///   - profileId: Owner profile ID.
    ///   - date: The workout date (will be normalized to start-of-day).
    ///   - mode: Free or routine mode.
    ///   - routinePresetId: Routine preset ID (required for routine mode).
    ///   - routineDayId: Routine day ID (required for routine mode).
    init(
        profileId: UUID,
        date: Date,
        mode: WorkoutMode = .free,
        routinePresetId: UUID? = nil,
        routineDayId: UUID? = nil
    ) {
        self.id = UUID()
        self.profileId = profileId
        self.date = DateUtilities.startOfDay(date)
        self.mode = mode
        self.routinePresetId = routinePresetId
        self.routineDayId = routineDayId
        self.entries = []
        self.exerciseGroups = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Computed Properties

    /// Total number of completed sets across all entries.
    var totalCompletedSets: Int {
        entries.reduce(0) { $0 + $1.completedSetsCount }
    }

    /// Total number of exercises with at least one completed set.
    var totalExercisesWithSets: Int {
        entries.filter { $0.completedSetsCount > 0 }.count
    }

    /// Total volume (weight * reps) for all completed sets.
    var totalVolume: Decimal {
        entries.reduce(Decimal.zero) { $0 + $1.totalVolume }
    }

    /// Entries sorted by order index.
    var sortedEntries: [WorkoutExerciseEntry] {
        entries.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Whether this is a routine workout and all planned exercises are complete.
    /// Completion means: for every entry with plannedSetCount > 0, there are
    /// exactly plannedSetCount non-deleted completed sets.
    var isRoutineCompleted: Bool {
        guard mode == .routine else { return false }

        // All entries with planned sets must be fully completed
        return entries.allSatisfy { entry in
            if entry.plannedSetCount == 0 { return true }
            return entry.isPlannedSetsCompleted
        }
    }

    // MARK: - Methods

    /// Marks the workout as updated.
    func touch() {
        self.updatedAt = Date()
    }

    /// Adds a new exercise entry to this workout.
    func addEntry(_ entry: WorkoutExerciseEntry) {
        entries.append(entry)
        touch()
    }

    /// Removes an entry from this workout.
    func removeEntry(_ entry: WorkoutExerciseEntry) {
        entries.removeAll { $0.id == entry.id }
        touch()
    }
}
