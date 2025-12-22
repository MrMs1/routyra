//
//  CycleService.swift
//  Routyra
//
//  Service for managing plan cycles and cycle progress.
//  Handles cycle creation, activation, and day/plan advancement.
//

import Foundation
import SwiftData
import SwiftUI

/// Service for plan cycle management.
enum CycleService {
    // MARK: - Cycle Management

    /// Creates a new plan cycle.
    /// - Parameters:
    ///   - profileId: Owner profile ID.
    ///   - name: Display name for the cycle.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: The created cycle.
    @MainActor
    @discardableResult
    static func createCycle(
        profileId: UUID,
        name: String,
        modelContext: ModelContext
    ) -> PlanCycle {
        let cycle = PlanCycle(profileId: profileId, name: name)
        modelContext.insert(cycle)
        return cycle
    }

    /// Gets all cycles for a profile.
    /// - Parameters:
    ///   - profileId: Owner profile ID.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Array of cycles.
    @MainActor
    static func getCycles(
        profileId: UUID,
        modelContext: ModelContext
    ) -> [PlanCycle] {
        let descriptor = FetchDescriptor<PlanCycle>(
            predicate: #Predicate<PlanCycle> { cycle in
                cycle.profileId == profileId
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching cycles: \(error)")
            return []
        }
    }

    /// Gets the active cycle for a profile.
    /// - Parameters:
    ///   - profileId: Owner profile ID.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: The active cycle if exists.
    @MainActor
    static func getActiveCycle(
        profileId: UUID,
        modelContext: ModelContext
    ) -> PlanCycle? {
        var descriptor = FetchDescriptor<PlanCycle>(
            predicate: #Predicate<PlanCycle> { cycle in
                cycle.profileId == profileId && cycle.isActive
            }
        )
        descriptor.fetchLimit = 1

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("Error fetching active cycle: \(error)")
            return nil
        }
    }

    /// Gets a cycle by ID.
    /// - Parameters:
    ///   - cycleId: The cycle ID.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: The cycle if found.
    @MainActor
    static func getCycle(
        id cycleId: UUID,
        modelContext: ModelContext
    ) -> PlanCycle? {
        var descriptor = FetchDescriptor<PlanCycle>(
            predicate: #Predicate<PlanCycle> { $0.id == cycleId }
        )
        descriptor.fetchLimit = 1

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("Error fetching cycle: \(error)")
            return nil
        }
    }

    // MARK: - Cycle Activation

    /// Sets a cycle as active, deactivating all others.
    /// - Parameters:
    ///   - cycle: The cycle to activate.
    ///   - profileId: Owner profile ID.
    ///   - modelContext: The SwiftData model context.
    @MainActor
    static func setActiveCycle(
        _ cycle: PlanCycle,
        profileId: UUID,
        modelContext: ModelContext
    ) {
        // Deactivate all other cycles
        let allCycles = getCycles(profileId: profileId, modelContext: modelContext)
        for c in allCycles where c.id != cycle.id {
            c.isActive = false
        }

        // Activate the target cycle
        cycle.isActive = true

        // Ensure progress exists
        ensureProgressExists(for: cycle, modelContext: modelContext)
    }

    /// Deactivates a cycle.
    /// - Parameter cycle: The cycle to deactivate.
    @MainActor
    static func deactivateCycle(_ cycle: PlanCycle) {
        cycle.isActive = false
    }

    // MARK: - Item Management

    /// Adds a plan to a cycle.
    /// - Parameters:
    ///   - cycle: The target cycle.
    ///   - plan: The plan to add.
    ///   - modelContext: The SwiftData model context.
    @MainActor
    static func addPlan(
        to cycle: PlanCycle,
        plan: WorkoutPlan,
        modelContext: ModelContext
    ) {
        let nextOrder = (cycle.items.map(\.order).max() ?? -1) + 1
        let item = PlanCycleItem(planId: plan.id, order: nextOrder)
        item.plan = plan
        cycle.addItem(item)
        modelContext.insert(item)
    }

    /// Removes an item from a cycle.
    /// - Parameters:
    ///   - item: The item to remove.
    ///   - cycle: The parent cycle.
    ///   - modelContext: The SwiftData model context.
    @MainActor
    static func removeItem(
        _ item: PlanCycleItem,
        from cycle: PlanCycle,
        modelContext: ModelContext
    ) {
        cycle.removeItem(item)
        modelContext.delete(item)
        cycle.reindexItems()
    }

    /// Moves items within a cycle (reordering).
    /// - Parameters:
    ///   - cycle: The cycle to reorder.
    ///   - fromOffsets: Source indices.
    ///   - toOffset: Destination index.
    @MainActor
    static func moveItems(
        in cycle: PlanCycle,
        fromOffsets: IndexSet,
        toOffset: Int
    ) {
        var items = cycle.sortedItems
        items.move(fromOffsets: fromOffsets, toOffset: toOffset)

        for (index, item) in items.enumerated() {
            item.order = index
        }
        cycle.touch()
    }

    // MARK: - Progress Management

    /// Ensures a progress tracker exists for a cycle.
    /// - Parameters:
    ///   - cycle: The cycle.
    ///   - modelContext: The SwiftData model context.
    @MainActor
    static func ensureProgressExists(
        for cycle: PlanCycle,
        modelContext: ModelContext
    ) {
        if cycle.progress == nil {
            let progress = PlanCycleProgress()
            cycle.progress = progress
            modelContext.insert(progress)
        }
    }

    /// Resets progress for a cycle.
    /// - Parameter cycle: The cycle to reset.
    @MainActor
    static func resetProgress(for cycle: PlanCycle) {
        cycle.progress?.reset()
    }

    // MARK: - Advancement Logic

    /// Advances the cycle to the next day/plan.
    /// Call this when a workout is completed.
    ///
    /// Logic:
    /// 1. Get current plan and its days
    /// 2. Advance day index
    /// 3. If day index exceeds plan's days, advance to next plan
    /// 4. If plan index exceeds cycle's items, wrap to first plan
    /// 5. Skip plans with no days
    ///
    /// - Parameters:
    ///   - cycle: The cycle to advance.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: True if advanced successfully, false if cycle is empty.
    @MainActor
    @discardableResult
    static func advance(
        cycle: PlanCycle,
        modelContext: ModelContext
    ) -> Bool {
        guard let progress = cycle.progress else {
            ensureProgressExists(for: cycle, modelContext: modelContext)
            return false
        }

        let items = cycle.sortedItems
        guard !items.isEmpty else { return false }

        // Load plans for items
        loadPlans(for: items, modelContext: modelContext)

        // Get current plan's day count
        let currentItemIndex = progress.currentItemIndex
        guard currentItemIndex < items.count else {
            progress.currentItemIndex = 0
            progress.currentDayIndex = 0
            return true
        }

        guard let currentPlan = items[currentItemIndex].plan else {
            // Plan was deleted, skip to next
            return advanceToNextValidPlan(
                cycle: cycle,
                progress: progress,
                items: items,
                modelContext: modelContext
            )
        }

        let totalDays = currentPlan.dayCount

        // Handle empty plan
        if totalDays == 0 {
            return advanceToNextValidPlan(
                cycle: cycle,
                progress: progress,
                items: items,
                modelContext: modelContext
            )
        }

        // Advance day
        let needsNextPlan = progress.advanceDay(totalDays: totalDays)

        if needsNextPlan {
            progress.advancePlan(totalItems: items.count)

            // Skip empty plans
            return skipEmptyPlans(
                cycle: cycle,
                progress: progress,
                items: items,
                modelContext: modelContext
            )
        }

        return true
    }

    /// Advances to the next valid plan (skipping deleted/empty ones).
    @MainActor
    private static func advanceToNextValidPlan(
        cycle: PlanCycle,
        progress: PlanCycleProgress,
        items: [PlanCycleItem],
        modelContext: ModelContext
    ) -> Bool {
        progress.advancePlan(totalItems: items.count)
        return skipEmptyPlans(
            cycle: cycle,
            progress: progress,
            items: items,
            modelContext: modelContext
        )
    }

    /// Skips plans that are empty or deleted.
    @MainActor
    private static func skipEmptyPlans(
        cycle: PlanCycle,
        progress: PlanCycleProgress,
        items: [PlanCycleItem],
        modelContext: ModelContext
    ) -> Bool {
        let startIndex = progress.currentItemIndex
        var checkedCount = 0

        while checkedCount < items.count {
            let item = items[progress.currentItemIndex]
            if let plan = item.plan, plan.dayCount > 0 {
                return true // Found valid plan
            }

            progress.advancePlan(totalItems: items.count)
            checkedCount += 1

            if progress.currentItemIndex == startIndex {
                break // Looped back, no valid plans
            }
        }

        return false
    }

    // MARK: - Day Change (Cycle Mode)

    /// Changes the current workout day to a different plan day within the current cycle plan.
    /// Only allowed when completedSets == 0.
    ///
    /// - Parameters:
    ///   - cycle: The cycle.
    ///   - workoutDay: The workout day to modify.
    ///   - newDayIndex: The new day index (1-indexed for display, converted to 0-indexed internally).
    ///   - skipAndAdvance: Whether to also advance the progress pointer.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: True if change was successful.
    @MainActor
    @discardableResult
    static func changeDay(
        cycle: PlanCycle,
        workoutDay: WorkoutDay,
        to newDayIndex: Int,
        skipAndAdvance: Bool,
        modelContext: ModelContext
    ) -> Bool {
        // Verify no completed sets
        guard workoutDay.totalCompletedSets == 0 else {
            return false
        }

        guard let progress = cycle.progress else {
            return false
        }

        // Get current plan
        let items = cycle.sortedItems
        guard progress.currentItemIndex < items.count else {
            return false
        }

        let item = items[progress.currentItemIndex]
        if item.plan == nil {
            item.plan = PlanService.getPlan(id: item.planId, modelContext: modelContext)
        }

        guard let plan = item.plan else {
            return false
        }

        // Convert 1-indexed to 0-indexed for internal use
        let internalDayIndex = newDayIndex - 1
        let sortedDays = plan.sortedDays
        guard internalDayIndex >= 0, internalDayIndex < sortedDays.count else {
            return false
        }

        let newPlanDay = sortedDays[internalDayIndex]

        // Clear existing entries
        for entry in workoutDay.entries {
            modelContext.delete(entry)
        }
        workoutDay.entries.removeAll()

        // Update the routine day ID
        workoutDay.routineDayId = newPlanDay.id

        // Expand the new plan day
        PlanService.expandPlanToWorkout(planDay: newPlanDay, workoutDay: workoutDay)

        // Update progress pointer if skip is enabled
        if skipAndAdvance {
            // Set to next day after the selected one (wrapping around)
            let totalDays = plan.dayCount
            progress.currentDayIndex = newDayIndex % totalDays // This wraps: if newDayIndex==totalDays, goes to 0
            progress.lastAdvancedAt = Date()
        }

        return true
    }

    // MARK: - Current State Helpers

    /// Gets the current plan day for a cycle.
    /// - Parameters:
    ///   - cycle: The cycle.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Tuple of (plan, planDay) or nil if not available.
    @MainActor
    static func getCurrentPlanDay(
        for cycle: PlanCycle,
        modelContext: ModelContext
    ) -> (plan: WorkoutPlan, day: PlanDay)? {
        guard let progress = cycle.progress else { return nil }

        let items = cycle.sortedItems
        guard progress.currentItemIndex < items.count else { return nil }

        let item = items[progress.currentItemIndex]

        // Load plan if needed
        if item.plan == nil {
            item.plan = PlanService.getPlan(id: item.planId, modelContext: modelContext)
        }

        guard let plan = item.plan else { return nil }

        let sortedDays = plan.sortedDays
        guard progress.currentDayIndex < sortedDays.count else { return nil }

        return (plan, sortedDays[progress.currentDayIndex])
    }

    /// Gets display info for the current cycle state.
    /// - Parameters:
    ///   - cycle: The cycle.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Display info tuple.
    @MainActor
    static func getCurrentStateInfo(
        for cycle: PlanCycle,
        modelContext: ModelContext
    ) -> (cycleName: String, planName: String, dayInfo: String)? {
        guard let (plan, _) = getCurrentPlanDay(for: cycle, modelContext: modelContext),
              let progress = cycle.progress else {
            return nil
        }

        let totalDays = plan.dayCount
        let currentDay = progress.currentDayIndex + 1

        return (
            cycleName: cycle.name,
            planName: plan.name,
            dayInfo: L10n.tr("cycle_day_progress", currentDay, totalDays)
        )
    }

    // MARK: - Day Info Resolution

    /// Resolves day info from a plan day ID within a cycle.
    /// - Parameters:
    ///   - planDayId: The plan day ID (routineDayId from WorkoutDay).
    ///   - cycle: The cycle.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Tuple of (dayIndex, totalDays, dayName) or nil if not found.
    @MainActor
    static func getDayInfo(
        planDayId: UUID,
        cycle: PlanCycle,
        modelContext: ModelContext
    ) -> (dayIndex: Int, totalDays: Int, dayName: String?)? {
        // Load plans for items
        loadPlans(for: cycle.sortedItems, modelContext: modelContext)

        // Search through all plans in the cycle
        for item in cycle.sortedItems {
            guard let plan = item.plan else { continue }

            let sortedDays = plan.sortedDays
            if let dayIndex = sortedDays.firstIndex(where: { $0.id == planDayId }) {
                return (dayIndex + 1, plan.dayCount, sortedDays[dayIndex].name)
            }
        }

        return nil
    }

    /// Calculates the preview day for a future date based on current cycle progress.
    /// - Parameters:
    ///   - cycle: The active cycle.
    ///   - targetDate: The target date to calculate for.
    ///   - todayDate: Today's workout date.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: Tuple of (dayIndex, totalDays, dayName) or nil.
    @MainActor
    static func getPreviewDayInfo(
        cycle: PlanCycle,
        targetDate: Date,
        todayDate: Date,
        modelContext: ModelContext
    ) -> (dayIndex: Int, totalDays: Int, dayName: String?)? {
        guard let progress = cycle.progress else { return nil }

        let items = cycle.sortedItems
        guard !items.isEmpty else { return nil }

        loadPlans(for: items, modelContext: modelContext)

        // Get current plan
        guard progress.currentItemIndex < items.count,
              let currentPlan = items[progress.currentItemIndex].plan else {
            return nil
        }

        let totalDays = currentPlan.dayCount
        guard totalDays > 0 else { return nil }

        // Calculate days difference from today
        let calendar = Calendar.current
        let daysDiff = calendar.dateComponents([.day], from: todayDate, to: targetDate).day ?? 0

        // Current day index is 0-indexed, we need to calculate the target
        let currentDayIndex = progress.currentDayIndex // 0-indexed

        // For simplicity, assume staying in current plan (preview within one plan)
        // More complex logic would need to handle plan transitions
        var targetDayIndex = currentDayIndex + daysDiff

        // Handle wrapping
        targetDayIndex = ((targetDayIndex % totalDays) + totalDays) % totalDays

        let sortedDays = currentPlan.sortedDays
        let dayName = targetDayIndex < sortedDays.count ? sortedDays[targetDayIndex].name : nil

        // Return 1-indexed for display
        return (targetDayIndex + 1, totalDays, dayName)
    }

    // MARK: - Helper Methods

    /// Loads plans for cycle items.
    @MainActor
    static func loadPlans(
        for items: [PlanCycleItem],
        modelContext: ModelContext
    ) {
        for item in items where item.plan == nil {
            item.plan = PlanService.getPlan(id: item.planId, modelContext: modelContext)
        }
    }

    /// Deletes a cycle.
    /// - Parameters:
    ///   - cycle: The cycle to delete.
    ///   - modelContext: The SwiftData model context.
    @MainActor
    static func deleteCycle(
        _ cycle: PlanCycle,
        modelContext: ModelContext
    ) {
        modelContext.delete(cycle)
    }
}
