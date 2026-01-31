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
    /// Uses a 2-phase approach: Phase 1 saves basic data immediately for fast UI update,
    /// Phase 2 backfills heart rate data in parallel.
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
        // Collect workouts that need heart rate backfill: (CardioWorkout, HKWorkout)
        var heartRateBackfillTargets: [(CardioWorkout, HKWorkout)] = []

        // MARK: Phase 1 - Insert/update basic data immediately

        for workout in workouts {
            let uuid = workout.uuid.uuidString

            if let existing = existingByUUID[uuid] {
                var didUpdate = false
                if existing.totalEnergyBurned == nil,
                   let energy = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                    existing.totalEnergyBurned = energy
                    didUpdate = true
                }

                // Queue for heart rate backfill if missing
                if existing.averageHeartRate == nil || existing.maxHeartRate == nil {
                    heartRateBackfillTargets.append((existing, workout))
                    didUpdate = true
                }

                if didUpdate {
                    updatedCount += 1
                }
                continue
            }

            // Insert new workout without heart rate (will be backfilled in Phase 2)
            let cardioWorkout = CardioWorkout(
                activityType: Int(workout.workoutActivityType.rawValue),
                startDate: workout.startDate,
                duration: workout.duration,
                totalDistance: workout.totalDistance?.doubleValue(for: .meter()),
                totalEnergyBurned: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                averageHeartRate: nil,
                maxHeartRate: nil,
                isCompleted: true,
                workoutDayId: nil,
                orderIndex: 0,
                source: .healthKit,
                healthKitUUID: uuid,
                profile: profile
            )

            modelContext.insert(cardioWorkout)
            heartRateBackfillTargets.append((cardioWorkout, workout))
            importedCount += 1
        }

        // Save basic data so @Query updates and UI reflects immediately
        if importedCount > 0 || updatedCount > 0 {
            try modelContext.save()
        }

        // MARK: Phase 2 - Backfill heart rate data

        if !heartRateBackfillTargets.isEmpty {
            // Phase 2a: Fetch heart rate stats in parallel (no model operations)
            let hkWorkouts = heartRateBackfillTargets.map { $0.1 }
            let heartRateResults = await fetchHeartRateStatsInParallel(for: hkWorkouts)

            // Phase 2b: Apply results to models on MainActor
            var heartRateUpdated = false
            for (index, (cardioWorkout, _)) in heartRateBackfillTargets.enumerated() {
                let stats = heartRateResults[index]
                if cardioWorkout.averageHeartRate == nil, let avg = stats.average {
                    cardioWorkout.averageHeartRate = avg
                    heartRateUpdated = true
                }
                if cardioWorkout.maxHeartRate == nil, let max = stats.max {
                    cardioWorkout.maxHeartRate = max
                    heartRateUpdated = true
                }
            }

            if heartRateUpdated {
                try modelContext.save()
            }
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

    struct HeartRateStats {
        let average: Double?
        let max: Double?
    }

    /// Maximum number of concurrent heart rate queries to avoid HealthKit throttling.
    private static let maxConcurrentHeartRateQueries = 5

    /// Fetches heart rate stats for multiple workouts in parallel (max 5 concurrent).
    /// Individual failures are silently caught and return nil values.
    private static func fetchHeartRateStatsInParallel(for workouts: [HKWorkout]) async -> [HeartRateStats] {
        var results = Array(repeating: HeartRateStats(average: nil, max: nil), count: workouts.count)

        await withTaskGroup(of: (Int, HeartRateStats).self) { group in
            var nextIndex = 0

            // Seed initial batch
            while nextIndex < min(maxConcurrentHeartRateQueries, workouts.count) {
                let index = nextIndex
                group.addTask { await fetchHeartRateStatsSafe(for: workouts[index], index: index) }
                nextIndex += 1
            }

            // As each completes, launch the next
            for await (index, stats) in group {
                results[index] = stats
                if nextIndex < workouts.count {
                    let index = nextIndex
                    group.addTask { await fetchHeartRateStatsSafe(for: workouts[index], index: index) }
                    nextIndex += 1
                }
            }
        }

        return results
    }

    /// Fetches heart rate stats for a single workout, returning nil values on failure.
    private static func fetchHeartRateStatsSafe(for workout: HKWorkout, index: Int) async -> (Int, HeartRateStats) {
        do {
            let stats = try await fetchHeartRateStats(for: workout)
            return (index, stats)
        } catch {
            print("HealthKitService: Heart rate fetch failed for workout \(workout.uuid): \(error)")
            return (index, HeartRateStats(average: nil, max: nil))
        }
    }

    /// Fetches heart rate statistics (average/max bpm) for a workout.
    static func fetchHeartRateStats(for workout: HKWorkout) async throws -> HeartRateStats {
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
        case .stepTraining: return L10n.tr("activity_step_training")
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
