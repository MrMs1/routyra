//
//  CycleProgressTests.swift
//  RoutyraTests
//
//  Tests for cycle mode progress logic.
//  Ensures proper day advancement, rescue flow, and preview calculations.
//

import Testing
import SwiftData
import Foundation
@testable import Routyra

/// Tests for cycle mode progress logic
struct CycleProgressTests {

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

    /// Creates a plan with specified number of days
    @MainActor
    private func createPlan(
        profileId: UUID,
        name: String,
        dayCount: Int,
        modelContext: ModelContext
    ) -> WorkoutPlan {
        let plan = WorkoutPlan(profileId: profileId, name: name)
        modelContext.insert(plan)

        for i in 1...dayCount {
            let day = PlanDay(dayIndex: i, name: "\(name) Day \(i)")
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

        return plan
    }

    /// Creates a profile with a cycle containing multiple plans
    @MainActor
    private func createProfileAndCycle(
        planDayCounts: [Int],
        modelContext: ModelContext
    ) -> (profile: LocalProfile, cycle: PlanCycle, plans: [WorkoutPlan]) {
        let profile = LocalProfile()
        profile.executionMode = .cycle
        modelContext.insert(profile)

        let cycle = PlanCycle(profileId: profile.id, name: "Test Cycle")
        cycle.isActive = true
        modelContext.insert(cycle)

        // Ensure progress exists
        let progress = PlanCycleProgress()
        cycle.progress = progress
        modelContext.insert(progress)

        var plans: [WorkoutPlan] = []

        for (index, dayCount) in planDayCounts.enumerated() {
            let plan = createPlan(
                profileId: profile.id,
                name: "Plan \(index + 1)",
                dayCount: dayCount,
                modelContext: modelContext
            )
            plans.append(plan)

            let item = PlanCycleItem(planId: plan.id, order: index)
            item.plan = plan
            cycle.addItem(item)
            modelContext.insert(item)
        }

        // Note: Active cycle is tracked via cycle.isActive = true (already set above)
        // There's no activeCycleId on LocalProfile

        return (profile, cycle, plans)
    }

    // MARK: - markCycleDayCompleted Tests

    @Test("サイクル救済で進捗が進む")
    @MainActor
    func testCycleRescueAdvancesProgress() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // Create cycle with 2 plans: 3 days each
        let (_, cycle, _) = createProfileAndCycle(
            planDayCounts: [3, 3],
            modelContext: context
        )

        let progress = cycle.progress!
        let yesterday = DateUtilities.addDays(-1, to: DateUtilities.today)!

        // Set initial state: lastCompletedAt = yesterday, day 1 of plan 1
        progress.lastCompletedAt = yesterday
        progress.currentItemIndex = 0
        progress.currentDayIndex = 1

        try context.save()

        // Call markCycleDayCompleted with today's date
        CycleService.markCycleDayCompleted(
            cycle: cycle,
            completionDate: DateUtilities.today,
            modelContext: context
        )

        // Should advance to day 2 of plan 1
        #expect(progress.currentDayIndex == 2)
        #expect(progress.currentItemIndex == 0)
        #expect(DateUtilities.isSameDay(progress.lastCompletedAt!, DateUtilities.today))
    }

    @Test("サイクル：同日二重完了で二重に進まない")
    @MainActor
    func testCycleDoubleCompletionDoesNotDoubleAdvance() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (_, cycle, _) = createProfileAndCycle(
            planDayCounts: [3, 3],
            modelContext: context
        )

        let progress = cycle.progress!

        // Set initial state: lastCompletedAt = today, day 1 of plan 1
        progress.lastCompletedAt = DateUtilities.today
        progress.currentItemIndex = 0
        progress.currentDayIndex = 1

        try context.save()

        // Call markCycleDayCompleted twice with today's date
        CycleService.markCycleDayCompleted(
            cycle: cycle,
            completionDate: DateUtilities.today,
            modelContext: context
        )

        CycleService.markCycleDayCompleted(
            cycle: cycle,
            completionDate: DateUtilities.today,
            modelContext: context
        )

        // Should stay at day 1 (not advance since today <= lastCompletedAt)
        #expect(progress.currentDayIndex == 1)
        #expect(progress.currentItemIndex == 0)
    }

    @Test("サイクル：過去の救済は進捗に影響しない")
    @MainActor
    func testCycleOldBackfillDoesNotAffectProgress() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (_, cycle, _) = createProfileAndCycle(
            planDayCounts: [3, 3],
            modelContext: context
        )

        let progress = cycle.progress!
        let yesterday = DateUtilities.addDays(-1, to: DateUtilities.today)!

        // Set initial state: lastCompletedAt = today, day 1 of plan 1
        progress.lastCompletedAt = DateUtilities.today
        progress.currentItemIndex = 0
        progress.currentDayIndex = 1

        try context.save()

        // Call markCycleDayCompleted with yesterday's date (old backfill)
        CycleService.markCycleDayCompleted(
            cycle: cycle,
            completionDate: yesterday,
            modelContext: context
        )

        // Should stay at day 1 (yesterday < lastCompletedAt)
        #expect(progress.currentDayIndex == 1)
        #expect(DateUtilities.isSameDay(progress.lastCompletedAt!, DateUtilities.today))
    }

    @Test("サイクル：プラン境界での進捗")
    @MainActor
    func testCyclePlanBoundaryAdvancement() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // Create cycle with 2 plans: 2 days and 3 days
        let (_, cycle, _) = createProfileAndCycle(
            planDayCounts: [2, 3],
            modelContext: context
        )

        let progress = cycle.progress!
        let yesterday = DateUtilities.addDays(-1, to: DateUtilities.today)!

        // Set initial state: last day of plan 1 (day 1, 0-indexed)
        progress.lastCompletedAt = yesterday
        progress.currentItemIndex = 0
        progress.currentDayIndex = 1  // 0-indexed, so this is day 2 of 2

        try context.save()

        // Complete today - should advance to next plan
        CycleService.markCycleDayCompleted(
            cycle: cycle,
            completionDate: DateUtilities.today,
            modelContext: context
        )

        // Should move to plan 2 (index 1), day 0
        #expect(progress.currentItemIndex == 1)
        #expect(progress.currentDayIndex == 0)
    }

    // MARK: - getPreviewDayInfo Tests

    @Test("サイクルプレビュー計算（同日）")
    @MainActor
    func testCyclePreviewDayInfoSameDay() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (_, cycle, _) = createProfileAndCycle(
            planDayCounts: [4],
            modelContext: context
        )

        let progress = cycle.progress!
        progress.currentItemIndex = 0
        progress.currentDayIndex = 2  // 0-indexed, so day 3

        let today = DateUtilities.today

        let previewInfo = CycleService.getPreviewDayInfo(
            cycle: cycle,
            targetDate: today,
            todayDate: today,
            modelContext: context
        )

        // Should return current day (1-indexed: 3)
        #expect(previewInfo != nil)
        #expect(previewInfo!.dayIndex == 3)  // 0-indexed 2 -> 1-indexed 3
        #expect(previewInfo!.totalDays == 4)
    }

    @Test("サイクルプレビュー計算（未来日）")
    @MainActor
    func testCyclePreviewDayInfoFuture() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (_, cycle, _) = createProfileAndCycle(
            planDayCounts: [4],
            modelContext: context
        )

        let progress = cycle.progress!
        progress.currentItemIndex = 0
        progress.currentDayIndex = 1  // 0-indexed

        let today = DateUtilities.today
        let twoDaysLater = DateUtilities.addDays(2, to: today)!

        let previewInfo = CycleService.getPreviewDayInfo(
            cycle: cycle,
            targetDate: twoDaysLater,
            todayDate: today,
            modelContext: context
        )

        // currentDayIndex = 1 (0-indexed), +2 days = 3 (0-indexed)
        // 1-indexed: 4
        #expect(previewInfo != nil)
        #expect(previewInfo!.dayIndex == 4)
        #expect(previewInfo!.totalDays == 4)
    }

    @Test("サイクルプレビュー計算（ラップアラウンド）")
    @MainActor
    func testCyclePreviewDayInfoWrapAround() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (_, cycle, _) = createProfileAndCycle(
            planDayCounts: [3],
            modelContext: context
        )

        let progress = cycle.progress!
        progress.currentItemIndex = 0
        progress.currentDayIndex = 2  // 0-indexed, last day

        let today = DateUtilities.today
        let twoDaysLater = DateUtilities.addDays(2, to: today)!

        let previewInfo = CycleService.getPreviewDayInfo(
            cycle: cycle,
            targetDate: twoDaysLater,
            todayDate: today,
            modelContext: context
        )

        // currentDayIndex = 2 (0-indexed), +2 = 4, wrapped: 4 % 3 = 1 (0-indexed)
        // 1-indexed: 2
        #expect(previewInfo != nil)
        #expect(previewInfo!.dayIndex == 2)
        #expect(previewInfo!.totalDays == 3)
    }

    // MARK: - advance() Tests

    @Test("サイクル進捗：通常のDay進行")
    @MainActor
    func testCycleNormalDayAdvancement() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        let (_, cycle, _) = createProfileAndCycle(
            planDayCounts: [3],
            modelContext: context
        )

        let progress = cycle.progress!
        progress.currentItemIndex = 0
        progress.currentDayIndex = 0

        // Advance once
        let result = CycleService.advance(cycle: cycle, modelContext: context)

        #expect(result == true)
        #expect(progress.currentDayIndex == 1)
        #expect(progress.currentItemIndex == 0)
    }

    @Test("サイクル進捗：プラン切り替え")
    @MainActor
    func testCyclePlanSwitching() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // 2 plans with 2 days each
        let (_, cycle, _) = createProfileAndCycle(
            planDayCounts: [2, 2],
            modelContext: context
        )

        let progress = cycle.progress!
        progress.currentItemIndex = 0
        progress.currentDayIndex = 1  // Last day of plan 1 (0-indexed)

        // Advance should move to next plan
        let result = CycleService.advance(cycle: cycle, modelContext: context)

        #expect(result == true)
        #expect(progress.currentItemIndex == 1)  // Moved to plan 2
        #expect(progress.currentDayIndex == 0)   // First day of plan 2
    }

    @Test("サイクル進捗：サイクル全体のラップアラウンド")
    @MainActor
    func testCycleFullWrapAround() throws {
        let container = try createTestContainer()
        let context = container.mainContext

        // 2 plans with 1 day each
        let (_, cycle, _) = createProfileAndCycle(
            planDayCounts: [1, 1],
            modelContext: context
        )

        let progress = cycle.progress!
        progress.currentItemIndex = 1  // Last plan
        progress.currentDayIndex = 0   // Last day of last plan

        // Advance should wrap to first plan
        let result = CycleService.advance(cycle: cycle, modelContext: context)

        #expect(result == true)
        #expect(progress.currentItemIndex == 0)  // Back to plan 1
        #expect(progress.currentDayIndex == 0)   // First day
    }
}
