//
//  PlanEditorView.swift
//  Routyra
//
//  Main editor view for creating and editing workout plans.
//  Uses push navigation for exercise selection (no modals).
//  Supports drag-to-reorder for days.
//

import SwiftUI
import SwiftData

/// Navigation destination types for plan editor
enum PlanEditorDestination: Hashable {
    case exercisePicker(dayId: UUID)
    case newExercise(dayId: UUID)
    case exerciseOrder(dayId: UUID)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .exercisePicker(let dayId):
            hasher.combine(0)
            hasher.combine(dayId)
        case .newExercise(let dayId):
            hasher.combine(1)
            hasher.combine(dayId)
        case .exerciseOrder(let dayId):
            hasher.combine(2)
            hasher.combine(dayId)
        }
    }
}

/// Editor mode for plan editing
enum PlanEditorMode {
    case none
    case editDays
    case editExercises
}

struct PlanEditorView: View {
    @Bindable var plan: WorkoutPlan
    let isNewPlan: Bool
    let onSave: () -> Void
    let onDiscard: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var expandedDayIds: Set<UUID> = []
    @State private var expandedExerciseId: UUID?
    @State private var showDiscardConfirmation: Bool = false
    @State private var isDirty: Bool = false
    @State private var editorMode: PlanEditorMode = .none

    // For day reordering
    @State private var days: [PlanDay] = []

    // Cached lookups
    @State private var exercisesMap: [UUID: Exercise] = [:]
    @State private var bodyPartsMap: [UUID: BodyPart] = [:]
    @State private var profile: LocalProfile?

    var body: some View {
        List {
            // Plan info section
            Section {
                TextField("プラン名", text: $plan.name)
                    .foregroundColor(AppColors.textPrimary)

                TextField("メモ (任意)", text: Binding(
                    get: { plan.note ?? "" },
                    set: { plan.note = $0.isEmpty ? nil : $0 }
                ))
                .foregroundColor(AppColors.textPrimary)
            } header: {
                Text("プラン情報")
            }

            // Days section with reordering
            Section {
                // Edit mode guide for exercise editing
                if editorMode == .editExercises && expandedDayIds.isEmpty {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("並び替えたいDayを開いてください")
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                ForEach(days, id: \.id) { day in
                    PlanDayCardView(
                        day: day,
                        exercises: exercisesMap,
                        bodyParts: bodyPartsMap,
                        isExpanded: expandedDayIds.contains(day.id),
                        expandedExerciseId: expandedExerciseId,
                        editorMode: editorMode,
                        onToggleExpand: {
                            toggleDayExpansion(day.id)
                        },
                        onToggleExerciseExpand: { exerciseId in
                            toggleExerciseExpansion(exerciseId)
                        },
                        onAddExerciseDestination: {
                            PlanEditorDestination.exercisePicker(dayId: day.id)
                        },
                        onReorderExercisesDestination: {
                            PlanEditorDestination.exerciseOrder(dayId: day.id)
                        },
                        onDelete: {
                            deleteDay(day)
                        },
                        onDuplicate: {
                            duplicateDay(day)
                        },
                        onExerciseDeleted: {
                            isDirty = true
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteDay(day)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                    .moveDisabled(editorMode != .editDays)
                }
                .onMove(perform: moveDays)

                // Add day button
                Button {
                    addDay()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Dayを追加")
                    }
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } header: {
                editorModeHeader
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .environment(\.editMode, editorMode == .editDays ? .constant(.active) : .constant(.inactive))
        .navigationTitle(plan.name.isEmpty ? "新規プラン" : plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") {
                    handleCancel()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave()
                }
                .disabled(plan.name.trimmed.isEmpty)
            }
        }
        .navigationDestination(for: PlanEditorDestination.self) { destination in
            switch destination {
            case .exercisePicker(let dayId):
                if let profile = profile, let day = findDay(byId: dayId) {
                    ExercisePickerView(
                        profile: profile,
                        dayTitle: day.fullTitle,
                        onSelect: { exercise in
                            addExerciseToDay(exercise, dayId: dayId)
                        }
                    )
                }
            case .newExercise(let dayId):
                if let profile = profile {
                    NewExerciseFlowView(
                        profile: profile,
                        onCreated: { exercise in
                            addExerciseToDay(exercise, dayId: dayId)
                        }
                    )
                }
            case .exerciseOrder(let dayId):
                if let day = findDay(byId: dayId) {
                    ExerciseOrderEditorView(day: day) {
                        isDirty = true
                    }
                }
            }
        }
        .onAppear {
            loadData()
            ensureAtLeastOneDay()
            syncDays()
        }
        .alert("変更を破棄", isPresented: $showDiscardConfirmation) {
            Button("破棄", role: .destructive) {
                onDiscard()
            }
            Button("編集を続ける", role: .cancel) {}
        } message: {
            Text("保存されていない変更があります。破棄しますか？")
        }
        .onChange(of: plan.name) { _, _ in isDirty = true }
        .onChange(of: plan.note) { _, _ in isDirty = true }
    }

    // MARK: - Actions

    private func handleCancel() {
        if isDirty || isNewPlan {
            showDiscardConfirmation = true
        } else {
            onDiscard()
        }
    }

    private func toggleDayExpansion(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedDayIds.contains(id) {
                expandedDayIds.remove(id)
            } else {
                expandedDayIds.insert(id)
            }
        }
    }

    private func toggleExerciseExpansion(_ id: UUID) {
        // Don't allow expansion in Day edit mode
        guard editorMode != .editDays else { return }

        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedExerciseId == id {
                expandedExerciseId = nil
            } else {
                expandedExerciseId = id
            }
        }
    }

    // MARK: - Editor Mode Header

    private var editorModeHeader: some View {
        HStack {
            Text("Days")
            Spacer()
            Text("\(days.count)日間")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            if editorMode == .none {
                Button("編集") {
                    withAnimation {
                        editorMode = .editDays
                        // Collapse all days for cleaner reordering
                        expandedDayIds.removeAll()
                    }
                }
                .font(.subheadline)
            } else {
                // Edit mode selector
                Picker("", selection: $editorMode) {
                    Text("Day").tag(PlanEditorMode.editDays)
                    Text("種目").tag(PlanEditorMode.editExercises)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
                .onChange(of: editorMode) { _, newMode in
                    if newMode == .editDays {
                        // Collapse all days for cleaner reordering
                        withAnimation {
                            expandedDayIds.removeAll()
                        }
                    }
                }

                Button("完了") {
                    withAnimation {
                        editorMode = .none
                    }
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }
        }
    }

    private func addDay() {
        let day = plan.createDay()
        syncDays()
        expandedDayIds.insert(day.id)
        isDirty = true
    }

    private func deleteDay(_ day: PlanDay) {
        plan.removeDay(day)
        modelContext.delete(day)
        plan.reindexDays()
        syncDays()
        isDirty = true
    }

    private func deleteDays(at offsets: IndexSet) {
        for index in offsets {
            let day = days[index]
            plan.removeDay(day)
            modelContext.delete(day)
        }
        plan.reindexDays()
        syncDays()
        isDirty = true
    }

    private func moveDays(from source: IndexSet, to destination: Int) {
        days.move(fromOffsets: source, toOffset: destination)

        // Update dayIndex for all days
        for (index, day) in days.enumerated() {
            day.dayIndex = index + 1
        }
        isDirty = true
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
        syncDays()
        isDirty = true
    }

    private func findDay(byId id: UUID) -> PlanDay? {
        days.first { $0.id == id }
    }

    private func addExerciseToDay(_ exercise: Exercise, dayId: UUID) {
        guard let day = findDay(byId: dayId) else { return }

        let planExercise = day.createExercise(exerciseId: exercise.id, plannedSetCount: 3)

        // Auto-expand the day and the newly added exercise
        expandedDayIds.insert(dayId)
        expandedExerciseId = planExercise.id

        // Refresh lookup data
        loadLookupData()
        isDirty = true
    }

    private func ensureAtLeastOneDay() {
        if plan.days.isEmpty {
            let day = plan.createDay()
            expandedDayIds.insert(day.id)
        }
    }

    private func syncDays() {
        days = plan.sortedDays
    }

    private func loadData() {
        profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
        loadLookupData()
    }

    private func loadLookupData() {
        // Load exercises
        let exerciseDescriptor = FetchDescriptor<Exercise>()
        if let exercises = try? modelContext.fetch(exerciseDescriptor) {
            exercisesMap = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        }

        // Load body parts
        let bodyPartDescriptor = FetchDescriptor<BodyPart>()
        if let bodyParts = try? modelContext.fetch(bodyPartDescriptor) {
            bodyPartsMap = Dictionary(uniqueKeysWithValues: bodyParts.map { ($0.id, $0) })
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        let plan = WorkoutPlan(profileId: UUID(), name: "Push Pull Legs")
        let day1 = PlanDay(dayIndex: 1, name: "Push")
        let day2 = PlanDay(dayIndex: 2, name: "Pull")
        let day3 = PlanDay(dayIndex: 3, name: "Legs")
        plan.addDay(day1)
        plan.addDay(day2)
        plan.addDay(day3)

        return PlanEditorView(
            plan: plan,
            isNewPlan: false,
            onSave: {},
            onDiscard: {}
        )
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
