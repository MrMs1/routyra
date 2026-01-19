//
//  RoutyraApp.swift
//  Routyra
//
//  Created by 村田昌知 on 2025/12/14.
//

import SwiftUI
import SwiftData
import GoogleMobileAds
import Combine
import HealthKit

// MARK: - Watch Sync Coordinator

/// Coordinates Watch connectivity at the app level to ensure sync requests are handled
/// even when WorkoutView is not active.
@MainActor
final class WatchSyncCoordinator: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private weak var modelContainer: ModelContainer?

    init() {
        // Initialize PhoneWatchConnectivityManager singleton early
        _ = PhoneWatchConnectivityManager.shared

        // Observe sync requests from Watch
        NotificationCenter.default.publisher(for: .watchRequestedSync)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleSyncRequest()
            }
            .store(in: &cancellables)

        // Push updates when the user changes theme on iPhone,
        // so Watch can pick up the latest accent immediately.
        NotificationCenter.default.publisher(for: .themeDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleSyncRequest()
            }
            .store(in: &cancellables)
    }

    func configure(with container: ModelContainer) {
        self.modelContainer = container
        // Send initial data to Watch when app launches
        handleSyncRequest()
    }

    private func handleSyncRequest() {
        guard let container = modelContainer else { return }

        let context = ModelContext(container)

        // Fetch profile
        let profile = ProfileService.getOrCreateProfile(modelContext: context)

        // Calculate workout date (respects transition hour)
        let workoutDate = DateUtilities.todayWorkoutDate(transitionHour: profile.dayTransitionHour)

        // Get existing WorkoutDay (do NOT create or advance day here)
        // Day advancement and workout creation are handled by WorkoutView.onAppear
        // If workoutDay is nil, we send empty data to Watch
        let workoutDay = WorkoutService.getWorkoutDay(
            profileId: profile.id,
            date: workoutDate,
            modelContext: context
        )

        // Fetch exercises and body parts
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        let bodyPartDescriptor = FetchDescriptor<BodyPart>()

        do {
            let exercises = try context.fetch(exerciseDescriptor)
            let bodyParts = try context.fetch(bodyPartDescriptor)

            PhoneWatchConnectivityManager.shared.sendWorkoutData(
                workoutDay: workoutDay,
                exercises: exercises,
                bodyParts: bodyParts,
                defaultRestTimeSeconds: profile.defaultRestTimeSeconds,
                combineRecordAndTimerStart: profile.combineRecordAndTimerStart,
                skipRestTimerOnFinalSet: profile.skipRestTimerOnFinalSet
            )
        } catch {
            print("WatchSyncCoordinator: Failed to fetch data: \(error)")
        }
    }
}

// MARK: - App

@main
struct RoutyraApp: App {
    @StateObject private var watchSyncCoordinator: WatchSyncCoordinator

    init() {
        let coordinator = WatchSyncCoordinator()
        _watchSyncCoordinator = StateObject(wrappedValue: coordinator)

        // Initialize Google Mobile Ads SDK
        MobileAds.shared.start(completionHandler: nil)

        // Configure watch sync as early as possible to handle background sync requests.
        coordinator.configure(with: sharedModelContainer)
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Core entities
            LocalProfile.self,
            BodyPart.self,
            BodyPartTranslation.self,
            Exercise.self,
            ExerciseTranslation.self,

            // Workout entities
            WorkoutDay.self,
            WorkoutExerciseEntry.self,
            WorkoutExerciseGroup.self,
            WorkoutSet.self,

            // Plan entities
            WorkoutPlan.self,
            PlanDay.self,
            PlanExercise.self,
            PlanExerciseGroup.self,
            PlannedSet.self,
            PlanProgress.self,

            // Cycle entities
            PlanCycle.self,
            PlanCycleItem.self,
            PlanCycleProgress.self,

            // Cardio entities
            CardioWorkout.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    // Run cardio data migration
                    let context = ModelContext(sharedModelContainer)
                    CardioMigrationService.migrateIfNeeded(modelContext: context)

                    // Sync HealthKit workouts (incremental, with cooldown)
                    Task {
                        await syncHealthKitWorkoutsIfNeeded(modelContext: context)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Syncs HealthKit workouts incrementally at app launch.
    /// Only runs if HealthKit is available and authorized.
    @MainActor
    private func syncHealthKitWorkoutsIfNeeded(modelContext: ModelContext) async {
        guard HealthKitService.isHealthKitAvailable else { return }

        let status = HealthKitService.authorizationStatus()
        guard status == .sharingAuthorized else { return }

        let profile = ProfileService.getOrCreateProfile(modelContext: modelContext)

        do {
            let imported = try await HealthKitService.syncIncrementalWorkouts(
                profile: profile,
                modelContext: modelContext
            )
            if let count = imported, count > 0 {
                print("RoutyraApp: Synced \(count) workouts from HealthKit")
            }
        } catch {
            print("RoutyraApp: HealthKit sync failed: \(error)")
        }
    }
}
