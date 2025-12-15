//
//  WorkoutSet.swift
//  Routyra
//
//  Represents a single set within an exercise entry.
//  Supports soft-delete for undo functionality.
//

import Foundation
import SwiftData

@Model
final class WorkoutSet {
    /// Unique identifier.
    var id: UUID

    /// Parent exercise entry (relationship).
    var entry: WorkoutExerciseEntry?

    /// Set number within the exercise (1-indexed for display).
    var setIndex: Int

    /// Weight used for this set (supports decimals like 62.5kg).
    var weight: Decimal

    /// Number of repetitions.
    var reps: Int

    /// Whether this set has been completed/logged.
    var isCompleted: Bool

    /// Soft-delete flag for undo safety.
    /// When true, the set is hidden from UI but can be restored.
    var isDeleted: Bool

    /// Creation timestamp.
    var createdAt: Date

    /// Last update timestamp.
    var updatedAt: Date

    // MARK: - Initialization

    /// Creates a new workout set.
    /// - Parameters:
    ///   - setIndex: Set number (1-indexed).
    ///   - weight: Weight in kg.
    ///   - reps: Number of repetitions.
    ///   - isCompleted: Whether the set is completed.
    init(
        setIndex: Int,
        weight: Decimal,
        reps: Int,
        isCompleted: Bool = false
    ) {
        self.id = UUID()
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
        self.isDeleted = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Computed Properties

    /// Volume for this set (weight * reps).
    var volume: Decimal {
        weight * Decimal(reps)
    }

    /// Weight as Double for UI binding convenience.
    var weightDouble: Double {
        get { NSDecimalNumber(decimal: weight).doubleValue }
        set {
            weight = Decimal(newValue)
            touch()
        }
    }

    // MARK: - Methods

    /// Marks the set as updated.
    func touch() {
        self.updatedAt = Date()
    }

    /// Marks the set as completed.
    func complete() {
        self.isCompleted = true
        touch()
    }

    /// Marks the set as not completed.
    func uncomplete() {
        self.isCompleted = false
        touch()
    }

    /// Toggles the completion state.
    func toggleCompletion() {
        self.isCompleted.toggle()
        touch()
    }

    /// Soft-deletes the set.
    func softDelete() {
        self.isDeleted = true
        touch()
    }

    /// Restores a soft-deleted set.
    func restore() {
        self.isDeleted = false
        touch()
    }

    /// Updates the set values.
    func update(weight: Decimal, reps: Int) {
        self.weight = weight
        self.reps = reps
        touch()
    }

    /// Updates the set values using Double for weight.
    func update(weightDouble: Double, reps: Int) {
        self.weight = Decimal(weightDouble)
        self.reps = reps
        touch()
    }
}
