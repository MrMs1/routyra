//
//  HealthKitService.swift
//  Routyra
//
//  Service for reading workout data from HealthKit.
//  Read-only: does not write data back to HealthKit.
//

import Foundation
import HealthKit
import SwiftData

/// Service for importing cardio workouts from HealthKit.
enum HealthKitService {
    // MARK: - Properties

    /// Shared HealthKit store instance.
    private static let healthStore = HKHealthStore()

    /// The workout type we read from HealthKit.
    private static let workoutType = HKObjectType.workoutType()

    // MARK: - Authorization

    /// Checks if HealthKit is available on this device.
    static var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Checks the current authorization status for reading workouts.
    static func authorizationStatus() -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: workoutType)
    }

    /// Requests authorization to read workout data from HealthKit.
    /// - Returns: True if authorization was granted or already authorized.
    static func requestAuthorization() async -> Bool {
        guard isHealthKitAvailable else { return false }

        var typesToRead: Set<HKObjectType> = [workoutType]
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            typesToRead.insert(heartRateType)
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            return true
        } catch {
            print("HealthKitService: Authorization failed: \(error)")
            return false
        }
    }

    // MARK: - Fetch Workouts

    /// Fetches workouts from HealthKit within the specified date range.
    /// - Parameters:
    ///   - startDate: The start of the date range.
    ///   - endDate: The end of the date range.
    /// - Returns: Array of HKWorkout objects.
    static func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }

            healthStore.execute(query)
        }
    }

    /// Fetches all workouts from HealthKit (no date filter).
    /// - Parameter limit: Maximum number of workouts to fetch.
    /// - Returns: Array of HKWorkout objects.
    static func fetchAllWorkouts(limit: Int = HKObjectQueryNoLimit) async throws -> [HKWorkout] {
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Import to App

    /// Imports workouts from HealthKit into the app's data store.
    /// Skips workouts that have already been imported (based on UUID).
    /// - Parameters:
    ///   - workouts: Array of HKWorkout to import.
    ///   - profile: The user's profile.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Number of newly imported workouts.
    @MainActor
    static func importWorkouts(
        _ workouts: [HKWorkout],
        profile: LocalProfile,
        modelContext: ModelContext
    ) async throws -> Int {
        // Fetch existing HealthKit workouts to avoid duplicates and backfill new fields
        let existingWorkouts = try fetchExistingHealthKitWorkouts(modelContext: modelContext)
        let existingByUUID: [String: CardioWorkout] = Dictionary(
            uniqueKeysWithValues: existingWorkouts.compactMap { workout -> (String, CardioWorkout)? in
                guard let uuid = workout.healthKitUUID else { return nil }
                return (uuid, workout)
            }
        )

        var importedCount = 0
        var updatedCount = 0

        for workout in workouts {
            let uuid = workout.uuid.uuidString

            if let existing = existingByUUID[uuid] {
                var didUpdate = false
                if existing.totalEnergyBurned == nil,
                   let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                    existing.totalEnergyBurned = energy
                    didUpdate = true
                }

                if existing.averageHeartRate == nil || existing.maxHeartRate == nil {
                    let heartRateStats: HeartRateStats
                    do {
                        heartRateStats = try await fetchHeartRateStats(for: workout)
                    } catch {
                        heartRateStats = HeartRateStats(average: nil, max: nil)
                    }

                    if existing.averageHeartRate == nil, let averageHeartRate = heartRateStats.average {
                        existing.averageHeartRate = averageHeartRate
                        didUpdate = true
                    }
                    if existing.maxHeartRate == nil, let maxHeartRate = heartRateStats.max {
                        existing.maxHeartRate = maxHeartRate
                        didUpdate = true
                    }
                }

                if didUpdate {
                    updatedCount += 1
                }
                continue
            }

            let heartRateStats: HeartRateStats
            do {
                heartRateStats = try await fetchHeartRateStats(for: workout)
            } catch {
                heartRateStats = HeartRateStats(average: nil, max: nil)
            }

            let cardioWorkout = CardioWorkout(
                activityType: Int(workout.workoutActivityType.rawValue),
                startDate: workout.startDate,
                duration: workout.duration,
                totalDistance: workout.totalDistance?.doubleValue(for: .meter()),
                totalEnergyBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                averageHeartRate: heartRateStats.average,
                maxHeartRate: heartRateStats.max,
                isCompleted: true,  // HealthKit imports are always completed
                workoutDayId: nil,  // Not linked to workout screen (history only)
                orderIndex: 0,
                source: .healthKit,
                healthKitUUID: uuid,
                profile: profile
            )

            modelContext.insert(cardioWorkout)
            importedCount += 1
        }

        if importedCount > 0 || updatedCount > 0 {
            try modelContext.save()
        }

        return importedCount
    }

    /// Fetches existing HealthKit workouts from the local database.
    private static func fetchExistingHealthKitWorkouts(modelContext: ModelContext) throws -> [CardioWorkout] {
        var descriptor = FetchDescriptor<CardioWorkout>(
            predicate: #Predicate { $0.healthKitUUID != nil }
        )
        return try modelContext.fetch(descriptor)
    }

    private struct HeartRateStats {
        let average: Double?
        let max: Double?
    }

    /// Fetches heart rate statistics (average/max bpm) for a workout.
    private static func fetchHeartRateStats(for workout: HKWorkout) async throws -> HeartRateStats {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return HeartRateStats(average: nil, max: nil)
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: [.discreteAverage, .discreteMax]
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let unit = HKUnit.count().unitDivided(by: .minute())
                let average = result?.averageQuantity()?.doubleValue(for: unit)
                let max = result?.maximumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: HeartRateStats(average: average, max: max))
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Sync

    /// Syncs recent workouts from HealthKit.
    /// Fetches workouts from the last 30 days and imports new ones.
    /// - Parameters:
    ///   - profile: The user's profile.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Number of newly imported workouts.
    @MainActor
    static func syncRecentWorkouts(
        profile: LocalProfile,
        modelContext: ModelContext
    ) async throws -> Int {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate

        let workouts = try await fetchWorkouts(from: startDate, to: endDate)
        return try await importWorkouts(workouts, profile: profile, modelContext: modelContext)
    }

    /// Cooldown duration before allowing another sync (1 hour).
    private static let syncCooldownSeconds: TimeInterval = 3600

    /// Syncs workouts incrementally from HealthKit.
    /// - On first sync: fetches last 30 days
    /// - On subsequent syncs: fetches from last sync date (with 1-hour buffer)
    /// - Respects cooldown: skips if less than 1 hour since last sync
    /// - Parameters:
    ///   - profile: The user's profile.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Number of newly imported workouts, or nil if skipped due to cooldown.
    @MainActor
    static func syncIncrementalWorkouts(
        profile: LocalProfile,
        modelContext: ModelContext
    ) async throws -> Int? {
        // Check cooldown
        if let lastSync = profile.lastHealthKitSyncDate {
            let elapsed = Date().timeIntervalSince(lastSync)
            if elapsed < syncCooldownSeconds {
                return nil  // Skip due to cooldown
            }
        }

        let endDate = Date()
        let startDate: Date

        if let lastSync = profile.lastHealthKitSyncDate {
            // Incremental: from 1 hour before last sync (buffer for edge cases)
            startDate = Calendar.current.date(byAdding: .hour, value: -1, to: lastSync) ?? lastSync
        } else {
            // First sync: last 30 days
            startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        }

        let workouts = try await fetchWorkouts(from: startDate, to: endDate)
        let importedCount = try await importWorkouts(workouts, profile: profile, modelContext: modelContext)

        // Update last sync date
        profile.lastHealthKitSyncDate = endDate
        try modelContext.save()

        return importedCount
    }
}

// MARK: - HKWorkoutActivityType Extensions

extension HKWorkoutActivityType {
    /// Localized display name for the activity type.
    var displayName: String {
        switch self {
        case .running: return L10n.tr("activity_running")
        case .walking: return L10n.tr("activity_walking")
        case .cycling: return L10n.tr("activity_cycling")
        case .swimming: return L10n.tr("activity_swimming")
        case .hiking: return L10n.tr("activity_hiking")
        case .elliptical: return L10n.tr("activity_elliptical")
        case .rowing: return L10n.tr("activity_rowing")
        case .stairClimbing: return L10n.tr("activity_stair_climbing")
        case .stairs: return L10n.tr("activity_stairs")
        case .highIntensityIntervalTraining: return L10n.tr("activity_hiit")
        case .mixedCardio: return L10n.tr("activity_mixed_cardio")
        case .jumpRope: return L10n.tr("activity_jump_rope")
        case .dance: return L10n.tr("activity_dance")
        case .cardioDance: return L10n.tr("activity_cardio_dance")
        case .socialDance: return L10n.tr("activity_social_dance")
        case .yoga: return L10n.tr("activity_yoga")
        case .pilates: return L10n.tr("activity_pilates")
        case .coreTraining: return L10n.tr("activity_core_training")
        case .functionalStrengthTraining: return L10n.tr("activity_functional_strength")
        case .traditionalStrengthTraining: return L10n.tr("activity_traditional_strength")
        case .crossTraining: return L10n.tr("activity_cross_training")
        case .kickboxing: return L10n.tr("activity_kickboxing")
        case .martialArts: return L10n.tr("activity_martial_arts")
        case .boxing: return L10n.tr("activity_boxing")
        case .climbing: return L10n.tr("activity_climbing")
        case .crossCountrySkiing: return L10n.tr("activity_cross_country_skiing")
        case .downhillSkiing: return L10n.tr("activity_downhill_skiing")
        case .snowSports: return L10n.tr("activity_snow_sports")
        case .snowboarding: return L10n.tr("activity_snowboarding")
        case .skatingSports: return L10n.tr("activity_skating")
        case .surfingSports: return L10n.tr("activity_surfing")
        case .waterFitness: return L10n.tr("activity_water_fitness")
        case .tennis: return L10n.tr("activity_tennis")
        case .badminton: return L10n.tr("activity_badminton")
        case .tableTennis: return L10n.tr("activity_table_tennis")
        case .squash: return L10n.tr("activity_squash")
        case .racquetball: return L10n.tr("activity_racquetball")
        case .golf: return L10n.tr("activity_golf")
        case .baseball: return L10n.tr("activity_baseball")
        case .softball: return L10n.tr("activity_softball")
        case .basketball: return L10n.tr("activity_basketball")
        case .soccer: return L10n.tr("activity_soccer")
        case .volleyball: return L10n.tr("activity_volleyball")
        case .americanFootball: return L10n.tr("activity_american_football")
        case .australianFootball: return L10n.tr("activity_australian_football")
        case .rugby: return L10n.tr("activity_rugby")
        case .hockey: return L10n.tr("activity_hockey")
        case .lacrosse: return L10n.tr("activity_lacrosse")
        case .handball: return L10n.tr("activity_handball")
        case .cricket: return L10n.tr("activity_cricket")
        default: return L10n.tr("activity_other")
        }
    }
}
