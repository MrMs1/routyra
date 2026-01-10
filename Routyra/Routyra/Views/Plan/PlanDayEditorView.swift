//
//  PlanDayEditorView.swift
//  Routyra
//
//  Editor for a single day's exercises.
//  Allows adding, editing, reordering, and deleting exercises.
//  Supports exercise groups (supersets/giant sets).
//

import SwiftUI
import SwiftData
import GoogleMobileAds
import HealthKit

// MARK: - Display Item

/// Unified display item for groups and ungrouped exercises
private enum DayDisplayItem: Identifiable {
    case group(PlanExerciseGroup)
    case exercise(PlanExercise)

    var id: String {
        switch self {
        case .group(let group): return "group-\(group.id)"
        case .exercise(let exercise): return "exercise-\(exercise.id)"
        }
    }

    var orderIndex: Int {
        switch self {
        case .group(let group): return group.orderIndex
        case .exercise(let exercise): return exercise.orderIndex
        }
    }
}

struct PlanDayEditorView: View {
    @Bindable var day: PlanDay
    let onChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode

    @State private var exercises: [PlanExercise] = []
    @State private var expandedExerciseId: UUID?
    @State private var profile: LocalProfile?

    // Cached lookups
    @State private var exercisesMap: [UUID: Exercise] = [:]
    @State private var bodyPartsMap: [UUID: BodyPart] = [:]

    // Sheet state
    @State private var showEditDaySheet: Bool = false
    @State private var showExercisePickerSheet: Bool = false
    @State private var showGroupCreationSheet: Bool = false
    @State private var editingExercise: PlanExercise? = nil

    // Workout sync confirmation
    @State private var pendingExerciseData: (exerciseId: UUID, sets: [SetInputData])? = nil
    @State private var linkedWorkoutDay: WorkoutDay? = nil
    @State private var showAddToWorkoutConfirmation: Bool = false

    // Ad manager
    @StateObject private var adManager = NativeAdManager()

    // MARK: - Computed Properties

    /// Build unified display items from groups and ungrouped exercises
    private var displayItems: [DayDisplayItem] {
        var items: [DayDisplayItem] = []

        // Add all groups
        for group in day.exerciseGroups {
            items.append(.group(group))
        }

        // Add ungrouped exercises
        for exercise in exercises where !exercise.isGrouped {
            items.append(.exercise(exercise))
        }

        // Sort by orderIndex
        return items.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Check if we can create a group (need 2+ ungrouped exercises)
    private var canCreateGroup: Bool {
        exercises.filter { !$0.isGrouped }.count >= 2
    }

    var body: some View {
        List {
            // Exercises section
            Section {
                if exercises.isEmpty {
                    emptyStateView
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(displayItems) { item in
                        switch item {
                        case .group(let group):
                            groupView(for: group)

                        case .exercise(let planExercise):
                            exerciseRow(for: planExercise)
                        }
                    }
                    .onMove(perform: moveDisplayItems)
                }

                // Action buttons (hidden during reorder mode)
                if !isReordering {
                    VStack(spacing: 8) {
                        // Add exercise button
                        Button {
                            showExercisePickerSheet = true
                        } label: {
                            ActionCardButton(title: L10n.tr("add_exercise"))
                        }
                        .buttonStyle(.plain)

                        // Create group button
                        if canCreateGroup {
                            Button {
                                showGroupCreationSheet = true
                            } label: {
                                ActionCardButton(
                                    title: L10n.tr("create_group"),
                                    icon: "rectangle.stack"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    // Show ad at bottom (outside ForEach to avoid reorder issues)
                    if shouldShowExerciseAd {
                        NativeAdCardView(nativeAd: adManager.nativeAds[0])
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            } header: {
                HStack {
                    Text("exercises")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text("\(exercises.count)\(L10n.tr("exercises_unit"))")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Button {
                        withAnimation {
                            editMode?.wrappedValue = editMode?.wrappedValue == .active ? .inactive : .active
                        }
                    } label: {
                        Text(editMode?.wrappedValue == .active ? L10n.tr("done") : L10n.tr("reorder"))
                            .font(.subheadline)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(day.fullTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("edit") {
                    showEditDaySheet = true
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showEditDaySheet) {
            EditDaySheetView(
                dayIndex: day.dayIndex,
                currentTitle: day.name,
                onSave: { newTitle in
                    day.name = newTitle
                    onChanged()
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showExercisePickerSheet) {
            ExerciseAddFlowView(
                dayTitle: day.fullTitle,
                day: day,
                exercisesMap: exercisesMap,
                bodyPartsMap: bodyPartsMap,
                onExerciseAdded: { exerciseId, sets in
                    addExercise(exerciseId: exerciseId, sets: sets)
                }
            )
        }
        .sheet(isPresented: $showGroupCreationSheet) {
            GroupCreationSheet(
                planDay: day,
                exercisesMap: exercisesMap,
                bodyPartsMap: bodyPartsMap,
                onCreateGroup: { selectedExercises, setCount, restSeconds in
                    createGroup(exercises: selectedExercises, setCount: setCount, restSeconds: restSeconds)
                }
            )
        }
        .sheet(item: $editingExercise) { planExercise in
            PlanExerciseSetEditorSheet(
                planExercise: planExercise,
                exercisesMap: exercisesMap,
                bodyPartsMap: bodyPartsMap,
                onSave: {
                    syncExercises()
                    syncExerciseToLinkedWorkout(planExercise)
                    onChanged()
                }
            )
        }
        .alert(
            L10n.tr("add_to_workout_title"),
            isPresented: $showAddToWorkoutConfirmation
        ) {
            Button(L10n.tr("add_to_workout_confirm")) {
                if let pending = pendingExerciseData,
                   let workoutDay = linkedWorkoutDay {
                    addExerciseToWorkout(
                        exerciseId: pending.exerciseId,
                        sets: pending.sets,
                        workoutDay: workoutDay
                    )
                }
                pendingExerciseData = nil
                linkedWorkoutDay = nil
            }
            Button(L10n.tr("add_to_plan_only"), role: .cancel) {
                pendingExerciseData = nil
                linkedWorkoutDay = nil
            }
        } message: {
            Text(L10n.tr("add_to_workout_message"))
        }
        .onAppear {
            loadData()
            syncExercises()
            // Load ads
            if adManager.nativeAds.isEmpty {
                adManager.loadNativeAds(count: 3)
            }
        }
    }

    // MARK: - Ad Helpers

    private var isReordering: Bool {
        editMode?.wrappedValue == .active
    }

    /// Show ad at bottom (outside ForEach to avoid reorder issues)
    private var shouldShowExerciseAd: Bool {
        guard !(profile?.isPremiumUser ?? false) else { return false }
        guard !adManager.nativeAds.isEmpty else { return false }
        return true
    }

    // MARK: - Group View

    @ViewBuilder
    private func groupView(for group: PlanExerciseGroup) -> some View {
        // Group header
        PlanExerciseGroupCardView(
            group: group,
            exercisesMap: exercisesMap,
            bodyPartsMap: bodyPartsMap,
            onDissolve: {
                dissolveGroup(group)
            },
            onUpdateSetCount: { newCount in
                updateGroupSetCount(group, to: newCount)
            },
            onUpdateRest: { newRest in
                updateGroupRest(group, to: newRest)
            }
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 2, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)

        // Grouped exercises (indented)
        ForEach(group.sortedExercises, id: \.id) { planExercise in
            groupedExerciseRow(for: planExercise, in: group)
        }
    }

    @ViewBuilder
    private func groupedExerciseRow(for planExercise: PlanExercise, in group: PlanExerciseGroup) -> some View {
        let exercise = exercisesMap[planExercise.exerciseId]
        let bodyPartId = exercise?.bodyPartId
        let bodyPart = bodyPartId.flatMap { bodyPartsMap[$0] }

        PlanExerciseRowView(
            planExercise: planExercise,
            exercise: exercise,
            bodyPart: bodyPart,
            isExpanded: expandedExerciseId == planExercise.id,
            isGrouped: true,
            onToggleExpand: {
                toggleExerciseExpansion(planExercise.id)
            },
            onDelete: {
                removeExerciseFromGroup(planExercise, group: group)
            },
            onDuplicate: {
                duplicateExercise(planExercise)
            },
            onEditSets: {
                editingExercise = planExercise
            },
            weightUnit: profile?.effectiveWeightUnit ?? .kg
        )
        .listRowInsets(EdgeInsets(top: 2, leading: 32, bottom: 2, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .moveDisabled(true)
    }

    // MARK: - Exercise Row

    @ViewBuilder
    private func exerciseRow(for planExercise: PlanExercise) -> some View {
        let exercise = exercisesMap[planExercise.exerciseId]
        let bodyPartId = exercise?.bodyPartId
        let bodyPart = bodyPartId.flatMap { bodyPartsMap[$0] }

        PlanExerciseRowView(
            planExercise: planExercise,
            exercise: exercise,
            bodyPart: bodyPart,
            isExpanded: expandedExerciseId == planExercise.id,
            isGrouped: false,
            onToggleExpand: {
                toggleExerciseExpansion(planExercise.id)
            },
            onDelete: {
                deleteExercise(planExercise)
            },
            onDuplicate: {
                duplicateExercise(planExercise)
            },
            onEditSets: {
                editingExercise = planExercise
            },
            weightUnit: profile?.effectiveWeightUnit ?? .kg
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteExercise(planExercise)
            } label: {
                Label("delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textMuted)

            Text("no_exercises")
                .font(.headline)
                .foregroundColor(AppColors.textSecondary)

            Text("plan_day_add_exercise_hint")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Actions

    private func toggleExerciseExpansion(_ id: UUID) {
        if expandedExerciseId == id {
            expandedExerciseId = nil
        } else {
            expandedExerciseId = id
        }
    }

    // MARK: - Group Actions

    private func createGroup(exercises: [PlanExercise], setCount: Int, restSeconds: Int?) {
        if let group = GroupService.createGroup(
            in: day,
            exercises: exercises,
            setCount: setCount,
            roundRestSeconds: restSeconds,
            modelContext: modelContext
        ) {
            syncGroupToLinkedWorkout(group, resyncSets: true)
        }
        syncExercises()
        onChanged()
    }

    private func dissolveGroup(_ group: PlanExerciseGroup) {
        dissolveGroupInLinkedWorkout(group)
        GroupService.dissolveGroup(group, in: day, modelContext: modelContext)
        syncExercises()
        onChanged()
    }

    private func updateGroupSetCount(_ group: PlanExerciseGroup, to newCount: Int) {
        GroupService.updateGroupSetCount(group, to: newCount)
        syncGroupToLinkedWorkout(group, resyncSets: true)
        syncExercises()
        onChanged()
    }

    private func updateGroupRest(_ group: PlanExerciseGroup, to newRest: Int?) {
        group.roundRestSeconds = newRest
        syncGroupToLinkedWorkout(group, resyncSets: false)
        syncExercises()
        onChanged()
    }

    private func removeExerciseFromGroup(_ exercise: PlanExercise, group: PlanExerciseGroup) {
        let shouldDissolve = group.exercises.count <= 2
        GroupService.removeExerciseFromGroup(exercise, group: group, in: day, modelContext: modelContext)
        if shouldDissolve {
            dissolveGroupInLinkedWorkout(group)
        } else {
            syncGroupToLinkedWorkout(group, resyncSets: false)
        }
        syncExercises()
        onChanged()
    }

    // MARK: - Exercise Actions

    private func addExercise(exerciseId: UUID, sets: [SetInputData]) {
        // Determine base metricType from first set, defaulting to weightReps
        let baseMetricType = sets.first?.metricType ?? .weightReps
        let planExercise = day.createExercise(exerciseId: exerciseId, metricType: baseMetricType, plannedSetCount: sets.count)

        // Add planned sets with values from user input (each set has its own metricType)
        for setData in sets {
            // For bodyweightReps, force weight=nil (don't infer from 0kg)
            let weight: Double? = setData.metricType == .bodyweightReps ? nil : setData.weight
            planExercise.createPlannedSet(
                metricType: setData.metricType,
                weight: weight,
                reps: setData.reps,
                durationSeconds: setData.durationSeconds,
                distanceMeters: setData.distanceMeters,
                restTimeSeconds: setData.restTimeSeconds
            )
        }

        syncExercises()
        loadLookupData()

        // Auto-expand the newly added exercise
        expandedExerciseId = planExercise.id
        onChanged()

        // Check if today's workout is linked to this plan day
        guard let profile = profile else { return }

        if let workoutDay = WorkoutService.getTodayWorkoutLinkedToPlanDay(
            profileId: profile.id,
            planDayId: day.id,
            modelContext: modelContext
        ) {
            pendingExerciseData = (exerciseId: exerciseId, sets: sets)
            linkedWorkoutDay = workoutDay
            showAddToWorkoutConfirmation = true
        }
    }

    private func addExerciseToWorkout(
        exerciseId: UUID,
        sets: [SetInputData],
        workoutDay: WorkoutDay
    ) {
        // Safety guard: don't create empty entries
        guard !sets.isEmpty else { return }

        let exercise = exercisesMap[exerciseId] ?? {
            let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == exerciseId })
            return try? modelContext.fetch(descriptor).first
        }()

        let bodyPart = exercise?.bodyPartId.flatMap { bodyPartId in
            bodyPartsMap[bodyPartId] ?? {
                let descriptor = FetchDescriptor<BodyPart>(predicate: #Predicate { $0.id == bodyPartId })
                return try? modelContext.fetch(descriptor).first
            }()
        }

        if let exercise = exercise,
           let bodyPart = bodyPart,
           bodyPart.code == "cardio" {
            addCardioWorkoutsToWorkout(
                exercise: exercise,
                sets: sets,
                workoutDay: workoutDay
            )
            return
        }

        let metricType = sets.first?.metricType ?? .weightReps

        let entry = WorkoutService.addEntry(
            to: workoutDay,
            exerciseId: exerciseId,
            metricType: metricType,
            plannedSetCount: sets.count,
            source: .routine
        )

        for (index, setData) in sets.enumerated() {
            // For bodyweightReps, force weight=nil (consistent with plan)
            let weight: Decimal? = setData.metricType == .bodyweightReps ? nil : setData.weight.map { Decimal($0) }
            let set = WorkoutSet(
                setIndex: index + 1,
                metricType: setData.metricType,
                weight: weight,
                reps: setData.reps,
                durationSeconds: setData.durationSeconds,
                distanceMeters: setData.distanceMeters,
                isCompleted: false
            )
            entry.addSet(set)
        }

        try? modelContext.save()
    }

    private func addCardioWorkoutsToWorkout(
        exercise: Exercise,
        sets: [SetInputData],
        workoutDay: WorkoutDay
    ) {
        let activityType = CardioActivityTypeResolver.activityType(for: exercise)
        var nextOrderIndex = nextCardioOrderIndex(for: workoutDay.id)

        for setData in sets {
            let durationSeconds = setData.durationSeconds ?? 0
            let distanceMeters = setData.distanceMeters
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

        try? modelContext.save()
    }

    private func nextCardioOrderIndex(for workoutDayId: UUID) -> Int {
        let descriptor = FetchDescriptor<CardioWorkout>(
            predicate: #Predicate<CardioWorkout> { $0.workoutDayId == workoutDayId },
            sortBy: [SortDescriptor(\.orderIndex, order: .reverse)]
        )
        let maxExisting = (try? modelContext.fetch(descriptor).first?.orderIndex) ?? -1
        return maxExisting + 1
    }

    // MARK: - Workout Group Sync

    private func linkedWorkoutDayForSync() -> WorkoutDay? {
        guard let profile = profile else { return nil }
        return WorkoutService.getTodayWorkoutLinkedToPlanDay(
            profileId: profile.id,
            planDayId: day.id,
            modelContext: modelContext
        )
    }

    private func findWorkoutEntry(
        for planExercise: PlanExercise,
        in workoutDay: WorkoutDay
    ) -> WorkoutExerciseEntry? {
        workoutDay.entries.first {
            $0.exerciseId == planExercise.exerciseId && $0.orderIndex == planExercise.orderIndex
        }
    }

    private func findWorkoutGroup(
        for planGroup: PlanExerciseGroup,
        in workoutDay: WorkoutDay,
        matchingEntries: [WorkoutExerciseEntry]
    ) -> WorkoutExerciseGroup? {
        let entryIds = Set(matchingEntries.map(\.id))
        if !entryIds.isEmpty {
            if let group = workoutDay.exerciseGroups.first(where: { group in
                group.entries.contains { entryIds.contains($0.id) }
            }) {
                return group
            }
        }
        return workoutDay.exerciseGroups.first { $0.orderIndex == planGroup.orderIndex }
    }

    private func syncExerciseToLinkedWorkout(_ planExercise: PlanExercise) {
        guard let workoutDay = linkedWorkoutDayForSync(),
              workoutDay.totalCompletedSets == 0,
              let entry = findWorkoutEntry(for: planExercise, in: workoutDay) else {
            return
        }

        resetWorkoutEntry(entry, to: planExercise)
        try? modelContext.save()
    }

    private func syncGroupToLinkedWorkout(_ planGroup: PlanExerciseGroup, resyncSets: Bool) {
        guard let workoutDay = linkedWorkoutDayForSync() else { return }
        let shouldResyncSets = resyncSets && workoutDay.totalCompletedSets == 0

        let matchedPairs: [(PlanExercise, WorkoutExerciseEntry)] = planGroup.sortedExercises.compactMap { planExercise in
            guard let entry = findWorkoutEntry(for: planExercise, in: workoutDay) else { return nil }
            return (planExercise, entry)
        }

        guard matchedPairs.count >= 2 else { return }

        let entries = matchedPairs.map(\.1)
        let workoutGroup = findWorkoutGroup(
            for: planGroup,
            in: workoutDay,
            matchingEntries: entries
        ) ?? {
            let group = WorkoutExerciseGroup(
                orderIndex: planGroup.orderIndex,
                setCount: planGroup.setCount,
                roundRestSeconds: planGroup.roundRestSeconds
            )
            workoutDay.exerciseGroups.append(group)
            modelContext.insert(group)
            return group
        }()

        workoutGroup.orderIndex = planGroup.orderIndex
        workoutGroup.setCount = planGroup.setCount
        workoutGroup.roundRestSeconds = planGroup.roundRestSeconds

        let entryIds = Set(entries.map(\.id))

        for entry in workoutGroup.entries where !entryIds.contains(entry.id) {
            entry.group = nil
            entry.groupOrderIndex = nil
        }
        workoutGroup.entries.removeAll { !entryIds.contains($0.id) }

        for (planExercise, entry) in matchedPairs {
            entry.group = workoutGroup
            entry.groupOrderIndex = planExercise.groupOrderIndex
            if shouldResyncSets {
                resetWorkoutEntry(entry, to: planExercise)
            }
            if !workoutGroup.entries.contains(where: { $0.id == entry.id }) {
                workoutGroup.entries.append(entry)
            }
        }

        try? modelContext.save()
    }

    private func dissolveGroupInLinkedWorkout(_ planGroup: PlanExerciseGroup) {
        guard let workoutDay = linkedWorkoutDayForSync() else { return }

        let matchingEntries = planGroup.sortedExercises.compactMap { planExercise in
            findWorkoutEntry(for: planExercise, in: workoutDay)
        }

        guard let workoutGroup = findWorkoutGroup(
            for: planGroup,
            in: workoutDay,
            matchingEntries: matchingEntries
        ) else {
            return
        }

        for entry in workoutGroup.entries {
            entry.group = nil
            entry.groupOrderIndex = nil
        }

        workoutGroup.entries.removeAll()
        workoutDay.exerciseGroups.removeAll { $0.id == workoutGroup.id }
        modelContext.delete(workoutGroup)

        try? modelContext.save()
    }

    private func resetWorkoutEntry(_ entry: WorkoutExerciseEntry, to planExercise: PlanExercise) {
        for set in entry.sets {
            modelContext.delete(set)
        }
        entry.sets.removeAll()
        entry.metricType = planExercise.metricType

        let plannedSets = planExercise.sortedPlannedSets
        let effectiveSetCount = plannedSets.isEmpty ? planExercise.plannedSetCount : plannedSets.count
        entry.plannedSetCount = effectiveSetCount

        if plannedSets.isEmpty {
            if effectiveSetCount > 0 {
                entry.createPlaceholderSets()
            }
            return
        }

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
    }

    private func deleteExercise(_ planExercise: PlanExercise) {
        day.removeExercise(planExercise)
        day.reindexExercises()
        syncExercises()
        onChanged()
    }

    private func duplicateExercise(_ planExercise: PlanExercise) {
        let newExercise = PlanExercise(
            exerciseId: planExercise.exerciseId,
            orderIndex: (day.exercises.map(\.orderIndex).max() ?? -1) + 1,
            metricType: planExercise.metricType,
            plannedSetCount: planExercise.plannedSetCount
        )

        // Copy planned sets (preserve individual metricType and rest time)
        for plannedSet in planExercise.sortedPlannedSets {
            newExercise.createPlannedSet(
                metricType: plannedSet.metricType,
                weight: plannedSet.targetWeight,
                reps: plannedSet.targetReps,
                durationSeconds: plannedSet.targetDurationSeconds,
                distanceMeters: plannedSet.targetDistanceMeters,
                restTimeSeconds: plannedSet.restTimeSeconds
            )
        }

        day.addExercise(newExercise)
        syncExercises()
        onChanged()
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)

        // Reindex all exercises
        for (index, exercise) in exercises.enumerated() {
            exercise.orderIndex = index
        }

        try? modelContext.save()
        onChanged()
    }

    private func moveDisplayItems(from source: IndexSet, to destination: Int) {
        var items = displayItems
        items.move(fromOffsets: source, toOffset: destination)

        for (index, item) in items.enumerated() {
            switch item {
            case .group(let group):
                group.orderIndex = index
            case .exercise(let exercise):
                exercise.orderIndex = index
            }
        }

        try? modelContext.save()
        syncExercises()
        onChanged()
    }

    private func syncExercises() {
        exercises = day.sortedExercises
    }

    private func loadData() {
        profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
        loadLookupData()
    }

    private func loadLookupData() {
        // Load exercises
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        if let allExercises = try? modelContext.fetch(exerciseDescriptor) {
            exercisesMap = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })
        }

        // Load body parts
        let bodyPartDescriptor = FetchDescriptor<BodyPart>()
        if let bodyParts = try? modelContext.fetch(bodyPartDescriptor) {
            bodyPartsMap = Dictionary(uniqueKeysWithValues: bodyParts.map { ($0.id, $0) })
        }
    }
}

// MARK: - Plan Exercise Set Editor Sheet

/// Sheet for editing sets of an existing exercise
private struct PlanExerciseSetEditorSheet: View {
    let planExercise: PlanExercise
    let exercisesMap: [UUID: Exercise]
    let bodyPartsMap: [UUID: BodyPart]
    let onSave: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var profile: LocalProfile?

    private var exercise: Exercise? {
        exercisesMap[planExercise.exerciseId]
    }

    private var bodyPart: BodyPart? {
        guard let bodyPartId = exercise?.bodyPartId else { return nil }
        return bodyPartsMap[bodyPartId]
    }

    private var existingSets: [SetInputData] {
        planExercise.sortedPlannedSets.map { plannedSet in
            SetInputData(
                metricType: plannedSet.metricType,
                weight: plannedSet.targetWeight,
                reps: plannedSet.targetReps,
                durationSeconds: plannedSet.targetDurationSeconds,
                distanceMeters: plannedSet.targetDistanceMeters
            )
        }
    }

    var body: some View {
        NavigationStack {
            if let exercise = exercise {
                SetEditorView(
                    exercise: exercise,
                    bodyPart: bodyPart,
                    metricType: planExercise.metricType,
                    existingSets: existingSets.isEmpty
                        ? [SetInputData(metricType: planExercise.metricType, weight: 60, reps: 10)]
                        : existingSets,
                    config: .planEdit,
                    candidateCollection: buildCandidateCollection(),
                    onConfirm: { newSets in
                        updateSets(newSets)
                        onSave()
                        dismiss()
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("cancel") {
                            dismiss()
                        }
                    }
                }
            } else {
                Text("exercise_not_found")
                    .foregroundColor(AppColors.textMuted)
            }
        }
        .onAppear {
            if profile == nil {
                profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
            }
        }
    }

    private func buildCandidateCollection() -> CopyCandidateCollection {
        let exerciseId = planExercise.exerciseId
        guard let currentDay = planExercise.planDay,
              let currentPlan = currentDay.plan else {
            return .empty
        }

        var planCandidates: [PlanCopyCandidate] = []
        var workoutCandidates: [WorkoutCopyCandidate] = []

        // Priority order:
        // 1. Same Day's matching exercises (highest priority)
        // 2. Same Plan's other Days
        // 3. Other Plans

        // 1. Same Day candidates (excluding current exercise)
        let sameDayExercises = currentDay.sortedExercises
            .filter { $0.exerciseId == exerciseId && $0.id != planExercise.id }
        for planEx in sameDayExercises {
            let sets = planEx.sortedPlannedSets.map {
                CopyableSetData(weight: $0.targetWeight ?? 60.0, reps: $0.targetReps ?? 10, restTimeSeconds: $0.restTimeSeconds)
            }
            if !sets.isEmpty {
                planCandidates.append(PlanCopyCandidate(
                    planId: currentPlan.id,
                    planName: currentPlan.name,
                    dayId: currentDay.id,
                    dayName: currentDay.fullTitle,
                    sets: sets,
                    updatedAt: currentPlan.updatedAt,
                    isCurrentPlan: true
                ))
            }
        }

        // 2. Same Plan's other Days
        for day in currentPlan.sortedDays where day.id != currentDay.id {
            let matchingExercises = day.sortedExercises.filter { $0.exerciseId == exerciseId }
            for planEx in matchingExercises {
                let sets = planEx.sortedPlannedSets.map {
                    CopyableSetData(weight: $0.targetWeight ?? 60.0, reps: $0.targetReps ?? 10, restTimeSeconds: $0.restTimeSeconds)
                }
                if !sets.isEmpty {
                    planCandidates.append(PlanCopyCandidate(
                        planId: currentPlan.id,
                        planName: currentPlan.name,
                        dayId: day.id,
                        dayName: day.fullTitle,
                        sets: sets,
                        updatedAt: currentPlan.updatedAt,
                        isCurrentPlan: true
                    ))
                }
            }
        }

        // 3. Other Plans (sorted by updatedAt desc)
        let descriptor = FetchDescriptor<WorkoutPlan>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        if let allPlans = try? modelContext.fetch(descriptor) {
            for plan in allPlans where plan.id != currentPlan.id {
                for day in plan.sortedDays {
                    let matchingExercises = day.sortedExercises.filter { $0.exerciseId == exerciseId }
                    for planEx in matchingExercises {
                        let sets = planEx.sortedPlannedSets.map {
                            CopyableSetData(weight: $0.targetWeight ?? 60.0, reps: $0.targetReps ?? 10, restTimeSeconds: $0.restTimeSeconds)
                        }
                        if !sets.isEmpty {
                            planCandidates.append(PlanCopyCandidate(
                                planId: plan.id,
                                planName: plan.name,
                                dayId: day.id,
                                dayName: day.fullTitle,
                                sets: sets,
                                updatedAt: plan.updatedAt,
                                isCurrentPlan: false
                            ))
                        }
                    }
                }
            }
        }

        // Array is already in priority order, limit to 20 candidates
        planCandidates = Array(planCandidates.prefix(20))

        // 3. Collect workout history candidates
        if let profile = profile {
            workoutCandidates = WorkoutService.getWorkoutHistorySets(
                profileId: profile.id,
                exerciseId: exerciseId,
                limit: 20,
                modelContext: modelContext
            )
        }

        return CopyCandidateCollection(
            planCandidates: planCandidates,
            workoutCandidates: workoutCandidates
        )
    }

    private func updateSets(_ newSets: [SetInputData]) {
        // Remove existing sets
        let existingSets = planExercise.sortedPlannedSets
        for set in existingSets {
            planExercise.removePlannedSet(set)
        }

        // Add new sets with all metric type fields including rest time
        for setData in newSets {
            planExercise.createPlannedSet(
                metricType: setData.metricType,
                weight: setData.weight,
                reps: setData.reps,
                durationSeconds: setData.durationSeconds,
                distanceMeters: setData.distanceMeters,
                restTimeSeconds: setData.restTimeSeconds
            )
        }

        planExercise.plannedSetCount = newSets.count
    }
}

// MARK: - Exercise Add Flow View

/// Sheet-based flow for adding exercises: Picker → Set Editor → Confirm
private struct ExerciseAddFlowView: View {
    let dayTitle: String
    let day: PlanDay?
    let exercisesMap: [UUID: Exercise]
    let bodyPartsMap: [UUID: BodyPart]
    let onExerciseAdded: (UUID, [SetInputData]) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var profile: LocalProfile?
    @State private var selectedExercise: Exercise?

    var body: some View {
        NavigationStack {
            Group {
                if let profile = profile {
                    if let exercise = selectedExercise {
                        let bodyPart = exercise.bodyPartId.flatMap { bodyPartsMap[$0] }
                        if bodyPart?.code == "cardio" {
                            CardioTimeDistanceEntryView { durationSeconds, distanceMeters in
                                let sets = [
                                    SetInputData(
                                        metricType: .timeDistance,
                                        durationSeconds: durationSeconds,
                                        distanceMeters: distanceMeters
                                    )
                                ]
                                onExerciseAdded(exercise.id, sets)
                                dismiss()
                            }
                        } else {
                            // Step 2: Set Editor
                            SetEditorView(
                                exercise: exercise,
                                bodyPart: bodyPart,
                                metricType: exercise.defaultMetricType,
                                initialWeight: 60,
                                initialReps: 10,
                                initialRestTimeSeconds: profile.defaultRestTimeSeconds,
                                config: .plan,
                                candidateCollection: buildCandidateCollection(for: exercise, profile: profile),
                                onConfirm: { sets in
                                    onExerciseAdded(exercise.id, sets)
                                    dismiss()
                                }
                            )
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button {
                                        selectedExercise = nil
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "chevron.left")
                                            Text("back")
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // Step 1: Exercise Picker
                        ExercisePickerView(
                            profile: profile,
                            dayTitle: dayTitle,
                            autoDismiss: false,
                            onSelect: { exercise in
                                selectedExercise = exercise
                            }
                        )
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("cancel") {
                                    dismiss()
                                }
                            }
                        }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            if profile == nil {
                profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
            }
        }
    }

    private func buildCandidateCollection(for exercise: Exercise, profile: LocalProfile) -> CopyCandidateCollection {
        let exerciseId = exercise.id
        guard let currentDay = day,
              let currentPlan = currentDay.plan else {
            return .empty
        }

        var planCandidates: [PlanCopyCandidate] = []
        var workoutCandidates: [WorkoutCopyCandidate] = []

        // 1. Collect all plan candidates from current plan
        for planDay in currentPlan.sortedDays {
            let matchingExercises = planDay.sortedExercises.filter { $0.exerciseId == exerciseId }
            for planEx in matchingExercises {
                let sets = planEx.sortedPlannedSets.map {
                    CopyableSetData(weight: $0.targetWeight ?? 60.0, reps: $0.targetReps ?? 10, restTimeSeconds: $0.restTimeSeconds)
                }
                if !sets.isEmpty {
                    planCandidates.append(PlanCopyCandidate(
                        planId: currentPlan.id,
                        planName: currentPlan.name,
                        dayId: planDay.id,
                        dayName: planDay.fullTitle,
                        sets: sets,
                        updatedAt: currentPlan.updatedAt,
                        isCurrentPlan: true
                    ))
                }
            }
        }

        // 2. Collect plan candidates from other plans
        let descriptor = FetchDescriptor<WorkoutPlan>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        if let allPlans = try? modelContext.fetch(descriptor) {
            for plan in allPlans where plan.id != currentPlan.id {
                for planDay in plan.sortedDays {
                    let matchingExercises = planDay.sortedExercises.filter { $0.exerciseId == exerciseId }
                    for planEx in matchingExercises {
                        let sets = planEx.sortedPlannedSets.map {
                            CopyableSetData(weight: $0.targetWeight ?? 60.0, reps: $0.targetReps ?? 10, restTimeSeconds: $0.restTimeSeconds)
                        }
                        if !sets.isEmpty {
                            planCandidates.append(PlanCopyCandidate(
                                planId: plan.id,
                                planName: plan.name,
                                dayId: planDay.id,
                                dayName: planDay.fullTitle,
                                sets: sets,
                                updatedAt: plan.updatedAt,
                                isCurrentPlan: false
                            ))
                        }
                    }
                }
            }
        }

        // Sort: current plan first, then by updatedAt desc
        planCandidates.sort { lhs, rhs in
            if lhs.isCurrentPlan != rhs.isCurrentPlan {
                return lhs.isCurrentPlan
            }
            return lhs.updatedAt > rhs.updatedAt
        }

        // Limit to 20 candidates
        planCandidates = Array(planCandidates.prefix(20))

        // 3. Collect workout history candidates
        workoutCandidates = WorkoutService.getWorkoutHistorySets(
            profileId: profile.id,
            exerciseId: exerciseId,
            limit: 20,
            modelContext: modelContext
        )

        return CopyCandidateCollection(
            planCandidates: planCandidates,
            workoutCandidates: workoutCandidates
        )
    }
}

#Preview {
    NavigationStack {
        let day = PlanDay(dayIndex: 1, name: "胸・三頭")
        let exercise1 = PlanExercise(exerciseId: UUID(), orderIndex: 0, plannedSetCount: 3)
        exercise1.createPlannedSet(weight: 60, reps: 10)
        exercise1.createPlannedSet(weight: 60, reps: 10)
        exercise1.createPlannedSet(weight: 60, reps: 8)
        day.addExercise(exercise1)

        let exercise2 = PlanExercise(exerciseId: UUID(), orderIndex: 1, plannedSetCount: 3)
        day.addExercise(exercise2)

        return PlanDayEditorView(day: day, onChanged: {})
            .modelContainer(for: [
                PlanDay.self,
                PlanExercise.self,
                PlannedSet.self,
                Exercise.self,
                BodyPart.self,
                BodyPartTranslation.self,
                ExerciseTranslation.self,
                LocalProfile.self
            ], inMemory: true)
    }
    .preferredColorScheme(.dark)
}
