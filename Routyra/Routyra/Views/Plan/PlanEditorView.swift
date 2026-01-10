//
//  PlanEditorView.swift
//  Routyra
//
//  Main editor view for creating and editing workout plans.
//  Days can be expanded to view exercises. Edit via edit button on each day.
//

import SwiftUI
import SwiftData
import GoogleMobileAds

/// Navigation destination types for plan editor
enum PlanEditorDestination: Hashable {
    case dayEditor(dayId: UUID)
}

struct PlanEditorView: View {
    @Bindable var plan: WorkoutPlan
    let allowEmptyPlan: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode

    // Navigation to day editor after creation
    @State private var navigateToDayId: UUID?

    // Sheet states
    @State private var showEditPlanSheet: Bool = false
    @State private var editingDay: PlanDay? = nil
    @State private var editingExercise: PlanExercise? = nil

    // New day dialog
    @State private var showNewDayAlert: Bool = false
    @State private var newDayName: String = ""

    // For day display and reordering
    @State private var days: [PlanDay] = []
    @State private var expandedDayIds: Set<UUID> = []

    // Cached lookups for exercise display
    @State private var exercisesMap: [UUID: Exercise] = [:]
    @State private var bodyPartsMap: [UUID: BodyPart] = [:]

    // Profile for settings access
    @State private var profile: LocalProfile?

    // Ad manager
    @StateObject private var adManager = NativeAdManager()

    // Spotlight for Add Day button (first-time only)
    @AppStorage("hasShownPlanAddDaySpotlight") private var hasShownPlanAddDaySpotlight = false
    @State private var showAddDaySpotlight = false
    @State private var addDayButtonFrame: CGRect = .zero

    /// Whether we're in reorder mode (EditMode active)
    private var isReordering: Bool {
        editMode?.wrappedValue == .active
    }

    init(plan: WorkoutPlan, allowEmptyPlan: Bool = false) {
        self._plan = Bindable(plan)
        self.allowEmptyPlan = allowEmptyPlan
    }

    var body: some View {
        List {
            // Compact memo section (only shown if memo exists)
            if let note = plan.note, !note.isEmpty {
                Section {
                    memoCard
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            // Days section
            Section {
                ForEach(days) { day in
                    PlanDayCardView(
                        day: day,
                        exercises: exercisesMap,
                        bodyParts: bodyPartsMap,
                        isExpanded: isReordering ? false : expandedDayIds.contains(day.id),
                        editDestination: PlanEditorDestination.dayEditor(dayId: day.id),
                        onToggleExpand: {
                            // Disable expansion during reorder mode
                            if !isReordering {
                                toggleDayExpansion(day.id)
                            }
                        },
                        onEditExerciseSets: { planExercise in
                            editingExercise = planExercise
                        },
                        weightUnit: profile?.effectiveWeightUnit ?? .kg
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .contextMenu {
                        Button {
                            editingDay = day
                        } label: {
                            Label("rename_day", systemImage: "pencil")
                        }

                        Button {
                            duplicateDay(day)
                        } label: {
                            Label("duplicate_day", systemImage: "doc.on.doc")
                        }

                        Button(role: .destructive) {
                            deleteDay(day)
                        } label: {
                            Label("delete_day", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteDay(day)
                        } label: {
                            Label("delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            editingDay = day
                        } label: {
                            Label("rename_day", systemImage: "pencil")
                        }
                        .tint(AppColors.accentBlue)
                    }
                }
                .onMove(perform: moveDays)

                // Add day button (hidden during reorder mode)
                if !isReordering {
                    Button {
                        showNewDayDialog()
                    } label: {
                        ActionCardButton(title: L10n.tr("add_day"), showChevron: false)
                            .overlay(
                                GeometryReader { proxy in
                                    Color.clear
                                        .onAppear {
                                            addDayButtonFrame = proxy.frame(in: .global)
                                        }
                                        .onChange(of: proxy.frame(in: .global)) { _, newFrame in
                                            addDayButtonFrame = newFrame
                                        }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    // Show ad at bottom (always outside ForEach to avoid reorder issues)
                    if shouldShowDayAd {
                        NativeAdCardView(nativeAd: adManager.nativeAds[0])
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            } header: {
                HStack {
                    Text("days")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text("\(days.count)\(L10n.tr("days_unit"))")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    if days.count >= 2 {
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
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle(plan.name.isEmpty ? L10n.tr("new_plan") : plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditPlanSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .navigationDestination(for: PlanEditorDestination.self) { destination in
            switch destination {
            case .dayEditor(let dayId):
                if let day = findDay(byId: dayId) {
                    PlanDayEditorView(day: day) {
                        syncDays()
                        loadLookupData()
                        saveChanges()
                    }
                }
            }
        }
        .onAppear {
            loadData()
            if !allowEmptyPlan {
                ensureAtLeastOneDay()
            }
            plan.reindexDays()  // Fix any non-consecutive dayIndex values
            syncDays()
            // Load ads
            if adManager.nativeAds.isEmpty {
                adManager.loadNativeAds(count: 3)
            }
            attemptShowAddDaySpotlight()
        }
        .onChange(of: days.count) { _, newCount in
            if newCount < 2 {
                editMode?.wrappedValue = .inactive
            }
            attemptShowAddDaySpotlight()
        }
        .onChange(of: addDayButtonFrame) { _, _ in
            attemptShowAddDaySpotlight()
        }
        .overlay {
            if showAddDaySpotlight && addDayButtonFrame.width > 0 {
                SpotlightOverlayView(
                    targetFrame: addDayButtonFrame,
                    label: L10n.tr("spotlight_add_day_hint"),
                    onDismiss: {
                        showAddDaySpotlight = false
                    }
                )
            }
        }
        .sheet(isPresented: $showEditPlanSheet) {
            EditPlanSheetView(
                currentName: plan.name,
                currentNote: plan.note,
                onSave: { name, note in
                    plan.name = name
                    plan.note = note
                    saveChanges()
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(item: $editingDay) { day in
            EditDaySheetView(
                dayIndex: day.dayIndex,
                currentTitle: day.name,
                onSave: { newTitle in
                    day.name = newTitle
                    syncDays()
                    saveChanges()
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(item: $editingExercise) { planExercise in
            PlanExerciseSetEditorSheet(
                planExercise: planExercise,
                exercisesMap: exercisesMap,
                bodyPartsMap: bodyPartsMap,
                onSave: {
                    syncDays()
                    saveChanges()
                }
            )
        }
        .alert("new_day", isPresented: $showNewDayAlert) {
            TextField("day_name", text: $newDayName)
            Button("cancel", role: .cancel) {}
            Button("create") {
                createDay()
            }
        } message: {
            Text("enter_day_name")
        }
        // Programmatic navigation after day creation
        .navigationDestination(isPresented: Binding(
            get: { navigateToDayId != nil },
            set: { if !$0 { navigateToDayId = nil } }
        )) {
            if let dayId = navigateToDayId, let day = findDay(byId: dayId) {
                PlanDayEditorView(day: day) {
                    syncDays()
                    loadLookupData()
                    saveChanges()
                }
            }
        }
    }

    // MARK: - Compact Memo Card

    private var memoCard: some View {
        Button {
            showEditPlanSheet = true
        } label: {
            HStack {
                Text(plan.note ?? "")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func saveChanges() {
        plan.touch()
        try? modelContext.save()
    }

    private func toggleDayExpansion(_ id: UUID) {
        if expandedDayIds.contains(id) {
            expandedDayIds.remove(id)
        } else {
            expandedDayIds.insert(id)
        }
    }

    private func showNewDayDialog() {
        // Set default name to "Day N" where N is the next day number
        let nextDayNumber = (days.map(\.dayIndex).max() ?? 0) + 1
        newDayName = L10n.tr("day_label", nextDayNumber)
        showNewDayAlert = true
    }

    private func attemptShowAddDaySpotlight() {
        guard allowEmptyPlan else { return }
        guard days.isEmpty else { return }
        guard !hasShownPlanAddDaySpotlight else { return }
        guard addDayButtonFrame.width > 0 else { return }

        showAddDaySpotlight = true
        hasShownPlanAddDaySpotlight = true
    }

    private func createDay() {
        let trimmedName = newDayName.trimmingCharacters(in: .whitespaces)
        let dayName: String? = trimmedName.isEmpty ? nil : trimmedName

        let day = plan.createDay(name: dayName)
        modelContext.insert(day)
        syncDays()
        saveChanges()
        syncFutureWorkoutsForPlanChanges()

        // Navigate to the day editor (exercise picker)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            navigateToDayId = day.id
        }
    }

    private func deleteDay(_ day: PlanDay) {
        plan.removeDay(day)
        modelContext.delete(day)
        plan.reindexDays()
        expandedDayIds.remove(day.id)
        syncDays()
        saveChanges()
        syncFutureWorkoutsForPlanChanges()
    }

    private func duplicateDay(_ day: PlanDay) {
        let copy = plan.duplicateDay(day)
        for exercise in copy.exercises {
            for plannedSet in exercise.plannedSets {
                modelContext.insert(plannedSet)
            }
            modelContext.insert(exercise)
        }
        modelContext.insert(copy)
        plan.reindexDays()  // Ensure consecutive dayIndex values
        syncDays()
        saveChanges()
        syncFutureWorkoutsForPlanChanges()
    }

    private func moveDays(from source: IndexSet, to destination: Int) {
        days.move(fromOffsets: source, toOffset: destination)

        // Reindex all days
        for (index, day) in days.enumerated() {
            day.dayIndex = index + 1
        }

        saveChanges()
        syncFutureWorkoutsForPlanChanges()
    }

    private func findDay(byId id: UUID) -> PlanDay? {
        days.first { $0.id == id }
    }

    private func ensureAtLeastOneDay() {
        if plan.days.isEmpty {
            _ = plan.createDay()
        }
    }

    private func syncDays() {
        days = plan.sortedDays
    }

    private func loadData() {
        loadLookupData()
        profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
    }

    // MARK: - Ad Helpers

    /// Show ad at bottom (outside ForEach to avoid reorder issues)
    private var shouldShowDayAd: Bool {
        guard !(profile?.isPremiumUser ?? false) else { return false }
        guard !adManager.nativeAds.isEmpty else { return false }
        return true
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

    private func syncFutureWorkoutsForPlanChanges() {
        let profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
        let planId = plan.id
        let profileId = profile.id
        let today = DateUtilities.todayWorkoutDate(transitionHour: profile.dayTransitionHour)

        // Note: SwiftData #Predicate can't use enum member access directly
        // Filter by routinePresetId presence instead (routinePresetId != nil implies routine mode)
        let descriptor = FetchDescriptor<WorkoutDay>(
            predicate: #Predicate<WorkoutDay> { workoutDay in
                workoutDay.profileId == profileId &&
                workoutDay.date >= today &&
                workoutDay.routinePresetId == planId
            }
        )

        guard let workoutDays = try? modelContext.fetch(descriptor) else { return }

        for workoutDay in workoutDays {
            // Skip if not routine mode (defensive check since routinePresetId implies routine)
            guard workoutDay.mode == .routine else { continue }
            guard workoutDay.totalCompletedSets == 0 else { continue }
            guard let planDay = resolvePlanDayForSync(profile: profile, targetDate: workoutDay.date, todayDate: today) else {
                continue
            }

            if workoutDay.routineDayId == planDay.id {
                continue
            }

            for group in workoutDay.exerciseGroups {
                modelContext.delete(group)
            }
            workoutDay.exerciseGroups.removeAll()

            for entry in workoutDay.entries {
                modelContext.delete(entry)
            }
            workoutDay.entries.removeAll()

            workoutDay.mode = .routine
            workoutDay.routinePresetId = planId
            workoutDay.routineDayId = planDay.id

            PlanService.expandPlanToWorkout(
                planDay: planDay,
                workoutDay: workoutDay,
                modelContext: modelContext
            )
        }

        try? modelContext.save()
    }

    private func resolvePlanDayForSync(
        profile: LocalProfile,
        targetDate: Date,
        todayDate: Date
    ) -> PlanDay? {
        switch profile.executionMode {
        case .single:
            guard profile.activePlanId == plan.id,
                  let info = PlanService.getPreviewDayInfo(
                    profile: profile,
                    targetDate: targetDate,
                    todayDate: todayDate,
                    modelContext: modelContext
                  ) else {
                return nil
            }
            return plan.day(at: info.dayIndex)
        case .cycle:
            guard let activeCycle = CycleService.getActiveCycle(
                    profileId: profile.id,
                    modelContext: modelContext
                  ) else {
                return nil
            }
            let items = activeCycle.sortedItems
            CycleService.loadPlans(for: items, modelContext: modelContext)
            guard let progress = activeCycle.progress,
                  progress.currentItemIndex < items.count,
                  let currentPlan = items[progress.currentItemIndex].plan,
                  currentPlan.id == plan.id,
                  let info = CycleService.getPreviewDayInfo(
                    cycle: activeCycle,
                    targetDate: targetDate,
                    todayDate: todayDate,
                    modelContext: modelContext
                  ) else {
                return nil
            }
            return plan.day(at: info.dayIndex)
        }
    }
}

// MARK: - Plan Exercise Set Editor Sheet

/// Sheet for editing sets of an existing exercise in a plan
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

        // 1. Collect all plan candidates from current plan
        for day in currentPlan.sortedDays {
            let matchingExercises = day.sortedExercises
                .filter { $0.exerciseId == exerciseId && $0.id != planExercise.id }

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

        // 2. Collect plan candidates from other plans
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

        // Add new sets with individual metricType and rest time
        for setData in newSets {
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

        planExercise.plannedSetCount = newSets.count
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        let plan = WorkoutPlan(profileId: UUID(), name: "Push Pull Legs", note: "週3回のトレーニングプラン")
        let day1 = PlanDay(dayIndex: 1, name: "Push")
        let day2 = PlanDay(dayIndex: 2, name: "Pull")
        let day3 = PlanDay(dayIndex: 3, name: "Legs")
        plan.addDay(day1)
        plan.addDay(day2)
        plan.addDay(day3)

        return PlanEditorView(plan: plan)
            .modelContainer(for: [
                WorkoutPlan.self,
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
