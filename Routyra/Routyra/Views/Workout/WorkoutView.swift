//
//  WorkoutView.swift
//  Routyra
//

import SwiftUI
import SwiftData

/// Navigation destinations for WorkoutView
enum WorkoutDestination: Hashable {
    case exercisePicker
    case setEditor(exercise: Exercise)
    case exerciseChanger(entryId: UUID, currentExerciseId: UUID)
}

struct WorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutDay.date, order: .reverse) private var workoutDays: [WorkoutDay]
    @Query private var exercises: [Exercise]
    @Query private var bodyParts: [BodyPart]
    @Binding var navigateToHistory: Bool
    @Binding var navigateToRoutines: Bool

    @State private var selectedDate: Date = DateUtilities.todayWorkoutDate(transitionHour: 3)
    @State private var expandedEntryId: UUID?
    @State private var snackBarMessage: String?
    @State private var snackBarUndoAction: (() -> Void)?
    @State private var currentWeight: Double = 60
    @State private var currentReps: Int = 8
    @State private var profile: LocalProfile?
    @State private var navigationPath = NavigationPath()

    // Cycle support
    @State private var activeCycle: PlanCycle?
    @State private var cycleStateInfo: (cycleName: String, planName: String, dayInfo: String)?

    // Day change support
    @State private var showDayChangeDialog = false
    @State private var pendingDayChange: Int? = nil
    @State private var skipCurrentDay = false

    private var transitionHour: Int {
        profile?.dayTransitionHour ?? 3
    }

    private var todayWorkoutDate: Date {
        DateUtilities.todayWorkoutDate(transitionHour: transitionHour)
    }

    private var selectedWorkoutDate: Date {
        DateUtilities.startOfDay(selectedDate)
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

    /// Whether to show empty state (selected date's entries are empty)
    private var shouldShowEmptyState: Bool {
        sortedEntries.isEmpty
    }

    /// Most recent workout day with entries (excluding today), used for "copy previous" feature
    private var lastWorkoutDay: WorkoutDay? {
        let today = todayWorkoutDate
        return workoutDays.first { workoutDay in
            !DateUtilities.isSameDay(workoutDay.date, today) && !workoutDay.sortedEntries.isEmpty
        }
    }

    /// Whether "copy previous workout" option should be shown
    private var canCopyPreviousWorkout: Bool {
        lastWorkoutDay != nil
    }

    private var currentWeekStart: Date? {
        Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))
    }

    private var selectedDayIndex: Int {
        let calendar = Calendar.current
        guard let weekStart = currentWeekStart else { return 0 }
        return calendar.dateComponents([.day], from: weekStart, to: selectedDate).day ?? 0
    }

    private var weeklyProgress: [Int: Double] {
        let calendar = Calendar.current
        guard let weekStart = currentWeekStart else { return [:] }

        var progress: [Int: Double] = [:]
        for workoutDay in workoutDays {
            if let dayDiff = calendar.dateComponents([.day], from: weekStart, to: workoutDay.date).day,
               dayDiff >= 0 && dayDiff < 7 {
                // Count actual sets (completed + incomplete)
                let totalSets = workoutDay.entries.reduce(0) { $0 + $1.activeSets.count }
                let completedSets = workoutDay.totalCompletedSets
                if totalSets > 0 {
                    progress[dayDiff] = Double(completedSets) / Double(totalSets)
                }
            }
        }
        return progress
    }

    private var expandedEntryIndex: Int? {
        sortedEntries.firstIndex { $0.id == expandedEntryId }
    }

    /// Exercises dictionary for quick lookup
    private var exercisesDict: [UUID: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    /// Body parts dictionary for quick lookup
    private var bodyPartsDict: [UUID: BodyPart] {
        Dictionary(uniqueKeysWithValues: bodyParts.map { ($0.id, $0) })
    }

    /// Whether day context view should be shown (plan or cycle is active, regardless of date)
    private var shouldShowDayContext: Bool {
        guard let profile = profile else { return false }

        switch profile.executionMode {
        case .single:
            return profile.activePlanId != nil
        case .cycle:
            return activeCycle != nil
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
              let planId = profile.activePlanId else {
            return nil
        }

        // If selected date has a WorkoutDay with routineDayId, resolve from it
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

        // No WorkoutDay or couldn't resolve - calculate preview
        if let info = PlanService.getPreviewDayInfo(
            profile: profile,
            targetDate: selectedWorkoutDate,
            todayDate: todayWorkoutDate,
            modelContext: modelContext
        ) {
            return (info.dayIndex, info.totalDays, info.dayName, info.planId)
        }

        return nil
    }

    /// Gets day info for cycle mode
    private func getCycleDayInfo() -> (dayIndex: Int, totalDays: Int, dayName: String?, planId: UUID?)? {
        guard let cycle = activeCycle else { return nil }

        // If selected date has a WorkoutDay with routineDayId, resolve from it
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

        // No WorkoutDay or couldn't resolve - calculate preview
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

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                WorkoutHeaderView(
                    date: selectedDate,
                    streakCount: 12,
                    isViewingToday: isViewingToday,
                    onDateTap: handleDateTap
                )

                // Day context (when plan or cycle is active - shows for any selected date)
                if shouldShowDayContext, let dayInfo = currentDayContextInfo {
                    DayContextView(
                        currentDayIndex: dayInfo.dayIndex,
                        totalDays: dayInfo.totalDays,
                        dayName: dayInfo.dayName,
                        canChangeDay: canChangeDay,
                        onPrevious: {
                            let prevDay = dayInfo.dayIndex > 1 ? dayInfo.dayIndex - 1 : dayInfo.totalDays
                            requestDayChange(to: prevDay)
                        },
                        onNext: {
                            let nextDay = dayInfo.dayIndex < dayInfo.totalDays ? dayInfo.dayIndex + 1 : 1
                            requestDayChange(to: nextDay)
                        },
                        onTapPlanLabel: {
                            // Navigate to Plans tab when plan label is tapped
                            navigateToRoutines = true
                        }
                    )
                }

                // Cycle context (when active cycle exists and viewing today) - shows cycle/plan name + complete button
                if isViewingToday, let info = cycleStateInfo {
                    CycleContextView(
                        cycleName: info.cycleName,
                        planName: info.planName,
                        dayInfo: info.dayInfo,
                        onComplete: {
                            completeAndAdvanceCycle()
                        }
                    )
                }

                WeeklyActivityStripView(
                    dayProgress: weeklyProgress,
                    selectedDayIndex: selectedDayIndex,
                    onDayTap: selectDay
                )

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
                                let isExpanded = expandedEntryId == entry.id
                                let exerciseName = getExerciseName(for: entry.exerciseId)
                                let bodyPartColor = getBodyPartColor(for: entry.exerciseId)

                                ExerciseEntryCardView(
                                    entry: entry,
                                    exerciseName: exerciseName,
                                    bodyPartColor: bodyPartColor,
                                    isExpanded: isExpanded,
                                    currentWeight: $currentWeight,
                                    currentReps: $currentReps,
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
                                        return logSet(for: entry, scrollProxy: proxy)
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
                                    }
                                )
                                .id(entry.id)

                                if shouldShowAd(afterIndex: index) {
                                    AdPlaceholderView()
                                }
                            }

                            if shouldShowEmptyState {
                                EmptyStateView(
                                    isToday: isViewingToday,
                                    showCopyOption: canCopyPreviousWorkout,
                                    onCreatePlan: {
                                        navigateToRoutines = true
                                    },
                                    onCopyPrevious: {
                                        copyPreviousWorkout()
                                    },
                                    onAddExercise: {
                                        navigationPath.append(WorkoutDestination.exercisePicker)
                                    }
                                )
                            } else {
                                // Add exercise card at bottom of list (only when entries exist)
                                AddExerciseCard {
                                    navigationPath.append(WorkoutDestination.exercisePicker)
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

                            if !sortedEntries.isEmpty {
                                BottomStatusBarView(
                                    sets: selectedWorkoutDay?.totalCompletedSets ?? 0,
                                    exercises: selectedWorkoutDay?.totalExercisesWithSets ?? 0,
                                    volume: Double(truncating: (selectedWorkoutDay?.totalVolume ?? 0) as NSNumber)
                                )
                            }
                        }
                    }
                }
            }
            .background(AppColors.background)
            .navigationBarHidden(true)
            .navigationDestination(for: WorkoutDestination.self) { destination in
                switch destination {
                case .exercisePicker:
                    if let profile = profile {
                        WorkoutExercisePickerView(
                            profile: profile,
                            exercises: exercisesDict,
                            bodyParts: bodyPartsDict,
                            onSelect: { exercise in
                                // Navigate to set editor instead of directly adding
                                navigationPath.removeLast()
                                navigationPath.append(WorkoutDestination.setEditor(exercise: exercise))
                            }
                        )
                    }

                case .setEditor(let exercise):
                    let bodyPart = exercise.bodyPartId.flatMap { bodyPartsDict[$0] }
                    WorkoutSetEditorView(
                        exercise: exercise,
                        bodyPart: bodyPart,
                        initialWeight: currentWeight,
                        initialReps: currentReps,
                        onConfirm: { sets in
                            addExerciseToWorkout(exercise, withSets: sets)
                            navigationPath.removeLast()
                        }
                    )

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
        }
        .onAppear {
            profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
            // Update selectedDate with actual profile settings
            selectedDate = todayWorkoutDate
            loadActiveCycle()
            ensureTodayWorkout()
            if let first = sortedEntries.first {
                expandedEntryId = first.id
            }
        }
        .onChange(of: selectedDate) { _, _ in
            if let first = sortedEntries.first {
                expandedEntryId = first.id
            } else {
                expandedEntryId = nil
            }
        }
        .overlay {
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
                        onConfirm: { skipAndAdvance in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDayChangeDialog = false
                            }
                            executeDayChange(to: newDay, skipAndAdvance: skipAndAdvance)
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
        }
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

    /// Updates currentWeight and currentReps to match the entry's next incomplete set
    private func updateCurrentWeightReps(for entry: WorkoutExerciseEntry) {
        if let nextSet = entry.sortedSets.first(where: { !$0.isCompleted }) {
            currentWeight = nextSet.weightDouble
            currentReps = nextSet.reps
        } else if let lastSet = entry.sortedSets.last {
            // All sets completed, use last set's values
            currentWeight = lastSet.weightDouble
            currentReps = lastSet.reps
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

    private func shouldShowAd(afterIndex index: Int) -> Bool {
        guard let expandedIndex = expandedEntryIndex else {
            return index % 3 == 1 && index < sortedEntries.count - 1
        }

        let isExpanded = sortedEntries[index].id == expandedEntryId
        if isExpanded { return false }

        let isAdjacentToExpanded = index == expandedIndex - 1 || index == expandedIndex
        if isAdjacentToExpanded { return false }

        if index >= sortedEntries.count - 1 { return false }

        let collapsedIndexBeforeExpanded = index < expandedIndex ? index : index - 1
        return collapsedIndexBeforeExpanded % 3 == 1
    }

    private func loadActiveCycle() {
        guard let profile = profile else { return }

        // Only load cycle if in cycle mode
        if profile.executionMode == .cycle {
            activeCycle = CycleService.getActiveCycle(profileId: profile.id, modelContext: modelContext)

            if let cycle = activeCycle {
                cycleStateInfo = CycleService.getCurrentStateInfo(for: cycle, modelContext: modelContext)
            } else {
                cycleStateInfo = nil
            }
        } else {
            // In single mode, clear cycle state
            activeCycle = nil
            cycleStateInfo = nil
        }
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
        let previousEntries = workoutDay.entries.map { entry -> (exerciseId: UUID, orderIndex: Int, sets: [(weight: Decimal, reps: Int, isCompleted: Bool)]) in
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
        previousEntries: [(exerciseId: UUID, orderIndex: Int, sets: [(weight: Decimal, reps: Int, isCompleted: Bool)])],
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

    private func setupWorkoutFromSinglePlan(planId: UUID, workoutDate: Date) {
        guard let profile = profile else { return }

        // Use PlanService to setup today's workout (it handles plan lookup internally)
        _ = PlanService.setupTodayWorkout(
            profile: profile,
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
                // Auto-advance to next day
                CycleService.advance(cycle: cycle, modelContext: modelContext)
                cycleStateInfo = CycleService.getCurrentStateInfo(for: cycle, modelContext: modelContext)
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
                PlanService.expandPlanToWorkout(planDay: planDay, workoutDay: existingWorkout)
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
            PlanService.expandPlanToWorkout(planDay: planDay, workoutDay: workoutDay)
        }
    }

    /// Changes the exercise for a given entry
    private func changeExercise(entryId: UUID, to exercise: Exercise) {
        guard let entry = sortedEntries.first(where: { $0.id == entryId }) else { return }
        entry.exerciseId = exercise.id
    }

    /// Adds a selected exercise to the current workout with specified sets
    private func addExerciseToWorkout(_ exercise: Exercise, withSets sets: [(weight: Double, reps: Int)]) {
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

        // Get next order index
        let nextOrder = (workoutDay.entries.map(\.orderIndex).max() ?? -1) + 1

        // Create entry with the specified sets
        let entry = WorkoutExerciseEntry(
            exerciseId: exercise.id,
            orderIndex: nextOrder,
            source: .free,
            plannedSetCount: sets.count
        )

        // Add all sets as incomplete
        for (index, setData) in sets.enumerated() {
            let set = WorkoutSet(
                setIndex: index + 1,
                weight: Decimal(setData.weight),
                reps: setData.reps,
                isCompleted: false
            )
            entry.addSet(set)
        }

        workoutDay.addEntry(entry)

        // Update current weight/reps to match first set
        if let firstSet = sets.first {
            currentWeight = firstSet.weight
            currentReps = firstSet.reps
        }

        // Expand the newly added entry
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedEntryId = entry.id
        }
    }

    private func addSet(to entry: WorkoutExerciseEntry) {
        _ = entry.createSet(weight: Decimal(currentWeight), reps: currentReps, isCompleted: false)
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

        // Copy each entry from previous workout
        let previousEntries = previousDay.sortedEntries
        for (index, previousEntry) in previousEntries.enumerated() {
            let newEntry = WorkoutExerciseEntry(
                exerciseId: previousEntry.exerciseId,
                orderIndex: index,
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
        }

        // Expand the first entry
        if let firstEntry = workoutDay.sortedEntries.first {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedEntryId = firstEntry.id
            }

            // Update current weight/reps from first set
            if let firstSet = firstEntry.sortedSets.first {
                currentWeight = firstSet.weightDouble
                currentReps = firstSet.reps
            }
        }
    }

    @discardableResult
    private func logSet(for entry: WorkoutExerciseEntry, scrollProxy: ScrollViewProxy) -> Bool {
        guard let nextSet = entry.sortedSets.first(where: { !$0.isCompleted }) else { return false }

        nextSet.weight = Decimal(currentWeight)
        nextSet.reps = currentReps
        nextSet.complete()

        // Check if all sets for this entry are now completed
        let allSetsCompleted = entry.sortedSets.allSatisfy { $0.isCompleted }

        if allSetsCompleted {
            // Find the next incomplete entry
            if let nextEntry = sortedEntries.first(where: { !$0.isPlannedSetsCompleted && $0.id != entry.id }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        expandedEntryId = nextEntry.id
                        scrollProxy.scrollTo(nextEntry.id, anchor: .top)
                    }
                }
            }
        }

        return true
    }

    private func removePlannedSet(_ set: WorkoutSet, from entry: WorkoutExerciseEntry) {
        guard entry.sortedSets.count > 1 else { return }
        set.softDelete()
    }

    private func deleteCompletedSet(_ set: WorkoutSet, from entry: WorkoutExerciseEntry) {
        guard entry.sortedSets.count > 1 else { return }
        set.softDelete()
    }

    /// Deletes an entire exercise entry from the workout
    private func deleteEntry(_ entry: WorkoutExerciseEntry) {
        // Clear expanded state if this entry was expanded
        if expandedEntryId == entry.id {
            expandedEntryId = nil
        }

        // Delete the entry
        modelContext.delete(entry)

        // Expand the next available entry
        if let nextEntry = sortedEntries.first(where: { $0.id != entry.id }) {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedEntryId = nextEntry.id
            }
        }
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
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
    }
}

// MARK: - Empty State View

/// Empty state shown when selected date's exercises are empty.
/// Presents value proposition and action cards (2-3 depending on previous workout existence).
struct EmptyStateView: View {
    let isToday: Bool
    let showCopyOption: Bool
    let onCreatePlan: () -> Void
    let onCopyPrevious: () -> Void
    let onAddExercise: () -> Void

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

                Text(L10n.tr(descriptionKey))
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)

            // Action cards
            VStack(spacing: 12) {
                // Card A: Create Plan (Primary) - Always shown
                PlanActionCard(
                    badgeText: L10n.tr("empty_state_recommended"),
                    title: L10n.tr("empty_state_create_plan_title"),
                    subtitle: L10n.tr("empty_state_create_plan_subtitle"),
                    buttonText: L10n.tr("empty_state_create_plan_button"),
                    isPrimary: true,
                    action: onCreatePlan
                )

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
        .padding(.vertical, 40)
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
        Button(action: action) {
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
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
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
            .foregroundColor(Color.white.opacity(0.60))
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
