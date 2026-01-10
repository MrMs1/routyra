//
//  PlannedSet.swift
//  Routyra
//
//  Represents a planned set within a plan exercise.
//  Stores target weight and reps for each set.
//

import Foundation
import SwiftData

@Model
final class PlannedSet {
    /// Unique identifier.
    var id: UUID

    /// Parent plan exercise (relationship).
    var planExercise: PlanExercise?

    /// Order within the exercise (0-indexed).
    var orderIndex: Int

    /// Metric type for this planned set (inherited from PlanExercise).
    var metricType: SetMetricType

    /// Target weight in kg. Nil means "use previous" or unspecified.
    /// Used for weightReps type.
    var targetWeight: Double?

    /// Target reps. Nil means unspecified.
    /// Used for weightReps and bodyweightReps types.
    var targetReps: Int?

    /// Target duration in seconds (for timeDistance type).
    var targetDurationSeconds: Int?

    /// Target distance in meters (for timeDistance type, optional).
    var targetDistanceMeters: Double?

    /// Rest time in seconds after completing this set.
    /// nil or 0 means no rest timer for this set.
    /// Used for weightReps and bodyweightReps types.
    var restTimeSeconds: Int?

    // MARK: - Initialization

    /// Creates a new planned set with full metric support.
    /// - Parameters:
    ///   - orderIndex: Order within the exercise.
    ///   - metricType: The metric type for this set.
    ///   - targetWeight: Target weight in kg.
    ///   - targetReps: Target number of reps.
    ///   - targetDurationSeconds: Target duration in seconds.
    ///   - targetDistanceMeters: Target distance in meters.
    ///   - restTimeSeconds: Rest time in seconds after this set.
    init(
        orderIndex: Int,
        metricType: SetMetricType = .weightReps,
        targetWeight: Double? = nil,
        targetReps: Int? = nil,
        targetDurationSeconds: Int? = nil,
        targetDistanceMeters: Double? = nil,
        restTimeSeconds: Int? = nil
    ) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.metricType = metricType
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.targetDurationSeconds = targetDurationSeconds
        self.targetDistanceMeters = targetDistanceMeters
        self.restTimeSeconds = restTimeSeconds
    }

    // MARK: - Display Helpers

    /// Formatted weight string.
    var weightString: String {
        if let w = targetWeight {
            return weightStringWithUnit(w)
        }
        return L10n.tr("weight_placeholder")
    }

    /// Formatted reps string.
    var repsString: String {
        if let r = targetReps {
            return "\(r)"
        }
        return "—"
    }

    /// Formatted reps string with unit.
    var repsStringWithUnit: String {
        if let r = targetReps {
            return L10n.tr("reps_with_unit", r)
        }
        return L10n.tr("reps_placeholder")
    }

    /// Formatted duration string (e.g., "3:30" or "3分30秒").
    var durationString: String {
        guard let seconds = targetDurationSeconds else { return "--:--" }
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Formatted distance string.
    var distanceString: String {
        guard let meters = targetDistanceMeters else { return "--" }
        let km = meters / 1000.0
        if km >= 1.0 {
            return String(format: "%.2f km", km)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// Formatted rest time string (e.g., "1:30").
    var restTimeString: String {
        guard let seconds = restTimeSeconds, seconds > 0 else { return "--:--" }
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Summary string for display based on metric type.
    var summary: String {
        switch metricType {
        case .weightReps:
            let weight = targetWeight.map(weightStringWithUnit) ?? L10n.tr("weight_placeholder")
            let reps = targetReps.map { L10n.tr("reps_with_unit", $0) }
                ?? L10n.tr("reps_placeholder")
            return "\(weight) / \(reps)"

        case .bodyweightReps:
            let reps = targetReps.map { L10n.tr("reps_with_unit", $0) }
                ?? L10n.tr("reps_placeholder")
            return "\(L10n.tr("bodyweight_label")) / \(reps)"

        case .timeDistance:
            var parts: [String] = []
            if targetDurationSeconds != nil {
                parts.append(durationString)
            }
            if targetDistanceMeters != nil {
                parts.append(distanceString)
            }
            return parts.isEmpty ? "--" : parts.joined(separator: " / ")

        case .completion:
            return L10n.tr("completion_only_hint")
        }
    }

    private func weightStringWithUnit(_ weight: Double) -> String {
        let formatted = weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weight))"
            : String(format: "%.1f", weight)
        return L10n.tr("weight_with_unit", formatted)
    }
}
