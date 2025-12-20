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

    private var transitionHour: Int {
        profile?.dayTransitionHour ?? 3
    }

    private var todayWorkoutDate: Date {
        DateUtilities.todayWorkoutDate(transitionHour: transitionHour)
    }

    private var isViewingToday: Bool {
        DateUtilities.isSameWorkoutDay(selectedDate, Date(), transitionHour: transitionHour)
    }

    private var selectedWorkoutDay: WorkoutDay? {
        workoutDays.first { DateUtilities.isSameWorkoutDay($0.date, selectedDate, transitionHour: transitionHour) }
    }

    private var sortedEntries: [WorkoutExerciseEntry] {
        selectedWorkoutDay?.sortedEntries ?? []
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

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) {
                AppColors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    WorkoutHeaderView(
                        date: selectedDate,
                        streakCount: 12,
                        isViewingToday: isViewingToday,
                        onDateTap: handleDateTap
                    )

                    // Cycle context (when active cycle exists and viewing today)
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

                                if sortedEntries.isEmpty {
                                    EmptyWorkoutView(
                                        onAddExercise: {
                                            navigationPath.append(WorkoutDestination.exercisePicker)
                                        },
                                        onCreatePlan: {
                                            navigateToRoutines = true
                                        }
                                    )
                                } else {
                                    // Add exercise card at bottom of list
                                    AddExerciseCard {
                                        navigationPath.append(WorkoutDestination.exercisePicker)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, UIScreen.main.bounds.height * 0.6)
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }

                    Spacer(minLength: 0)
                }

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

                    BottomStatusBarView(
                        sets: selectedWorkoutDay?.totalCompletedSets ?? 0,
                        exercises: selectedWorkoutDay?.totalExercisesWithSets ?? 0,
                        volume: Double(truncating: (selectedWorkoutDay?.totalVolume ?? 0) as NSNumber)
                    )
                }
            }
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
    }

    private func getExerciseName(for exerciseId: UUID) -> String {
        exercises.first { $0.id == exerciseId }?.localizedName ?? "Unknown Exercise"
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
        if isViewingToday {
            navigateToHistory = true
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = Date()
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
            message: "次のワークアウトに進みました",
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
            if existingWorkout.routineDayId == planDay.id {
                return
            }
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

        let workoutDate = DateUtilities.workoutDate(for: selectedDate, transitionHour: transitionHour)

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
        set.softDelete()

        showSnackBar(
            message: "Planned set removed",
            undoAction: {
                set.restore()
            }
        )
    }

    private func deleteCompletedSet(_ set: WorkoutSet, from entry: WorkoutExerciseEntry) {
        let deletedWeight = set.weightDouble
        let deletedReps = set.reps

        set.softDelete()

        showSnackBar(
            message: "Set deleted: \(formatWeight(deletedWeight)) kg × \(deletedReps)",
            undoAction: {
                set.restore()
            }
        )
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

struct EmptyWorkoutView: View {
    let onAddExercise: () -> Void
    let onCreatePlan: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("種目がありません")
                .font(.headline)
                .foregroundColor(AppColors.textSecondary)

            Button(action: onAddExercise) {
                Text("種目を追加")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppColors.accentBlue)
                    .cornerRadius(10)
            }

            Button(action: onCreatePlan) {
                Text("またはワークアウトプランを作成する")
                    .font(.caption)
                    .foregroundColor(AppColors.accentBlue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
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
                Text("種目を追加")
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
