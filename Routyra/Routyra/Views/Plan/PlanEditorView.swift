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
    let isNewPlan: Bool
    let onSave: () -> Void
    let onDiscard: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showDiscardConfirmation: Bool = false
    @State private var isDirty: Bool = false

    // For day display and reordering
    @State private var days: [PlanDay] = []
    @State private var expandedDayIds: Set<UUID> = []

    // Cached lookups for exercise display
    @State private var exercisesMap: [UUID: Exercise] = [:]
    @State private var bodyPartsMap: [UUID: BodyPart] = [:]

    var body: some View {
        List {
            // Plan info section
            Section {
                TextField("プラン名", text: $plan.name)
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary)

                TextField("メモ (任意)", text: Binding(
                    get: { plan.note ?? "" },
                    set: { plan.note = $0.isEmpty ? nil : $0 }
                ))
                .font(.body)
                .foregroundColor(AppColors.textPrimary)
            } header: {
                Text("プラン情報")
            }

            // Days section
            Section {
                ForEach(days, id: \.id) { day in
                    PlanDayCardView(
                        day: day,
                        exercises: exercisesMap,
                        bodyParts: bodyPartsMap,
                        isExpanded: expandedDayIds.contains(day.id),
                        editDestination: PlanEditorDestination.dayEditor(dayId: day.id),
                        onToggleExpand: {
                            toggleDayExpansion(day.id)
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .contextMenu {
                        Button {
                            duplicateDay(day)
                        } label: {
                            Label("Dayを複製", systemImage: "doc.on.doc")
                        }

                        Button(role: .destructive) {
                            deleteDay(day)
                        } label: {
                            Label("Dayを削除", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteDay(day)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
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
                HStack {
                    Text("Days")
                    Spacer()
                    Text("\(days.count)日間")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    EditButton()
                        .font(.subheadline)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
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
            case .dayEditor(let dayId):
                if let day = findDay(byId: dayId) {
                    PlanDayEditorView(day: day) {
                        isDirty = true
                        syncDays()
                        loadLookupData()
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
        if expandedDayIds.contains(id) {
            expandedDayIds.remove(id)
        } else {
            expandedDayIds.insert(id)
        }
    }

    private func addDay() {
        _ = plan.createDay()
        syncDays()
        isDirty = true
    }

    private func deleteDay(_ day: PlanDay) {
        plan.removeDay(day)
        modelContext.delete(day)
        plan.reindexDays()
        expandedDayIds.remove(day.id)
        syncDays()
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

    private func moveDays(from source: IndexSet, to destination: Int) {
        days.move(fromOffsets: source, toOffset: destination)

        // Reindex all days
        for (index, day) in days.enumerated() {
            day.dayIndex = index + 1
        }

        try? modelContext.save()
        isDirty = true
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
