//
//  PlanService.swift
//  Routyra
//
//  Service for managing workout plans, plan progress, and plan-to-workout expansion.
//  Handles the core plan logic including day advancement.
//

import Foundation
import SwiftData
import HealthKit

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

    /// Marks a plan day as completed and advances progress if needed.
    /// Used for backfilling past days - only advances if this is the most recent completion.
    /// - Parameters:
    ///   - profileId: Owner profile ID.
    ///   - planId: The workout plan ID.
    ///   - completionDate: The date the workout was completed.
    ///   - modelContext: The SwiftData model context.
    @MainActor
    static func markPlanDayCompleted(
        profileId: UUID,
        planId: UUID,
        completionDate: Date,
        modelContext: ModelContext
    ) {
        guard let plan = getPlan(id: planId, modelContext: modelContext) else { return }

        let progress = getOrCreateProgress(
            profileId: profileId,
            planId: planId,
            modelContext: modelContext
        )

        let normalized = DateUtilities.startOfDay(completionDate)

        // Only update lastCompletedDate if this is the most recent completion
        // Note: Don't advance here - let handleAppOpen handle advancement to prevent
        // double-advancement when the app is opened the next day
        if progress.lastCompletedDate == nil || normalized > progress.lastCompletedDate! {
            progress.lastCompletedDate = normalized
            try? modelContext.save()
        }
        // normalized <= lastCompletedDate: do nothing (old backfill doesn't affect progress)
    }

    // MARK: - Day Advancement Logic

    /// Handles app open for plan mode.
    /// Checks if day should advance based on previous day's completion.
    ///
    /// Logic:
    /// 1. Get or create progress tracker
    /// 2. If lastOpenedDate is nil, set to today and don't advance
    /// 3. If lastOpenedDate != today (using workout date with transition hour):
    ///    - Check if previous day's workout exists and is completed
    ///    - If completed, advance to next day (wrap around)
    ///    - Update lastOpenedDate to today
    /// 4. Return the current day index to show
    ///
    /// - Parameters:
    ///   - profileId: Owner profile ID.
    ///   - planId: The workout plan ID.
    ///   - transitionHour: The hour at which the workout day transitions (0-23).
    ///   - modelContext: The SwiftData model context.
    /// - Returns: The plan day index to show today (1-indexed).
    @MainActor
    static func handleAppOpen(
        profileId: UUID,
        planId: UUID,
        transitionHour: Int,
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

        // Use workout date (respects transition hour) instead of calendar date
        let todayWorkout = DateUtilities.todayWorkoutDate(transitionHour: transitionHour)

        // First time using this plan
        guard let lastOpenedDate = progress.lastOpenedDate else {
            progress.lastOpenedDate = todayWorkout
            try? modelContext.save()
            return progress.currentDayIndex
        }

        // Same workout day - no advancement needed
        if DateUtilities.isSameDay(lastOpenedDate, todayWorkout) {
            return progress.currentDayIndex
        }

        // If the previous plan day was a rest day, auto-advance regardless of workout data.
        if let previousPlanDay = plan.day(at: progress.currentDayIndex),
           previousPlanDay.isRestDay {
            progress.advanceToNextDay(totalDays: totalDays)
            progress.lastOpenedDate = todayWorkout
            try? modelContext.save()
            return progress.currentDayIndex
        }

        // Different workout day - check if previous plan day was completed
        let (shouldAdvance, incompleteWorkout) = checkPreviousDayCompletionAndGetWorkout(
            profileId: profileId,
            planId: planId,
            date: lastOpenedDate,
            modelContext: modelContext
        )

        if shouldAdvance {
            progress.advanceToNextDay(totalDays: totalDays)
        } else if let incompleteWorkout = incompleteWorkout {
            // Delete the incomplete previous day's workout
            // so the same plan day can be used for today
            modelContext.delete(incompleteWorkout)
        }

        progress.lastOpenedDate = todayWorkout
        try? modelContext.save()
        return progress.currentDayIndex
    }

    /// Checks if the workout for a previous date in plan mode was completed.
    /// - Parameters:
    ///   - profileId: Owner profile ID.
    ///   - planId: The workout plan ID.
    ///   - date: The date to check.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Tuple of (shouldAdvance, incompleteWorkout). If completed, returns (true, nil).
    ///            If incomplete, returns (false, workoutDay) so caller can delete it.
    @MainActor
    private static func checkPreviousDayCompletionAndGetWorkout(
        profileId: UUID,
        planId: UUID,
        date: Date,
        modelContext: ModelContext
    ) -> (shouldAdvance: Bool, incompleteWorkout: WorkoutDay?) {
        guard let workoutDay = WorkoutService.getWorkoutDay(
            profileId: profileId,
            date: date,
            modelContext: modelContext
        ) else {
            // No workout for that day - don't advance
            return (false, nil)
        }

        // Must be in plan mode with the same plan
        guard workoutDay.mode == .routine,
              workoutDay.routinePresetId == planId else {
            // Different mode or plan - don't touch it
            return (false, nil)
        }

        if workoutDay.isRoutineCompleted {
            return (true, nil)
        } else {
            // Incomplete - return the workout so it can be deleted
            return (false, workoutDay)
        }
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

        // Clear existing groups
        for group in workoutDay.exerciseGroups {
            modelContext.delete(group)
        }
        workoutDay.exerciseGroups.removeAll()

        // Clear existing entries
        for entry in workoutDay.entries {
            modelContext.delete(entry)
        }
        workoutDay.entries.removeAll()
        clearCardioWorkouts(for: workoutDay, modelContext: modelContext)

        // Update the routine day ID
        workoutDay.routineDayId = newPlanDay.id

        // Expand the new plan day
        expandPlanToWorkout(planDay: newPlanDay, workoutDay: workoutDay, modelContext: modelContext)

        // Update progress pointer if skip is enabled
        if skipAndAdvance {
            let progress = getOrCreateProgress(
                profileId: profile.id,
                planId: planId,
                modelContext: modelContext
            )
            // Set to the selected day (handleAppOpen will advance after completion)
            progress.currentDayIndex = newDayIndex
        }

        return true
    }

    // MARK: - Plan Expansion to Workout

    /// Expands a plan day to a workout day.
    /// Creates exercise entries from the plan day exercises, including planned set details.
    /// Handles exercise groups (supersets/giant sets) by creating corresponding workout groups.
    ///
    /// - Parameters:
    ///   - planDay: The plan day to expand.
    ///   - workoutDay: The workout day to populate.
    ///   - modelContext: The model context.
    @MainActor
    static func expandPlanToWorkout(
        planDay: PlanDay,
        workoutDay: WorkoutDay,
        modelContext: ModelContext
    ) {
        // Rest day: no exercises to expand.
        if planDay.isRestDay {
            return
        }

        // Build a unified list of items to expand (groups + ungrouped exercises)
        // sorted by orderIndex
        var items: [(orderIndex: Int, isGroup: Bool, group: PlanExerciseGroup?, exercise: PlanExercise?)] = []

        // Add groups
        for group in planDay.exerciseGroups {
            items.append((group.orderIndex, true, group, nil))
        }

        // Add ungrouped exercises
        for exercise in planDay.exercises where !exercise.isGrouped {
            items.append((exercise.orderIndex, false, nil, exercise))
        }

        // Sort by orderIndex
        items.sort { $0.orderIndex < $1.orderIndex }

        // Build lookup maps
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        let bodyPartDescriptor = FetchDescriptor<BodyPart>()
        let exercises = (try? modelContext.fetch(exerciseDescriptor)) ?? []
        let bodyParts = (try? modelContext.fetch(bodyPartDescriptor)) ?? []
        let exerciseMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        let bodyPartsMap = Dictionary(uniqueKeysWithValues: bodyParts.map { ($0.id, $0) })
        let profile = ProfileService.getProfile(modelContext: modelContext)
            ?? ProfileService.getOrCreateProfile(modelContext: modelContext)
        var cardioOrderIndex = nextCardioOrderIndex(for: workoutDay.id, modelContext: modelContext)

        // Expand each item
        for item in items {
            if item.isGroup, let group = item.group {
                // Expand group
                expandGroupToWorkout(
                    planGroup: group,
                    workoutDay: workoutDay,
                    modelContext: modelContext,
                    exerciseMap: exerciseMap,
                    bodyPartsMap: bodyPartsMap,
                    profile: profile,
                    nextCardioOrderIndex: &cardioOrderIndex
                )
            } else if let planExercise = item.exercise {
                guard let exercise = exerciseMap[planExercise.exerciseId] else { continue }

                if CardioActivityTypeResolver.isCardioExercise(exercise, bodyPartsMap: bodyPartsMap) {
                    createCardioWorkouts(
                        planExercise: planExercise,
                        exercise: exercise,
                        workoutDay: workoutDay,
                        profile: profile,
                        modelContext: modelContext,
                        nextOrderIndex: &cardioOrderIndex
                    )
                } else {
                    // Expand ungrouped exercise
                    let entry = expandExerciseToEntry(planExercise)
                    workoutDay.addEntry(entry)
                }
            }
        }
    }

    /// Expands a plan exercise group to a workout exercise group.
    @MainActor
    private static func expandGroupToWorkout(
        planGroup: PlanExerciseGroup,
        workoutDay: WorkoutDay,
        modelContext: ModelContext,
        exerciseMap: [UUID: Exercise],
        bodyPartsMap: [UUID: BodyPart],
        profile: LocalProfile?,
        nextCardioOrderIndex: inout Int
    ) {
        let cardioExercises = planGroup.sortedExercises.compactMap { planExercise -> (PlanExercise, Exercise)? in
            guard let exercise = exerciseMap[planExercise.exerciseId],
                  CardioActivityTypeResolver.isCardioExercise(exercise, bodyPartsMap: bodyPartsMap) else {
                return nil
            }
            return (planExercise, exercise)
        }
        let strengthExercises = planGroup.sortedExercises.filter { planExercise in
            guard let exercise = exerciseMap[planExercise.exerciseId] else { return false }
            return !CardioActivityTypeResolver.isCardioExercise(exercise, bodyPartsMap: bodyPartsMap)
        }

        for (planExercise, exercise) in cardioExercises {
            createCardioWorkouts(
                planExercise: planExercise,
                exercise: exercise,
                workoutDay: workoutDay,
                profile: profile,
                modelContext: modelContext,
                nextOrderIndex: &nextCardioOrderIndex
            )
        }

        guard !strengthExercises.isEmpty else { return }

        // Create workout group for strength exercises
        let workoutGroup = WorkoutExerciseGroup(
            orderIndex: planGroup.orderIndex,
            setCount: planGroup.setCount,
            roundRestSeconds: planGroup.roundRestSeconds
        )
        workoutDay.exerciseGroups.append(workoutGroup)
        modelContext.insert(workoutGroup)

        // Expand each strength exercise in the group
        for exercise in strengthExercises {
            let entry = expandExerciseToEntry(exercise)

            // Set group relationship
            entry.group = workoutGroup
            entry.groupOrderIndex = exercise.groupOrderIndex

            workoutDay.addEntry(entry)
            workoutGroup.entries.append(entry)
        }
    }

    private static func nextCardioOrderIndex(
        for workoutDayId: UUID,
        modelContext: ModelContext
    ) -> Int {
        let descriptor = FetchDescriptor<CardioWorkout>(
            predicate: #Predicate<CardioWorkout> { $0.workoutDayId == workoutDayId },
            sortBy: [SortDescriptor(\.orderIndex, order: .reverse)]
        )
        let maxExisting = (try? modelContext.fetch(descriptor).first?.orderIndex) ?? -1
        return maxExisting + 1
    }

    private static func createCardioWorkouts(
        planExercise: PlanExercise,
        exercise: Exercise,
        workoutDay: WorkoutDay,
        profile: LocalProfile?,
        modelContext: ModelContext,
        nextOrderIndex: inout Int
    ) {
        let activityType = CardioActivityTypeResolver.activityType(for: exercise)
        let plannedSets = planExercise.sortedPlannedSets
        let setCount = plannedSets.isEmpty ? planExercise.plannedSetCount : plannedSets.count

        guard setCount > 0 else { return }

        if plannedSets.isEmpty {
            for _ in 0..<setCount {
                let cardioWorkout = CardioWorkout(
                    activityType: Int(activityType.rawValue),
                    startDate: workoutDay.date,
                    duration: 0,
                    totalDistance: nil,
                    isCompleted: false,
                    workoutDayId: workoutDay.id,
                    orderIndex: nextOrderIndex,
                    source: .manual,
                    profile: profile
                )
                modelContext.insert(cardioWorkout)
                nextOrderIndex += 1
            }
            return
        }

        for plannedSet in plannedSets {
            let durationSeconds = plannedSet.targetDurationSeconds ?? 0
            let distanceMeters = plannedSet.targetDistanceMeters
            let totalDistance = (distanceMeters ?? 0) > 0 ? distanceMeters : nil
            let cardioWorkout = CardioWorkout(
                activityType: Int(activityType.rawValue),
                startDate: workoutDay.date,
                duration: Double(durationSeconds),
                totalDistance: totalDistance,
                isCompleted: false,
                workoutDayId: workoutDay.id,
                orderIndex: nextOrderIndex,
                source: .manual,
                profile: profile
            )
            modelContext.insert(cardioWorkout)
            nextOrderIndex += 1
        }
    }

    @MainActor
    private static func clearCardioWorkouts(for workoutDay: WorkoutDay, modelContext: ModelContext) {
        let workoutDayId = workoutDay.id
        let descriptor = FetchDescriptor<CardioWorkout>(
            predicate: #Predicate<CardioWorkout> { $0.workoutDayId == workoutDayId }
        )
        if let workouts = try? modelContext.fetch(descriptor) {
            for workout in workouts {
                modelContext.delete(workout)
            }
        }
    }

    /// Expands a single plan exercise to a workout entry.
    private static func expandExerciseToEntry(_ exercise: PlanExercise) -> WorkoutExerciseEntry {
        let plannedSets = exercise.sortedPlannedSets
        let effectiveSetCount = plannedSets.isEmpty ? exercise.plannedSetCount : plannedSets.count

        let entry = WorkoutExerciseEntry(
            exerciseId: exercise.exerciseId,
            orderIndex: exercise.orderIndex,
            metricType: exercise.metricType,
            source: .routine,
            plannedSetCount: effectiveSetCount
        )

        // Create WorkoutSet objects from planned sets
        if !plannedSets.isEmpty {
            for (index, plannedSet) in plannedSets.enumerated() {
                let set = WorkoutSet(
                    setIndex: index + 1,
                    metricType: plannedSet.metricType,
                    weight: plannedSet.targetWeight.map { Decimal($0) },
                    reps: plannedSet.targetReps,
                    durationSeconds: plannedSet.targetDurationSeconds,
                    distanceMeters: plannedSet.targetDistanceMeters,
                    restTimeSeconds: plannedSet.restTimeSeconds,
                    isCompleted: false
                )
                entry.addSet(set)
            }
        } else if effectiveSetCount > 0 {
            // Fallback: create placeholder sets if plannedSets is empty but count > 0
            entry.createPlaceholderSets()
        }

        return entry
    }

    /// Updates a plan exercise's sets based on a completed workout entry.
    /// Replaces the plan's set count and values to match the workout entry.
    @MainActor
    static func updatePlanExercise(
        _ planExercise: PlanExercise,
        from entry: WorkoutExerciseEntry,
        modelContext: ModelContext
    ) {
        let workoutSets = entry.sortedSets

        // Remove existing planned sets
        for plannedSet in planExercise.plannedSets {
            modelContext.delete(plannedSet)
        }
        planExercise.plannedSets = []

        // Update plan-level metadata
        planExercise.updatePlannedSets(workoutSets.count)
        let uniqueMetricTypes = Set(workoutSets.map(\.metricType))
        if uniqueMetricTypes.count == 1, let metricType = uniqueMetricTypes.first {
            planExercise.metricType = metricType
        }

        // Create new planned sets from workout sets
        for (index, workoutSet) in workoutSets.enumerated() {
            let plannedSet = PlannedSet(
                orderIndex: index,
                metricType: workoutSet.metricType,
                targetWeight: workoutSet.weight.map { NSDecimalNumber(decimal: $0).doubleValue },
                targetReps: workoutSet.reps,
                targetDurationSeconds: workoutSet.durationSeconds,
                targetDistanceMeters: workoutSet.distanceMeters,
                restTimeSeconds: workoutSet.restTimeSeconds
            )
            planExercise.addPlannedSet(plannedSet)
        }

        planExercise.planDay?.plan?.touch()
        try? modelContext.save()
    }

    /// Sets up today's workout from the active plan.
    /// This is the main entry point for plan-based workout creation.
    ///
    /// - Parameters:
    ///   - profile: The local profile.
    ///   - workoutDate: The workout date (must be calculated with transitionHour consideration).
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Today's workout day (created or existing), or nil if no active plan.
    @MainActor
    static func setupTodayWorkout(
        profile: LocalProfile,
        workoutDate: Date,
        modelContext: ModelContext
    ) -> WorkoutDay? {
        // Check if profile has active plan
        guard let planId = profile.activePlanId else {
            // Free mode - no plan setup needed
            return nil
        }

        // OPTIMIZATION: Early return if workout is already set up for current plan
        // This avoids expensive handleAppOpen() and reindexDays() calls on subsequent opens
        if let existingWorkout = WorkoutService.getWorkoutDay(
            profileId: profile.id,
            date: workoutDate,
            modelContext: modelContext
        ) {
            // If already linked to a plan day from this plan, return immediately
            if existingWorkout.routinePresetId == planId && existingWorkout.routineDayId != nil {
                return existingWorkout
            }
        }

        // Get the plan and day
        guard let plan = getPlan(id: planId, modelContext: modelContext) else {
            return nil
        }

        // Get the plan day index for today (handles advancement)
        let dayIndex = handleAppOpen(
            profileId: profile.id,
            planId: planId,
            transitionHour: profile.dayTransitionHour,
            modelContext: modelContext
        )

        // Find the current PlanDay by index BEFORE reindexing
        let currentPlanDay = plan.day(at: dayIndex)
        let currentPlanDayId = currentPlanDay?.id

        // Ensure dayIndex values are consecutive (fixes any data inconsistencies)
        plan.reindexDays()

        // After reindexing, update progress if the day's index changed
        let progress = getOrCreateProgress(
            profileId: profile.id,
            planId: planId,
            modelContext: modelContext
        )

        // Find the plan day: prefer the same UUID, fallback to clamped index
        let planDay: PlanDay?
        if let dayId = currentPlanDayId,
           let sameDayAfterReindex = plan.days.first(where: { $0.id == dayId }) {
            // Day still exists, use its new index
            planDay = sameDayAfterReindex
            if progress.currentDayIndex != sameDayAfterReindex.dayIndex {
                progress.currentDayIndex = sameDayAfterReindex.dayIndex
                try? modelContext.save()
            }
        } else {
            // Day was deleted or not found, clamp to valid range
            let clampedIndex = max(1, min(dayIndex, plan.dayCount))
            planDay = plan.day(at: clampedIndex)
            if progress.currentDayIndex != clampedIndex && plan.dayCount > 0 {
                progress.currentDayIndex = clampedIndex
                try? modelContext.save()
            }
        }

        guard let planDay else {
            return nil
        }

        // Check if workout already exists for today (re-check after handleAppOpen)
        if let existingWorkout = WorkoutService.getWorkoutDay(
            profileId: profile.id,
            date: workoutDate,
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
                expandPlanToWorkout(planDay: planDay, workoutDay: existingWorkout, modelContext: modelContext)
                return existingWorkout
            }

            // Otherwise return existing (might have manual entries)
            return existingWorkout
        }

        // Create new workout day in plan mode
        let workoutDay = WorkoutService.getOrCreateWorkoutDay(
            profileId: profile.id,
            date: workoutDate,
            mode: .routine,
            routinePresetId: planId,
            routineDayId: planDay.id,
            modelContext: modelContext
        )

        // Expand plan to workout
        expandPlanToWorkout(planDay: planDay, workoutDay: workoutDay, modelContext: modelContext)

        return workoutDay
    }

    /// Applies a plan to today's workout immediately.
    /// Used when user selects "Start Today" from the plan activation sheet.
    /// Replaces any existing entries if the workout exists.
    ///
    /// - Parameters:
    ///   - profile: The local profile.
    ///   - plan: The workout plan to apply.
    ///   - dayIndex: The day index to apply (1-indexed).
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Today's workout day, or nil if plan day not found.
    @MainActor
    static func applyPlanToday(
        profile: LocalProfile,
        plan: WorkoutPlan,
        dayIndex: Int,
        modelContext: ModelContext
    ) -> WorkoutDay? {
        guard let planDay = plan.day(at: dayIndex) else {
            return nil
        }

        // Get today's date considering dayTransitionHour
        let workoutDate = DateUtilities.todayWorkoutDate(transitionHour: profile.dayTransitionHour)

        // Get or create today's workout
        let workoutDay = WorkoutService.getOrCreateWorkoutDay(
            profileId: profile.id,
            date: workoutDate,
            mode: .routine,
            routinePresetId: plan.id,
            routineDayId: planDay.id,
            modelContext: modelContext
        )

        // Clear existing groups
        for group in workoutDay.exerciseGroups {
            modelContext.delete(group)
        }
        workoutDay.exerciseGroups.removeAll()

        // Clear existing entries
        for entry in workoutDay.entries {
            modelContext.delete(entry)
        }
        workoutDay.entries.removeAll()
        clearCardioWorkouts(for: workoutDay, modelContext: modelContext)

        // Set mode and routine info
        workoutDay.mode = .routine
        workoutDay.routinePresetId = plan.id
        workoutDay.routineDayId = planDay.id

        // Expand plan to workout
        expandPlanToWorkout(planDay: planDay, workoutDay: workoutDay, modelContext: modelContext)

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
