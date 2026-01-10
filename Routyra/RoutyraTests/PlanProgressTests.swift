//
//  PlanProgressTests.swift
//  RoutyraTests
//
//  Tests for single plan mode progress logic.
//  Ensures proper day advancement, rescue flow, and preview calculations.
//

import Testing
import SwiftData
import Foundation
@testable import Routyra

/// Tests for single plan mode progress logic
struct PlanProgressTests {

    // MARK: - Test Helpers

    /// Creates an in-memory model container for testing
    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([
            LocalProfile.self,
            BodyPart.self,
            BodyPartTranslation.self,
            Exercise.self,
            ExerciseTranslation.self,
            WorkoutDay.self,
            WorkoutExerciseEntry.self,
            WorkoutSet.self,
            WorkoutPlan.self,
            PlanDay.self,
            PlanExercise.self,
            PlannedSet.self,
            PlanProgress.self,
            PlanCycle.self,
            PlanCycleItem.self,
            PlanCycleProgress.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Creates a profile and plan with specified number of days
    @MainActor
    private func createProfileAndPlan(
        dayCount: Int,
        modelContext: ModelContext
    ) -> (profile: LocalProfile, plan: WorkoutPlan) {
        let profile = LocalProfile()
        modelContext.insert(profile)

        let plan = WorkoutPlan(profileId: profile.id, name: "Test Plan")
        modelContext.insert(plan)

        // Create days with at least one exercise each
        for i in 1...dayCount {
            let day = PlanDay(dayIndex: i, name: "Day \(i)")
            plan.addDay(day)
            modelContext.insert(day)

            // Add one exercise with 3 sets
            let exercise = day.createExercise(
                exerciseId: UUID(),
                metricType: .weightReps,
                plannedSetCount: 3
            )
            modelContext.insert(exercise)
        }

        // Set plan as active
        profile.activePlanId = plan.id
        profile.executionMode = .single

        return (profile, plan)
    }

    /// Creates a completed workout day for the given date
    @MainActor
    private func createCompletedWorkoutDay(
        profileId: UUID,
        planId: UUID,
        planDay: PlanDay,
        date: Date,
        modelContext: ModelContext
    ) -> WorkoutDay {
        let workoutDay = WorkoutDay(
            profileId: profileId,
            date: date,
            mode: .routine,
            routinePresetId: planId,
            routineDayId: planDay.id
        )
        modelContext.insert(workoutDay)

        // Create a completed entry with 3 completed sets
        let entry = WorkoutExerciseEntry(
            exerciseId: UUID(),
            orderIndex: 0,
            metricType: .weightReps,
            source: .routine,
            plannedSetCount: 3
        )
        workoutDay.addEntry(entry)
        modelContext.insert(entry)

        // Create 3 completed sets
        for i in 1...3 {
            let set = WorkoutSet(
                setIndex: i,
                metricType: .weightReps,
                weight: 60,
                reps: 10,
                isCompleted: true
            )
            entry.addSet(set)
            modelContext.insert(set)
        }

        return workoutDay
    }

    /// Creates an incomplete workout day for the given date
    @MainActor
    private func createIncompleteWorkoutDay(
        profileId: UUID,
        planId: UUID,
        planDay: PlanDay,
        date: Date,
        modelContext: ModelContext
    ) -> WorkoutDay {
        let workoutDay = WorkoutDay(
            profileId: profileId,
            date: date,
            mode: .routine,
            routinePresetId: planId,
            routineDayId: planDay.id
        )
        modelContext.insert(workoutDay)

        // Create an entry with 3 planned sets but only 1 completed
        let entry = WorkoutExerciseEntry(
            exerciseId: UUID(),
            orderIndex: 0,
            metricType: .weightReps,
            source: .routine,
            plannedSetCount: 3
        )
        workoutDay.addEntry(entry)
        modelContext.insert(entry)

        // Create 3 sets but only first is completed
        for i in 1...3 {
            let set = WorkoutSet(
                setIndex: i,
                metricType: .weightReps,
                weight: 60,
                reps: 10,
                isCompleted: i == 1  // Only first set completed
            )
            entry.addSet(set)
            modelContext.insert(set)
        }

        return workoutDay
    }

    // MARK: - handleAppOpen Tests

    @Test("初回オープンで進捗は進まない")
    @MainActor
    func testFirstOpenDoesNotAdvance() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (profile, plan) = createProfileAndPlan(dayCount: 4, modelContext: context)

        // Get or create progress - should be fresh with no lastOpenedDate
        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: context
        )

        // Verify initial state
        #expect(progress.lastOpenedDate == nil)
        #expect(progress.currentDayIndex == 1)

        // Call handleAppOpen
        let resultDayIndex = PlanService.handleAppOpen(
            profileId: profile.id,
            planId: plan.id,
            transitionHour: profile.dayTransitionHour,
            modelContext: context
        )

        // Should return 1 and set lastOpenedDate to today's workout date
        let todayWorkout = DateUtilities.todayWorkoutDate(transitionHour: profile.dayTransitionHour)
        #expect(resultDayIndex == 1)
        #expect(progress.lastOpenedDate != nil)
        #expect(DateUtilities.isSameDay(progress.lastOpenedDate!, todayWorkout))
    }

    @Test("同日再オープンで進捗は進まない")
    @MainActor
    func testSameDayReopenDoesNotAdvance() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (profile, plan) = createProfileAndPlan(dayCount: 4, modelContext: context)

        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: context
        )

        // Set initial state: lastOpenedDate = today, currentDayIndex = 2
        progress.lastOpenedDate = DateUtilities.today
        progress.currentDayIndex = 2

        // Call handleAppOpen
        let resultDayIndex = PlanService.handleAppOpen(
            profileId: profile.id,
            planId: plan.id,
            transitionHour: profile.dayTransitionHour,
            modelContext: context
        )

        // Should still be day 2
        #expect(resultDayIndex == 2)
        #expect(progress.currentDayIndex == 2)
    }

    @Test("前日が完了していれば進捗が進む")
    @MainActor
    func testAdvancesWhenPreviousDayCompleted() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (profile, plan) = createProfileAndPlan(dayCount: 4, modelContext: context)
        let todayWorkout = DateUtilities.todayWorkoutDate(transitionHour: profile.dayTransitionHour)
        let yesterday = DateUtilities.addDays(-1, to: todayWorkout)!

        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: context
        )

        // Set initial state: lastOpenedDate = yesterday, currentDayIndex = 1
        progress.lastOpenedDate = yesterday
        progress.currentDayIndex = 1

        // Create completed workout for yesterday
        let planDay = plan.day(at: 1)!
        _ = createCompletedWorkoutDay(
            profileId: profile.id,
            planId: plan.id,
            planDay: planDay,
            date: yesterday,
            modelContext: context
        )

        try context.save()

        // Call handleAppOpen
        let resultDayIndex = PlanService.handleAppOpen(
            profileId: profile.id,
            planId: plan.id,
            transitionHour: profile.dayTransitionHour,
            modelContext: context
        )

        // Should advance to day 2
        #expect(resultDayIndex == 2)
        #expect(progress.currentDayIndex == 2)
        #expect(DateUtilities.isSameDay(progress.lastOpenedDate!, todayWorkout))
    }

    @Test("前日が未完了なら進まない")
    @MainActor
    func testDoesNotAdvanceWhenPreviousDayIncomplete() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (profile, plan) = createProfileAndPlan(dayCount: 4, modelContext: context)
        let todayWorkout = DateUtilities.todayWorkoutDate(transitionHour: profile.dayTransitionHour)
        let yesterday = DateUtilities.addDays(-1, to: todayWorkout)!

        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: context
        )

        // Set initial state
        progress.lastOpenedDate = yesterday
        progress.currentDayIndex = 1

        // Create incomplete workout for yesterday
        let planDay = plan.day(at: 1)!
        _ = createIncompleteWorkoutDay(
            profileId: profile.id,
            planId: plan.id,
            planDay: planDay,
            date: yesterday,
            modelContext: context
        )

        try context.save()

        // Call handleAppOpen
        let resultDayIndex = PlanService.handleAppOpen(
            profileId: profile.id,
            planId: plan.id,
            transitionHour: profile.dayTransitionHour,
            modelContext: context
        )

        // Should stay at day 1
        #expect(resultDayIndex == 1)
        #expect(progress.currentDayIndex == 1)
    }

    @Test("前日にWorkoutDayが存在しないなら進まない")
    @MainActor
    func testDoesNotAdvanceWhenNoPreviousWorkoutDay() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (profile, plan) = createProfileAndPlan(dayCount: 4, modelContext: context)
        let todayWorkout = DateUtilities.todayWorkoutDate(transitionHour: profile.dayTransitionHour)
        let yesterday = DateUtilities.addDays(-1, to: todayWorkout)!

        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: context
        )

        // Set initial state: lastOpenedDate = yesterday, currentDayIndex = 1
        progress.lastOpenedDate = yesterday
        progress.currentDayIndex = 1

        // Do NOT create any workout for yesterday

        // Call handleAppOpen
        let resultDayIndex = PlanService.handleAppOpen(
            profileId: profile.id,
            planId: plan.id,
            transitionHour: profile.dayTransitionHour,
            modelContext: context
        )

        // Should stay at day 1
        #expect(resultDayIndex == 1)
        #expect(progress.currentDayIndex == 1)
    }

    // MARK: - markPlanDayCompleted Tests

    @Test("救済（過去日完了）で進捗が1つ進む")
    @MainActor
    func testRescueAdvancesProgress() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (profile, plan) = createProfileAndPlan(dayCount: 4, modelContext: context)
        let yesterday = DateUtilities.addDays(-1, to: DateUtilities.today)!

        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: context
        )

        // Set initial state: lastCompletedDate = yesterday, currentDayIndex = 2
        progress.lastCompletedDate = yesterday
        progress.currentDayIndex = 2

        // Call markPlanDayCompleted with today's date
        PlanService.markPlanDayCompleted(
            profileId: profile.id,
            planId: plan.id,
            completionDate: DateUtilities.today,
            modelContext: context
        )

        // Should advance to day 3 and update lastCompletedDate
        #expect(progress.currentDayIndex == 3)
        #expect(DateUtilities.isSameDay(progress.lastCompletedDate!, DateUtilities.today))
    }

    @Test("同じ日で二重に完了しても進捗は二重に進まない")
    @MainActor
    func testDoubleCompletionDoesNotDoubleAdvance() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (profile, plan) = createProfileAndPlan(dayCount: 4, modelContext: context)

        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: context
        )

        // Set initial state: lastCompletedDate = today, currentDayIndex = 2
        progress.lastCompletedDate = DateUtilities.today
        progress.currentDayIndex = 2

        // Call markPlanDayCompleted twice with today's date
        PlanService.markPlanDayCompleted(
            profileId: profile.id,
            planId: plan.id,
            completionDate: DateUtilities.today,
            modelContext: context
        )

        PlanService.markPlanDayCompleted(
            profileId: profile.id,
            planId: plan.id,
            completionDate: DateUtilities.today,
            modelContext: context
        )

        // Should stay at day 2 (not advance since today <= lastCompletedDate)
        #expect(progress.currentDayIndex == 2)
    }

    @Test("過去すぎる救済は進捗に影響しない")
    @MainActor
    func testOldBackfillDoesNotAffectProgress() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (profile, plan) = createProfileAndPlan(dayCount: 4, modelContext: context)
        let yesterday = DateUtilities.addDays(-1, to: DateUtilities.today)!

        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: context
        )

        // Set initial state: lastCompletedDate = today, currentDayIndex = 2
        progress.lastCompletedDate = DateUtilities.today
        progress.currentDayIndex = 2

        // Call markPlanDayCompleted with yesterday's date (old backfill)
        PlanService.markPlanDayCompleted(
            profileId: profile.id,
            planId: plan.id,
            completionDate: yesterday,
            modelContext: context
        )

        // Should stay at day 2 (yesterday < lastCompletedDate)
        #expect(progress.currentDayIndex == 2)
        #expect(DateUtilities.isSameDay(progress.lastCompletedDate!, DateUtilities.today))
    }

    @Test("プランずれの再現シナリオ")
    @MainActor
    func testPlanShiftScenario() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (profile, plan) = createProfileAndPlan(dayCount: 4, modelContext: context)

        // Calculate dates: Thu = today, Wed = yesterday, Tue = 2 days ago
        let today = DateUtilities.today
        let wednesday = DateUtilities.addDays(-1, to: today)!
        let tuesday = DateUtilities.addDays(-2, to: today)!

        // --- Tuesday: Complete Day 1 workout ---
        let tuesdayPlanDay = plan.day(at: 1)!
        _ = createCompletedWorkoutDay(
            profileId: profile.id,
            planId: plan.id,
            planDay: tuesdayPlanDay,
            date: tuesday,
            modelContext: context
        )

        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: context
        )

        // Simulate state after Tuesday completion
        progress.lastOpenedDate = tuesday
        progress.currentDayIndex = 1
        progress.lastCompletedDate = tuesday

        try context.save()

        // --- Wednesday: Open app but don't record ---
        // This simulates opening the app on Wednesday
        progress.lastOpenedDate = tuesday  // Still set to Tuesday before the open

        let wednesdayResult = PlanService.handleAppOpen(
            profileId: profile.id,
            planId: plan.id,
            transitionHour: profile.dayTransitionHour,
            modelContext: context
        )

        // Should advance to Day 2 because Tuesday was completed
        #expect(wednesdayResult == 2)
        #expect(progress.currentDayIndex == 2)

        // Update lastOpenedDate to Wednesday (simulating the app was opened)
        progress.lastOpenedDate = wednesday

        try context.save()

        // --- Thursday: Open app (Wednesday was not completed) ---
        let thursdayResult = PlanService.handleAppOpen(
            profileId: profile.id,
            planId: plan.id,
            transitionHour: profile.dayTransitionHour,
            modelContext: context
        )

        // Should stay at Day 2 because Wednesday was not completed
        #expect(thursdayResult == 2)
        #expect(progress.currentDayIndex == 2)

        // --- Rescue Wednesday: Complete it retroactively ---
        PlanService.markPlanDayCompleted(
            profileId: profile.id,
            planId: plan.id,
            completionDate: wednesday,
            modelContext: context
        )

        // After rescue, progress should advance to Day 3
        #expect(progress.currentDayIndex == 3)
        #expect(DateUtilities.isSameDay(progress.lastCompletedDate!, wednesday))
    }

    // MARK: - getPreviewDayInfo Tests

    @Test("プレビュー計算（未来日）ラップアラウンド")
    @MainActor
    func testPreviewDayInfoFutureWithWrapAround() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (profile, plan) = createProfileAndPlan(dayCount: 4, modelContext: context)

        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: context
        )

        // Set currentDayIndex = 3, totalDays = 4
        progress.currentDayIndex = 3

        let today = DateUtilities.today
        let twoDaysLater = DateUtilities.addDays(2, to: today)!

        // Get preview for 2 days in the future
        let previewInfo = PlanService.getPreviewDayInfo(
            profile: profile,
            targetDate: twoDaysLater,
            todayDate: today,
            modelContext: context
        )

        // currentDayIndex = 3, +2 days = 5, wrapped to 4 days: (5-1) % 4 + 1 = 1
        #expect(previewInfo != nil)
        #expect(previewInfo!.dayIndex == 1)  // Wrapped around
        #expect(previewInfo!.totalDays == 4)
    }

    @Test("プレビュー計算（同日）")
    @MainActor
    func testPreviewDayInfoSameDay() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (profile, plan) = createProfileAndPlan(dayCount: 4, modelContext: context)

        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: context
        )

        // Set currentDayIndex = 3
        progress.currentDayIndex = 3

        let today = DateUtilities.today

        // Get preview for same day (daysDiff = 0)
        let previewInfo = PlanService.getPreviewDayInfo(
            profile: profile,
            targetDate: today,
            todayDate: today,
            modelContext: context
        )

        // Should return currentDayIndex
        #expect(previewInfo != nil)
        #expect(previewInfo!.dayIndex == 3)
        #expect(previewInfo!.totalDays == 4)
    }

    @Test("プレビュー計算（1日後）")
    @MainActor
    func testPreviewDayInfoOneDayLater() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (profile, plan) = createProfileAndPlan(dayCount: 4, modelContext: context)

        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: context
        )

        // Set currentDayIndex = 2
        progress.currentDayIndex = 2

        let today = DateUtilities.today
        let tomorrow = DateUtilities.addDays(1, to: today)!

        // Get preview for tomorrow
        let previewInfo = PlanService.getPreviewDayInfo(
            profile: profile,
            targetDate: tomorrow,
            todayDate: today,
            modelContext: context
        )

        // currentDayIndex = 2, +1 = 3
        #expect(previewInfo != nil)
        #expect(previewInfo!.dayIndex == 3)
    }

    // MARK: - reindexDays Bug Prevention Tests

    @Test("reindexDaysでDay削除時にprogressが正しく追従する")
    @MainActor
    func testReindexDaysDoesNotCorruptProgressAfterDayDeletion() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // Create profile and plan with 4 days: Day A(1), Day B(2), Day C(3), Day D(4)
        let profile = LocalProfile()
        context.insert(profile)

        let plan = WorkoutPlan(profileId: profile.id, name: "Test Plan")
        context.insert(plan)

        // Create 4 days with specific UUIDs we can track
        var dayIds: [UUID] = []
        for i in 1...4 {
            let day = PlanDay(dayIndex: i, name: "Day \(i)")
            plan.addDay(day)
            context.insert(day)
            dayIds.append(day.id)

            // Add one exercise
            let exercise = day.createExercise(
                exerciseId: UUID(),
                metricType: .weightReps,
                plannedSetCount: 3
            )
            context.insert(exercise)
        }

        profile.activePlanId = plan.id
        profile.executionMode = .single

        // Set progress to Day 3 (Day C)
        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: context
        )
        progress.currentDayIndex = 3
        progress.lastOpenedDate = DateUtilities.today

        // Remember Day C's UUID
        let dayCId = dayIds[2]  // Day C (index 3)

        try context.save()

        // Delete Day B (index 2) - this makes indices non-consecutive: [1, 3, 4]
        if let dayB = plan.days.first(where: { $0.dayIndex == 2 }) {
            plan.days.removeAll { $0.id == dayB.id }
            context.delete(dayB)
        }

        try context.save()

        // Verify Day C still exists and progress points to it
        let dayCBeforeReindex = plan.days.first { $0.id == dayCId }
        #expect(dayCBeforeReindex != nil)
        #expect(dayCBeforeReindex?.dayIndex == 3)

        // Call setupTodayWorkout which internally calls reindexDays
        _ = PlanService.setupTodayWorkout(profile: profile, modelContext: context)

        // After reindexDays, Day C should now be at index 2 (was 3)
        let dayCAfterReindex = plan.days.first { $0.id == dayCId }
        #expect(dayCAfterReindex != nil)
        #expect(dayCAfterReindex?.dayIndex == 2)  // Reindexed from 3 to 2

        // CRITICAL: Progress should now point to 2, not still 3
        // Because Day C is now at index 2
        #expect(progress.currentDayIndex == 2)
    }

    @Test("reindexDaysでDay並び替え時にprogressは位置を追従する")
    @MainActor
    func testReindexDaysDoesNotCorruptProgressAfterDayReorder() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let profile = LocalProfile()
        context.insert(profile)

        let plan = WorkoutPlan(profileId: profile.id, name: "Test Plan")
        context.insert(plan)

        // Create 3 days: Day A(1), Day B(2), Day C(3)
        var dayIds: [UUID] = []
        for i in 1...3 {
            let day = PlanDay(dayIndex: i, name: "Day \(i)")
            plan.addDay(day)
            context.insert(day)
            dayIds.append(day.id)

            let exercise = day.createExercise(
                exerciseId: UUID(),
                metricType: .weightReps,
                plannedSetCount: 3
            )
            context.insert(exercise)
        }

        profile.activePlanId = plan.id
        profile.executionMode = .single

        // Set progress to Day 2 (Day B)
        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: context
        )
        progress.currentDayIndex = 2
        progress.lastOpenedDate = DateUtilities.todayWorkoutDate(transitionHour: profile.dayTransitionHour)

        let dayAId = dayIds[0]  // Day A (originally at index 1)

        try context.save()

        // Simulate reordering: swap Day A and Day B indices
        // Day A (index 1) -> index 2
        // Day B (index 2) -> index 1
        // After swap, sorted by dayIndex: Day B(1), Day A(2), Day C(3)
        if let dayA = plan.days.first(where: { $0.dayIndex == 1 }),
           let dayB = plan.days.first(where: { $0.dayIndex == 2 }) {
            dayA.dayIndex = 2
            dayB.dayIndex = 1
        }

        try context.save()

        // When setupTodayWorkout runs:
        // 1. handleAppOpen returns currentDayIndex = 2
        // 2. plan.day(at: 2) returns Day A (which now has dayIndex = 2)
        // 3. After reindexDays, Day A stays at index 2 (sorted order: Day B, Day A, Day C)
        // 4. Progress tracks Day A, which is at index 2
        _ = PlanService.setupTodayWorkout(profile: profile, modelContext: context)

        // After reindex, Day A should be at index 2
        let dayAAfterReindex = plan.days.first { $0.id == dayAId }
        #expect(dayAAfterReindex != nil)
        #expect(dayAAfterReindex?.dayIndex == 2)

        // Progress should point to 2 (tracking the day at the original position)
        #expect(progress.currentDayIndex == 2)
    }

    // MARK: - Transition Hour Bug Prevention Tests

    @Test("transitionHour考慮で深夜は前日として扱われる")
    @MainActor
    func testTransitionHourRespectedInDayComparison() throws {
        // This test verifies that workoutDate with transition hour works correctly
        // At 2 AM with transition hour 3, it should still be the previous day's workout

        // Get a reference date (today at midnight)
        let jan2_midnight = DateUtilities.startOfDay(Date())

        // Simulate 2 AM on Jan 2 (before transition hour of 3)
        guard let jan2_2am = Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: jan2_midnight) else {
            return
        }

        // With transition hour 3, 2 AM on Jan 2 should be treated as Jan 1
        let workoutDateAt2AM = DateUtilities.workoutDate(for: jan2_2am, transitionHour: 3)
        let jan1 = DateUtilities.addDays(-1, to: jan2_midnight)!

        // At 2 AM on Jan 2, the workout date should be Jan 1 (not Jan 2)
        #expect(DateUtilities.isSameDay(workoutDateAt2AM, jan1))

        // Now test 4 AM on Jan 2 (after transition hour of 3)
        guard let jan2_4am = Calendar.current.date(bySettingHour: 4, minute: 0, second: 0, of: jan2_midnight) else {
            return
        }

        let workoutDateAt4AM = DateUtilities.workoutDate(for: jan2_4am, transitionHour: 3)

        // At 4 AM on Jan 2, the workout date should be Jan 2 (not Jan 1)
        #expect(DateUtilities.isSameDay(workoutDateAt4AM, jan2_midnight))
    }

    @Test("transitionHour=0で通常のカレンダー日付として動作する")
    @MainActor
    func testTransitionHourZeroUsesCalendarDate() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (profile, plan) = createProfileAndPlan(dayCount: 4, modelContext: context)

        // Set transition hour to 0 (midnight)
        profile.dayTransitionHour = 0

        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: plan.id,
            modelContext: context
        )

        let yesterday = DateUtilities.addDays(-1, to: DateUtilities.today)!
        progress.lastOpenedDate = yesterday
        progress.currentDayIndex = 1

        // Create completed workout for yesterday
        let planDay = plan.day(at: 1)!
        _ = createCompletedWorkoutDay(
            profileId: profile.id,
            planId: plan.id,
            planDay: planDay,
            date: yesterday,
            modelContext: context
        )

        try context.save()

        // With transitionHour=0, today's workout date should be today
        let todayWorkout = DateUtilities.todayWorkoutDate(transitionHour: 0)
        #expect(DateUtilities.isSameDay(todayWorkout, DateUtilities.today))

        // Call handleAppOpen with transitionHour=0
        let resultDayIndex = PlanService.handleAppOpen(
            profileId: profile.id,
            planId: plan.id,
            transitionHour: 0,
            modelContext: context
        )

        // Should advance because yesterday was completed and today is a new day
        #expect(resultDayIndex == 2)
        #expect(progress.currentDayIndex == 2)
    }
}
