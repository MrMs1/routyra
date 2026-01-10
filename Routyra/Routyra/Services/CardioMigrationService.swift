//
//  CardioMigrationService.swift
//  Routyra
//
//  Migrates existing timeDistance workout data to the new CardioWorkout model.
//

import Foundation
import SwiftData
import HealthKit

/// Service for migrating existing cardio data (WorkoutSet with timeDistance)
/// to the new CardioWorkout model.
enum CardioMigrationService {
    // MARK: - Migration Status Key

    private static let migrationCompletedKey = "CardioMigrationCompleted_v2"

    /// Checks if migration has already been completed.
    static var isMigrationCompleted: Bool {
        UserDefaults.standard.bool(forKey: migrationCompletedKey)
    }

    /// Marks migration as completed.
    private static func markMigrationCompleted() {
        UserDefaults.standard.set(true, forKey: migrationCompletedKey)
    }

    // MARK: - Migration

    /// Performs migration if not already completed.
    /// Should be called on app launch.
    @MainActor
    static func migrateIfNeeded(modelContext: ModelContext) {
        guard !isMigrationCompleted else { return }

        do {
            let migratedCount = try performMigration(modelContext: modelContext)
            markMigrationCompleted()
            print("CardioMigrationService: Migrated \(migratedCount) cardio workouts")
        } catch {
            print("CardioMigrationService: Migration failed: \(error)")
        }
    }

    /// Performs the actual migration.
    /// - Returns: Number of CardioWorkout records created.
    @MainActor
    private static func performMigration(modelContext: ModelContext) throws -> Int {
        // 1. Get cardio body part
        let bodyPartDescriptor = FetchDescriptor<BodyPart>()
        let bodyParts = try modelContext.fetch(bodyPartDescriptor)
        guard let cardioBodyPart = bodyParts.first(where: { $0.code == "cardio" }) else {
            print("CardioMigrationService: No cardio body part found")
            return 0
        }

        // 2. Get all exercises
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        let exercises = try modelContext.fetch(exerciseDescriptor)

        // 3. Get cardio exercise IDs
        let cardioExercises = exercises.filter { $0.bodyPartId == cardioBodyPart.id }
        let cardioExerciseIds = Set(cardioExercises.map(\.id))
        let exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        guard !cardioExerciseIds.isEmpty else {
            print("CardioMigrationService: No cardio exercises found")
            return 0
        }

        // 4. Get profile
        let profile = ProfileService.getProfile(modelContext: modelContext)
            ?? ProfileService.getOrCreateProfile(modelContext: modelContext)

        // 5. Build order index cache for linked workout days
        let existingCardioDescriptor = FetchDescriptor<CardioWorkout>()
        let existingCardioWorkouts = try modelContext.fetch(existingCardioDescriptor)
        var maxOrderIndexByDay: [UUID: Int] = [:]
        for workout in existingCardioWorkouts {
            guard let dayId = workout.workoutDayId else { continue }
            maxOrderIndexByDay[dayId] = max(maxOrderIndexByDay[dayId] ?? -1, workout.orderIndex)
        }

        // 6. Get all workout entries with timeDistance sets
        let entryDescriptor = FetchDescriptor<WorkoutExerciseEntry>()
        let entries = try modelContext.fetch(entryDescriptor)

        var migratedCount = 0
        var didChange = false

        for entry in entries {
            // Check if this entry's exercise is a cardio exercise
            guard cardioExerciseIds.contains(entry.exerciseId),
                  let workoutDay = entry.workoutDay,
                  let exercise = exerciseMap[entry.exerciseId] else {
                continue
            }

            // Resolve activity type
            let activityType = CardioActivityTypeResolver.activityType(for: exercise)

            // Migrate all timeDistance sets with actual data
            let setsToMigrate = entry.activeSets.filter { $0.metricType == .timeDistance }
            for set in setsToMigrate {
                let durationValue = set.durationSeconds ?? 0
                let distanceValue = set.distanceMeters ?? 0

                guard durationValue > 0 || distanceValue > 0 else {
                    continue
                }

                let nextOrderIndex = (maxOrderIndexByDay[workoutDay.id] ?? -1) + 1
                maxOrderIndexByDay[workoutDay.id] = nextOrderIndex

                let totalDistance = (set.distanceMeters ?? 0) > 0 ? set.distanceMeters : nil
                let cardioWorkout = CardioWorkout(
                    activityType: Int(activityType.rawValue),
                    startDate: workoutDay.date,
                    duration: Double(durationValue),
                    totalDistance: totalDistance,
                    isCompleted: set.isCompleted,
                    workoutDayId: workoutDay.id,
                    orderIndex: nextOrderIndex,
                    source: .manual,
                    profile: profile
                )

                modelContext.insert(cardioWorkout)
                migratedCount += 1
                didChange = true
            }

            // Remove legacy cardio entry after migration
            if let group = entry.group {
                group.entries.removeAll { $0.id == entry.id }
                entry.group = nil
                entry.groupOrderIndex = nil
                if group.entries.isEmpty, let workoutDay = entry.workoutDay {
                    workoutDay.exerciseGroups.removeAll { $0.id == group.id }
                    modelContext.delete(group)
                }
            }
            workoutDay.entries.removeAll { $0.id == entry.id }
            modelContext.delete(entry)
            didChange = true
        }

        if didChange {
            try modelContext.save()
        }

        return migratedCount
    }

    // MARK: - Reset (for testing)

    /// Resets migration status (for testing purposes only).
    static func resetMigrationStatus() {
        UserDefaults.standard.removeObject(forKey: migrationCompletedKey)
    }
}
