//
//  CardioWorkout.swift
//  Routyra
//
//  A cardio workout record, either manually entered or imported from HealthKit.
//  Data structure aligns with HKWorkout for seamless HealthKit integration.
//

import Foundation
import SwiftData

@Model
final class CardioWorkout {
    // MARK: - Identifiers

    /// Unique identifier for this cardio workout.
    var id: UUID

    /// HealthKit workout UUID, if imported from HealthKit.
    /// Used to prevent duplicate imports.
    var healthKitUUID: String?

    // MARK: - Core Properties

    /// The activity type (HKWorkoutActivityType raw value).
    /// Examples: 37 = running, 52 = walking, 13 = cycling, 46 = swimming.
    var activityType: Int

    /// Optional manual activity code for finer-grained labeling (e.g., indoor vs outdoor running).
    /// Only set for manual entries when we need to distinguish beyond HKWorkoutActivityType.
    var manualExerciseCode: String?

    /// The start date and time of the workout.
    var startDate: Date

    /// Duration of the workout in seconds.
    var duration: Double

    /// Total distance in meters (optional).
    var totalDistance: Double?

    /// Total energy burned in kilocalories (optional, HealthKit only).
    var totalEnergyBurned: Double?

    /// Average heart rate in bpm (optional, HealthKit only).
    var averageHeartRate: Double?

    /// Max heart rate in bpm (optional, HealthKit only).
    var maxHeartRate: Double?

    // MARK: - Workout Integration

    /// Whether this cardio workout is completed.
    /// Manual entries start as false, HealthKit imports are always true.
    var isCompleted: Bool

    /// The WorkoutDay this cardio is associated with (optional).
    /// When added from the workout screen, this links the cardio to that day.
    var workoutDayId: UUID?

    /// Order index for display in WorkoutView (relative to other cardio entries).
    var orderIndex: Int

    // MARK: - Metadata

    /// The source of this record (manual or healthKit).
    var source: CardioSource

    /// When this record was created in the app.
    var createdAt: Date

    // MARK: - Relationships

    /// The profile this workout belongs to.
    @Relationship var profile: LocalProfile?

    // MARK: - Initialization

    /// Creates a new cardio workout record.
    /// - Parameters:
    ///   - activityType: HKWorkoutActivityType raw value.
    ///   - manualExerciseCode: Optional manual exercise code for label/icon differentiation.
    ///   - startDate: When the workout started.
    ///   - duration: Duration in seconds.
    ///   - totalDistance: Distance in meters (optional).
    ///   - totalEnergyBurned: Energy burned in kilocalories (optional).
    ///   - averageHeartRate: Average heart rate in bpm (optional).
    ///   - maxHeartRate: Max heart rate in bpm (optional).
    ///   - isCompleted: Whether this workout is completed (default false for manual, true for HealthKit).
    ///   - workoutDayId: Optional WorkoutDay ID to associate with.
    ///   - orderIndex: Display order index.
    ///   - source: Whether manual or from HealthKit.
    ///   - healthKitUUID: HealthKit UUID if imported.
    ///   - profile: The user's profile.
    init(
        activityType: Int,
        manualExerciseCode: String? = nil,
        startDate: Date,
        duration: Double,
        totalDistance: Double? = nil,
        totalEnergyBurned: Double? = nil,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        isCompleted: Bool = false,
        workoutDayId: UUID? = nil,
        orderIndex: Int = 0,
        source: CardioSource = .manual,
        healthKitUUID: String? = nil,
        profile: LocalProfile? = nil
    ) {
        self.id = UUID()
        self.activityType = activityType
        self.manualExerciseCode = manualExerciseCode
        self.startDate = startDate
        self.duration = duration
        self.totalDistance = totalDistance
        self.totalEnergyBurned = totalEnergyBurned
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.isCompleted = isCompleted
        self.workoutDayId = workoutDayId
        self.orderIndex = orderIndex
        self.source = source
        self.healthKitUUID = healthKitUUID
        self.createdAt = Date()
        self.profile = profile
    }

    // MARK: - Computed Properties

    /// Duration formatted as "HH:mm:ss" or "mm:ss".
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Distance formatted in kilometers with one decimal place.
    var formattedDistance: String? {
        guard let distance = totalDistance else { return nil }
        let km = distance / 1000.0
        return String(format: "%.1f km", km)
    }

    /// Energy burned formatted in kilocalories.
    var formattedEnergyBurned: String? {
        guard let energy = totalEnergyBurned, energy > 0 else { return nil }
        return String(format: "%.0f kcal", energy)
    }

    /// Energy burned formatted with label.
    var formattedEnergyBurnedLabel: String? {
        guard let energy = totalEnergyBurned, energy > 0 else { return nil }
        return L10n.tr("cardio_energy_burned", Int(energy.rounded()))
    }

    /// Average heart rate formatted in bpm.
    var formattedAverageHeartRate: String? {
        guard let heartRate = averageHeartRate, heartRate > 0 else { return nil }
        return String(format: "%.0f bpm", heartRate)
    }

    /// Average heart rate formatted in bpm with label.
    var formattedAverageHeartRateLabel: String? {
        guard let heartRate = averageHeartRate, heartRate > 0 else { return nil }
        return L10n.tr("cardio_avg_heart_rate", Int(heartRate.rounded()))
    }

    /// Max heart rate formatted in bpm with label.
    var formattedMaxHeartRate: String? {
        guard let heartRate = maxHeartRate, heartRate > 0 else { return nil }
        return L10n.tr("cardio_max_heart_rate", Int(heartRate.rounded()))
    }

    /// Max heart rate formatted in bpm (value only).
    var formattedMaxHeartRateValue: String? {
        guard let heartRate = maxHeartRate, heartRate > 0 else { return nil }
        return String(format: "%.0f bpm", heartRate)
    }

    /// The date portion of startDate (normalized to start of day).
    var workoutDate: Date {
        Calendar.current.startOfDay(for: startDate)
    }
}
