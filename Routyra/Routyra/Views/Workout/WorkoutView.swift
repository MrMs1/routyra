//
//  WorkoutView.swift
//  Routyra
//

import SwiftUI
import SwiftData
import UIKit
import HealthKit

/// Navigation destinations for WorkoutView
enum WorkoutDestination: Hashable {
    case exercisePicker
    case setEditor(exercise: Exercise)
    case exerciseChanger(entryId: UUID, currentExerciseId: UUID)
}

// MARK: - Display Item

/// Unified display item for groups, ungrouped entries, and cardio workouts
private enum WorkoutDisplayItem: Identifiable {
    case group(WorkoutExerciseGroup)
    case entry(WorkoutExerciseEntry)
    case cardio(CardioWorkout)

    var id: String {
        switch self {
        case .group(let group): return "group-\(group.id)"
        case .entry(let entry): return "entry-\(entry.id)"
        case .cardio(let cardio): return "cardio-\(cardio.id)"
        }
    }

    var orderIndex: Int {
        switch self {
        case .group(let group): return group.orderIndex
        case .entry(let entry): return entry.orderIndex
        case .cardio(let cardio): return cardio.orderIndex
        }
    }

    /// Whether this is a cardio item (used for sorting cardio after exercises)
    var isCardio: Bool {
        if case .cardio = self { return true }
        return false
    }
}

private struct ExerciseOrderKey: Hashable {
    let exerciseId: UUID
    let orderIndex: Int
}

private struct GroupEntryKey: Hashable {
    let exerciseId: UUID
    let groupOrderIndex: Int
}

private struct PlanReorderMap {
    let planId: UUID
    let planDayId: UUID
    let groupOrderUpdates: [(groupId: UUID, newOrderIndex: Int)]
    let exerciseOrderUpdates: [(exerciseId: UUID, newOrderIndex: Int)]
}

struct WorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutDay.date, order: .reverse) private var workoutDays: [WorkoutDay]
    @Query private var exercises: [Exercise]
    @Query private var bodyParts: [BodyPart]
    @Query(sort: \CardioWorkout.startDate, order: .reverse) private var allCardioWorkouts: [CardioWorkout]
    @Binding var navigateToHistory: Bool
    @Binding var navigateToRoutines: Bool

    @State private var selectedDate: Date = DateUtilities.todayWorkoutDate(transitionHour: 3)
    @State private var expandedEntryId: UUID?
    @State private var expandedGroupId: UUID?
    @State private var snackBarMessage: String?
    @State private var snackBarUndoAction: (() -> Void)?
    @State private var currentWeight: Double = 60
    @State private var currentReps: Int = 8
    @State private var currentDuration: Int = 60
    @State private var currentDistance: Double? = nil
    @State private var profile: LocalProfile?
    @State private var navigationPath = NavigationPath()
    @State private var shouldReturnToPickerAfterCardio = false
    @State private var hasInitialized: Bool = false
    @State private var pendingCardioExercise: Exercise?

    // Cycle support
    @State private var activeCycle: PlanCycle?
    @State private var cycleStateInfo: (cycleName: String, planName: String, dayInfo: String)?

    // Day change support
    @State private var showDayChangeDialog = false
    @State private var pendingDayChange: Int? = nil
    @State private var skipCurrentDay = false

    // Plan update support
    @State private var showPlanUpdateDialog = false
    @State private var pendingPlanUpdate: PlanUpdateRequest?

    // Reorder support
    @State private var isReordering = false
    @State private var reorderItems: [WorkoutDisplayItem] = []
    @State private var draggedItemId: String?
    @State private var showPlanReorderDialog = false
    @State private var pendingPlanReorder: PlanReorderMap?
    @State private var pendingGroupDelete: WorkoutExerciseGroup?
    @State private var showGroupDeleteDialog = false
    @State private var groupSwipeOffsets: [UUID: CGFloat] = [:]
    @State private var groupSwipeStartOffsets: [UUID: CGFloat] = [:]
    @State private var openGroupSwipeId: UUID?
    @State private var pendingHealthKitLinkCardio: CardioWorkout?
    @State private var showHealthKitLinkDialog = false
    @State private var optimisticCardioWorkouts: [CardioWorkout] = []

    // Past day rescue support
    @State private var showPastDayRescuePicker = false
    @State private var rescueDayIndex: Int = 1

    // Day selector sheet support
    @State private var showDaySelectorSheet = false

    // Rest timer support
    @ObservedObject private var restTimer = RestTimerManager.shared
    @State private var showTimerConflictAlert = false
    @State private var isKeyboardVisible = false
    @State private var pendingTimerDuration: Int = 0
    @State private var showCombinationAnnouncement = false
    @State private var combinationDontShowAgain = false
    @State private var selectedGroupRoundIndex: [UUID: Int] = [:]
    @State private var showCopyPreviousConfirm = false

    // Share support
    @State private var shareImagePayload: ShareImagePayload?

    // Ad support
    @StateObject private var adManager = NativeAdManager()

    // Watch Connectivity support
    @ObservedObject private var watchConnectivity = PhoneWatchConnectivityManager.shared
    @State private var lastSentWorkoutHash: Int?

    private var transitionHour: Int {
        profile?.dayTransitionHour ?? 3
    }

    private var todayWorkoutDate: Date {
        DateUtilities.todayWorkoutDate(transitionHour: transitionHour)
    }

    private var selectedWorkoutDate: Date {
        DateUtilities.startOfDay(selectedDate)
    }

    private var copySourceWorkoutDateLabel: String {
        let sourceDate = lastWorkoutDay?.date ?? selectedWorkoutDate
        return Formatters.monthDay.string(from: DateUtilities.startOfDay(sourceDate))
    }

    private var isViewingToday: Bool {
        DateUtilities.isSameDay(selectedWorkoutDate, todayWorkoutDate)
    }

    private var selectedWorkoutDay: WorkoutDay? {
        workoutDays.first { DateUtilities.isSameDay($0.date, selectedWorkoutDate) }
    }

    private var sortedEntries: [WorkoutExerciseEntry] {
        selectedWorkoutDay?.sortedEntries ?? []
    }

    /// Cardio workouts for the selected date (linked or imported by date)
    private var selectedDateCardioWorkouts: [CardioWorkout] {
        let profileId = profile?.id
        let selectedDate = selectedWorkoutDate
        let linkedWorkoutDayId = selectedWorkoutDay?.id

        var workouts = allCardioWorkouts.filter { workout in
            if let profileId = profileId, workout.profile?.id != profileId {
                return false
            }

            if let linkedId = linkedWorkoutDayId, workout.workoutDayId == linkedId {
                return true
            }

            return workout.workoutDayId == nil &&
                DateUtilities.isSameDay(workout.startDate, selectedDate)
        }
        let existingIds = Set(workouts.map(\.id))
        let optimisticMatches = optimisticCardioWorkouts.filter { workout in
            if let profileId = profileId, workout.profile?.id != profileId {
                return false
            }
            if let linkedId = linkedWorkoutDayId, workout.workoutDayId == linkedId {
                return true
            }
            return workout.workoutDayId == nil &&
                DateUtilities.isSameDay(workout.startDate, selectedDate)
        }
        workouts.append(contentsOf: optimisticMatches.filter { !existingIds.contains($0.id) })
        return workouts
    }

    /// Unlinked HealthKit workouts for the selected date (link candidates).
    private var availableHealthKitWorkoutsForSelectedDate: [CardioWorkout] {
        let profileId = profile?.id
        let selectedDate = selectedWorkoutDate

        return allCardioWorkouts.filter { workout in
            if let profileId = profileId, workout.profile?.id != profileId {
                return false
            }

            guard workout.source == .healthKit else { return false }
            guard workout.workoutDayId == nil else { return false }
            return DateUtilities.isSameDay(workout.startDate, selectedDate)
        }
    }

    /// Unified display items for groups + ungrouped entries + cardio workouts
    private var displayItems: [WorkoutDisplayItem] {
        var items: [WorkoutDisplayItem] = []

        if let workoutDay = selectedWorkoutDay {
            for group in workoutDay.exerciseGroups {
                items.append(.group(group))
            }

            for entry in workoutDay.sortedEntries where !entry.isGrouped {
                items.append(.entry(entry))
            }
        }

        // Sort exercise items by orderIndex
        let exerciseItems = items.sorted { $0.orderIndex < $1.orderIndex }

        // Add cardio items at the end, sorted by their own orderIndex
        let cardioItems = selectedDateCardioWorkouts
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { WorkoutDisplayItem.cardio($0) }

        return exerciseItems + cardioItems
    }

    /// Whether to show empty state (selected date's entries are empty)
    private var shouldShowEmptyState: Bool {
        displayItems.isEmpty
    }

    /// Whether the selected date is a future date without a WorkoutDay
    private var isFutureWithoutWorkout: Bool {
        selectedWorkoutDate > todayWorkoutDate && selectedWorkoutDay == nil
    }

    /// Whether the selected date is a past date without a WorkoutDay
    private var isPastWithoutWorkout: Bool {
        selectedWorkoutDate < todayWorkoutDate && selectedWorkoutDay == nil
    }

    /// Whether the active plan is scheduled for a future start date.
    private var isScheduledPlanPending: Bool {
        guard let profile = profile,
              let scheduledDate = profile.scheduledPlanStartDate,
              let scheduledPlanId = profile.scheduledPlanId,
              let activePlanId = profile.activePlanId,
              scheduledPlanId == activePlanId else {
            return false
        }
        return scheduledDate > todayWorkoutDate
    }

    /// Whether there is an active plan that should apply to workouts today.
    private var hasActiveSinglePlan: Bool {
        guard let profile = profile, profile.executionMode == .single else { return false }
        return profile.activePlanId != nil && !isScheduledPlanPending
    }

    /// Whether the active cycle is scheduled for a future start date.
    private var isScheduledCyclePending: Bool {
        guard let profile = profile,
              profile.executionMode == .cycle,
              let scheduledDate = profile.scheduledCycleStartDate,
              let scheduledCycleId = profile.scheduledCycleId,
              let activeCycle = activeCycle,
              scheduledCycleId == activeCycle.id else {
            return false
        }
        return scheduledDate > todayWorkoutDate
    }

    /// Whether "rescue from plan" option should be shown (past date + active plan/cycle)
    private var canRescueFromPlan: Bool {
        isPastWithoutWorkout && (hasActiveSinglePlan || (activeCycle != nil && !isScheduledCyclePending))
    }

    /// Gets the active plan for rescue/preview (works for both single and cycle modes)
    private var activePlan: WorkoutPlan? {
        guard let profile = profile else { return nil }

        switch profile.executionMode {
        case .single:
            if !isScheduledPlanPending, let planId = profile.activePlanId {
                return PlanService.getPlan(id: planId, modelContext: modelContext)
            }
        case .cycle:
            if !isScheduledCyclePending, let cycle = activeCycle {
                return CycleService.getCurrentPlanDay(for: cycle, modelContext: modelContext)?.plan
            }
        }
        return nil
    }

    /// Gets the PlanDay for future preview display
    private var previewPlanDay: PlanDay? {
        guard isFutureWithoutWorkout,
              let dayInfo = currentDayContextInfo,
              let plan = activePlan else {
            return nil
        }
        return plan.day(at: dayInfo.dayIndex)
    }

    /// Gets the PlanDay for the selected date (today/future preview or linked WorkoutDay).
    private var selectedPlanDay: PlanDay? {
        // 1) If a WorkoutDay exists, resolve via routinePresetId + routineDayId
        if let workoutDay = selectedWorkoutDay,
           let planId = workoutDay.routinePresetId,
           let planDayId = workoutDay.routineDayId,
           let plan = PlanService.getPlan(id: planId, modelContext: modelContext) {
            return plan.days.first { $0.id == planDayId }
        }

        // 2) If no WorkoutDay exists, resolve from day context + active plan
        if let dayInfo = currentDayContextInfo,
           let plan = activePlan {
            return plan.day(at: dayInfo.dayIndex)
        }

        return nil
    }

    private var shouldShowRestDayView: Bool {
        guard shouldShowEmptyState else { return false }
        return selectedPlanDay?.isRestDay ?? false
    }

    private var isRestDay: Bool {
        selectedPlanDay?.isRestDay ?? false
    }

    private var shouldShowShareCard: Bool {
        // Never show on rest day
        guard !isRestDay else { return false }

        let hasStrength = !sortedEntries.isEmpty
        let hasCardio = !selectedDateCardioWorkouts.isEmpty

        // Must have at least 1 strength entry or 1 cardio workout
        guard hasStrength || hasCardio else { return false }

        // All strength entries (if any) must be "completed sets only"
        if hasStrength {
            guard sortedEntries.allSatisfy({ $0.isPlannedSetsCompleted }) else { return false }
        }

        // All cardio workouts (if any) must be completed
        if hasCardio {
            guard selectedDateCardioWorkouts.allSatisfy({ $0.isCompleted }) else { return false }
        }

        return true
    }

    /// Most recent workout day with entries before selected date, used for "copy previous" feature
    private var lastWorkoutDay: WorkoutDay? {
        let targetDate = selectedWorkoutDate
        return workoutDays.first { workoutDay in
            workoutDay.date < targetDate && !workoutDay.sortedEntries.isEmpty
        }
    }

    /// Whether "copy previous workout" option should be shown
    private var canCopyPreviousWorkout: Bool {
        lastWorkoutDay != nil
    }

    private var currentWeekStart: Date? {
        DateUtilities.startOfWeekMonday(containing: selectedDate)
    }

    private var selectedDayIndex: Int {
        let calendar = Calendar.current
        guard let weekStart = currentWeekStart else { return 0 }
        return calendar.dateComponents([.day], from: weekStart, to: selectedDate).day ?? 0
    }

    private var expandedEntryIndex: Int? {
        guard let expandedEntryId else { return nil }
        for (index, item) in displayItems.enumerated() {
            switch item {
            case .entry(let entry):
                if entry.id == expandedEntryId { return index }
            case .group(let group):
                if group.entries.contains(where: { $0.id == expandedEntryId }) { return index }
            case .cardio(let cardio):
                if cardio.id == expandedEntryId { return index }
            }
        }
        return nil
    }

    /// Exercises dictionary for quick lookup
    private var exercisesDict: [UUID: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    /// Body parts dictionary for quick lookup
    private var bodyPartsDict: [UUID: BodyPart] {
        Dictionary(uniqueKeysWithValues: bodyParts.map { ($0.id, $0) })
    }

    /// Whether day context view should be shown
    /// - Shows for today/past with WorkoutDay
    /// - Does NOT show for future without WorkoutDay (preview uses separate view)
    private var shouldShowDayContext: Bool {
        guard let profile = profile else { return false }

        // Don't show DayContext for future dates without WorkoutDay
        // (we'll show a preview view instead)
        if isFutureWithoutWorkout { return false }

        switch profile.executionMode {
        case .single:
            return hasActiveSinglePlan && currentDayContextInfo != nil
        case .cycle:
            return activeCycle != nil && !isScheduledCyclePending && currentDayContextInfo != nil
        }
    }

    /// Current day info for DayContextView (unified for both modes)
    /// Calculates based on:
    /// 1. If selectedWorkoutDay exists with routineDayId - resolve from that
    /// 2. If no WorkoutDay exists - calculate preview from progress + date difference
    private var currentDayContextInfo: (dayIndex: Int, totalDays: Int, dayName: String?, planId: UUID?)? {
        guard let profile = profile else { return nil }

        switch profile.executionMode {
        case .single:
            return getSinglePlanDayInfo()
        case .cycle:
            return getCycleDayInfo()
        }
    }

    /// Gets day info for single plan mode
    private func getSinglePlanDayInfo() -> (dayIndex: Int, totalDays: Int, dayName: String?, planId: UUID?)? {
        guard let profile = profile,
              profile.executionMode == .single,
              !isScheduledPlanPending,
              let planId = profile.activePlanId else {
            return nil
        }

        // 1. If selected date has a WorkoutDay with routineDayId, resolve from it
        if let workoutDay = selectedWorkoutDay,
           let routineDayId = workoutDay.routineDayId,
           workoutDay.routinePresetId == planId {
            if let info = PlanService.getDayInfo(
                planDayId: routineDayId,
                planId: planId,
                modelContext: modelContext
            ) {
                return (info.dayIndex, info.totalDays, info.dayName, planId)
            }
        }

        // 2. No WorkoutDay - check if today or future
        let isToday = DateUtilities.isSameDay(selectedWorkoutDate, todayWorkoutDate)
        let isFuture = selectedWorkoutDate > todayWorkoutDate

        if isToday || isFuture {
            // Calculate preview
            if let info = PlanService.getPreviewDayInfo(
                profile: profile,
                targetDate: selectedWorkoutDate,
                todayDate: todayWorkoutDate,
                modelContext: modelContext
            ) {
                return (info.dayIndex, info.totalDays, info.dayName, info.planId)
            }
        }

        // 3. Past date without WorkoutDay - return nil (no Day display)
        return nil
    }

    /// Gets day info for cycle mode
    private func getCycleDayInfo() -> (dayIndex: Int, totalDays: Int, dayName: String?, planId: UUID?)? {
        guard let cycle = activeCycle, !isScheduledCyclePending else { return nil }

        // 1. If selected date has a WorkoutDay with routineDayId, resolve from it
        if let workoutDay = selectedWorkoutDay,
           let routineDayId = workoutDay.routineDayId {
            if let info = CycleService.getDayInfo(
                planDayId: routineDayId,
                cycle: cycle,
                modelContext: modelContext
            ) {
                // Get current plan ID for day change
                let planId = workoutDay.routinePresetId
                return (info.dayIndex, info.totalDays, info.dayName, planId)
            }
        }

        // 2. No WorkoutDay - check if today or future
        let isToday = DateUtilities.isSameDay(selectedWorkoutDate, todayWorkoutDate)
        let isFuture = selectedWorkoutDate > todayWorkoutDate

        if isToday || isFuture {
            // Calculate preview
            if let info = CycleService.getPreviewDayInfo(
                cycle: cycle,
                targetDate: selectedWorkoutDate,
                todayDate: todayWorkoutDate,
                modelContext: modelContext
            ) {
                // Get current plan ID from cycle progress
                let items = cycle.sortedItems
                let planId = cycle.progress.flatMap { progress in
                    progress.currentItemIndex < items.count ? items[progress.currentItemIndex].planId : nil
                }
                return (info.dayIndex, info.totalDays, info.dayName, planId)
            }
        }

        // 3. Past date without WorkoutDay - return nil (no Day display)
        return nil
    }

    /// Whether day can be changed (only when completed sets == 0 and plan has > 1 day)
    private var canChangeDay: Bool {
        // Can't change if only 1 day in the plan
        guard let dayInfo = currentDayContextInfo, dayInfo.totalDays > 1 else {
            return false
        }

        // Can change if no workout exists yet
        guard let workoutDay = selectedWorkoutDay else { return true }

        // Can't change if already started (has completed sets)
        return workoutDay.totalCompletedSets == 0
    }

    private var navigationRoot: some View {
        NavigationStack(path: $navigationPath) {
            mainContent
                .navigationDestination(for: WorkoutDestination.self) { destination in
                    destinationView(for: destination)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isKeyboardVisible = true
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isKeyboardVisible = false
                    }
                }
        }
    }

    var body: some View {
        bodyWithAnimation
    }

    private var bodyWithAnimation: some View {
        bodyWithCombinationOverlay
            .animation(.easeInOut(duration: 0.2), value: showCombinationAnnouncement)
    }

    private var bodyWithCombinationOverlay: some View {
        bodyWithAlert
            .overlay {
                combinationOverlay
            }
    }

    private var bodyWithAlert: some View {
        bodyWithSheets
            .alert(L10n.tr("rest_timer_conflict_title"), isPresented: $showTimerConflictAlert) {
                Button(L10n.tr("rest_timer_conflict_continue"), role: .cancel) {
                    // Keep current timer running
                    pendingTimerDuration = 0
                }
                Button(L10n.tr("rest_timer_conflict_switch")) {
                    // Switch to new timer
                    restTimer.forceStart(duration: pendingTimerDuration)
                    pendingTimerDuration = 0
                }
            } message: {
                Text(L10n.tr("rest_timer_conflict_message"))
            }
            .alert(L10n.tr("empty_state_copy_title"), isPresented: $showCopyPreviousConfirm) {
                Button(L10n.tr("cancel"), role: .cancel) {}
                Button(L10n.tr("empty_state_copy_button")) {
                    copyPreviousWorkout()
                }
            } message: {
                Text(L10n.tr("workout_copy_confirm_message", copySourceWorkoutDateLabel))
                    + Text("\n")
                    + Text(L10n.tr("workout_copy_confirm_note_healthkit"))
                        .font(.footnote)
            }
            .confirmationDialog(
                L10n.tr("workout_delete_group_title"),
                isPresented: $showGroupDeleteDialog,
                titleVisibility: .visible
            ) {
                Button(L10n.tr("delete"), role: .destructive) {
                    if let group = pendingGroupDelete {
                        deleteGroup(group)
                    }
                    pendingGroupDelete = nil
                }
                Button(L10n.tr("cancel"), role: .cancel) {
                    pendingGroupDelete = nil
                }
            } message: {
                Text(L10n.tr("workout_delete_group_message"))
            }
            .confirmationDialog(
                L10n.tr("cardio_link_healthkit_title"),
                isPresented: $showHealthKitLinkDialog,
                titleVisibility: .visible
            ) {
                ForEach(availableHealthKitWorkoutsForSelectedDate, id: \.id) { workout in
                    Button(healthKitLinkLabel(for: workout)) {
                        if let target = pendingHealthKitLinkCardio {
                            linkHealthKitWorkout(workout, to: target)
                        }
                        pendingHealthKitLinkCardio = nil
                    }
                }
                Button(L10n.tr("cancel"), role: .cancel) {
                    pendingHealthKitLinkCardio = nil
                }
            } message: {
                Text(L10n.tr("cardio_link_healthkit_message"))
            }
    }

    private var bodyWithSheets: some View {
        bodyWithDayOverlay
            .sheet(isPresented: $showPastDayRescuePicker) {
                pastDayRescueSheet
            }
            .sheet(
                item: $pendingCardioExercise,
                onDismiss: {
                    shouldReturnToPickerAfterCardio = false
                },
                content: { exercise in
                    cardioEntrySheet(for: exercise)
                }
            )
            .sheet(item: $shareImagePayload) { payload in
                ShareSheet(items: [payload.image])
            }
    }

    private var bodyWithDayOverlay: some View {
        bodyWithLifecycle
            .overlay {
                dayOverlay
            }
    }

    private var bodyWithLifecycle: some View {
        navigationRoot
            .onAppear(perform: handleOnAppear)
            .onChange(of: selectedDate) { _, _ in
                handleSelectedDateChange()
            }
            .onChange(of: allCardioWorkouts) { _, newValue in
                pruneOptimisticCardioWorkouts(using: newValue)
            }
    }

    private func handleOnAppear() {
        // OPTIMIZATION: Guard all heavy operations with hasInitialized
        // Profile caching in ProfileService makes this call cheap on subsequent visits
        profile = ProfileService.getOrCreateProfile(modelContext: modelContext)

        if !hasInitialized {
            // Initialize only once to preserve state when switching tabs
            // These operations are expensive and don't need to run on every tab switch

            // Only load cycle if in cycle mode
            if profile?.executionMode == .cycle {
                loadActiveCycle()
            }

            ensureTodayWorkout()

            selectedDate = todayWorkoutDate
            if let first = sortedEntries.first {
                expandedEntryId = first.id
                updateCurrentWeightReps(for: first)
            }

            // Load ads if not premium
            if !(profile?.isPremiumUser ?? false) {
                adManager.loadNativeAds(count: 3)
            }

            // Setup Watch Connectivity
            setupWatchConnectivity()

            hasInitialized = true
        }

        // Send workout data to Watch on appear
        sendWorkoutDataToWatch()
    }

    private func handleSelectedDateChange() {
        if isReordering {
            stopReorderMode()
        }
        if let first = sortedEntries.first {
            expandedEntryId = first.id
            updateCurrentWeightReps(for: first)
        } else {
            expandedEntryId = nil
        }
    }

    private func shiftSelectedDate(by days: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedWorkoutDate) else {
            return
        }

        // Prevent moving to a different week
        let currentWeekStart = DateUtilities.startOfWeekMonday(containing: selectedWorkoutDate)
        let newWeekStart = DateUtilities.startOfWeekMonday(containing: newDate)

        if currentWeekStart != newWeekStart {
            return
        }

        selectedDate = DateUtilities.startOfDay(newDate)
    }

    @ViewBuilder
    private var pastDayRescueSheet: some View {
        if let plan = activePlan {
            PlanStartDayPickerSheet(
                days: plan.sortedDays,
                selectedDayIndex: $rescueDayIndex
            )
            .onDisappear {
                // After sheet is dismissed, execute rescue if a day was selected
                if rescueDayIndex > 0 {
                    rescuePastDay(planId: plan.id, dayIndex: rescueDayIndex)
                    rescueDayIndex = 0 // Reset for next time
                }
            }
        } else {
            EmptyView()
        }
    }

    private func cardioEntrySheet(for exercise: Exercise) -> some View {
        NavigationStack {
            CardioTimeDistanceEntryView { durationSeconds, distanceMeters in
                addCardioWorkout(
                    exercise,
                    durationSeconds: durationSeconds,
                    distanceMeters: distanceMeters
                )
                if shouldReturnToPickerAfterCardio {
                    navigationPath.removeLast()
                }
                shouldReturnToPickerAfterCardio = false
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            headerView
            weeklyStripView

            // Rest timer progress bar (shown when timer is running or completed)
            RestTimerProgressBar()

            reorderBar

            workoutListView
        }
        .background(AppColors.background)
        .navigationBarHidden(true)
    }

    private var headerView: some View {
        WorkoutHeaderView(
            date: selectedDate,
            isViewingToday: isViewingToday,
            dayInfo: buildDayDisplayInfo(),
            onTodayTap: {
                selectedDate = DateUtilities.startOfDay(Date())
            },
            onDayTap: {
                showDaySelectorSheet = true
            }
        )
    }

    private var weeklyStripView: some View {
        WeeklyActivityStripView(
            weekStart: currentWeekStart ?? Date(),
            selectedDayIndex: selectedDayIndex,
            workoutStates: computeWorkoutStates(),
            onDayTap: selectDay
        )
    }

    @ViewBuilder
    private var reorderBar: some View {
        // 並び替えモード中のみ「完了」ボタンを表示
        if isReordering {
            HStack {
                Spacer()
                Button(action: toggleReorderMode) {
                    Text(L10n.tr("done"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(AppColors.accentBlue)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private var workoutListView: some View {
        ScrollViewReader { proxy in
            workoutListContent(scrollProxy: proxy)
                .onChange(of: expandedEntryId) { _, newId in
                    guard let entryId = newId else { return }
                    scrollToEntry(entryId, scrollProxy: proxy)
                }
        }
    }

    @ViewBuilder
    private func workoutListContent(scrollProxy: ScrollViewProxy) -> some View {
        if isReordering && !reorderItems.isEmpty {
            reorderableListContent()
        } else {
            normalScrollContent(scrollProxy: scrollProxy)
        }
    }

    // MARK: - List版並び替えUI

    @ViewBuilder
    private func reorderableListContent() -> some View {
        List {
            ForEach(reorderItems) { item in
                reorderRowView(item)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .onMove(perform: moveReorderItems)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .environment(\.editMode, .constant(.active))
    }

    private func moveReorderItems(from source: IndexSet, to destination: Int) {
        reorderItems.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - 通常のScrollView版

    private func normalScrollContent(scrollProxy: ScrollViewProxy) -> some View {
        let cachedDisplayItems = displayItems

        return ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(cachedDisplayItems.enumerated()), id: \.element.id) { index, item in
                    displayItemView(item, scrollProxy: scrollProxy)

                    // Show ad after the 3rd exercise only when there are 5+ exercises
                    if let adIndex = shouldShowAd(afterIndex: index, displayItemsCount: cachedDisplayItems.count),
                       adIndex < adManager.nativeAds.count,
                       !(profile?.isPremiumUser ?? false) {
                        NativeAdCardView(nativeAd: adManager.nativeAds[adIndex])
                    }
                }

                if cachedDisplayItems.isEmpty {
                    VStack(spacing: 0) {
                        if shouldShowRestDayView {
                            RestDayEmptyView(
                                dayIndex: currentDayContextInfo?.dayIndex,
                                totalDays: currentDayContextInfo?.totalDays,
                                dayName: selectedPlanDay?.name
                            )
                        // Future date without workout: show plan preview
                        } else if isFutureWithoutWorkout, let planDay = previewPlanDay, let dayInfo = currentDayContextInfo {
                            PlanDayPreviewView(
                                planDay: planDay,
                                dayIndex: dayInfo.dayIndex,
                                totalDays: dayInfo.totalDays,
                                exercises: exercisesDict,
                                bodyParts: bodyPartsDict,
                                weightUnit: profile?.effectiveWeightUnit ?? .kg
                            )
                        } else {
                            // Regular empty state (today or past)
                            EmptyStateView(
                                isToday: isViewingToday,
                                showCopyOption: canCopyPreviousWorkout,
                                showRescueOption: canRescueFromPlan,
                                showRecordFromPlanPrimary: activePlan != nil,
                                showDescription: activePlan == nil,
                                onCreatePlan: {
                                    navigateToRoutines = true
                                },
                                onRecordFromPlan: {
                                    recordFromPlan()
                                },
                                onCopyPrevious: {
                                    showCopyPreviousConfirm = true
                                },
                                onAddExercise: {
                                    navigationPath.append(WorkoutDestination.exercisePicker)
                                },
                                onRescueFromPlan: {
                                    showPastDayRescuePicker = true
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .simultaneousGesture(emptyStateDaySwipeGesture)

                    // Show ad at bottom of empty state
                    if shouldShowEmptyStateAd {
                        NativeAdCardView(nativeAd: adManager.nativeAds[0])
                    }
                } else {
                    // Add exercise card at bottom of list (only when entries exist)
                    AddExerciseCard {
                        navigationPath.append(WorkoutDestination.exercisePicker)
                    }

                    if shouldShowShareCard {
                        ShareWorkoutCard {
                            startWorkoutShare()
                        }
                    }

                    // Always show ad below add exercise button
                    if shouldShowBottomAd(displayItemsEmpty: cachedDisplayItems.isEmpty) {
                        NativeAdCardView(nativeAd: adManager.nativeAds[0])
                    }
                }
            }
            .padding(.horizontal)
        }
        .id(selectedWorkoutDate) // Force fresh render when date changes to prevent flicker
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if let message = snackBarMessage {
                    SnackBarView(
                        message: message,
                        onUndo: {
                            snackBarUndoAction?()
                            dismissSnackBar()
                        },
                        onAdjustWeight: { delta in
                            currentWeight += delta
                        },
                        onAdjustReps: { delta in
                            currentReps += delta
                        },
                        onDismiss: {
                            dismissSnackBar()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if !sortedEntries.isEmpty && !isKeyboardVisible {
                    BottomStatusBarView(
                        sets: selectedWorkoutDay?.totalCompletedSets ?? 0,
                        exercises: selectedWorkoutDay?.totalExercisesWithSets ?? 0,
                        volume: Double(truncating: (selectedWorkoutDay?.totalVolume ?? 0) as NSNumber),
                        weightUnit: profile?.effectiveWeightUnit ?? .kg
                    )
                }
            }
        }
    }

    private var emptyStateDaySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                guard shouldShowEmptyState else { return }

                let horizontalTranslation = value.translation.width
                let verticalTranslation = value.translation.height
                guard abs(horizontalTranslation) > abs(verticalTranslation) else { return }

                let swipeThreshold: CGFloat = 80
                if horizontalTranslation > swipeThreshold {
                    shiftSelectedDate(by: -1)
                } else if horizontalTranslation < -swipeThreshold {
                    shiftSelectedDate(by: 1)
                }
            }
    }

    @ViewBuilder
    private func destinationView(for destination: WorkoutDestination) -> some View {
        switch destination {
        case .exercisePicker:
            if let profile = profile {
                    WorkoutExercisePickerView(
                        profile: profile,
                        exercises: exercisesDict,
                        bodyParts: bodyPartsDict,
                        onSelect: { exercise in
                            // Navigate to set editor instead of directly adding
                            if isCardioExercise(exercise) {
                                shouldReturnToPickerAfterCardio = true
                                pendingCardioExercise = exercise
                            } else {
                                shouldReturnToPickerAfterCardio = false
                                navigationPath.removeLast()
                                navigationPath.append(WorkoutDestination.setEditor(exercise: exercise))
                            }
                        }
                    )
            }

        case .setEditor(let exercise):
            if isCardioExercise(exercise) {
                Color.clear
                    .onAppear {
                        if pendingCardioExercise == nil {
                            shouldReturnToPickerAfterCardio = false
                            pendingCardioExercise = exercise
                        }
                        navigationPath.removeLast()
                    }
            } else {
                let bodyPart = exercise.bodyPartId.flatMap { bodyPartsDict[$0] }
                // Use default values for new exercise (not persisted values from other exercises)
                SetEditorView(
                    exercise: exercise,
                    bodyPart: bodyPart,
                    metricType: exercise.defaultMetricType,
                    initialWeight: 60,
                    initialReps: 10,
                    initialRestTimeSeconds: profile?.defaultRestTimeSeconds,
                    config: .workout,
                    candidateCollection: buildCandidateCollectionForExercise(exercise),
                    onConfirm: { sets in
                        addExerciseToWorkout(exercise, withSets: sets)
                        navigationPath.removeLast()
                    },
                    weightUnit: profile?.effectiveWeightUnit ?? .kg
                )
            }

        case .exerciseChanger(let entryId, let currentExerciseId):
            if let profile = profile {
                WorkoutExercisePickerView(
                    profile: profile,
                    exercises: exercisesDict,
                    bodyParts: bodyPartsDict,
                    mode: .change(currentExerciseId: currentExerciseId),
                    onSelect: { exercise in
                        changeExercise(entryId: entryId, to: exercise)
                        navigationPath.removeLast()
                    }
                )
            }
        }
    }

    private var dayOverlay: some View {
        ZStack {
            // Day change confirmation dialog (custom overlay instead of sheet for better control)
            if showDayChangeDialog, let newDay = pendingDayChange {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDayChangeDialog = false
                                pendingDayChange = nil
                            }
                        }

                    DayChangeDialogView(
                        targetDayIndex: newDay,
                        totalDays: currentDayContextInfo?.totalDays ?? 1,
                        onConfirm: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDayChangeDialog = false
                            }
                            executeDayChange(to: newDay, skipAndAdvance: true)
                            pendingDayChange = nil
                        },
                        onCancel: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDayChangeDialog = false
                                pendingDayChange = nil
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                .animation(.easeInOut(duration: 0.2), value: showDayChangeDialog)
            }

            // Plan update confirmation dialog
            if showPlanUpdateDialog, let request = pendingPlanUpdate {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            dismissPlanUpdateDialog()
                        }

                    PlanUpdateDialogView(
                        exerciseName: request.exerciseName,
                        skipToggleText: request.skipToggleText,
                        onConfirm: { skipConfirmation in
                            applyPlanUpdate(planExercise: request.planExercise, entry: request.entry)
                            if skipConfirmation {
                                applyPlanUpdatePolicySkip(for: request.direction)
                            }
                            dismissPlanUpdateDialog()
                        },
                        onCancel: {
                            dismissPlanUpdateDialog()
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                .animation(.easeInOut(duration: 0.2), value: showPlanUpdateDialog)
            }

            // Plan reorder confirmation dialog
            if showPlanReorderDialog {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            dismissPlanReorderDialog()
                        }

                    PlanReorderDialogView(
                        onConfirm: {
                            applyPendingPlanReorder()
                            dismissPlanReorderDialog()
                        },
                        onCancel: {
                            dismissPlanReorderDialog()
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                .animation(.easeInOut(duration: 0.2), value: showPlanReorderDialog)
            }

            // Day selector card overlay
            if showDaySelectorSheet, let plan = activePlan, let dayInfo = currentDayContextInfo {
                let cycleName: String? = {
                    guard let profile = profile,
                          profile.executionMode == .cycle,
                          let cycle = activeCycle else { return nil }
                    return cycle.name
                }()
                let cyclePosition: String? = {
                    guard let profile = profile,
                          profile.executionMode == .cycle,
                          let cycle = activeCycle,
                          let progress = cycle.progress else { return nil }
                    let currentItem = progress.currentItemIndex + 1
                    let totalItems = cycle.items.count
                    return "\(currentItem)/\(totalItems)"
                }()

                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDaySelectorSheet = false
                            }
                        }

                    PlanDaySelectorCardView(
                        planName: plan.name.isEmpty ? L10n.tr("new_plan") : plan.name,
                        cycleName: cycleName,
                        cyclePosition: cyclePosition,
                        days: plan.sortedDays,
                        currentDayIndex: dayInfo.dayIndex,
                        canSwitchDay: buildDayDisplayInfo()?.canSwitchDay ?? false,
                        onSelect: { newDayIndex in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDaySelectorSheet = false
                            }
                            requestDayChange(to: newDayIndex)
                        },
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDaySelectorSheet = false
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                .animation(.easeInOut(duration: 0.2), value: showDaySelectorSheet)
            }
        }
    }

    private var combinationOverlay: some View {
        Group {
            // Combination mode announcement overlay
            if showCombinationAnnouncement {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            dismissCombinationAnnouncement(startTimer: false, enableLink: false)
                        }

                    CombinationAnnouncementView(
                        dontShowAgain: $combinationDontShowAgain,
                        onEnableAndRun: {
                            dismissCombinationAnnouncement(startTimer: true, enableLink: true)
                        },
                        onRunWithoutLink: {
                            dismissCombinationAnnouncement(startTimer: true, enableLink: false)
                        },
                        onClose: {
                            dismissCombinationAnnouncement(startTimer: false, enableLink: false)
                        }
                    )
                }
                .transition(.opacity)
            }
        }
    }

    private func dismissCombinationAnnouncement(startTimer: Bool, enableLink: Bool) {
        if enableLink {
            profile?.combineRecordAndTimerStart = true
        }
        if combinationDontShowAgain {
            profile?.hasShownCombinationAnnouncement = true
        }
        if enableLink || combinationDontShowAgain {
            try? modelContext.save()
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            showCombinationAnnouncement = false
        }
        if startTimer, pendingTimerDuration > 0 {
            _ = restTimer.start(duration: pendingTimerDuration)
        }
        pendingTimerDuration = 0
        combinationDontShowAgain = false
    }

    private func getExerciseName(for exerciseId: UUID) -> String {
        exercises.first { $0.id == exerciseId }?.localizedName ?? L10n.tr("workout_unknown_exercise")
    }

    private func getBodyPartColor(for exerciseId: UUID) -> Color? {
        guard let exercise = exercisesDict[exerciseId],
              let bodyPartId = exercise.bodyPartId,
              let bodyPart = bodyPartsDict[bodyPartId] else {
            return nil
        }
        return bodyPart.color
    }

    private func isCardioExercise(_ exercise: Exercise) -> Bool {
        guard let bodyPartId = exercise.bodyPartId,
              let bodyPart = bodyPartsDict[bodyPartId] else {
            return false
        }
        return bodyPart.code == "cardio"
    }

    private func scrollToEntry(_ entryId: UUID, scrollProxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.25)) {
                scrollProxy.scrollTo(entryId, anchor: .top)
            }
        }
    }

    // MARK: - Row Builders

    @ViewBuilder
    private func groupView(for group: WorkoutExerciseGroup, scrollProxy: ScrollViewProxy) -> some View {
        let isExpanded = expandedGroupId == group.id
        let defaultRoundIndex = max(0, min(group.activeRound - 1, max(group.setCount - 1, 0)))
        let selectedRound = selectedGroupRoundIndex[group.id] ?? defaultRoundIndex
        let isCombinationMode = profile?.combineRecordAndTimerStart ?? false
        let restSeconds = group.roundRestSeconds ?? profile?.defaultRestTimeSeconds ?? 0
        let lastCompletedRoundIndex = group.roundsCompleted - 1
        let isViewingCompletedRound = !group.isAllRoundsComplete && selectedRound < defaultRoundIndex
        let canUncompleteSelectedRound = selectedRound == lastCompletedRoundIndex &&
            lastCompletedRoundIndex >= 0 &&
            canUncompleteGroupRound(group, roundIndex: selectedRound)

        VStack(alignment: .leading, spacing: 0) {
            if isExpanded {
                // MARK: - Expanded Content
                VStack(alignment: .leading, spacing: 10) {
                    WorkoutExerciseGroupCardView(
                        group: group,
                        onUpdateRest: { newRest in
                            group.roundRestSeconds = newRest
                        },
                        showsBackground: false,
                        showsRestTimeButton: false
                    )
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            expandedGroupId = nil
                        }
                    }

                    HStack(alignment: .top, spacing: 10) {
                        GroupRoundDotsColumnView(
                            completedRounds: group.roundsCompleted,
                            totalRounds: group.setCount,
                            activeRound: group.activeRound,
                            isAllRoundsComplete: group.isAllRoundsComplete,
                            isViewingCompletedRound: isViewingCompletedRound,
                            selectedRoundIndex: selectedRound,
                            onSelectRound: { index in
                                selectedGroupRoundIndex[group.id] = index
                            }
                        )
                        .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(group.sortedEntries, id: \.id) { entry in
                                GroupedExerciseRowView(
                                    entry: entry,
                                    exerciseName: getExerciseName(for: entry.exerciseId),
                                    bodyPartColor: getBodyPartColor(for: entry.exerciseId),
                                    selectedRoundIndex: selectedRound,
                                    onInvalidInput: {
                                        showSnackBar(
                                            message: L10n.tr("workout_invalid_input"),
                                            undoAction: {}
                                        )
                                    },
                                    weightUnit: profile?.effectiveWeightUnit ?? .kg
                                )
                            }

                            if !group.isAllRoundsComplete {
                                if isViewingCompletedRound {
                                    // Match single-exercise behavior:
                                    // When viewing a completed round, show "Go to latest set"
                                    // instead of logging the next (active) round.
                                    Button(action: {
                                        selectedGroupRoundIndex[group.id] = defaultRoundIndex
                                    }) {
                                        HStack(spacing: 6) {
                                            Text("workout_go_to_current_set")
                                            Image(systemName: "arrow.right")
                                                .font(.subheadline.weight(.semibold))
                                        }
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(AppColors.accentBlue.opacity(0.18))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(AppColors.accentBlue.opacity(0.45), lineWidth: 1)
                                        )
                                        .cornerRadius(12)
                                    }
                                } else {
                                    // Group spec: log round (single action). No REST timer UI for groups.
                                    Button(action: {
                                        let success = logGroupRound(for: group)
                                        guard success else { return }

                                        // Do NOT start rest timer when the final round was just completed.
                                        guard !group.isAllRoundsComplete else { return }

                                        // Start rest timer only for non-final rounds (combination mode).
                                        if isCombinationMode, restSeconds > 0 {
                                            handleCombinationModeTimer(restTimeSeconds: group.roundRestSeconds)
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark")
                                                .font(.subheadline.weight(.semibold))
                                            Text(L10n.tr(isCombinationMode ? "rest_timer_log_and_start" : "rest_timer_log_set"))
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(AppColors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(AppColors.accentBlue)
                                        .cornerRadius(12)
                                    }
                                }
                            }

                            // Uncomplete (undo) button for group rounds:
                            // Only the last completed round can be reverted (same rule as single-set undo).
                            if canUncompleteSelectedRound {
                                Button(action: {
                                    _ = uncompleteGroupRound(for: group, roundIndex: selectedRound)
                                    // Match single-exercise behavior: return to latest after undo when viewing past rounds.
                                    if isViewingCompletedRound {
                                        selectedGroupRoundIndex[group.id] = max(0, group.activeRound - 1)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.uturn.backward")
                                            .font(.subheadline.weight(.semibold))
                                        Text("workout_uncomplete_set")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                }
                            }
                        }
                    }
                }
                .padding(10)
            } else {
                // MARK: - Collapsed Content
                groupCollapsedContent(for: group)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            expandedGroupId = group.id
                        }
                    }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                // Match single exercise card behavior:
                // when the group is fully completed, use the "completed" background variant.
                .fill(group.isAllRoundsComplete ? AppColors.groupedCardBackgroundCompleted : AppColors.groupedCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.divider.opacity(0.6), lineWidth: 0.5)
                )
        )
    }

    /// Collapsed content for group card showing exercise names and round progress.
    @ViewBuilder
    private func groupCollapsedContent(for group: WorkoutExerciseGroup) -> some View {
        let progressColor: Color = {
            switch group.progressState {
            case .notStarted:
                return AppColors.textMuted
            case .inProgress:
                return AppColors.textSecondary
            case .completed:
                return AppColors.accentBlue
            }
        }()

        // Round subtitle text (matches single exercise format)
        let roundSubtitle: String = {
            let completed = group.roundsCompleted
            let total = group.setCount
            if completed >= total {
                return L10n.tr("workout_rounds_completed", total)
            } else {
                return L10n.tr("workout_rounds_progress", completed, total)
            }
        }()

        VStack(alignment: .leading, spacing: 4) {
            // Group badge row
            HStack(spacing: 8) {
                // Group label badge
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.stack")
                        .font(.caption)
                    Text(group.displayName)
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(progressColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(progressColor.opacity(0.15))
                .cornerRadius(6)
            }

            // Exercise names list
            VStack(alignment: .leading, spacing: 4) {
                ForEach(group.sortedEntries, id: \.id) { entry in
                    HStack(spacing: 8) {
                        // Body part color dot
                        if let color = getBodyPartColor(for: entry.exerciseId) {
                            Circle()
                                .fill(color)
                                .frame(width: 8, height: 8)
                        }

                        Text(getExerciseName(for: entry.exerciseId))
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
            }

            // Round progress subtitle (same position as single exercise sets)
            HStack(spacing: 6) {
                Text(roundSubtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textMuted)

                if group.isAllRoundsComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.accentBlue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private func entryCardView(
        for entry: WorkoutExerciseEntry,
        scrollProxy: ScrollViewProxy,
        isGrouped: Bool
    ) -> some View {
        let isExpanded = expandedEntryId == entry.id
        let exerciseName = getExerciseName(for: entry.exerciseId)
        let bodyPartColor = getBodyPartColor(for: entry.exerciseId)

        return ExerciseEntryCardView(
            entry: entry,
            exerciseName: exerciseName,
            bodyPartColor: bodyPartColor,
            isExpanded: isExpanded,
            isGrouped: isGrouped,
            currentWeight: $currentWeight,
            currentReps: $currentReps,
            currentDuration: $currentDuration,
            currentDistance: $currentDistance,
            onTap: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedEntryId = isExpanded ? nil : entry.id
                }
                // Update weight/reps to next incomplete set's values
                if !isExpanded {
                    updateCurrentWeightReps(for: entry)
                }
            },
            onLogSet: {
                return logSet(for: entry, scrollProxy: scrollProxy)
            },
            onAddSet: {
                addSet(to: entry)
            },
            onRemovePlannedSet: { set in
                removePlannedSet(set, from: entry)
            },
            onDeleteSet: { set in
                deleteCompletedSet(set, from: entry)
            },
            onDeleteEntry: {
                deleteEntry(entry)
            },
            onChangeExercise: {
                navigationPath.append(
                    WorkoutDestination.exerciseChanger(
                        entryId: entry.id,
                        currentExerciseId: entry.exerciseId
                    )
                )
            },
            onUpdateSet: { set in
                updateCompletedSet(set)
            },
            onApplySet: { set in
                applyPendingSetValues(set)
            },
            onUncompleteSet: { set in
                uncompleteSet(set)
            },
            onTimerStart: { restTime in
                handleManualTimerStart(duration: restTime)
            },
            onTimerCancel: {
                restTimer.cancel()
            },
            onUpdateRestTime: { set, newRestTime in
                set.restTimeSeconds = newRestTime
                // Sync rest time change to Watch.
                sendWorkoutDataToWatch()
            },
            defaultRestTimeSeconds: profile?.defaultRestTimeSeconds ?? 90,
            isCombinationModeEnabled: profile?.combineRecordAndTimerStart ?? false,
            timerManager: restTimer,
            weightUnit: profile?.effectiveWeightUnit ?? .kg
        )
        .id(entry.id)
    }

    // MARK: - Cardio Card View

    @ViewBuilder
    private func cardioCardView(for cardio: CardioWorkout) -> some View {
        CardioEntryCardView(
            cardio: cardio,
            isExpanded: expandedEntryId == cardio.id,
            onTap: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expandedEntryId == cardio.id {
                        expandedEntryId = nil
                    } else {
                        expandedEntryId = cardio.id
                    }
                }
            },
            onComplete: {
                cardio.isCompleted = true
                try? modelContext.save()
            },
            onUncomplete: {
                // Only manual entries can be uncompleted
                if cardio.source == .manual {
                    cardio.isCompleted = false
                    try? modelContext.save()
                }
            },
            onDelete: {
                deleteCardioWorkout(cardio)
            },
            showsHealthKitLinkButton: cardio.source == .manual
                && !availableHealthKitWorkoutsForSelectedDate.isEmpty,
            onLinkFromHealthKit: {
                pendingHealthKitLinkCardio = cardio
                showHealthKitLinkDialog = true
            },
            onUpdateDuration: { newDuration in
                cardio.duration = newDuration
                try? modelContext.save()
            },
            onUpdateDistance: { newDistance in
                cardio.totalDistance = newDistance
                try? modelContext.save()
            }
        )
        .id(cardio.id)
    }

    private func linkHealthKitWorkout(_ source: CardioWorkout, to target: CardioWorkout) {
        guard source.id != target.id else { return }

        // Copy HealthKit data to the target (plan-derived) cardio workout.
        // Note: planExerciseId is intentionally NOT overwritten to preserve
        // the plan association for day progression logic.
        target.activityType = source.activityType
        target.manualExerciseCode = nil
        target.startDate = source.startDate
        target.duration = source.duration
        target.totalDistance = source.totalDistance
        target.totalEnergyBurned = source.totalEnergyBurned
        target.averageHeartRate = source.averageHeartRate
        target.maxHeartRate = source.maxHeartRate
        target.isCompleted = true
        target.source = .healthKit
        target.healthKitUUID = source.healthKitUUID
        if let workoutDayId = selectedWorkoutDay?.id {
            target.workoutDayId = workoutDayId
        }

        modelContext.delete(source)
        try? modelContext.save()
        optimisticCardioWorkouts.removeAll { $0.id == source.id || $0.id == target.id }
    }

    private func healthKitLinkLabel(for workout: CardioWorkout) -> String {
        let typeName = HKWorkoutActivityType(rawValue: UInt(workout.activityType))?.displayName
            ?? L10n.tr("unknown")
        var parts: [String] = [typeName]

        if workout.duration > 0 {
            parts.append(workout.formattedDuration)
        }
        if let distance = workout.formattedDistance {
            parts.append(distance)
        }

        return parts.joined(separator: " · ")
    }

    private func deleteCardioWorkout(_ cardio: CardioWorkout) {
        modelContext.delete(cardio)
        try? modelContext.save()
        optimisticCardioWorkouts.removeAll { $0.id == cardio.id }

        if expandedEntryId == cardio.id {
            expandedEntryId = nil
        }
    }

    private func pruneOptimisticCardioWorkouts(using workouts: [CardioWorkout]) {
        let existingIds = Set(workouts.map(\.id))
        optimisticCardioWorkouts.removeAll { existingIds.contains($0.id) }
    }

    @ViewBuilder
    private func displayItemView(
        _ item: WorkoutDisplayItem,
        scrollProxy: ScrollViewProxy
    ) -> some View {
        Group {
            switch item {
            case .group(let group):
                // Use custom swipe implementation for delete functionality in LazyVStack.
                groupSwipeCardView(for: group, scrollProxy: scrollProxy)
            case .entry(let entry):
                entryCardView(for: entry, scrollProxy: scrollProxy, isGrouped: false)
            case .cardio(let cardio):
                cardioCardView(for: cardio)
            }
        }
        .contextMenu {
            // Only show reorder for non-cardio items (cardio is always at the end)
            if displayItems.count > 1 && !item.isCardio {
                Button {
                    toggleReorderMode()
                } label: {
                    Label(L10n.tr("reorder"), systemImage: "arrow.up.arrow.down")
                }
            }
        }
    }

    @ViewBuilder
    private func groupSwipeCardView(
        for group: WorkoutExerciseGroup,
        scrollProxy: ScrollViewProxy
    ) -> some View {
        let deleteButtonWidth: CGFloat = 80
        let deleteButtonHeight: CGFloat = 56
        let offset = groupSwipeOffsets[group.id] ?? 0
        let isSwipeOpen = openGroupSwipeId == group.id

        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                pendingGroupDelete = group
                showGroupDeleteDialog = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red)

                    Image(systemName: "trash.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: deleteButtonWidth, height: deleteButtonHeight)
            }
            .buttonStyle(.plain)

            groupView(for: group, scrollProxy: scrollProxy)
                .offset(x: offset)
                .gesture(groupSwipeGesture(for: group, deleteWidth: deleteButtonWidth))
                .onTapGesture {
                    if isSwipeOpen {
                        closeGroupSwipe(group.id)
                    }
                }
        }
    }

    private func groupSwipeGesture(
        for group: WorkoutExerciseGroup,
        deleteWidth: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                if openGroupSwipeId != nil && openGroupSwipeId != group.id {
                    closeAllGroupSwipes(except: group.id)
                }

                let isSwipeOpen = openGroupSwipeId == group.id
                let translation = value.translation.width

                if isSwipeOpen {
                    // Already open, allow dragging back
                    let newOffset = -deleteWidth + translation
                    groupSwipeOffsets[group.id] = min(0, max(-deleteWidth, newOffset))
                } else {
                    // Only allow left swipe (negative translation)
                    if translation < 0 {
                        groupSwipeOffsets[group.id] = max(-deleteWidth, translation)
                    }
                }
            }
            .onEnded { value in
                let translation = value.translation.width
                let velocity = value.predictedEndTranslation.width - translation
                let isSwipeOpen = openGroupSwipeId == group.id

                withAnimation(.easeOut(duration: 0.2)) {
                    if isSwipeOpen {
                        // If swiping right fast enough or past threshold, close
                        if translation > deleteWidth / 2 || velocity > 50 {
                            groupSwipeOffsets[group.id] = 0
                            openGroupSwipeId = nil
                        } else {
                            groupSwipeOffsets[group.id] = -deleteWidth
                        }
                    } else {
                        // If swiping left fast enough or past threshold, open
                        if translation < -deleteWidth / 2 || velocity < -50 {
                            groupSwipeOffsets[group.id] = -deleteWidth
                            openGroupSwipeId = group.id
                        } else {
                            groupSwipeOffsets[group.id] = 0
                        }
                    }
                }
            }
    }

    private func openGroupSwipe(_ id: UUID, width: CGFloat) {
        withAnimation(.easeOut(duration: 0.2)) {
            groupSwipeOffsets[id] = -width
            openGroupSwipeId = id
        }
        closeAllGroupSwipes(except: id)
    }

    private func closeGroupSwipe(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) {
            groupSwipeOffsets[id] = 0
            if openGroupSwipeId == id {
                openGroupSwipeId = nil
            }
        }
    }

    private func closeAllGroupSwipes(except id: UUID?) {
        for (groupId, _) in groupSwipeOffsets where groupId != id {
            groupSwipeOffsets[groupId] = 0
        }
        if let id, openGroupSwipeId != id {
            openGroupSwipeId = nil
        } else if id == nil {
            openGroupSwipeId = nil
        }
    }

    @ViewBuilder
    private func reorderRowView(_ item: WorkoutDisplayItem) -> some View {
        switch item {
        case .group(let group):
            reorderGroupRowView(group)
        case .entry(let entry):
            reorderEntryRowView(entry)
        case .cardio:
            // Cardio items are not included in reorder mode
            EmptyView()
        }
    }

    private func reorderEntryRowView(_ entry: WorkoutExerciseEntry) -> some View {
        let exerciseName = getExerciseName(for: entry.exerciseId)
        let bodyPartColor = getBodyPartColor(for: entry.exerciseId) ?? AppColors.dotEmpty
        let subtitle = reorderEntrySubtitle(for: entry)

        return HStack(spacing: 10) {
            Circle()
                .fill(bodyPartColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(exerciseName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.divider.opacity(0.6), lineWidth: 0.5)
        )
    }

    private func reorderEntrySubtitle(for entry: WorkoutExerciseEntry) -> String? {
        let completed = entry.completedSetsCount
        let total = entry.activeSets.count

        guard total > 0 else { return nil }

        if completed >= total {
            return L10n.tr("workout_sets_completed", total)
        }

        return L10n.tr("workout_sets_progress", completed, total)
    }

    private func reorderGroupRowView(_ group: WorkoutExerciseGroup) -> some View {
        let exerciseCountText = "\(group.entryCount)\(L10n.tr("exercises_unit"))"
        let roundCountText = L10n.tr("group_set_count", group.setCount)

        return HStack(spacing: 10) {
            Circle()
                .fill(AppColors.mutedBlue)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Text("\(exerciseCountText) · \(roundCountText)")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.divider.opacity(0.6), lineWidth: 0.5)
        )
    }

    /// Updates current input values to match the entry's next incomplete set based on metric type
    private func updateCurrentWeightReps(for entry: WorkoutExerciseEntry) {
        let targetSet = entry.sortedSets.first(where: { !$0.isCompleted }) ?? entry.sortedSets.last

        guard let set = targetSet else { return }

        switch entry.metricType {
        case .weightReps:
            currentWeight = set.weightDouble
            currentReps = set.reps ?? 0
        case .bodyweightReps:
            currentReps = set.reps ?? 0
        case .timeDistance:
            currentDuration = set.durationSeconds ?? 60
            currentDistance = set.distanceMeters
        case .completion:
            break
        }
    }

    private func handleDateTap() {
        // Always return to today's workout
        if !isViewingToday {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = todayWorkoutDate
            }
        }
    }

    private func selectDay(_ dayIndex: Int) {
        guard let weekStart = currentWeekStart,
              let newDate = Calendar.current.date(byAdding: .day, value: dayIndex, to: weekStart) else {
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDate = newDate
        }
    }

    private func cardioState(for date: Date) -> WorkoutDayState {
        let profileId = profile?.id
        // Get the WorkoutDay for this date
        let normalizedDate = DateUtilities.startOfDay(date)
        let linkedWorkoutDayId = workoutDays.first(where: { $0.date == normalizedDate })?.id

        let workouts = allCardioWorkouts.filter { workout in
            // Profile filter
            if let profileId = profileId, workout.profile?.id != profileId {
                return false
            }
            // If linked to a WorkoutDay, use that
            if let linkedId = linkedWorkoutDayId, workout.workoutDayId == linkedId {
                return true
            }
            // If not linked, use date comparison
            return workout.workoutDayId == nil &&
                DateUtilities.isSameDay(workout.startDate, date)
        }

        guard !workouts.isEmpty else { return .none }
        if workouts.allSatisfy({ $0.isCompleted }) {
            return .complete
        }
        return workouts.contains(where: { $0.isCompleted }) ? .incomplete : .none
    }

    /// Computes workout state for each day of the current week
    private func computeWorkoutStates() -> [Int: WorkoutDayState] {
        var states: [Int: WorkoutDayState] = [:]
        let calendar = Calendar.current
        guard let weekStart = currentWeekStart else { return states }

        for dayIndex in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayIndex, to: weekStart) else {
                continue
            }
            let normalizedDate = DateUtilities.startOfDay(date)

            let strengthState: WorkoutDayState
            let strengthHasEntries: Bool
            let strengthHasCompletedSets: Bool
            if let workoutDay = workoutDays.first(where: { $0.date == normalizedDate }) {
                strengthHasEntries = !workoutDay.entries.isEmpty
                strengthHasCompletedSets = workoutDay.totalCompletedSets > 0
                if workoutDay.entries.isEmpty {
                    strengthState = .none
                } else if workoutDay.entries.allSatisfy({ $0.isPlannedSetsCompleted }) {
                    strengthState = .complete
                } else if strengthHasCompletedSets {
                    strengthState = .incomplete
                } else {
                    strengthState = .none
                }
            } else {
                strengthState = .none
                strengthHasEntries = false
                strengthHasCompletedSets = false
            }

            let cardioState = cardioState(for: normalizedDate)

            // Combined state logic
            let finalState: WorkoutDayState
            switch (strengthState, cardioState) {
            case (.incomplete, _), (_, .incomplete):
                // If either is incomplete, the day is incomplete
                finalState = .incomplete
            case (.none, .complete) where strengthHasEntries && !strengthHasCompletedSets:
                // Cardio completed but strength entries exist with no progress: mark incomplete
                finalState = .incomplete
            case (.complete, .complete), (.complete, .none), (.none, .complete):
                // If all existing workouts are complete, the day is complete
                finalState = .complete
            case (.none, .none):
                // No workouts for this day
                finalState = .none
            }
            states[dayIndex] = finalState
        }
        return states
    }

    /// Builds day display info for the header
    private func buildDayDisplayInfo() -> DayDisplayInfo? {
        guard let dayInfo = currentDayContextInfo else { return nil }
        // Can switch: viewing today AND no completed sets AND multi-day plan
        let canSwitch = isViewingToday
            && (selectedWorkoutDay?.totalCompletedSets ?? 0) == 0
            && dayInfo.totalDays > 1
        return DayDisplayInfo(
            currentDayIndex: dayInfo.dayIndex,
            totalDays: dayInfo.totalDays,
            canSwitchDay: canSwitch
        )
    }

    /// Returns the ad index to show after the given item index, or nil if no ad should be shown.
    /// Ads are shown after every 3 exercises (indices 2, 5, 8...), but only when there are 5+ exercises.
    private func shouldShowAd(afterIndex index: Int, displayItemsCount: Int) -> Int? {
        // Don't show inline ads unless there are 5+ exercises (will show at bottom instead)
        guard displayItemsCount >= 5 else { return nil }

        // Show ad after index 2, 5, 8... (every 3rd item, 0-indexed)
        // This means after item at positions 3, 6, 9... in 1-indexed terms
        guard (index + 1) % 3 == 0 else { return nil }

        // Don't show ad too close to the end (keep at least 2 items after the ad)
        guard index <= displayItemsCount - 3 else { return nil }

        // Don't show ad adjacent to expanded card
        if let expandedIndex = expandedEntryIndex {
            let isAdjacentToExpanded = index == expandedIndex - 1 || index == expandedIndex
            if isAdjacentToExpanded { return nil }
        }

        // Calculate which ad to show (0, 1, 2...)
        let adIndex = (index + 1) / 3 - 1
        return adIndex
    }

    /// Returns whether the bottom ad should be shown (always below add exercise button)
    private func shouldShowBottomAd(displayItemsEmpty: Bool) -> Bool {
        guard !(profile?.isPremiumUser ?? false) else { return false }
        guard !displayItemsEmpty else { return false }
        guard !adManager.nativeAds.isEmpty else { return false }
        return true
    }

    /// Returns whether the ad should be shown in empty state
    private var shouldShowEmptyStateAd: Bool {
        guard !(profile?.isPremiumUser ?? false) else { return false }
        guard !adManager.nativeAds.isEmpty else { return false }
        return true
    }

    private func loadActiveCycle() {
        guard let profile = profile else { return }

        // Only load cycle if in cycle mode
        if profile.executionMode == .cycle {
            activeCycle = CycleService.getActiveCycle(profileId: profile.id, modelContext: modelContext)

            if let cycle = activeCycle {
                if isScheduledCyclePending {
                    cycleStateInfo = nil
                } else {
                    cycleStateInfo = CycleService.getCurrentStateInfo(for: cycle, modelContext: modelContext)
                }
            } else {
                cycleStateInfo = nil
            }
        } else {
            // In single mode, clear cycle state
            activeCycle = nil
            cycleStateInfo = nil
        }
    }

    // MARK: - Candidate Building

    private func buildCandidateCollectionForExercise(_ exercise: Exercise) -> CopyCandidateCollection {
        guard let profile = profile else { return .empty }

        // For Workout context, only workout history is available (no plan candidates)
        let workoutCandidates = WorkoutService.getWorkoutHistorySets(
            profileId: profile.id,
            exerciseId: exercise.id,
            limit: 20,
            excludeDate: selectedDate,
            modelContext: modelContext
        )

        return CopyCandidateCollection(
            planCandidates: [],
            workoutCandidates: workoutCandidates
        )
    }

    // MARK: - Day Change

    private func requestDayChange(to newDayIndex: Int) {
        guard canChangeDay else { return }
        pendingDayChange = newDayIndex
        skipCurrentDay = false
        showDayChangeDialog = true
    }

    private func executeDayChange(to newDayIndex: Int, skipAndAdvance: Bool) {
        guard let profile = profile else { return }

        // Get or create WorkoutDay for the selected date
        var workoutDay = selectedWorkoutDay
        if workoutDay == nil {
            // Create a new WorkoutDay for day change
            workoutDay = createWorkoutDayForDayChange(newDayIndex: newDayIndex)
        }

        guard let workoutDay = workoutDay else { return }

        // Store previous state for undo
        let previousRoutineDayId = workoutDay.routineDayId
        let previousEntries = workoutDay.entries.map { entry -> (exerciseId: UUID, orderIndex: Int, sets: [(weight: Decimal?, reps: Int?, isCompleted: Bool)]) in
            let sets = entry.sortedSets.map { ($0.weight, $0.reps, $0.isCompleted) }
            return (entry.exerciseId, entry.orderIndex, sets)
        }

        var success = false

        switch profile.executionMode {
        case .single:
            if let planId = profile.activePlanId {
                success = PlanService.changeDay(
                    profile: profile,
                    workoutDay: workoutDay,
                    planId: planId,
                    to: newDayIndex,
                    skipAndAdvance: skipAndAdvance,
                    modelContext: modelContext
                )
            }
        case .cycle:
            if let cycle = activeCycle {
                success = CycleService.changeDay(
                    cycle: cycle,
                    workoutDay: workoutDay,
                    to: newDayIndex,
                    skipAndAdvance: skipAndAdvance,
                    modelContext: modelContext
                )
            }
        }

        if success {
            // Reload cycle info (day info is computed dynamically)
            loadActiveCycle()

            // Expand the first entry if exists
            if let first = sortedEntries.first {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedEntryId = first.id
                }
                updateCurrentWeightReps(for: first)
            }

            // Show feedback with undo
            showSnackBar(
                message: L10n.tr("day_changed_success", newDayIndex),
                undoAction: { [weak workoutDay] in
                    self.undoDayChange(
                        workoutDay: workoutDay,
                        previousRoutineDayId: previousRoutineDayId,
                        previousEntries: previousEntries,
                        skipAndAdvance: skipAndAdvance,
                        previousDayIndex: currentDayContextInfo?.dayIndex ?? 1
                    )
                }
            )
        }
    }

    /// Creates a new WorkoutDay for the selected date when changing days
    private func createWorkoutDayForDayChange(newDayIndex: Int) -> WorkoutDay? {
        guard let profile = profile,
              let dayInfo = currentDayContextInfo,
              let planId = dayInfo.planId else {
            return nil
        }

        // Get the plan and new day
        guard let plan = PlanService.getPlan(id: planId, modelContext: modelContext),
              let newPlanDay = plan.day(at: newDayIndex) else {
            return nil
        }

        // Create new workout day
        let workoutDay = WorkoutDay(profileId: profile.id, date: selectedWorkoutDate)
        workoutDay.mode = .routine
        workoutDay.routinePresetId = planId
        workoutDay.routineDayId = newPlanDay.id
        modelContext.insert(workoutDay)

        return workoutDay
    }

    /// Undoes a day change
    private func undoDayChange(
        workoutDay: WorkoutDay?,
        previousRoutineDayId: UUID?,
        previousEntries: [(exerciseId: UUID, orderIndex: Int, sets: [(weight: Decimal?, reps: Int?, isCompleted: Bool)])],
        skipAndAdvance: Bool,
        previousDayIndex: Int
    ) {
        guard let workoutDay = workoutDay,
              let profile = profile else { return }

        // Restore routineDayId
        workoutDay.routineDayId = previousRoutineDayId

        // Clear current entries
        for entry in workoutDay.entries {
            modelContext.delete(entry)
        }
        workoutDay.entries.removeAll()

        // Restore previous entries
        for prevEntry in previousEntries {
            let entry = WorkoutExerciseEntry(
                exerciseId: prevEntry.exerciseId,
                orderIndex: prevEntry.orderIndex,
                source: .routine,
                plannedSetCount: prevEntry.sets.count
            )

            for (index, setData) in prevEntry.sets.enumerated() {
                let set = WorkoutSet(
                    setIndex: index + 1,
                    weight: setData.weight,
                    reps: setData.reps,
                    isCompleted: setData.isCompleted
                )
                entry.addSet(set)
            }

            workoutDay.addEntry(entry)
        }

        // Revert progress pointer if skipAndAdvance was true
        if skipAndAdvance {
            switch profile.executionMode {
            case .single:
                if let planId = profile.activePlanId {
                    let progress = PlanService.getOrCreateProgress(
                        profileId: profile.id,
                        planId: planId,
                        modelContext: modelContext
                    )
                    progress.currentDayIndex = previousDayIndex
                }
            case .cycle:
                if let cycle = activeCycle,
                   let progress = cycle.progress {
                    progress.currentDayIndex = previousDayIndex - 1 // Convert to 0-indexed
                }
            }
        }

        // Reload cycle state (day info is computed dynamically)
        loadActiveCycle()

        // Expand first entry
        if let first = sortedEntries.first {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedEntryId = first.id
            }
            updateCurrentWeightReps(for: first)
        }
    }

    /// Rescues a past day by creating a workout from the selected plan day
    private func rescuePastDay(planId: UUID, dayIndex: Int) {
        guard let profile = profile,
              let plan = PlanService.getPlan(id: planId, modelContext: modelContext) else {
            return
        }

        let sortedDays = plan.sortedDays
        guard dayIndex > 0, dayIndex <= sortedDays.count else { return }

        let planDay = sortedDays[dayIndex - 1]

        // Create new WorkoutDay for the selected past date
        let workoutDay = WorkoutDay(profileId: profile.id, date: selectedWorkoutDate)
        workoutDay.mode = .routine
        workoutDay.routinePresetId = planId
        workoutDay.routineDayId = planDay.id
        modelContext.insert(workoutDay)

        // Expand plan to workout
        PlanService.expandPlanToWorkout(planDay: planDay, workoutDay: workoutDay, modelContext: modelContext)

        try? modelContext.save()

        // Reload UI - force refresh by resetting and re-setting date
        let currentDate = selectedDate
        selectedDate = currentDate

        // Expand first entry
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let first = sortedEntries.first {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedEntryId = first.id
                }
                updateCurrentWeightReps(for: first)
            }
        }
    }

    private func recordFromPlan() {
        if activePlan != nil, shouldShowEmptyState {
            rescueDayIndex = 0
            showPastDayRescuePicker = true
            return
        }

        if isViewingToday {
            ensureTodayWorkout()
            let currentDate = selectedDate
            selectedDate = currentDate
        }
    }

    private func completeAndAdvanceCycle() {
        guard let cycle = activeCycle else { return }

        // Mark progress as completed
        cycle.progress?.markCompleted()

        // Advance to next day/plan
        CycleService.advance(cycle: cycle, modelContext: modelContext)

        // Update state info
        cycleStateInfo = CycleService.getCurrentStateInfo(for: cycle, modelContext: modelContext)

        // Show feedback
        showSnackBar(
            message: L10n.tr("workout_advanced_to_next"),
            undoAction: {
                // Note: undo would require storing previous state, simplified here
            }
        )
    }

    private func ensureTodayWorkout() {
        guard let profile = profile else { return }

        let workoutDate = todayWorkoutDate

        // Branch based on execution mode
        switch profile.executionMode {
        case .cycle:
            if let cycle = activeCycle {
                if applyScheduledCycleIfNeeded(profile: profile, cycle: cycle, workoutDate: workoutDate) {
                    return
                }
                if isScheduledCyclePending {
                    break
                }
            }

            // Check if we need to auto-advance the cycle
            checkAndAutoAdvanceCycle(workoutDate: workoutDate)

            // Setup from active cycle
            if let cycle = activeCycle,
               let (plan, planDay) = CycleService.getCurrentPlanDay(for: cycle, modelContext: modelContext) {
                setupWorkoutFromCycle(plan: plan, planDay: planDay, workoutDate: workoutDate)
                return
            }

        case .single:
            // Setup from active plan in single mode
            if let activePlanId = profile.activePlanId {
                let didCarryOver = moveIncompleteRoutineWorkoutToToday(
                    planId: activePlanId,
                    workoutDate: workoutDate
                )
                if didCarryOver {
                    return
                }
                if applyScheduledPlanIfNeeded(profile: profile, planId: activePlanId, workoutDate: workoutDate) {
                    return
                }
                if isScheduledPlanPending {
                    break
                }
                setupWorkoutFromSinglePlan(planId: activePlanId, workoutDate: workoutDate)
                return
            }
        }

        // Fall back - create empty workout day if none exists
        let todayWorkout = workoutDays.first { DateUtilities.isSameDay($0.date, workoutDate) }
        if todayWorkout == nil {
            let workoutDay = WorkoutDay(profileId: profile.id, date: workoutDate)
            modelContext.insert(workoutDay)
        }
    }

    private func moveIncompleteRoutineWorkoutToToday(planId: UUID, workoutDate: Date) -> Bool {
        let todayWorkout = workoutDays.first(where: { DateUtilities.isSameDay($0.date, workoutDate) })

        guard let candidate = workoutDays.first(where: { workoutDay in
            workoutDay.date < workoutDate
                && workoutDay.mode == .routine
                && workoutDay.routinePresetId == planId
                && workoutDay.routineDayId != nil
                && !hasAnyCompletedActivity(for: workoutDay)
        }) else {
            return false
        }

        if let todayWorkout {
            guard todayWorkout.mode == .routine,
                  todayWorkout.routinePresetId == planId,
                  !hasAnyCompletedActivity(for: todayWorkout) else {
                return false
            }
            deleteCardioWorkouts(for: todayWorkout)
            modelContext.delete(todayWorkout)
        }

        candidate.date = workoutDate
        candidate.touch()
        return true
    }

    private func hasAnyCompletedActivity(for workoutDay: WorkoutDay) -> Bool {
        if workoutDay.totalCompletedSets > 0 {
            return true
        }

        let workoutDayId = workoutDay.id
        let descriptor = FetchDescriptor<CardioWorkout>(
            predicate: #Predicate<CardioWorkout> { workout in
                workout.workoutDayId == workoutDayId && workout.isCompleted == true
            }
        )
        let completedCardio = (try? modelContext.fetch(descriptor)) ?? []
        return !completedCardio.isEmpty
    }

    private func deleteCardioWorkouts(for workoutDay: WorkoutDay) {
        let workoutDayId = workoutDay.id
        let descriptor = FetchDescriptor<CardioWorkout>(
            predicate: #Predicate<CardioWorkout> { workout in
                workout.workoutDayId == workoutDayId
            }
        )
        if let workouts = try? modelContext.fetch(descriptor) {
            for workout in workouts {
                modelContext.delete(workout)
            }
        }
    }

    private func applyScheduledPlanIfNeeded(
        profile: LocalProfile,
        planId: UUID,
        workoutDate: Date
    ) -> Bool {
        guard let scheduledDate = profile.scheduledPlanStartDate,
              let scheduledDayIndex = profile.scheduledPlanStartDayIndex,
              let scheduledPlanId = profile.scheduledPlanId,
              scheduledPlanId == planId else {
            return false
        }

        if scheduledDate > workoutDate {
            return false
        }

        guard let plan = PlanService.getPlan(id: planId, modelContext: modelContext) else {
            return false
        }

        let progress = PlanService.getOrCreateProgress(
            profileId: profile.id,
            planId: planId,
            modelContext: modelContext
        )
        progress.currentDayIndex = scheduledDayIndex
        progress.lastOpenedDate = workoutDate

        _ = PlanService.applyPlanToday(
            profile: profile,
            plan: plan,
            dayIndex: scheduledDayIndex,
            modelContext: modelContext
        )

        profile.scheduledPlanStartDate = nil
        profile.scheduledPlanStartDayIndex = nil
        profile.scheduledPlanId = nil
        try? modelContext.save()

        return true
    }

    private func applyScheduledCycleIfNeeded(
        profile: LocalProfile,
        cycle: PlanCycle,
        workoutDate: Date
    ) -> Bool {
        guard let scheduledDate = profile.scheduledCycleStartDate,
              let scheduledPlanIndex = profile.scheduledCyclePlanIndex,
              let scheduledDayIndex = profile.scheduledCycleDayIndex,
              let scheduledCycleId = profile.scheduledCycleId,
              scheduledCycleId == cycle.id else {
            return false
        }

        if scheduledDate > workoutDate {
            return false
        }

        let items = cycle.sortedItems
        if scheduledPlanIndex >= items.count {
            profile.scheduledCycleStartDate = nil
            profile.scheduledCyclePlanIndex = nil
            profile.scheduledCycleDayIndex = nil
            profile.scheduledCycleId = nil
            try? modelContext.save()
            return false
        }

        CycleService.loadPlans(for: items, modelContext: modelContext)
        guard let plan = items[scheduledPlanIndex].plan else { return false }

        let sortedDays = plan.sortedDays
        if scheduledDayIndex >= sortedDays.count {
            profile.scheduledCycleStartDate = nil
            profile.scheduledCyclePlanIndex = nil
            profile.scheduledCycleDayIndex = nil
            profile.scheduledCycleId = nil
            try? modelContext.save()
            return false
        }

        let planDay = sortedDays[scheduledDayIndex]

        if let progress = cycle.progress {
            progress.currentItemIndex = scheduledPlanIndex
            progress.currentDayIndex = scheduledDayIndex
            progress.lastAdvancedAt = Date()
        }

        let workoutDay = WorkoutService.getOrCreateWorkoutDay(
            profileId: profile.id,
            date: workoutDate,
            mode: .routine,
            routinePresetId: plan.id,
            routineDayId: planDay.id,
            modelContext: modelContext
        )

        // Clear existing entries
        for entry in workoutDay.entries {
            modelContext.delete(entry)
        }
        workoutDay.entries.removeAll()

        // Set mode and routine info
        workoutDay.mode = .routine
        workoutDay.routinePresetId = plan.id
        workoutDay.routineDayId = planDay.id

        // Expand plan to workout
        PlanService.expandPlanToWorkout(planDay: planDay, workoutDay: workoutDay, modelContext: modelContext)

        profile.scheduledCycleStartDate = nil
        profile.scheduledCyclePlanIndex = nil
        profile.scheduledCycleDayIndex = nil
        profile.scheduledCycleId = nil
        cycleStateInfo = CycleService.getCurrentStateInfo(for: cycle, modelContext: modelContext)
        try? modelContext.save()

        return true
    }

    private func setupWorkoutFromSinglePlan(planId: UUID, workoutDate: Date) {
        guard let profile = profile else { return }

        // Use PlanService to setup today's workout (it handles plan lookup internally)
        _ = PlanService.setupTodayWorkout(
            profile: profile,
            workoutDate: workoutDate,
            modelContext: modelContext
        )
    }

    /// Checks if the cycle should be auto-advanced based on the last workout date
    private func checkAndAutoAdvanceCycle(workoutDate: Date) {
        guard let cycle = activeCycle,
              let progress = cycle.progress else { return }

        // If last completed date exists and is different from today's workout date,
        // and the workout was completed, we should auto-advance
        if let lastCompleted = progress.lastCompletedAt {
            let lastWorkoutDate = DateUtilities.workoutDate(for: lastCompleted, transitionHour: transitionHour)

            // If different workout day and already completed
            if !DateUtilities.isSameDay(lastWorkoutDate, workoutDate) {
                // Prevent double-advancement within the same workout day.
                if let lastAdvancedAt = progress.lastAdvancedAt {
                    let lastAdvancedWorkoutDate = DateUtilities.workoutDate(for: lastAdvancedAt, transitionHour: transitionHour)
                    if DateUtilities.isSameDay(lastAdvancedWorkoutDate, workoutDate) {
                        return
                    }
                }
                // Auto-advance to next day
                CycleService.advance(cycle: cycle, modelContext: modelContext)
                cycleStateInfo = CycleService.getCurrentStateInfo(for: cycle, modelContext: modelContext)
            }
        }

        // If the current cycle day is a rest day, auto-advance once per workout day.
        if let (_, planDay) = CycleService.getCurrentPlanDay(for: cycle, modelContext: modelContext),
           planDay.isRestDay {
            if let lastAdvancedAt = progress.lastAdvancedAt {
                let lastAdvancedWorkoutDate = DateUtilities.workoutDate(for: lastAdvancedAt, transitionHour: transitionHour)
                if !DateUtilities.isSameDay(lastAdvancedWorkoutDate, workoutDate) {
                    CycleService.advance(cycle: cycle, modelContext: modelContext)
                    cycleStateInfo = CycleService.getCurrentStateInfo(for: cycle, modelContext: modelContext)
                }
            } else if let lastCompletedAt = progress.lastCompletedAt {
                let lastCompletedWorkoutDate = DateUtilities.workoutDate(for: lastCompletedAt, transitionHour: transitionHour)
                if let daysDiff = DateUtilities.daysBetween(lastCompletedWorkoutDate, and: workoutDate), daysDiff >= 2 {
                    // Rest day was skipped; advance once.
                    CycleService.advance(cycle: cycle, modelContext: modelContext)
                    cycleStateInfo = CycleService.getCurrentStateInfo(for: cycle, modelContext: modelContext)
                } else {
                    // First rest day open after completion; record to avoid same-day auto-advance.
                    progress.lastAdvancedAt = workoutDate
                    try? modelContext.save()
                }
            } else {
                // No completion yet; record to avoid same-day auto-advance.
                progress.lastAdvancedAt = workoutDate
                try? modelContext.save()
            }
        }
    }

    private func setupWorkoutFromCycle(plan: WorkoutPlan, planDay: PlanDay, workoutDate: Date) {
        guard let profile = profile else { return }

        // Check if workout already exists for today's workout date
        if let existingWorkout = workoutDays.first(where: { DateUtilities.isSameDay($0.date, workoutDate) }) {
            // If it's already set up for this plan day, do nothing
            if existingWorkout.routineDayId == planDay.id && existingWorkout.routinePresetId == plan.id {
                return
            }

            // If the workout is empty and not linked to any plan, set it up for the cycle
            if existingWorkout.entries.isEmpty && existingWorkout.routinePresetId == nil {
                existingWorkout.mode = .routine
                existingWorkout.routinePresetId = plan.id
                existingWorkout.routineDayId = planDay.id
                PlanService.expandPlanToWorkout(planDay: planDay, workoutDay: existingWorkout, modelContext: modelContext)
                return
            }

            // Otherwise, keep existing workout (has entries or linked to different plan)
            return
        }

        // Create new workout day in plan mode
        let workoutDay = WorkoutService.getOrCreateWorkoutDay(
            profileId: profile.id,
            date: workoutDate,
            mode: .routine,
            routinePresetId: plan.id,
            routineDayId: planDay.id,
            modelContext: modelContext
        )

        // Expand plan to workout if no entries yet
        if workoutDay.entries.isEmpty {
            PlanService.expandPlanToWorkout(planDay: planDay, workoutDay: workoutDay, modelContext: modelContext)
        }
    }

    /// Changes the exercise for a given entry
    private func changeExercise(entryId: UUID, to exercise: Exercise) {
        guard let entry = sortedEntries.first(where: { $0.id == entryId }) else { return }
        entry.exerciseId = exercise.id
        // Sync changes to Watch (today only; guarded inside sendWorkoutDataToWatch()).
        sendWorkoutDataToWatch()
    }

    /// Adds a selected exercise to the current workout with specified sets
    private func addExerciseToWorkout(_ exercise: Exercise, withSets sets: [SetInputData]) {
        guard let profile = profile else { return }
        guard !sets.isEmpty else { return }

        let workoutDate = selectedWorkoutDate

        // Create workout day if needed
        var workoutDay = selectedWorkoutDay
        if workoutDay == nil {
            let newWorkoutDay = WorkoutDay(profileId: profile.id, date: workoutDate)
            modelContext.insert(newWorkoutDay)
            workoutDay = newWorkoutDay
        }

        guard let workoutDay = workoutDay else { return }

        // Determine metric type from first set
        let metricType = sets.first?.metricType ?? exercise.defaultMetricType

        // Get next order index
        let nextOrder = (workoutDay.entries.map(\.orderIndex).max() ?? -1) + 1

        // Create entry with the specified sets
        let entry = WorkoutExerciseEntry(
            exerciseId: exercise.id,
            orderIndex: nextOrder,
            metricType: metricType,
            source: .free,
            plannedSetCount: sets.count
        )

        // Add all sets as incomplete
        for (index, setData) in sets.enumerated() {
            let set = WorkoutSet(
                setIndex: index + 1,
                metricType: setData.metricType,
                weight: setData.weight.map { Decimal($0) },
                reps: setData.reps,
                durationSeconds: setData.durationSeconds,
                distanceMeters: setData.distanceMeters,
                restTimeSeconds: setData.restTimeSeconds,
                isCompleted: false
            )
            entry.addSet(set)
        }

        workoutDay.addEntry(entry)

        // Update current values to match first set based on metric type
        if let firstSet = sets.first {
            switch firstSet.metricType {
            case .weightReps:
                if let weight = firstSet.weight {
                    currentWeight = weight
                }
                if let reps = firstSet.reps {
                    currentReps = reps
                }
            case .bodyweightReps:
                if let reps = firstSet.reps {
                    currentReps = reps
                }
            case .timeDistance:
                if let duration = firstSet.durationSeconds {
                    currentDuration = duration
                }
                currentDistance = firstSet.distanceMeters
            case .completion:
                break
            }
        }

        // Expand the newly added entry
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedEntryId = entry.id
        }

        // Sync new exercise to Watch immediately.
        sendWorkoutDataToWatch()
    }

    private func addCardioWorkout(
        _ exercise: Exercise,
        durationSeconds: Int,
        distanceMeters: Double?
    ) {
        guard let profile = profile else { return }

        let workoutDate = selectedWorkoutDate

        // Create workout day if needed
        var workoutDay = selectedWorkoutDay
        if workoutDay == nil {
            let newWorkoutDay = WorkoutDay(profileId: profile.id, date: workoutDate)
            modelContext.insert(newWorkoutDay)
            workoutDay = newWorkoutDay
        }

        guard let workoutDay = workoutDay else { return }

        let activityType = CardioActivityTypeResolver.activityType(for: exercise)
        let orderIndex = nextCardioOrderIndex(for: workoutDay.id)
        let totalDistance = (distanceMeters ?? 0) > 0 ? distanceMeters : nil
        let cardioWorkout = CardioWorkout(
            activityType: Int(activityType.rawValue),
            startDate: workoutDay.date,
            duration: Double(durationSeconds),
            totalDistance: totalDistance,
            isCompleted: false,
            workoutDayId: workoutDay.id,
            orderIndex: orderIndex,
            source: .manual,
            profile: profile
        )

        modelContext.insert(cardioWorkout)
        try? modelContext.save()
        optimisticCardioWorkouts.append(cardioWorkout)

        withAnimation(.easeInOut(duration: 0.2)) {
            expandedEntryId = cardioWorkout.id
        }

        // If Watch is showing today's workout, keep it in sync.
        // (Cardio itself isn't currently part of the Watch payload, but this keeps the sync behavior consistent.)
        sendWorkoutDataToWatch()
    }

    private func nextCardioOrderIndex(for workoutDayId: UUID) -> Int {
        let descriptor = FetchDescriptor<CardioWorkout>(
            predicate: #Predicate<CardioWorkout> { $0.workoutDayId == workoutDayId },
            sortBy: [SortDescriptor(\.orderIndex, order: .reverse)]
        )
        let maxExisting = (try? modelContext.fetch(descriptor).first?.orderIndex) ?? -1
        return maxExisting + 1
    }

    private func addSet(to entry: WorkoutExerciseEntry) {
        _ = entry.createSet(weight: Decimal(currentWeight), reps: currentReps, isCompleted: false)
        // Sync set count/values to Watch.
        sendWorkoutDataToWatch()
    }

    /// Copies exercises from the most recent workout to today
    private func copyPreviousWorkout() {
        guard let profile = profile,
              let previousDay = lastWorkoutDay else { return }

        let workoutDate = selectedWorkoutDate

        // Get or create today's workout
        var workoutDay = selectedWorkoutDay
        if workoutDay == nil {
            let newWorkoutDay = WorkoutDay(profileId: profile.id, date: workoutDate)
            modelContext.insert(newWorkoutDay)
            workoutDay = newWorkoutDay
        }

        guard let workoutDay = workoutDay else { return }

        // Copy groups first to preserve grouping structure
        let previousGroups = previousDay.exerciseGroups.sorted { $0.orderIndex < $1.orderIndex }
        var groupMap: [UUID: WorkoutExerciseGroup] = [:]
        for previousGroup in previousGroups {
            let newGroup = WorkoutExerciseGroup(
                orderIndex: previousGroup.orderIndex,
                setCount: previousGroup.setCount,
                roundRestSeconds: previousGroup.roundRestSeconds
            )
            workoutDay.exerciseGroups.append(newGroup)
            modelContext.insert(newGroup)
            groupMap[previousGroup.id] = newGroup
        }

        // Copy each entry from previous workout
        let previousEntries = previousDay.sortedEntries
        for previousEntry in previousEntries {
            let newEntry = WorkoutExerciseEntry(
                exerciseId: previousEntry.exerciseId,
                orderIndex: previousEntry.orderIndex,
                source: .free,
                plannedSetCount: previousEntry.activeSets.count
            )

            // Copy sets (as incomplete)
            for previousSet in previousEntry.sortedSets {
                let newSet = WorkoutSet(
                    setIndex: previousSet.setIndex,
                    weight: previousSet.weight,
                    reps: previousSet.reps,
                    isCompleted: false
                )
                newEntry.addSet(newSet)
            }

            workoutDay.addEntry(newEntry)

            if let previousGroup = previousEntry.group,
               let newGroup = groupMap[previousGroup.id] {
                GroupService.addEntryToGroup(
                    newEntry,
                    group: newGroup,
                    groupOrderIndex: previousEntry.groupOrderIndex ?? 0
                )
            }
        }

        // Copy cardio workouts (exclude HealthKit imports)
        let previousCardioWorkouts = allCardioWorkouts
            .filter { $0.workoutDayId == previousDay.id && $0.source != .healthKit }
            .sorted { $0.orderIndex < $1.orderIndex }
        if !previousCardioWorkouts.isEmpty {
            var nextOrderIndex = nextCardioOrderIndex(for: workoutDay.id)
            for previousCardio in previousCardioWorkouts {
                let cardioWorkout = CardioWorkout(
                    activityType: previousCardio.activityType,
                    startDate: workoutDay.date,
                    duration: previousCardio.duration,
                    totalDistance: previousCardio.totalDistance,
                    totalEnergyBurned: previousCardio.totalEnergyBurned,
                    averageHeartRate: previousCardio.averageHeartRate,
                    maxHeartRate: previousCardio.maxHeartRate,
                    isCompleted: false,
                    workoutDayId: workoutDay.id,
                    orderIndex: nextOrderIndex,
                    source: previousCardio.source,
                    profile: profile
                )
                nextOrderIndex += 1
                modelContext.insert(cardioWorkout)
            }
        }

        // Expand the first entry
        if let firstEntry = workoutDay.sortedEntries.first {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedEntryId = firstEntry.id
            }

            // Update current weight/reps from first set
            if let firstSet = firstEntry.sortedSets.first {
                currentWeight = firstSet.weightDouble
                currentReps = firstSet.reps ?? 0
            }
        }
    }

    @discardableResult
    private func logSet(for entry: WorkoutExerciseEntry, scrollProxy: ScrollViewProxy) -> Bool {
        guard let nextSet = entry.sortedSets.first(where: { !$0.isCompleted }) else { return false }
        let group = entry.group
        let previousGroupRoundsCompleted = group?.roundsCompleted ?? 0

        // Validate input before logging
        guard WorkoutService.validateSetInput(
            metricType: entry.metricType,
            weight: currentWeight,
            reps: currentReps,
            durationSeconds: currentDuration,
            distanceMeters: currentDistance
        ) else {
            showSnackBar(
                message: L10n.tr("workout_invalid_input"),
                undoAction: {}
            )
            return false
        }

        // Update set values based on metric type
        switch entry.metricType {
        case .weightReps:
            nextSet.weight = Decimal(currentWeight)
            nextSet.reps = currentReps
        case .bodyweightReps:
            nextSet.reps = currentReps
        case .timeDistance:
            nextSet.durationSeconds = currentDuration
            nextSet.distanceMeters = currentDistance
        case .completion:
            break
        }
        nextSet.complete()

        // Check if all sets for this entry are now completed
        let allSetsCompleted = entry.sortedSets.allSatisfy { $0.isCompleted }

        if let group = group {
            // Start rest timer when a round completes
            if group.roundsCompleted > previousGroupRoundsCompleted,
               let restSeconds = group.roundRestSeconds,
               restSeconds > 0 {
                let detail = nextGroupRoundNotificationDetail(group: group)
                handleManualTimerStart(duration: restSeconds, notificationDetail: detail)
            }

            if let nextEntry = GroupService.getNextEntryInGroup(after: entry, in: group) {
                // Update weight/reps to next entry's first incomplete set
                updateCurrentWeightReps(for: nextEntry)
                if nextEntry.id != entry.id {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            expandedEntryId = nextEntry.id
                        }
                    }
                }
            } else if let nextEntry = sortedEntries.first(where: { !$0.isPlannedSetsCompleted && $0.id != entry.id }) {
                // Group is complete, move to next incomplete entry
                updateCurrentWeightReps(for: nextEntry)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        expandedEntryId = nextEntry.id
                    }
                }
            }
        } else {
            if allSetsCompleted {
                // Find the next incomplete entry
                if let nextEntry = sortedEntries.first(where: { !$0.isPlannedSetsCompleted && $0.id != entry.id }) {
                    // Update weight/reps to next entry's first incomplete set
                    updateCurrentWeightReps(for: nextEntry)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            expandedEntryId = nextEntry.id
                        }
                    }
                }
            } else {
                // Update weight/reps to next incomplete set in current entry
                updateCurrentWeightReps(for: entry)
            }
        }

        if allSetsCompleted {
            handlePlanUpdateIfNeeded(for: entry)
        }

        // Check if the entire routine is now completed and update progress
        checkAndUpdateProgress()

        // Combination mode: auto-start timer after logging set (ungrouped only)
        if group == nil {
            // Skip timer if this was the final set and skipRestTimerOnFinalSet is enabled
            let shouldSkipFinalSet = (profile?.skipRestTimerOnFinalSet ?? true) && allSetsCompleted
            if !shouldSkipFinalSet {
                let detail = nextSetNotificationDetail(afterLoggingEntry: entry, allSetsCompleted: allSetsCompleted)
                handleCombinationModeTimer(restTimeSeconds: nextSet.restTimeSeconds, notificationDetail: detail)
            }
        }

        // Send updated data to Watch
        sendWorkoutDataToWatch()

        return true
    }

    @discardableResult
    private func logGroupRound(for group: WorkoutExerciseGroup) -> Bool {
        guard !group.isAllRoundsComplete else { return false }

        let previousActiveRoundIndex = max(0, group.activeRound - 1)
        let previousRoundsCompleted = group.roundsCompleted
        var pendingSets: [(WorkoutExerciseEntry, WorkoutSet)] = []

        for entry in group.sortedEntries {
            guard let nextSet = entry.sortedSets.first(where: { !$0.isCompleted }) else {
                return false
            }

            let weightValue = nextSet.weightDouble
            let repsValue = nextSet.reps ?? 0
            let durationValue = nextSet.durationSeconds ?? 0
            let distanceValue = nextSet.distanceMeters

            guard WorkoutService.validateSetInput(
                metricType: nextSet.metricType,
                weight: weightValue,
                reps: repsValue,
                durationSeconds: durationValue,
                distanceMeters: distanceValue
            ) else {
                showSnackBar(
                    message: L10n.tr("workout_invalid_input"),
                    undoAction: {}
                )
                return false
            }

            pendingSets.append((entry, nextSet))
        }

        for (entry, set) in pendingSets {
            set.complete()
            if entry.isPlannedSetsCompleted {
                handlePlanUpdateIfNeeded(for: entry)
            }
        }

        let newActiveRoundIndex = max(0, group.activeRound - 1)
        if selectedGroupRoundIndex[group.id] == nil || selectedGroupRoundIndex[group.id] == previousActiveRoundIndex {
            selectedGroupRoundIndex[group.id] = newActiveRoundIndex
        }

        checkAndUpdateProgress()

        // Send updated data to Watch
        sendWorkoutDataToWatch()

        return true
    }

    private func canUncompleteGroupRound(_ group: WorkoutExerciseGroup, roundIndex: Int) -> Bool {
        guard roundIndex >= 0 else { return false }
        guard group.roundsCompleted - 1 == roundIndex else { return false }

        // Only allow if the selected round is the last completed for every entry.
        // (Mirrors "only last completed set can be uncompleted" rule.)
        for entry in group.sortedEntries {
            let sets = entry.sortedSets
            guard roundIndex < sets.count else { return false }
            guard sets[roundIndex].isCompleted else { return false }
            guard entry.completedSetsCount == roundIndex + 1 else { return false }
        }
        return true
    }

    @discardableResult
    private func uncompleteGroupRound(for group: WorkoutExerciseGroup, roundIndex: Int) -> Bool {
        guard canUncompleteGroupRound(group, roundIndex: roundIndex) else { return false }

        // Uncomplete the round across all entries.
        for entry in group.sortedEntries {
            let set = entry.sortedSets[roundIndex]
            uncompleteSet(set)
        }

        // Keep the selection on the now-active round.
        selectedGroupRoundIndex[group.id] = max(0, min(roundIndex, max(group.setCount - 1, 0)))

        // Send updated data to Watch (in addition to per-set uncomplete messages).
        sendWorkoutDataToWatch()

        return true
    }

    /// Updates a completed set with new values.
    /// - Parameter set: The completed set to update.
    /// - Returns: true if update succeeded, false if validation failed.
    @discardableResult
    private func updateCompletedSet(_ set: WorkoutSet) -> Bool {
        // Use set.metricType (not entry.metricType) to support mixed sets
        guard WorkoutService.validateSetInput(
            metricType: set.metricType,
            weight: currentWeight,
            reps: currentReps,
            durationSeconds: currentDuration,
            distanceMeters: currentDistance
        ) else {
            showSnackBar(
                message: L10n.tr("workout_invalid_input"),
                undoAction: {}
            )
            return false
        }

        switch set.metricType {
        case .weightReps:
            set.update(weightDouble: currentWeight, reps: currentReps)
        case .bodyweightReps:
            set.update(reps: currentReps)
        case .timeDistance:
            set.durationSeconds = currentDuration
            set.distanceMeters = currentDistance
        case .completion:
            break
        }

        try? modelContext.save()

        // Send updated data to Watch
        sendWorkoutDataToWatch()

        return true
    }

    /// Applies current input values to an incomplete set without completing it.
    /// - Parameter set: The active (incomplete) set to update.
    /// - Returns: true if update succeeded, false if validation failed.
    @discardableResult
    private func applyPendingSetValues(_ set: WorkoutSet) -> Bool {
        guard !set.isCompleted else { return false }

        guard WorkoutService.validateSetInput(
            metricType: set.metricType,
            weight: currentWeight,
            reps: currentReps,
            durationSeconds: currentDuration,
            distanceMeters: currentDistance
        ) else {
            showSnackBar(
                message: L10n.tr("workout_invalid_input"),
                undoAction: {}
            )
            return false
        }

        switch set.metricType {
        case .weightReps:
            set.update(weightDouble: currentWeight, reps: currentReps)
        case .bodyweightReps:
            set.update(reps: currentReps)
        case .timeDistance:
            set.durationSeconds = currentDuration
            set.distanceMeters = currentDistance
        case .completion:
            break
        }

        try? modelContext.save()

        // Sync updated set values to Watch.
        sendWorkoutDataToWatch()

        return true
    }

    /// Checks if the routine is completed and updates progress tracking
    private func checkAndUpdateProgress() {
        guard let workoutDay = selectedWorkoutDay,
              workoutDay.isRoutineCompleted,
              let planId = workoutDay.routinePresetId,
              let profile = profile else {
            return
        }

        switch profile.executionMode {
        case .single:
            // Only update if this is the active plan
            if planId == profile.activePlanId {
                PlanService.markPlanDayCompleted(
                    profileId: profile.id,
                    planId: planId,
                    completionDate: selectedWorkoutDate,
                    modelContext: modelContext
                )
            }
        case .cycle:
            // Update cycle progress
            if let cycle = activeCycle {
                CycleService.markCycleDayCompleted(
                    cycle: cycle,
                    completionDate: selectedWorkoutDate,
                    modelContext: modelContext
                )
                // Reload cycle state info
                cycleStateInfo = CycleService.getCurrentStateInfo(for: cycle, modelContext: modelContext)
            }
        }
    }

    // MARK: - Rest Timer Handling

    /// Handles manual timer start from exercise card button
    private func handleManualTimerStart(duration: Int, notificationDetail: String? = nil) {
        guard duration > 0 else { return }

        // Check if should show combination announcement (first manual timer start)
        if let profile = profile,
           !profile.hasShownCombinationAnnouncement && !profile.combineRecordAndTimerStart {
            pendingTimerDuration = duration
            combinationDontShowAgain = false
            showCombinationAnnouncement = true
            return
        }

        // Check for conflict
        if restTimer.isRunning {
            pendingTimerDuration = duration
            showTimerConflictAlert = true
        } else {
            _ = restTimer.start(
                duration: duration,
                notificationDetail: notificationDetail ?? currentNextSetNotificationDetail()
            )
        }
    }

    /// Handles combination mode timer start after logging a set
    private func handleCombinationModeTimer(restTimeSeconds: Int?, notificationDetail: String? = nil) {
        guard let profile = profile,
              profile.combineRecordAndTimerStart else {
            return
        }

        // Use set's rest time or fall back to default
        let restTime = restTimeSeconds ?? profile.defaultRestTimeSeconds
        guard restTime > 0 else {
            return
        }

        // Check for conflict
        if restTimer.isRunning {
            pendingTimerDuration = restTime
            showTimerConflictAlert = true
        } else {
            _ = restTimer.start(duration: restTime, notificationDetail: notificationDetail ?? currentNextSetNotificationDetail())
        }
    }

    /// Starts the timer after user enables combination mode from announcement
    private func startTimerAfterEnablingCombination() {
        if pendingTimerDuration > 0 {
            _ = restTimer.start(duration: pendingTimerDuration, notificationDetail: currentNextSetNotificationDetail())
            pendingTimerDuration = 0
        }
    }

    private func currentNextSetNotificationDetail() -> String? {
        let weightUnit = profile?.effectiveWeightUnit ?? .kg

        if let expandedId = expandedEntryId,
           let entry = sortedEntries.first(where: { $0.id == expandedId }),
           let set = entry.sortedSets.first(where: { !$0.isCompleted }) {
            return formatNextSetNotificationDetail(entry: entry, set: set, weightUnit: weightUnit)
        }

        if let entry = sortedEntries.first(where: { !$0.isPlannedSetsCompleted }),
           let set = entry.sortedSets.first(where: { !$0.isCompleted }) {
            return formatNextSetNotificationDetail(entry: entry, set: set, weightUnit: weightUnit)
        }

        return nil
    }

    private func nextSetNotificationDetail(afterLoggingEntry entry: WorkoutExerciseEntry, allSetsCompleted: Bool) -> String? {
        let weightUnit = profile?.effectiveWeightUnit ?? .kg

        if allSetsCompleted {
            guard let nextEntry = sortedEntries.first(where: { !$0.isPlannedSetsCompleted && $0.id != entry.id }),
                  let nextSet = nextEntry.sortedSets.first(where: { !$0.isCompleted }) else {
                return nil
            }
            return formatNextSetNotificationDetail(entry: nextEntry, set: nextSet, weightUnit: weightUnit)
        } else {
            guard let nextSet = entry.sortedSets.first(where: { !$0.isCompleted }) else { return nil }
            return formatNextSetNotificationDetail(entry: entry, set: nextSet, weightUnit: weightUnit)
        }
    }

    private func nextGroupRoundNotificationDetail(group: WorkoutExerciseGroup) -> String? {
        let weightUnit = profile?.effectiveWeightUnit ?? .kg
        guard let nextEntry = group.nextEntryToFocus else { return nil }

        // After a round completes, activeRound points to the next round (1-indexed).
        let roundIndex = max(0, group.activeRound - 1)
        guard roundIndex < nextEntry.sortedSets.count else { return nil }

        let nextSet = nextEntry.sortedSets[roundIndex]
        guard !nextSet.isCompleted else { return nil }

        return formatNextSetNotificationDetail(entry: nextEntry, set: nextSet, weightUnit: weightUnit)
    }

    private func formatNextSetNotificationDetail(entry: WorkoutExerciseEntry, set: WorkoutSet, weightUnit: WeightUnit) -> String {
        let prefix = L10n.tr("rest_timer_next_prefix")
        let exerciseName = getExerciseName(for: entry.exerciseId)
        let setLabel = L10n.tr("set_label", set.setIndex)

        let metricText: String
        switch set.metricType {
        case .weightReps:
            metricText = "\(Formatters.formatWeight(set.weightDouble))\(weightUnit.symbol) × \(set.reps ?? 0)"
        case .bodyweightReps:
            metricText = "\(L10n.tr("bodyweight_label")) × \(set.reps ?? 0)"
        case .timeDistance:
            if let distance = set.distanceMeters, distance > 0 {
                metricText = "\(set.durationFormatted) / \(set.distanceFormatted)"
            } else {
                metricText = set.durationFormatted
            }
        case .completion:
            metricText = L10n.tr("history_completed")
        }

        return "\(prefix) \(exerciseName) \(setLabel)  \(metricText)"
    }

    // MARK: - Plan Update Handling

    private enum PlanUpdateDirection {
        case increase
        case decrease
        case mixed
        case unknown
    }

    private struct PlanUpdateComparison {
        let needsUpdate: Bool
        let direction: PlanUpdateDirection
    }

    private struct PlanUpdateRequest {
        let entry: WorkoutExerciseEntry
        let planExercise: PlanExercise
        let exerciseName: String
        let direction: PlanUpdateDirection
        let skipToggleText: String?
    }

    private func handlePlanUpdateIfNeeded(for entry: WorkoutExerciseEntry) {
        guard let profile,
              entry.source == .routine,
              let workoutDay = selectedWorkoutDay,
              let planId = workoutDay.routinePresetId,
              let planDayId = workoutDay.routineDayId,
              let plan = PlanService.getPlan(id: planId, modelContext: modelContext),
              let planDay = plan.sortedDays.first(where: { $0.id == planDayId }),
              let planExercise = planDay.sortedExercises.first(where: {
                  $0.exerciseId == entry.exerciseId && $0.orderIndex == entry.orderIndex
              }) else {
            return
        }

        let comparison = comparePlanUpdate(planExercise: planExercise, entry: entry)
        guard comparison.needsUpdate else { return }

        if !profile.planUpdateConfirmationEnabled {
            applyPlanUpdate(planExercise: planExercise, entry: entry, showToast: true)
            return
        }

        switch comparison.direction {
        case .increase:
            if profile.planUpdatePolicyIncrease == .autoUpdate {
                applyPlanUpdate(planExercise: planExercise, entry: entry, showToast: true)
                return
            }
        case .decrease:
            if profile.planUpdatePolicyDecrease == .autoUpdate {
                applyPlanUpdate(planExercise: planExercise, entry: entry, showToast: true)
                return
            }
        case .mixed, .unknown:
            break
        }

        let exerciseName = getExerciseName(for: entry.exerciseId)
        let skipToggleText = planUpdateSkipToggleText(for: comparison.direction)
        pendingPlanUpdate = PlanUpdateRequest(
            entry: entry,
            planExercise: planExercise,
            exerciseName: exerciseName,
            direction: comparison.direction,
            skipToggleText: skipToggleText
        )
        withAnimation(.easeInOut(duration: 0.2)) {
            showPlanUpdateDialog = true
        }
    }

    private func comparePlanUpdate(
        planExercise: PlanExercise,
        entry: WorkoutExerciseEntry
    ) -> PlanUpdateComparison {
        let plannedSets = planExercise.sortedPlannedSets
        let workoutSets = entry.sortedSets

        guard !workoutSets.isEmpty else {
            return PlanUpdateComparison(needsUpdate: false, direction: .unknown)
        }

        if plannedSets.isEmpty {
            return PlanUpdateComparison(needsUpdate: true, direction: .unknown)
        }

        if plannedSets.count != workoutSets.count {
            return PlanUpdateComparison(needsUpdate: true, direction: .unknown)
        }

        var hasDiff = false
        var hasIncrease = false
        var hasDecrease = false
        var hasUnknown = false
        let tolerance = 0.0001

        func compareDoubles(_ planned: Double?, _ workout: Double?) {
            if planned == nil && workout == nil { return }
            if let planned, let workout {
                let delta = workout - planned
                if abs(delta) > tolerance {
                    hasDiff = true
                    if delta > 0 {
                        hasIncrease = true
                    } else {
                        hasDecrease = true
                    }
                }
            } else {
                hasDiff = true
                hasUnknown = true
            }
        }

        func compareInts(_ planned: Int?, _ workout: Int?) {
            if planned == nil && workout == nil { return }
            if let planned, let workout {
                if planned != workout {
                    hasDiff = true
                    if workout > planned {
                        hasIncrease = true
                    } else {
                        hasDecrease = true
                    }
                }
            } else {
                hasDiff = true
                hasUnknown = true
            }
        }

        for (planSet, workoutSet) in zip(plannedSets, workoutSets) {
            if planSet.metricType != workoutSet.metricType {
                hasDiff = true
                hasUnknown = true
                continue
            }

            switch planSet.metricType {
            case .weightReps:
                let workoutWeight = workoutSet.weight.map { NSDecimalNumber(decimal: $0).doubleValue }
                compareDoubles(planSet.targetWeight, workoutWeight)
                compareInts(planSet.targetReps, workoutSet.reps)
            case .bodyweightReps:
                compareInts(planSet.targetReps, workoutSet.reps)
            case .timeDistance:
                if planSet.targetDurationSeconds != workoutSet.durationSeconds ||
                    planSet.targetDistanceMeters != workoutSet.distanceMeters {
                    hasDiff = true
                    hasUnknown = true
                }
            case .completion:
                break
            }
        }

        guard hasDiff else {
            return PlanUpdateComparison(needsUpdate: false, direction: .unknown)
        }

        if hasUnknown {
            return PlanUpdateComparison(needsUpdate: true, direction: .unknown)
        }

        if hasIncrease && hasDecrease {
            return PlanUpdateComparison(needsUpdate: true, direction: .mixed)
        }

        if hasIncrease {
            return PlanUpdateComparison(needsUpdate: true, direction: .increase)
        }

        if hasDecrease {
            return PlanUpdateComparison(needsUpdate: true, direction: .decrease)
        }

        return PlanUpdateComparison(needsUpdate: true, direction: .unknown)
    }

    private func applyPlanUpdate(
        planExercise: PlanExercise,
        entry: WorkoutExerciseEntry,
        showToast: Bool = false
    ) {
        PlanService.updatePlanExercise(planExercise, from: entry, modelContext: modelContext)
        if showToast {
            showSnackBar(message: L10n.tr("workout_plan_updated"), undoAction: {})
        }
    }

    private func applyPlanUpdatePolicySkip(for direction: PlanUpdateDirection) {
        guard let profile else { return }

        switch direction {
        case .increase:
            profile.planUpdatePolicyIncrease = .autoUpdate
        case .decrease:
            profile.planUpdatePolicyDecrease = .autoUpdate
        case .mixed, .unknown:
            return
        }

        try? modelContext.save()
    }

    private func planUpdateSkipToggleText(for direction: PlanUpdateDirection) -> String? {
        switch direction {
        case .increase:
            return L10n.tr("plan_update_skip_confirm_toggle", L10n.tr("plan_update_direction_increase"))
        case .decrease:
            return L10n.tr("plan_update_skip_confirm_toggle", L10n.tr("plan_update_direction_decrease"))
        case .mixed, .unknown:
            return nil
        }
    }

    private func dismissPlanUpdateDialog() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showPlanUpdateDialog = false
            pendingPlanUpdate = nil
        }
    }

    // MARK: - Reorder

    private func toggleReorderMode() {
        if isReordering {
            stopReorderMode()
        } else {
            expandedEntryId = nil
            reorderItems = displayItems
            isReordering = true
        }
    }

    private func stopReorderMode() {
        // orderIndex更新とプラン連動確認
        if !reorderItems.isEmpty {
            commitReorder(items: reorderItems)
        }

        isReordering = false
        draggedItemId = nil
        reorderItems = []
    }

    private func commitReorder(items: [WorkoutDisplayItem]) {
        guard let workoutDay = selectedWorkoutDay else { return }

        let currentIds = displayItems.map(\.id)
        let newIds = items.map(\.id)
        guard currentIds != newIds else { return }

        let planReorder = buildPlanReorderMap(items: items)

        for (index, item) in items.enumerated() {
            switch item {
            case .group(let group):
                group.orderIndex = index
            case .entry(let entry):
                entry.orderIndex = index
            case .cardio:
                // Cardio items are not included in reorder
                break
            }
        }

        workoutDay.touch()
        try? modelContext.save()

        if let planReorder {
            pendingPlanReorder = planReorder
            withAnimation(.easeInOut(duration: 0.2)) {
                showPlanReorderDialog = true
            }
        }
    }

    private func buildPlanReorderMap(items: [WorkoutDisplayItem]) -> PlanReorderMap? {
        guard let workoutDay = selectedWorkoutDay,
              workoutDay.mode == .routine,
              let planId = workoutDay.routinePresetId,
              let planDayId = workoutDay.routineDayId,
              let plan = PlanService.getPlan(id: planId, modelContext: modelContext),
              let planDay = plan.days.first(where: { $0.id == planDayId }) else {
            return nil
        }

        let planGroups = planDay.exerciseGroups
        let planExercises = planDay.exercises.filter { !$0.isGrouped }
        var planExerciseByKey: [ExerciseOrderKey: PlanExercise] = [:]
        for exercise in planExercises {
            let key = ExerciseOrderKey(exerciseId: exercise.exerciseId, orderIndex: exercise.orderIndex)
            planExerciseByKey[key] = exercise
        }

        var groupUpdates: [(UUID, Int)] = []
        var exerciseUpdates: [(UUID, Int)] = []

        for (index, item) in items.enumerated() {
            switch item {
            case .group(let group):
                if let planGroup = findPlanGroup(for: group, in: planGroups) {
                    groupUpdates.append((planGroup.id, index))
                }
            case .entry(let entry):
                let key = ExerciseOrderKey(exerciseId: entry.exerciseId, orderIndex: entry.orderIndex)
                if let planExercise = planExerciseByKey[key] {
                    exerciseUpdates.append((planExercise.id, index))
                }
            case .cardio:
                // Cardio items don't sync to plan
                break
            }
        }

        guard !groupUpdates.isEmpty || !exerciseUpdates.isEmpty else { return nil }

        return PlanReorderMap(
            planId: planId,
            planDayId: planDayId,
            groupOrderUpdates: groupUpdates,
            exerciseOrderUpdates: exerciseUpdates
        )
    }

    private func applyPendingPlanReorder() {
        guard let pendingPlanReorder,
              let plan = PlanService.getPlan(id: pendingPlanReorder.planId, modelContext: modelContext),
              let planDay = plan.days.first(where: { $0.id == pendingPlanReorder.planDayId }) else {
            return
        }

        let groupsById = Dictionary(uniqueKeysWithValues: planDay.exerciseGroups.map { ($0.id, $0) })
        let exercisesById = Dictionary(uniqueKeysWithValues: planDay.exercises.map { ($0.id, $0) })

        for update in pendingPlanReorder.groupOrderUpdates {
            groupsById[update.groupId]?.orderIndex = update.newOrderIndex
        }
        for update in pendingPlanReorder.exerciseOrderUpdates {
            exercisesById[update.exerciseId]?.orderIndex = update.newOrderIndex
        }

        planDay.plan?.touch()
        try? modelContext.save()
    }

    private func dismissPlanReorderDialog() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showPlanReorderDialog = false
            pendingPlanReorder = nil
        }
    }

    private func findPlanGroup(
        for workoutGroup: WorkoutExerciseGroup,
        in planGroups: [PlanExerciseGroup]
    ) -> PlanExerciseGroup? {
        let workoutSignature = groupSignature(for: workoutGroup.sortedEntries)
        if let matched = planGroups.first(where: { groupSignature(for: $0.sortedExercises) == workoutSignature }) {
            return matched
        }
        return planGroups.first { $0.orderIndex == workoutGroup.orderIndex }
    }

    private func groupSignature(for entries: [WorkoutExerciseEntry]) -> [GroupEntryKey] {
        entries
            .sorted { ($0.groupOrderIndex ?? 0) < ($1.groupOrderIndex ?? 0) }
            .map { GroupEntryKey(exerciseId: $0.exerciseId, groupOrderIndex: $0.groupOrderIndex ?? 0) }
    }

    private func groupSignature(for exercises: [PlanExercise]) -> [GroupEntryKey] {
        exercises
            .sorted { ($0.groupOrderIndex ?? 0) < ($1.groupOrderIndex ?? 0) }
            .map { GroupEntryKey(exerciseId: $0.exerciseId, groupOrderIndex: $0.groupOrderIndex ?? 0) }
    }

    private func removePlannedSet(_ set: WorkoutSet, from entry: WorkoutExerciseEntry) {
        guard entry.sortedSets.count > 1 else { return }
        set.softDelete()
        // Sync set removal to Watch.
        sendWorkoutDataToWatch()
    }

    private func deleteCompletedSet(_ set: WorkoutSet, from entry: WorkoutExerciseEntry) {
        guard entry.sortedSets.count > 1 else { return }
        set.softDelete()
        // Sync set removal to Watch.
        sendWorkoutDataToWatch()
    }

    /// Marks a completed set as not completed
    private func uncompleteSet(_ set: WorkoutSet) {
        WorkoutService.uncompleteSet(set)

        // Send update to Watch
        PhoneWatchConnectivityManager.shared.sendSetUncomplete(setId: set.id)
        sendWorkoutDataToWatch()
    }

    /// Deletes an entire exercise entry from the workout
    private func deleteEntry(_ entry: WorkoutExerciseEntry) {
        // Clear expanded state if this entry was expanded
        if expandedEntryId == entry.id {
            expandedEntryId = nil
        }

        // Delete the entry
        modelContext.delete(entry)
        // Sync entry deletion to Watch.
        sendWorkoutDataToWatch()
    }

    /// Deletes a group and releases its entries back to ungrouped state
    private func deleteGroup(_ group: WorkoutExerciseGroup) {
        closeGroupSwipe(group.id)
        groupSwipeStartOffsets[group.id] = nil

        let entryIds = Set(group.entries.map { $0.id })
        if let expandedEntryId, entryIds.contains(expandedEntryId) {
            self.expandedEntryId = nil
        }
        if let workoutDay = selectedWorkoutDay {
            workoutDay.entries.removeAll { entryIds.contains($0.id) }
        }
        for entry in group.entries {
            modelContext.delete(entry)
        }
        group.entries.removeAll()
        selectedWorkoutDay?.exerciseGroups.removeAll { $0.id == group.id }
        selectedGroupRoundIndex[group.id] = nil
        modelContext.delete(group)
        // Sync group deletion to Watch.
        sendWorkoutDataToWatch()
    }

    private func showSnackBar(message: String, undoAction: @escaping () -> Void) {
        withAnimation {
            snackBarMessage = message
            snackBarUndoAction = undoAction
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if snackBarMessage == message {
                dismissSnackBar()
            }
        }
    }

    private func dismissSnackBar() {
        withAnimation {
            snackBarMessage = nil
            snackBarUndoAction = nil
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        Formatters.formatWeight(weight)
    }

    // MARK: - Watch Connectivity

    /// Sets up Watch Connectivity callbacks and observers
    private func setupWatchConnectivity() {
        // Handle set completion from Watch
        watchConnectivity.onSetCompleted = { [self] setId in
            handleWatchSetCompletion(setId: setId)
        }

        // Listen for sync requests from Watch
        NotificationCenter.default.addObserver(
            forName: .watchRequestedSync,
            object: nil,
            queue: .main
        ) { _ in
            sendWorkoutDataToWatch()
        }
    }

    /// Sends current workout data to Watch
    private func sendWorkoutDataToWatch() {
        guard isViewingToday else { return }

        // Calculate hash of current workout state to avoid unnecessary sync
        let currentHash = computeWorkoutHash()
        guard currentHash != lastSentWorkoutHash else { return }

        let defaultRestTime = profile?.defaultRestTimeSeconds ?? 60
        let combineMode = profile?.combineRecordAndTimerStart ?? false
        let skipFinalSet = profile?.skipRestTimerOnFinalSet ?? true

        watchConnectivity.sendWorkoutData(
            workoutDay: selectedWorkoutDay,
            exercises: Array(exercises),
            bodyParts: Array(bodyParts),
            defaultRestTimeSeconds: defaultRestTime,
            combineRecordAndTimerStart: combineMode,
            skipRestTimerOnFinalSet: skipFinalSet
        )

        lastSentWorkoutHash = currentHash
    }

    /// Computes a hash representing the current workout state for change detection
    private func computeWorkoutHash() -> Int {
        var hasher = Hasher()
        hasher.combine(selectedWorkoutDay?.id)
        hasher.combine(selectedWorkoutDay?.mode)

        if let entries = selectedWorkoutDay?.sortedEntries {
            hasher.combine(entries.count)
            for entry in entries {
                hasher.combine(entry.id)
                hasher.combine(entry.exerciseId)
                hasher.combine(entry.orderIndex)
                hasher.combine(entry.metricType)
                hasher.combine(entry.group?.id)
                hasher.combine(entry.groupOrderIndex)
                for set in entry.sortedSets {
                    hasher.combine(set.id)
                    hasher.combine(set.setIndex)
                    hasher.combine(set.metricType)
                    hasher.combine(set.isCompleted)
                    hasher.combine(set.weight)
                    hasher.combine(set.reps)
                    hasher.combine(set.durationSeconds)
                    hasher.combine(set.distanceMeters)
                    hasher.combine(set.restTimeSeconds)
                }
            }
        }

        if let groups = selectedWorkoutDay?.exerciseGroups {
            let sortedGroups = groups.sorted { $0.orderIndex < $1.orderIndex }
            hasher.combine(sortedGroups.count)
            for group in sortedGroups {
                hasher.combine(group.id)
                hasher.combine(group.orderIndex)
                hasher.combine(group.setCount)
                hasher.combine(group.roundRestSeconds)
                let groupEntries = group.sortedEntries
                hasher.combine(groupEntries.count)
                for entry in groupEntries {
                    hasher.combine(entry.id)
                    hasher.combine(entry.exerciseId)
                    hasher.combine(entry.orderIndex)
                    hasher.combine(entry.groupOrderIndex)
                    hasher.combine(entry.metricType)
                    for set in entry.sortedSets {
                        hasher.combine(set.id)
                        hasher.combine(set.setIndex)
                        hasher.combine(set.metricType)
                        hasher.combine(set.isCompleted)
                        hasher.combine(set.weight)
                        hasher.combine(set.reps)
                        hasher.combine(set.durationSeconds)
                        hasher.combine(set.distanceMeters)
                        hasher.combine(set.restTimeSeconds)
                    }
                }
            }
        }

        return hasher.finalize()
    }

    /// Handles set completion notification from Watch
    private func handleWatchSetCompletion(setId: UUID) {
        guard let workoutDay = selectedWorkoutDay else { return }

        // Find the set and mark it as completed
        for entry in workoutDay.sortedEntries {
            if let set = entry.sortedSets.first(where: { $0.id == setId && !$0.isCompleted }) {
                set.complete()

                // Update UI state
                updateCurrentWeightReps(for: entry)

                // Note: Don't start rest timer here - Watch handles its own timer
                // Starting timer on both devices would be redundant

                // Check progress
                checkAndUpdateProgress()

                // Send updated data back to Watch
                sendWorkoutDataToWatch()

                break
            }
        }
    }

    private func startWorkoutShare() {
        Task { @MainActor in
            guard let image = renderWorkoutShareImage() else { return }
            shareImagePayload = ShareImagePayload(image: image)
        }
    }

    @MainActor
    private func renderWorkoutShareImage() -> UIImage? {
        guard shouldShowShareCard else { return nil }

        let weightUnit = profile?.effectiveWeightUnit ?? .kg
        let totalVolume = sortedEntries.reduce(Decimal.zero) { $0 + $1.totalVolume }

        // Only show volume if there are weightReps exercises
        let hasWeightRepsExercises = sortedEntries.contains { $0.metricType == .weightReps }
        let volumeText: String? = hasWeightRepsExercises
            ? Formatters.formatVolumeNumber(Double(truncating: totalVolume as NSNumber))
            : nil

        // Compute total cardio duration for hero display
        let totalCardioDuration = selectedDateCardioWorkouts.reduce(0.0) { $0 + $1.duration }
        let cardioDurationText: String? = (!selectedDateCardioWorkouts.isEmpty && volumeText == nil)
            ? formatDuration(seconds: Int(totalCardioDuration))
            : nil

        let shareView = WorkoutShareCardView(
            date: selectedWorkoutDate,
            exercises: buildShareExerciseSummaries(weightUnit: weightUnit),
            cardio: buildShareCardioSummaries(),
            totalVolumeText: volumeText,
            totalCardioDurationText: cardioDurationText
        )
        .preferredColorScheme(ThemeManager.shared.currentThemeType.colorScheme)

        let renderer = ImageRenderer(content: shareView)
        renderer.scale = UIScreen.main.scale
        renderer.isOpaque = true
        return renderer.uiImage
    }

    // MARK: - Share Image Data Builders

    private func buildShareExerciseSummaries(weightUnit: WeightUnit) -> [WorkoutShareExerciseSummary] {
        let shouldCondense = sortedEntries.count >= 7

        return sortedEntries.map { entry in
            let exercise = exercisesDict[entry.exerciseId]
            let name = exercise?.localizedName ?? getExerciseName(for: entry.exerciseId)
            let dotColor = exercise
                .flatMap { $0.bodyPartId }
                .flatMap { bodyPartsDict[$0] }
                .map(\.color)

            let completedSets = entry.sortedSets.filter { $0.isCompleted }

            // Find best set and calculate estimated RM
            let (bestSetId, estimatedRM) = findBestSetAndRM(
                entry: entry,
                completedSets: completedSets,
                weightUnit: weightUnit
            )

            // Build all sets with best set first, passing RM to attach to best set
            let allSets = buildShareSetDetails(
                entry: entry,
                completedSets: completedSets,
                bestSetId: bestSetId,
                bestSetRM: estimatedRM,
                weightUnit: weightUnit,
                shouldCondense: shouldCondense
            )

            return WorkoutShareExerciseSummary(
                name: name,
                dotColor: dotColor,
                allSets: allSets,
                bestSetIndex: allSets.isEmpty ? nil : 0  // Best is always first after reordering
            )
        }
    }

    /// Finds the best set and calculates estimated RM based on metric type.
    /// Returns (bestSetId, formattedRM string)
    private func findBestSetAndRM(
        entry: WorkoutExerciseEntry,
        completedSets: [WorkoutSet],
        weightUnit: WeightUnit
    ) -> (UUID?, String?) {
        guard !completedSets.isEmpty else { return (nil, nil) }

        switch entry.metricType {
        case .weightReps:
            // Find set with highest Epley 1RM, prefer lower setIndex on tie
            var bestSet: WorkoutSet?
            var best1RM: Double = 0

            for set in completedSets {
                guard let reps = set.reps, reps > 0, set.weightDouble > 0 else { continue }
                let epley1RM = set.weightDouble * (1.0 + Double(reps) / 30.0)

                if epley1RM > best1RM || (epley1RM == best1RM && (bestSet == nil || set.setIndex < bestSet!.setIndex)) {
                    best1RM = epley1RM
                    bestSet = set
                }
            }

            if let bestSet, best1RM > 0 {
                let rmText = L10n.tr("workout_share_rm_format", "\(Formatters.formatWeight(best1RM))\(weightUnit.symbol)")
                return (bestSet.id, rmText)
            }
            return (nil, nil)

        case .bodyweightReps:
            // Find set with most reps, prefer lower setIndex on tie
            let bestSet = completedSets
                .filter { ($0.reps ?? 0) > 0 }
                .sorted { lhs, rhs in
                    let lhsReps = lhs.reps ?? 0
                    let rhsReps = rhs.reps ?? 0
                    if lhsReps != rhsReps { return lhsReps > rhsReps }
                    return lhs.setIndex < rhs.setIndex
                }
                .first

            return (bestSet?.id, nil)  // No RM for bodyweight

        case .timeDistance:
            // Prefer longest distance, then longest time; lower setIndex on tie
            let bestSet = completedSets
                .sorted { lhs, rhs in
                    let lhsDist = lhs.distanceMeters ?? 0
                    let rhsDist = rhs.distanceMeters ?? 0
                    if lhsDist != rhsDist { return lhsDist > rhsDist }

                    let lhsTime = lhs.durationSeconds ?? 0
                    let rhsTime = rhs.durationSeconds ?? 0
                    if lhsTime != rhsTime { return lhsTime > rhsTime }

                    return lhs.setIndex < rhs.setIndex
                }
                .first

            return (bestSet?.id, nil)

        case .completion:
            return (nil, nil)  // No best set for completion type
        }
    }

    /// Builds ShareSetDetail array with best set first, then remaining in setIndex order.
    /// The best set includes rmText; other sets have nil.
    private func buildShareSetDetails(
        entry: WorkoutExerciseEntry,
        completedSets: [WorkoutSet],
        bestSetId: UUID?,
        bestSetRM: String?,
        weightUnit: WeightUnit,
        shouldCondense: Bool
    ) -> [ShareSetDetail] {
        guard !completedSets.isEmpty else { return [] }

        // Sort: best set first, then by setIndex
        let sortedSets: [WorkoutSet]
        if let bestSetId {
            let bestSet = completedSets.first { $0.id == bestSetId }
            let others = completedSets.filter { $0.id != bestSetId }.sorted { $0.setIndex < $1.setIndex }
            sortedSets = (bestSet.map { [$0] } ?? []) + others
        } else {
            sortedSets = completedSets.sorted { $0.setIndex < $1.setIndex }
        }

        // Condense mode: show only best + "other N sets"
        if shouldCondense && sortedSets.count > 1 {
            var result: [ShareSetDetail] = []

            if let first = sortedSets.first {
                let isBest = (first.id == bestSetId)
                result.append(ShareSetDetail(
                    text: formatSetText(set: first, metricType: entry.metricType, weightUnit: weightUnit),
                    rmText: isBest ? bestSetRM : nil
                ))
            }

            let otherCount = sortedSets.count - 1
            if otherCount > 0 {
                result.append(ShareSetDetail(
                    text: L10n.tr("workout_share_other_sets_format", otherCount),
                    rmText: nil
                ))
            }

            return result
        }

        // Normal mode: show all sets
        return sortedSets.enumerated().map { index, set in
            let isBest = (index == 0 && set.id == bestSetId)
            return ShareSetDetail(
                text: formatSetText(set: set, metricType: entry.metricType, weightUnit: weightUnit),
                rmText: isBest ? bestSetRM : nil
            )
        }
    }

    /// Formats a single set's display text based on metric type.
    private func formatSetText(set: WorkoutSet, metricType: SetMetricType, weightUnit: WeightUnit) -> String {
        switch metricType {
        case .weightReps:
            let weight = Formatters.formatWeight(set.weightDouble)
            let reps = set.reps ?? 0
            return "\(weight)\(weightUnit.symbol) × \(reps)"

        case .bodyweightReps:
            let reps = set.reps ?? 0
            return "\(L10n.tr("bodyweight_label")) × \(reps)"

        case .timeDistance:
            let duration = formatDuration(seconds: set.durationSeconds ?? 0)
            if let distance = set.distanceMeters, distance > 0 {
                return "\(duration) / \(formatDistance(meters: distance))"
            }
            return duration

        case .completion:
            return L10n.tr("history_completed")
        }
    }

    private func buildShareCardioSummaries() -> [WorkoutShareCardioSummary] {
        // Group cardio workouts by activity type
        let groupedByType = Dictionary(grouping: selectedDateCardioWorkouts) { workout in
            HKWorkoutActivityType(rawValue: UInt(workout.activityType)) ?? .other
        }

        return groupedByType.map { (activityType, workouts) in
            let name = activityType.displayName

            // Build set details for each workout (cardio has no RM)
            let allSets = workouts.map { workout -> ShareSetDetail in
                let duration = workout.formattedDuration
                if let distance = workout.formattedDistance {
                    return ShareSetDetail(text: "\(duration) / \(distance)", rmText: nil)
                }
                return ShareSetDetail(text: duration, rmText: nil)
            }

            // Find best: prefer longest distance, then longest time
            let bestIndex = workouts.enumerated()
                .sorted { lhs, rhs in
                    let lhsDist = lhs.element.totalDistance ?? 0
                    let rhsDist = rhs.element.totalDistance ?? 0
                    if lhsDist != rhsDist { return lhsDist > rhsDist }

                    return lhs.element.duration > rhs.element.duration
                }
                .first?.offset

            return WorkoutShareCardioSummary(
                name: name,
                allSets: allSets,
                bestSetIndex: allSets.count > 1 ? bestIndex : (allSets.isEmpty ? nil : 0)
            )
        }
        .sorted { $0.name < $1.name }  // Alphabetical order
    }

    private func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatDistance(meters: Double) -> String {
        let km = meters / 1000.0
        if km >= 1.0 {
            return String(format: "%.1f km", km)
        }
        return String(format: "%.0f m", meters)
    }
}

private struct ShareImagePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Empty State View

/// Empty state shown when selected date's exercises are empty.
/// Presents value proposition and action cards (2-4 depending on context).
struct EmptyStateView: View {
    let isToday: Bool
    let showCopyOption: Bool
    var showRescueOption: Bool = false
    var showRecordFromPlanPrimary: Bool = false
    var showDescription: Bool = true
    let onCreatePlan: () -> Void
    var onRecordFromPlan: (() -> Void)? = nil
    let onCopyPrevious: () -> Void
    let onAddExercise: () -> Void
    var onRescueFromPlan: (() -> Void)? = nil

    private var headlineKey: String {
        isToday ? "empty_state_headline" : "empty_state_headline_other"
    }

    private var descriptionKey: String {
        isToday ? "empty_state_description" : "empty_state_description_other"
    }

    var body: some View {
        VStack(spacing: 24) {
            // Value proposition message
            VStack(spacing: 8) {
                Text(L10n.tr(headlineKey))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                if showDescription {
                    Text(L10n.tr(descriptionKey))
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 8)

            // Action cards
            VStack(spacing: 12) {
                // Card A: Create Plan or Record from Plan (Primary)
                if showRecordFromPlanPrimary, let recordAction = onRecordFromPlan {
                    PlanActionCard(
                        badgeText: nil,
                        title: L10n.tr("workout_rescue_from_plan"),
                        subtitle: L10n.tr("workout_rescue_from_plan_subtitle"),
                        buttonText: L10n.tr("workout_rescue_from_plan_button"),
                        isPrimary: true,
                        action: recordAction
                    )
                } else {
                    PlanActionCard(
                        badgeText: L10n.tr("empty_state_recommended"),
                        title: L10n.tr("empty_state_create_plan_title"),
                        subtitle: L10n.tr("empty_state_create_plan_subtitle"),
                        buttonText: L10n.tr("empty_state_create_plan_button"),
                        isPrimary: true,
                        action: onCreatePlan
                    )
                }

                // Card C: Copy Previous (Conditional) - Between A and B
                if showCopyOption {
                    PlanActionCard(
                        badgeText: nil,
                        title: L10n.tr("empty_state_copy_title"),
                        subtitle: L10n.tr("empty_state_copy_subtitle"),
                        buttonText: L10n.tr("empty_state_copy_button"),
                        isPrimary: false,
                        action: onCopyPrevious
                    )
                }

                // Card D: Rescue from Plan (Conditional - past date with active plan)
                if showRescueOption, !showRecordFromPlanPrimary, let rescueAction = onRescueFromPlan {
                    PlanActionCard(
                        badgeText: nil,
                        title: L10n.tr("workout_rescue_from_plan"),
                        subtitle: L10n.tr("workout_rescue_from_plan_subtitle"),
                        buttonText: L10n.tr("workout_rescue_from_plan_button"),
                        isPrimary: false,
                        action: rescueAction
                    )
                }

                // Card B: Add Exercise (Secondary) - Always shown
                PlanActionCard(
                    badgeText: nil,
                    title: L10n.tr("empty_state_manual_title"),
                    subtitle: L10n.tr("empty_state_manual_subtitle"),
                    buttonText: L10n.tr("empty_state_manual_button"),
                    isPrimary: false,
                    action: onAddExercise
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
}

/// Rest day view shown when selected date is a routine rest day.
private struct RestDayEmptyView: View {
    var dayIndex: Int? = nil
    var totalDays: Int? = nil
    var dayName: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day info header (optional)
            if let dayIndex = dayIndex, let totalDays = totalDays {
                dayInfoHeader(dayIndex: dayIndex, totalDays: totalDays)
            }

            // Rest day card
            restDayCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func dayInfoHeader(dayIndex: Int, totalDays: Int) -> some View {
        HStack(spacing: 4) {
            Text(L10n.tr("day_label", dayIndex))
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            if let dayName = dayName, !dayName.isEmpty {
                Text(":")
                    .font(.headline)
                    .foregroundColor(AppColors.textSecondary)
                Text(dayName)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
            }

            Spacer()

            Text("\(dayIndex)/\(totalDays)")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var restDayCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "bed.double")
                .font(.system(size: 44))
                .foregroundColor(AppColors.textMuted)

            Text(L10n.tr("rest_day"))
                .font(.headline)
                .foregroundColor(AppColors.textSecondary)

            Text(L10n.tr("rest_day_description"))
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
}

// MARK: - Plan Action Card

/// Tappable card with title, subtitle, and button for empty state actions.
struct PlanActionCard: View {
    let badgeText: String?
    let title: String
    let subtitle: String
    let buttonText: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Badge (optional)
            if let badge = badgeText {
                Text(badge)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accentBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.accentBlue.opacity(0.15))
                    .cornerRadius(4)
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Button
            HStack {
                Spacer()
                Button(action: action) {
                    Text(buttonText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isPrimary ? AppColors.textPrimary : AppColors.accentBlue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            isPrimary
                                ? AppColors.accentBlue
                                : Color.clear
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isPrimary ? Color.clear : AppColors.accentBlue.opacity(0.5), lineWidth: 1)
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Plan Reorder Dialog

struct PlanReorderDialogView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text(L10n.tr("workout_reorder_plan_title"))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            Text(L10n.tr("workout_reorder_plan_message"))
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text(L10n.tr("workout_reorder_plan_cancel"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.cardBackground)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button {
                    onConfirm()
                } label: {
                    Text(L10n.tr("workout_reorder_plan_confirm"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accentBlue)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(AppColors.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.textMuted.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
        .padding(.horizontal, 24)
    }
}

// MARK: - Add Exercise Card

/// Card-style button for adding a new exercise, displayed at the bottom of the exercise list.
struct AddExerciseCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                Text("add_exercise")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Workout Card

/// Card-style button for sharing the day's workout summary as an image.
struct ShareWorkoutCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
                Text("share")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WorkoutView(navigateToHistory: .constant(false), navigateToRoutines: .constant(false))
        .modelContainer(for: [
            LocalProfile.self,
            Exercise.self,
            WorkoutDay.self,
            WorkoutExerciseEntry.self,
            WorkoutSet.self,
            WorkoutPlan.self,
            PlanDay.self,
            PlanExercise.self,
            PlanProgress.self,
            PlanCycle.self,
            PlanCycleItem.self,
            PlanCycleProgress.self
        ], inMemory: true)
        .preferredColorScheme(.dark)
}
