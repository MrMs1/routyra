//
//  PlanExercise.swift
//  Routyra
//
//  Represents an exercise within a plan day.
//  Links to an exercise definition and contains planned sets.
//

import Foundation
import SwiftData

@Model
final class PlanExercise {
    /// Unique identifier.
    var id: UUID

    /// Parent plan day (relationship).
    var planDay: PlanDay?

    /// Reference to the exercise definition.
    /// Using UUID instead of relationship to keep Exercise independent.
    var exerciseId: UUID

    /// Display order within the plan day (0-indexed).
    var orderIndex: Int

    /// Metric type for all sets in this exercise.
    /// Inherited from Exercise.defaultMetricType when created.
    var metricType: SetMetricType

    /// Number of sets planned for this exercise (legacy, kept for backward compatibility).
    var plannedSetCount: Int

    /// Planned sets with detailed weight/reps info.
    @Relationship(deleteRule: .cascade, inverse: \PlannedSet.planExercise)
    var plannedSets: [PlannedSet]

    /// Parent exercise group (for superset/giant set).
    /// nil means this exercise is not grouped.
    var group: PlanExerciseGroup?

    /// Display order within the group (0-indexed).
    /// Only used when this exercise belongs to a group.
    var groupOrderIndex: Int?

    // MARK: - Initialization

    /// Creates a new plan exercise.
    /// - Parameters:
    ///   - exerciseId: Reference to the exercise definition.
    ///   - orderIndex: Display order.
    ///   - metricType: Metric type for sets.
    ///   - plannedSetCount: Target number of sets.
    init(
        exerciseId: UUID,
        orderIndex: Int,
        metricType: SetMetricType = .weightReps,
        plannedSetCount: Int
    ) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.orderIndex = orderIndex
        self.metricType = metricType
        self.plannedSetCount = plannedSetCount
        self.plannedSets = []
    }

    // MARK: - Computed Properties

    /// Whether this exercise belongs to a group (superset/giant set).
    var isGrouped: Bool {
        group != nil
    }

    /// Planned sets sorted by order.
    var sortedPlannedSets: [PlannedSet] {
        plannedSets.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Effective set count (uses plannedSets count if available, otherwise plannedSetCount).
    var effectiveSetCount: Int {
        plannedSets.isEmpty ? plannedSetCount : plannedSets.count
    }

    /// Summary string for display (e.g., "60kg / 10回 / 3セット").
    /// Supports mixed weight/bodyweight sets.
    var setsSummary: String {
        setsSummary(weightUnit: .kg)
    }

    /// Summary string for display with configurable weight unit.
    func setsSummary(weightUnit: WeightUnit) -> String {
        if plannedSets.isEmpty {
            return L10n.tr("plan_sets_not_configured")
        }

        let sorted = sortedPlannedSets
        let setCount = sorted.count

        // Check for mixed weight/bodyweight sets
        let hasBodyweight = sorted.contains { $0.metricType == .bodyweightReps }
        let hasWeight = sorted.contains { $0.metricType == .weightReps }
        let isMixed = hasBodyweight && hasWeight

        // If all sets are the same metric type, use the dedicated summary
        if !isMixed {
            // Use set's metricType (they're all the same)
            let setMetricType = sorted.first?.metricType ?? metricType
            switch setMetricType {
            case .completion:
                return "\(setsString(setCount)) • \(L10n.tr("completion_only_hint"))"
            case .timeDistance:
                return timeDistanceSummary(for: sorted)
            case .bodyweightReps:
                return bodyweightRepsSummary(for: sorted)
            case .weightReps:
                return weightRepsSummary(for: sorted, weightUnit: weightUnit)
            }
        }

        // Mixed weight/bodyweight summary
        return mixedWeightBodyweightSummary(for: sorted, weightUnit: weightUnit)
    }

    /// Summary for mixed weight/bodyweight sets.
    /// Format: "BW / 60–80kg / 8–12回 / 3セット"
    private func mixedWeightBodyweightSummary(for sets: [PlannedSet]) -> String {
        mixedWeightBodyweightSummary(for: sets, weightUnit: .kg)
    }

    private func mixedWeightBodyweightSummary(for sets: [PlannedSet], weightUnit: WeightUnit) -> String {
        let setCount = sets.count

        // Get weight sets only for weight range
        let weightSets = sets.filter { $0.metricType == .weightReps }
        let weights = weightSets.compactMap(\.targetWeight)

        // Get all reps from both weight and bodyweight sets
        let allReps = sets.compactMap(\.targetReps)

        var parts: [String] = []

        // Add "BW" first (since we know there's at least one bodyweight set)
        parts.append(L10n.tr("bodyweight_label"))

        // Add weight range (from weightReps sets only)
        if !weights.isEmpty {
            let minWeight = weights.min()!
            let maxWeight = weights.max()!
            if minWeight == maxWeight {
                parts.append(weightString(minWeight, unit: weightUnit))
            } else {
                parts.append(weightRangeString(minWeight, maxWeight, unit: weightUnit))
            }
        }

        // Add reps range (from all sets)
        if !allReps.isEmpty {
            let minReps = allReps.min()!
            let maxReps = allReps.max()!
            if minReps == maxReps {
                parts.append(repsString(minReps))
            } else {
                parts.append(repsRangeString(minReps, maxReps))
            }
        } else {
            parts.append(L10n.tr("reps_placeholder"))
        }

        parts.append(setsString(setCount))

        return parts.joined(separator: " / ")
    }

    private func weightRepsSummary(for sets: [PlannedSet]) -> String {
        weightRepsSummary(for: sets, weightUnit: .kg)
    }

    private func weightRepsSummary(for sets: [PlannedSet], weightUnit: WeightUnit) -> String {
        let setCount = sets.count

        // Check if all sets have the same weight and reps
        if sets.count > 1,
           let first = sets.first,
           sets.allSatisfy({ $0.targetWeight == first.targetWeight && $0.targetReps == first.targetReps }) {
            // Format: "60kg / 10回 / 3セット"
            let weight = first.targetWeight.map { weightString($0, unit: weightUnit) } ?? weightPlaceholder(unit: weightUnit)
            let reps = first.targetReps.map(repsString) ?? L10n.tr("reps_placeholder")
            let setsStr = setsString(setCount)
            return "\(weight) / \(reps) / \(setsStr)"
        }

        // Different sets - show count and range
        let weights = sets.compactMap(\.targetWeight)
        let reps = sets.compactMap(\.targetReps)

        var parts: [String] = []

        if !weights.isEmpty {
            let minWeight = weights.min()!
            let maxWeight = weights.max()!
            if minWeight == maxWeight {
                parts.append(weightString(minWeight, unit: weightUnit))
            } else {
                parts.append(weightRangeString(minWeight, maxWeight, unit: weightUnit))
            }
        } else {
            parts.append(weightPlaceholder(unit: weightUnit))
        }

        if !reps.isEmpty {
            let minReps = reps.min()!
            let maxReps = reps.max()!
            if minReps == maxReps {
                parts.append(repsString(minReps))
            } else {
                parts.append(repsRangeString(minReps, maxReps))
            }
        } else {
            parts.append(L10n.tr("reps_placeholder"))
        }

        parts.append(setsString(setCount))

        return parts.joined(separator: " / ")
    }

    private func bodyweightRepsSummary(for sets: [PlannedSet]) -> String {
        let setCount = sets.count
        let reps = sets.compactMap(\.targetReps)

        var parts: [String] = [L10n.tr("bodyweight_label")]

        if !reps.isEmpty {
            let minReps = reps.min()!
            let maxReps = reps.max()!
            if minReps == maxReps {
                parts.append(repsString(minReps))
            } else {
                parts.append(repsRangeString(minReps, maxReps))
            }
        } else {
            parts.append(L10n.tr("reps_placeholder"))
        }

        parts.append(setsString(setCount))

        return parts.joined(separator: " / ")
    }

    private func timeDistanceSummary(for sets: [PlannedSet]) -> String {
        let setCount = sets.count
        let durations = sets.compactMap(\.targetDurationSeconds)
        let distances = sets.compactMap(\.targetDistanceMeters)

        var parts: [String] = []

        if !durations.isEmpty {
            let minDuration = durations.min()!
            let maxDuration = durations.max()!
            if minDuration == maxDuration {
                parts.append(durationString(minDuration))
            } else {
                parts.append("\(durationString(minDuration))–\(durationString(maxDuration))")
            }
        }

        if !distances.isEmpty {
            let minDistance = distances.min()!
            let maxDistance = distances.max()!
            if minDistance == maxDistance {
                parts.append(distanceString(minDistance))
            } else {
                parts.append("\(distanceString(minDistance))–\(distanceString(maxDistance))")
            }
        }

        parts.append(setsString(setCount))

        return parts.isEmpty ? setsString(setCount) : parts.joined(separator: " / ")
    }

    private func durationString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func distanceString(_ meters: Double) -> String {
        let km = meters / 1000.0
        if km >= 1.0 {
            return String(format: "%.1f km", km)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    /// Compact summary for Plan view (e.g., "3 sets • 8–10 reps • 75–80kg").
    var compactSummary: String {
        let sets = sortedPlannedSets
        guard !sets.isEmpty else {
            return L10n.tr("plan_sets_not_configured")
        }

        let setsCount = sets.count

        switch metricType {
        case .completion:
            return "\(setsString(setsCount)) • \(L10n.tr("completion_only_hint"))"

        case .timeDistance:
            var parts: [String] = [setsString(setsCount)]
            let durations = sets.compactMap(\.targetDurationSeconds)
            let distances = sets.compactMap(\.targetDistanceMeters)

            if !durations.isEmpty {
                let minDuration = durations.min()!
                let maxDuration = durations.max()!
                if minDuration == maxDuration {
                    parts.append(durationString(minDuration))
                } else {
                    parts.append("\(durationString(minDuration))–\(durationString(maxDuration))")
                }
            }

            if !distances.isEmpty {
                let minDistance = distances.min()!
                let maxDistance = distances.max()!
                if minDistance == maxDistance {
                    parts.append(distanceString(minDistance))
                } else {
                    parts.append("\(distanceString(minDistance))–\(distanceString(maxDistance))")
                }
            }

            return parts.joined(separator: " • ")

        case .bodyweightReps:
            var parts: [String] = [setsString(setsCount)]
            let reps = sets.compactMap(\.targetReps)

            if !reps.isEmpty {
                let minReps = reps.min()!
                let maxReps = reps.max()!
                if minReps == maxReps {
                    parts.append(repsString(minReps))
                } else {
                    parts.append(repsRangeString(minReps, maxReps))
                }
            }

            parts.append(L10n.tr("bodyweight_label"))
            return parts.joined(separator: " • ")

        case .weightReps:
            var parts: [String] = [setsString(setsCount)]
            let weights = sets.compactMap(\.targetWeight)
            let reps = sets.compactMap(\.targetReps)

            if !reps.isEmpty {
                let minReps = reps.min()!
                let maxReps = reps.max()!
                if minReps == maxReps {
                    parts.append(repsString(minReps))
                } else {
                    parts.append(repsRangeString(minReps, maxReps))
                }
            }

            if !weights.isEmpty {
                let minWeight = weights.min()!
                let maxWeight = weights.max()!
                if minWeight == maxWeight {
                    parts.append(weightString(minWeight))
                } else {
                    parts.append(weightRangeString(minWeight, maxWeight))
                }
            }

            return parts.joined(separator: " • ")
        }
    }

    private func formatWeightValue(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weight))"
            : String(format: "%.1f", weight)
    }

    private func weightString(_ weight: Double) -> String {
        L10n.tr("weight_with_unit", formatWeightValue(weight))
    }

    private func weightString(_ weight: Double, unit: WeightUnit) -> String {
        switch unit {
        case .kg: return L10n.tr("weight_with_unit", formatWeightValue(weight))
        case .lb: return L10n.tr("weight_with_unit_lb", formatWeightValue(weight))
        }
    }

    private func weightRangeString(_ min: Double, _ max: Double) -> String {
        L10n.tr("weight_range_with_unit", formatWeightValue(min), formatWeightValue(max))
    }

    private func weightRangeString(_ min: Double, _ max: Double, unit: WeightUnit) -> String {
        switch unit {
        case .kg: return L10n.tr("weight_range_with_unit", formatWeightValue(min), formatWeightValue(max))
        case .lb: return L10n.tr("weight_range_with_unit_lb", formatWeightValue(min), formatWeightValue(max))
        }
    }

    private func weightPlaceholder(unit: WeightUnit) -> String {
        switch unit {
        case .kg: return L10n.tr("weight_placeholder")
        case .lb: return L10n.tr("weight_placeholder_lb")
        }
    }

    private func repsString(_ reps: Int) -> String {
        L10n.tr("reps_with_unit", reps)
    }

    private func repsRangeString(_ min: Int, _ max: Int) -> String {
        L10n.tr("reps_range_with_unit", min, max)
    }

    private func setsString(_ count: Int) -> String {
        L10n.tr("sets_with_unit", count)
    }

    // MARK: - Methods

    /// Updates the planned set count (legacy).
    func updatePlannedSets(_ count: Int) {
        self.plannedSetCount = max(0, count)
    }

    /// Adds a planned set.
    func addPlannedSet(_ set: PlannedSet) {
        plannedSets.append(set)
    }

    /// Creates and adds a new planned set.
    /// - Parameters:
    ///   - metricType: Metric type for this set (defaults to exercise's metricType).
    ///   - weight: Target weight (for weightReps).
    ///   - reps: Target reps (for weightReps and bodyweightReps).
    ///   - durationSeconds: Target duration (for timeDistance).
    ///   - distanceMeters: Target distance (for timeDistance).
    ///   - restTimeSeconds: Rest time in seconds after this set.
    @discardableResult
    func createPlannedSet(
        metricType: SetMetricType? = nil,
        weight: Double? = nil,
        reps: Int? = nil,
        durationSeconds: Int? = nil,
        distanceMeters: Double? = nil,
        restTimeSeconds: Int? = nil
    ) -> PlannedSet {
        let nextOrder = (plannedSets.map(\.orderIndex).max() ?? -1) + 1
        let set = PlannedSet(
            orderIndex: nextOrder,
            metricType: metricType ?? self.metricType,
            targetWeight: weight,
            targetReps: reps,
            targetDurationSeconds: durationSeconds,
            targetDistanceMeters: distanceMeters,
            restTimeSeconds: restTimeSeconds
        )
        addPlannedSet(set)
        return set
    }

    /// Removes a planned set.
    func removePlannedSet(_ set: PlannedSet) {
        plannedSets.removeAll { $0.id == set.id }
    }

    /// Reindexes planned sets after reordering.
    func reindexPlannedSets() {
        for (index, set) in sortedPlannedSets.enumerated() {
            set.orderIndex = index
        }
    }
}
