//
//  WorkoutView.swift
//  Routyra
//

import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutDay.date, order: .reverse) private var workoutDays: [WorkoutDay]
    @Query private var exercises: [Exercise]
    @Binding var navigateToHistory: Bool

    @State private var selectedDate: Date = Date()
    @State private var expandedEntryId: UUID?
    @State private var snackBarMessage: String?
    @State private var snackBarUndoAction: (() -> Void)?
    @State private var currentWeight: Double = 60
    @State private var currentReps: Int = 8
    @State private var showExercisePicker: Bool = false
    @State private var entryToChange: WorkoutExerciseEntry?
    @State private var profile: LocalProfile?

    // Cycle support
    @State private var activeCycle: PlanCycle?
    @State private var cycleStateInfo: (cycleName: String, planName: String, dayInfo: String)?

    private var isViewingToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var selectedWorkoutDay: WorkoutDay? {
        workoutDays.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
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
                let totalSets = workoutDay.entries.reduce(0) { $0 + $1.plannedSetCount }
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

    var body: some View {
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

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
                            let isExpanded = expandedEntryId == entry.id
                            let exerciseName = getExerciseName(for: entry.exerciseId)

                            ExerciseEntryCardView(
                                entry: entry,
                                exerciseName: exerciseName,
                                isExpanded: isExpanded,
                                currentWeight: $currentWeight,
                                currentReps: $currentReps,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedEntryId = isExpanded ? nil : entry.id
                                    }
                                },
                                onLogSet: {
                                    logSet(for: entry)
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
                                    entryToChange = entry
                                    showExercisePicker = true
                                }
                            )

                            if shouldShowAd(afterIndex: index) {
                                AdPlaceholderView()
                            }
                        }

                        if sortedEntries.isEmpty {
                            EmptyWorkoutView(onAddExercise: addSampleExercises)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
                .scrollDismissesKeyboard(.interactively)

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
        .onAppear {
            profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
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
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerSheet(
                currentName: entryToChange.flatMap { getExerciseName(for: $0.exerciseId) } ?? "",
                onSelect: { newName in
                    if let entry = entryToChange,
                       let exercise = exercises.first(where: { $0.name == newName }) {
                        entry.exerciseId = exercise.id
                    }
                    showExercisePicker = false
                },
                onCancel: {
                    showExercisePicker = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func getExerciseName(for exerciseId: UUID) -> String {
        exercises.first { $0.id == exerciseId }?.localizedName ?? "Unknown Exercise"
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
        activeCycle = CycleService.getActiveCycle(profileId: profile.id, modelContext: modelContext)

        if let cycle = activeCycle {
            cycleStateInfo = CycleService.getCurrentStateInfo(for: cycle, modelContext: modelContext)
        } else {
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

        // First check if we should setup from active cycle
        if let cycle = activeCycle,
           let (plan, planDay) = CycleService.getCurrentPlanDay(for: cycle, modelContext: modelContext) {
            setupWorkoutFromCycle(plan: plan, planDay: planDay)
            return
        }

        // Fall back to existing logic
        let todayWorkout = workoutDays.first { Calendar.current.isDateInToday($0.date) }
        if todayWorkout == nil {
            let workoutDay = WorkoutDay(profileId: profile.id, date: Date())
            modelContext.insert(workoutDay)
        }
    }

    private func setupWorkoutFromCycle(plan: WorkoutPlan, planDay: PlanDay) {
        guard let profile = profile else { return }

        // Check if workout already exists for today
        if let existingWorkout = workoutDays.first(where: { Calendar.current.isDateInToday($0.date) }) {
            // If it's already set up for this plan day, do nothing
            if existingWorkout.routineDayId == planDay.id {
                return
            }
        }

        // Create new workout day in plan mode
        let workoutDay = WorkoutService.getOrCreateWorkoutDay(
            profileId: profile.id,
            date: Date(),
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

    private func addSampleExercises() {
        guard let profile = profile else { return }

        if selectedWorkoutDay == nil {
            let workoutDay = WorkoutDay(profileId: profile.id, date: selectedDate)
            modelContext.insert(workoutDay)
        }

        guard let workoutDay = selectedWorkoutDay else { return }

        let exerciseNames = ["Bench Press", "Squat", "Deadlift", "Barbell Row"]
        for (index, name) in exerciseNames.enumerated() {
            if let exercise = exercises.first(where: { $0.name == name }) {
                let entry = WorkoutExerciseEntry(
                    exerciseId: exercise.id,
                    orderIndex: index,
                    source: .free,
                    plannedSetCount: 5
                )
                for setIndex in 1...5 {
                    let set = WorkoutSet(setIndex: setIndex, weight: Decimal(60), reps: 8)
                    entry.addSet(set)
                }
                workoutDay.addEntry(entry)
            }
        }

        if let first = workoutDay.sortedEntries.first {
            expandedEntryId = first.id
        }
    }

    private func addSet(to entry: WorkoutExerciseEntry) {
        let newSet = entry.createSet(weight: Decimal(currentWeight), reps: currentReps, isCompleted: true)

        showSnackBar(
            message: "Set added: \(formatWeight(currentWeight)) kg × \(currentReps)",
            undoAction: {
                newSet.softDelete()
            }
        )
    }

    private func logSet(for entry: WorkoutExerciseEntry) {
        guard let nextSet = entry.sortedSets.first(where: { !$0.isCompleted }) else { return }

        let previousWeight = nextSet.weight
        let previousReps = nextSet.reps
        let wasCompleted = nextSet.isCompleted

        nextSet.weight = Decimal(currentWeight)
        nextSet.reps = currentReps
        nextSet.complete()

        showSnackBar(
            message: "Set logged: \(formatWeight(currentWeight)) kg × \(currentReps)",
            undoAction: {
                nextSet.weight = previousWeight
                nextSet.reps = previousReps
                if !wasCompleted {
                    nextSet.uncomplete()
                }
            }
        )

        // Check if all sets for this entry are now completed
        let allSetsCompleted = entry.sortedSets.allSatisfy { $0.isCompleted }

        if allSetsCompleted {
            // Find the next incomplete entry
            if let nextEntry = sortedEntries.first(where: { !$0.isPlannedSetsCompleted && $0.id != entry.id }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        expandedEntryId = nextEntry.id
                    }
                }
            }
        }
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

    var body: some View {
        VStack(spacing: 16) {
            Text("No exercises yet")
                .font(.headline)
                .foregroundColor(AppColors.textSecondary)

            Button(action: onAddExercise) {
                Text("Add Sample Exercises")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppColors.accentBlue)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Exercise Picker Sheet

struct ExercisePickerSheet: View {
    let currentName: String
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""

    private let commonExercises = [
        "Bench Press",
        "Incline Bench Press",
        "Dumbbell Press",
        "Squat",
        "Front Squat",
        "Leg Press",
        "Deadlift",
        "Romanian Deadlift",
        "Barbell Row",
        "Lat Pulldown",
        "Pull Up",
        "Chin Up",
        "Overhead Press",
        "Dumbbell Shoulder Press",
        "Lateral Raise",
        "Bicep Curl",
        "Tricep Extension",
        "Cable Fly",
        "Leg Curl",
        "Leg Extension",
        "Calf Raise",
        "Plank",
        "Hip Thrust"
    ]

    private var filteredExercises: [String] {
        if searchText.isEmpty {
            return commonExercises
        }
        return commonExercises.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Search or enter custom name", text: $searchText)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty && !commonExercises.contains(where: { $0.localizedCaseInsensitiveCompare(searchText) == .orderedSame }) {
                        Button(action: {
                            onSelect(searchText)
                        }) {
                            HStack {
                                Text("Use \"\(searchText)\"")
                                    .foregroundColor(AppColors.accentBlue)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(AppColors.accentBlue)
                            }
                        }
                    }
                }

                Section("Common Exercises") {
                    ForEach(filteredExercises, id: \.self) { name in
                        Button(action: {
                            onSelect(name)
                        }) {
                            HStack {
                                Text(name)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if name == currentName {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.accentBlue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Change Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    WorkoutView(navigateToHistory: .constant(false))
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
