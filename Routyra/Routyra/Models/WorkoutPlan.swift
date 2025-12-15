//
//  WorkoutPlan.swift
//  Routyra
//
//  A workout plan defines a multi-day training program.
//  Users can create plans and set one as active.
//

import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    /// Unique identifier.
    var id: UUID

    /// Owner profile ID.
    var profileId: UUID

    /// Display name of the plan (e.g., "PPL", "Upper/Lower Split").
    var name: String

    /// Optional note for the plan.
    var note: String?

    /// Whether this plan is archived (hidden from selection).
    var isArchived: Bool

    /// Days within this workout plan.
    @Relationship(deleteRule: .cascade, inverse: \PlanDay.plan)
    var days: [PlanDay]

    /// Creation timestamp.
    var createdAt: Date

    /// Last update timestamp.
    var updatedAt: Date

    // MARK: - Initialization

    /// Creates a new workout plan.
    /// - Parameters:
    ///   - profileId: Owner profile ID.
    ///   - name: Display name.
    ///   - note: Optional note.
    init(profileId: UUID, name: String, note: String? = nil) {
        self.id = UUID()
        self.profileId = profileId
        self.name = name
        self.note = note
        self.isArchived = false
        self.days = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Computed Properties

    /// Days sorted by day index.
    var sortedDays: [PlanDay] {
        days.sorted { $0.dayIndex < $1.dayIndex }
    }

    /// Number of days in this plan.
    var dayCount: Int {
        days.count
    }

    /// Total exercises across all days.
    var totalExerciseCount: Int {
        days.reduce(0) { $0 + $1.exerciseCount }
    }

    /// Total planned sets across all days.
    var totalPlannedSets: Int {
        days.reduce(0) { $0 + $1.totalPlannedSets }
    }

    // MARK: - Methods

    /// Marks the plan as updated.
    func touch() {
        self.updatedAt = Date()
    }

    /// Archives the plan.
    func archive() {
        self.isArchived = true
        touch()
    }

    /// Unarchives the plan.
    func unarchive() {
        self.isArchived = false
        touch()
    }

    /// Adds a new day to this plan.
    func addDay(_ day: PlanDay) {
        days.append(day)
        touch()
    }

    /// Gets a day by its index (1-indexed).
    func day(at index: Int) -> PlanDay? {
        days.first { $0.dayIndex == index }
    }

    /// Creates a new day and adds it to this plan.
    @discardableResult
    func createDay(name: String? = nil, note: String? = nil) -> PlanDay {
        let nextIndex = (days.map(\.dayIndex).max() ?? 0) + 1
        let day = PlanDay(dayIndex: nextIndex, name: name, note: note)
        addDay(day)
        return day
    }

    /// Removes a day from this plan.
    func removeDay(_ day: PlanDay) {
        days.removeAll { $0.id == day.id }
        touch()
    }

    /// Reindexes days after reordering.
    /// Updates dayIndex to be 1-indexed based on current order.
    func reindexDays() {
        for (index, day) in sortedDays.enumerated() {
            day.dayIndex = index + 1
        }
        touch()
    }

    /// Duplicates a day and adds it after the original.
    /// - Parameter day: The day to duplicate.
    /// - Returns: The new duplicated day.
    @discardableResult
    func duplicateDay(_ day: PlanDay) -> PlanDay {
        let nextIndex = (days.map(\.dayIndex).max() ?? 0) + 1
        let copy = day.duplicate(newDayIndex: nextIndex)
        addDay(copy)
        return copy
    }
}
