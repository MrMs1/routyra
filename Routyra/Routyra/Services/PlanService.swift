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

    // MARK: - Day Change (Single Plan Mode)

    /// Changes the current workout day to a different plan day.
    /// Only allowed when completedSets == 0.
    ///
    /// - Parameters:
    ///   - profile: The local profile.
    ///   - workoutDay: The workout day to modify.
    ///   - planId: The plan ID.
    ///   - newDayIndex: The new day index (1-indexed).
    ///   - skipAndAdvance: Whether to also advance the progress pointer.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: True if change was successful.
    @MainActor
    @discardableResult
    static func changeDay(
        profile: LocalProfile,
        workoutDay: WorkoutDay,
        planId: UUID,
        to newDayIndex: Int,
        skipAndAdvance: Bool,
        modelContext: ModelContext
    ) -> Bool {
        // Verify no completed sets
        guard workoutDay.totalCompletedSets == 0 else {
            return false
        }

        // Get the plan and new day
        guard let plan = getPlan(id: planId, modelContext: modelContext),
              let newPlanDay = plan.day(at: newDayIndex) else {
            return false
        }

        // Clear existing entries
        for entry in workoutDay.entries {
            modelContext.delete(entry)
        }
        workoutDay.entries.removeAll()

        // Update the routine day ID
        workoutDay.routineDayId = newPlanDay.id

        // Expand the new plan day
        expandPlanToWorkout(planDay: newPlanDay, workoutDay: workoutDay)

        // Update progress pointer if skip is enabled
        if skipAndAdvance {
            let progress = getOrCreateProgress(
                profileId: profile.id,
                planId: planId,
                modelContext: modelContext
            )
            // Set to next day after the selected one (wrapping around)
            let totalDays = plan.dayCount
            progress.currentDayIndex = (newDayIndex % totalDays) + 1
        }

        return true
    }

    // MARK: - Plan Expansion to Workout

    /// Expands a plan day to a workout day.
    /// Creates exercise entries from the plan day exercises, including planned set details.
    ///
    /// - Parameters:
    ///   - planDay: The plan day to expand.
    ///   - workoutDay: The workout day to populate.
    static func expandPlanToWorkout(
        planDay: PlanDay,
        workoutDay: WorkoutDay
    ) {
        for exercise in planDay.sortedExercises {
            let plannedSets = exercise.sortedPlannedSets
            let effectiveSetCount = plannedSets.isEmpty ? exercise.plannedSetCount : plannedSets.count

            let entry = WorkoutExerciseEntry(
                exerciseId: exercise.exerciseId,
                orderIndex: exercise.orderIndex,
                source: .routine,
                plannedSetCount: effectiveSetCount
            )

            workoutDay.addEntry(entry)

            // Create WorkoutSet objects from planned sets
            if !plannedSets.isEmpty {
                for (index, plannedSet) in plannedSets.enumerated() {
                    let weight = Decimal(plannedSet.targetWeight ?? 0)
                    let reps = plannedSet.targetReps ?? 0
                    let set = WorkoutSet(
                        setIndex: index + 1,
                        weight: weight,
                        reps: reps,
                        isCompleted: false
                    )
                    entry.addSet(set)
                }
            } else if effectiveSetCount > 0 {
                // Fallback: create placeholder sets if plannedSets is empty but count > 0
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
            // If the workout is already set up for this plan day, return as is
            if existingWorkout.routineDayId == planDay.id && existingWorkout.routinePresetId == planId {
                return existingWorkout
            }

            // If the workout is empty (no entries) and not linked to any plan, set it up
            if existingWorkout.entries.isEmpty && existingWorkout.routinePresetId == nil {
                existingWorkout.mode = .routine
                existingWorkout.routinePresetId = planId
                existingWorkout.routineDayId = planDay.id
                expandPlanToWorkout(planDay: planDay, workoutDay: existingWorkout)
                return existingWorkout
            }

            // Otherwise return existing (might have manual entries)
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

    // MARK: - Day Info Resolution

    /// Resolves day info from a plan day ID.
    /// - Parameters:
    ///   - planDayId: The plan day ID (routineDayId from WorkoutDay).
    ///   - planId: The plan ID.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Tuple of (dayIndex, totalDays, dayName) or nil if not found.
    @MainActor
    static func getDayInfo(
        planDayId: UUID,
        planId: UUID,
        modelContext: ModelContext
    ) -> (dayIndex: Int, totalDays: Int, dayName: String?)? {
        guard let plan = getPlan(id: planId, modelContext: modelContext) else {
            return nil
        }

        let sortedDays = plan.sortedDays
        guard let dayIndex = sortedDays.firstIndex(where: { $0.id == planDayId }) else {
            return nil
        }

        return (dayIndex + 1, plan.dayCount, sortedDays[dayIndex].name)
    }

    /// Calculates the preview day for a future date based on current progress.
    /// - Parameters:
    ///   - profile: The local profile.
    ///   - targetDate: The target date to calculate for.
    ///   - todayDate: Today's workout date.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Tuple of (dayIndex, totalDays, dayName, planId) or nil.
    @MainActor
    static func getPreviewDayInfo(
        profile: LocalProfile,
        targetDate: Date,
        todayDate: Date,
        modelContext: ModelContext
    ) -> (dayIndex: Int, totalDays: Int, dayName: String?, planId: UUID)? {
        guard let planId = profile.activePlanId,
              let plan = getPlan(id: planId, modelContext: modelContext) else {
            return nil
        }

        let totalDays = plan.dayCount
        guard totalDays > 0 else { return nil }

        let progress = getOrCreateProgress(
            profileId: profile.id,
            planId: planId,
            modelContext: modelContext
        )

        // Calculate days difference from today
        let calendar = Calendar.current
        let daysDiff = calendar.dateComponents([.day], from: todayDate, to: targetDate).day ?? 0

        // Calculate the target day index (wrap around)
        // currentDayIndex is 1-indexed
        let currentDayIndex = progress.currentDayIndex
        var targetDayIndex = currentDayIndex + daysDiff

        // Handle wrapping (modular arithmetic with 1-indexed)
        targetDayIndex = ((targetDayIndex - 1) % totalDays + totalDays) % totalDays + 1

        let dayName = plan.day(at: targetDayIndex)?.name

        return (targetDayIndex, totalDays, dayName, planId)
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
