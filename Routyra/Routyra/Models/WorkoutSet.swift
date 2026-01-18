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

    /// The metric type for this set.
    var metricType: SetMetricType

    /// Weight used for this set (supports decimals like 62.5kg).
    /// Optional: nil for bodyweightReps, timeDistance, and completion types.
    var weight: Decimal?

    /// Number of repetitions.
    /// Optional: nil for timeDistance and completion types.
    var reps: Int?

    /// Duration in seconds (for timeDistance type).
    var durationSeconds: Int?

    /// Distance in meters (for timeDistance type, optional even for that type).
    var distanceMeters: Double?

    /// Rest time in seconds after completing this set.
    /// nil or 0 means no rest timer for this set.
    /// Used for weightReps and bodyweightReps types.
    var restTimeSeconds: Int?

    /// Whether this set has been completed/logged.
    var isCompleted: Bool

    /// Timestamp of last completion state change.
    /// Used for sync conflict resolution between iPhone and Watch.
    var completedAt: Date?

    /// Soft-delete flag for undo safety.
    /// When true, the set is hidden from UI but can be restored.
    /// Named isSoftDeleted to avoid collision with SwiftData's internal isDeleted property.
    var isSoftDeleted: Bool

    /// Creation timestamp.
    var createdAt: Date

    /// Last update timestamp.
    var updatedAt: Date

    // MARK: - Initialization

    /// Creates a new workout set with full metric support.
    /// - Parameters:
    ///   - setIndex: Set number (1-indexed).
    ///   - metricType: The metric type for this set.
    ///   - weight: Weight in kg (for weightReps type).
    ///   - reps: Number of repetitions (for weightReps and bodyweightReps types).
    ///   - durationSeconds: Duration in seconds (for timeDistance type).
    ///   - distanceMeters: Distance in meters (for timeDistance type, optional).
    ///   - restTimeSeconds: Rest time in seconds after this set.
    ///   - isCompleted: Whether the set is completed.
    init(
        setIndex: Int,
        metricType: SetMetricType = .weightReps,
        weight: Decimal? = nil,
        reps: Int? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Double? = nil,
        restTimeSeconds: Int? = nil,
        isCompleted: Bool = false
    ) {
        self.id = UUID()
        self.setIndex = setIndex
        self.metricType = metricType
        self.weight = weight
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.restTimeSeconds = restTimeSeconds
        self.isCompleted = isCompleted
        self.isSoftDeleted = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Convenience initializer for weight/reps sets (backwards compatible).
    convenience init(
        setIndex: Int,
        weight: Decimal,
        reps: Int,
        isCompleted: Bool = false
    ) {
        self.init(
            setIndex: setIndex,
            metricType: .weightReps,
            weight: weight,
            reps: reps,
            isCompleted: isCompleted
        )
    }

    // MARK: - Computed Properties

    /// Volume for this set (weight * reps).
    /// Only valid for weightReps metric type; returns 0 for other types.
    var volume: Decimal {
        guard metricType == .weightReps,
              let weight = weight,
              let reps = reps else {
            return Decimal.zero
        }
        return weight * Decimal(reps)
    }

    /// Weight as Double for UI binding convenience.
    /// Returns 0 if weight is nil.
    var weightDouble: Double {
        get {
            guard let weight = weight else { return 0 }
            return NSDecimalNumber(decimal: weight).doubleValue
        }
        set {
            weight = Decimal(newValue)
            touch()
        }
    }

    /// Duration formatted as "M:SS" for display.
    var durationFormatted: String {
        guard let seconds = durationSeconds else { return "--:--" }
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Distance formatted in km for display.
    var distanceFormatted: String {
        guard let meters = distanceMeters else { return "--" }
        let km = meters / 1000.0
        if km >= 1.0 {
            return String(format: "%.2f km", km)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// Rest time formatted as "M:SS" for display.
    var restTimeFormatted: String {
        guard let seconds = restTimeSeconds, seconds > 0 else { return "--:--" }
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - Methods

    /// Marks the set as updated.
    func touch() {
        self.updatedAt = Date()
    }

    /// Marks the set as completed.
    func complete() {
        self.isCompleted = true
        self.completedAt = Date()
        touch()
    }

    /// Marks the set as not completed.
    func uncomplete() {
        self.isCompleted = false
        self.completedAt = Date()
        touch()
    }

    /// Toggles the completion state.
    func toggleCompletion() {
        self.isCompleted.toggle()
        self.completedAt = Date()
        touch()
    }

    /// Soft-deletes the set.
    func softDelete() {
        self.isSoftDeleted = true
        touch()
    }

    /// Restores a soft-deleted set.
    func restore() {
        self.isSoftDeleted = false
        touch()
    }

    /// Updates the set values for weightReps type.
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

    /// Updates only the reps (for bodyweightReps type).
    func update(reps: Int) {
        self.reps = reps
        touch()
    }

    /// Updates time and distance (for timeDistance type).
    func update(durationSeconds: Int, distanceMeters: Double? = nil) {
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        touch()
    }

    /// Generic update for any metric type.
    func update(
        weight: Decimal? = nil,
        reps: Int? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Double? = nil
    ) {
        if let weight = weight { self.weight = weight }
        if let reps = reps { self.reps = reps }
        if let duration = durationSeconds { self.durationSeconds = duration }
        if let distance = distanceMeters { self.distanceMeters = distance }
        touch()
    }
}
