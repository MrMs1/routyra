//
//  PlanEditorView.swift
//  Routyra
//
//  Main editor view for creating and editing workout plans.
//  Days can be expanded to view exercises. Edit via edit button on each day.
//

import SwiftUI
import SwiftData

/// Navigation destination types for plan editor
enum PlanEditorDestination: Hashable {
    case dayEditor(dayId: UUID)
}

struct PlanEditorView: View {
    @Bindable var plan: WorkoutPlan

    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode

    // Sheet states
    @State private var showEditPlanSheet: Bool = false
    @State private var editingDay: PlanDay? = nil

    // For day display and reordering
    @State private var days: [PlanDay] = []
    @State private var expandedDayIds: Set<UUID> = []

    // Cached lookups for exercise display
    @State private var exercisesMap: [UUID: Exercise] = [:]
    @State private var bodyPartsMap: [UUID: BodyPart] = [:]

    /// Whether we're in reorder mode (EditMode active)
    private var isReordering: Bool {
        editMode?.wrappedValue == .active
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
                ForEach(days, id: \.id) { day in
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
                        }
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
                        addDay()
                    } label: {
                        ActionCardButton(title: L10n.tr("add_day"), showChevron: false)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } header: {
                HStack {
                    Text("days")
                    Spacer()
                    Text("\(days.count)\(L10n.tr("days_unit"))")
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
            ensureAtLeastOneDay()
            syncDays()
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

    private func addDay() {
        _ = plan.createDay()
        syncDays()
        saveChanges()
    }

    private func deleteDay(_ day: PlanDay) {
        plan.removeDay(day)
        modelContext.delete(day)
        plan.reindexDays()
        expandedDayIds.remove(day.id)
        syncDays()
        saveChanges()
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
        saveChanges()
    }

    private func moveDays(from source: IndexSet, to destination: Int) {
        days.move(fromOffsets: source, toOffset: destination)

        // Reindex all days
        for (index, day) in days.enumerated() {
            day.dayIndex = index + 1
        }

        saveChanges()
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
