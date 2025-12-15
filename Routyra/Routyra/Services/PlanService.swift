//
//  PlanService.swift
//  Routyra
//
//  Service for managing workout plans, plan progress, and plan-to-workout expansion.
//  Handles the core plan logic including day advancement.
//

import Foundation
import SwiftData

/// Service for workout plan management and progress tracking.
enum PlanService {
    // MARK: - Workout Plan Management

    /// Creates a new workout plan.
    /// - Parameters:
    ///   - profileId: Owner profile ID.
    ///   - name: Display name for the plan.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: The created workout plan.
    @MainActor
    @discardableResult
    static func createPlan(
        profileId: UUID,
        name: String,
        modelContext: ModelContext
    ) -> WorkoutPlan {
        let plan = WorkoutPlan(profileId: profileId, name: name)
        modelContext.insert(plan)
        return plan
    }

    /// Gets all workout plans for a profile.
    /// - Parameters:
    ///   - profileId: Owner profile ID.
    ///   - includeArchived: Whether to include archived plans.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Array of workout plans.
    @MainActor
    static func getPlans(
        profileId: UUID,
        includeArchived: Bool = false,
        modelContext: ModelContext
    ) -> [WorkoutPlan] {
        let descriptor = FetchDescriptor<WorkoutPlan>(
            predicate: #Predicate<WorkoutPlan> { plan in
                plan.profileId == profileId && (includeArchived || !plan.isArchived)
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching plans: \(error)")
            return []
        }
    }

    /// Gets a workout plan by ID.
    /// - Parameters:
    ///   - planId: The plan ID.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: The plan if found.
    @MainActor
    static func getPlan(id planId: UUID, modelContext: ModelContext) -> WorkoutPlan? {
        var descriptor = FetchDescriptor<WorkoutPlan>(
            predicate: #Predicate<WorkoutPlan> { $0.id == planId }
        )
        descriptor.fetchLimit = 1

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("Error fetching plan: \(error)")
            return nil
        }
    }

    // MARK: - Plan Progress Management

    /// Gets or creates a plan progress tracker for a profile and plan.
    /// - Parameters:
    ///   - profileId: Owner profile ID.
    ///   - planId: The workout plan ID.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: The plan progress tracker.
    @MainActor
    static func getOrCreateProgress(
        profileId: UUID,
        planId: UUID,
        modelContext: ModelContext
    ) -> PlanProgress {
        // Try to find existing progress
        var descriptor = FetchDescriptor<PlanProgress>(
            predicate: #Predicate<PlanProgress> { progress in
                progress.profileId == profileId && progress.planId == planId
            }
        )
        descriptor.fetchLimit = 1

        do {
            if let existing = try modelContext.fetch(descriptor).first {
                return existing
            }
        } catch {
            print("Error fetching progress: \(error)")
        }

        // Create new progress
        let progress = PlanProgress(profileId: profileId, planId: planId)
        modelContext.insert(progress)
        return progress
    }

    // MARK: - Day Advancement Logic

    /// Handles app open for plan mode.
    /// Checks if day should advance based on previous day's completion.
    ///
    /// Logic:
    /// 1. Get or create progress tracker
    /// 2. If lastOpenedDate is nil, set to today and don't advance
    /// 3. If lastOpenedDate != today:
    ///    - Check if previous day's workout exists and is completed
    ///    - If completed, advance to next day (wrap around)
    ///    - Update lastOpenedDate to today
    /// 4. Return the current day index to show
    ///
    /// - Parameters:
    ///   - profileId: Owner profile ID.
    ///   - planId: The workout plan ID.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: The plan day index to show today (1-indexed).
    @MainActor
    static func handleAppOpen(
        profileId: UUID,
        planId: UUID,
        modelContext: ModelContext
    ) -> Int {
        // Get the plan
        guard let plan = getPlan(id: planId, modelContext: modelContext) else {
            return 1 // Default to day 1 if plan not found
        }

        let totalDays = plan.dayCount
        guard totalDays > 0 else { return 1 }

        // Get or create progress tracker
        let progress = getOrCreateProgress(
            profileId: profileId,
            planId: planId,
            modelContext: modelContext
        )

        let today = DateUtilities.today

        // First time using this plan
        guard let lastOpenedDate = progress.lastOpenedDate else {
            progress.lastOpenedDate = today
            return progress.currentDayIndex
        }

        // Same day - no advancement needed
        if DateUtilities.isSameDay(lastOpenedDate, today) {
            return progress.currentDayIndex
        }

        // Different day - check if previous plan day was completed
        let shouldAdvance = checkPreviousDayCompletion(
            profileId: profileId,
            planId: planId,
            date: lastOpenedDate,
            modelContext: modelContext
        )

        if shouldAdvance {
            progress.advanceToNextDay(totalDays: totalDays)
        }

        progress.lastOpenedDate = today
        return progress.currentDayIndex
    }

    /// Checks if the workout for a previous date in plan mode was completed.
    /// - Parameters:
    ///   - profileId: Owner profile ID.
    ///   - planId: The workout plan ID.
    ///   - date: The date to check.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: True if the workout was completed.
    @MainActor
    private static func checkPreviousDayCompletion(
        profileId: UUID,
        planId: UUID,
        date: Date,
        modelContext: ModelContext
    ) -> Bool {
        guard let workoutDay = WorkoutService.getWorkoutDay(
            profileId: profileId,
            date: date,
            modelContext: modelContext
        ) else {
            // No workout for that day - don't advance
            return false
        }

        // Must be in plan mode with the same plan
        guard workoutDay.mode == .routine,
              workoutDay.routinePresetId == planId else {
            return false
        }

        return workoutDay.isRoutineCompleted
    }

    // MARK: - Plan Expansion to Workout

    /// Expands a plan day to a workout day.
    /// Creates exercise entries from the plan day exercises.
    ///
    /// - Parameters:
    ///   - planDay: The plan day to expand.
    ///   - workoutDay: The workout day to populate.
    ///   - createPlaceholderSets: Whether to pre-create placeholder sets (default false).
    ///
    /// Note: We use lazy set creation by default (createPlaceholderSets = false).
    /// Sets are created when the user actually logs them.
    /// If you prefer placeholder sets, pass createPlaceholderSets = true.
    static func expandPlanToWorkout(
        planDay: PlanDay,
        workoutDay: WorkoutDay,
        createPlaceholderSets: Bool = false
    ) {
        for exercise in planDay.sortedExercises {
            let entry = WorkoutExerciseEntry(
                exerciseId: exercise.exerciseId,
                orderIndex: exercise.orderIndex,
                source: .routine,
                plannedSetCount: exercise.plannedSetCount
            )

            workoutDay.addEntry(entry)

            // Optionally create placeholder sets
            if createPlaceholderSets && exercise.plannedSetCount > 0 {
                entry.createPlaceholderSets()
            }
        }
    }

    /// Sets up today's workout from the active plan.
    /// This is the main entry point for plan-based workout creation.
    ///
    /// - Parameters:
    ///   - profile: The local profile.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Today's workout day (created or existing), or nil if no active plan.
    @MainActor
    static func setupTodayWorkout(
        profile: LocalProfile,
        modelContext: ModelContext
    ) -> WorkoutDay? {
        // Check if profile has active plan
        guard let planId = profile.activePlanId else {
            // Free mode - no plan setup needed
            return nil
        }

        // Get the plan day index for today (handles advancement)
        let dayIndex = handleAppOpen(
            profileId: profile.id,
            planId: planId,
            modelContext: modelContext
        )

        // Get the plan and day
        guard let plan = getPlan(id: planId, modelContext: modelContext),
              let planDay = plan.day(at: dayIndex) else {
            return nil
        }

        // Check if workout already exists for today
        if let existingWorkout = WorkoutService.getTodayWorkout(
            profileId: profile.id,
            modelContext: modelContext
        ) {
            return existingWorkout
        }

        // Create new workout day in plan mode
        let workoutDay = WorkoutService.getOrCreateWorkoutDay(
            profileId: profile.id,
            date: Date(),
            mode: .routine,
            routinePresetId: planId,
            routineDayId: planDay.id,
            modelContext: modelContext
        )

        // Expand plan to workout
        expandPlanToWorkout(planDay: planDay, workoutDay: workoutDay)

        return workoutDay
    }

    // MARK: - Exercise Lookup Helper

    /// Gets an exercise by ID.
    /// - Parameters:
    ///   - exerciseId: The exercise ID.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: The exercise if found.
    @MainActor
    static func getExercise(id exerciseId: UUID, modelContext: ModelContext) -> Exercise? {
        var descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate<Exercise> { $0.id == exerciseId }
        )
        descriptor.fetchLimit = 1

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("Error fetching exercise: \(error)")
            return nil
        }
    }

    /// Gets all available exercises for selection.
    /// - Parameters:
    ///   - profileId: Profile ID for user exercises.
    ///   - includeArchived: Whether to include archived exercises.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Array of exercises (global + user's custom).
    /// Note: Due to SwiftData predicate limitations with enums, we filter in memory.
    @MainActor
    static func getAvailableExercises(
        profileId: UUID,
        includeArchived: Bool = false,
        modelContext: ModelContext
    ) -> [Exercise] {
        // Fetch all exercises and filter in memory due to enum predicate limitations
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [
                SortDescriptor(\.category),
                SortDescriptor(\.name)
            ]
        )

        do {
            let allExercises = try modelContext.fetch(descriptor)
            return allExercises.filter { exercise in
                (includeArchived || !exercise.isArchived) &&
                (exercise.scope == .global || exercise.ownerProfileId == profileId)
            }
        } catch {
            print("Error fetching exercises: \(error)")
            return []
        }
    }
}
