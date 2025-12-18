//
//  PlanDayEditorView.swift
//  Routyra
//
//  Editor for a single day's exercises.
//  Allows adding, editing, reordering, and deleting exercises.
//

import SwiftUI
import SwiftData

/// Navigation destination types for day editor
enum PlanDayEditorDestination: Hashable {
    case exercisePicker
    case newExercise
}

struct PlanDayEditorView: View {
    @Bindable var day: PlanDay
    let onChanged: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var exercises: [PlanExercise] = []
    @State private var expandedExerciseId: UUID?
    @State private var profile: LocalProfile?

    // Cached lookups
    @State private var exercisesMap: [UUID: Exercise] = [:]
    @State private var bodyPartsMap: [UUID: BodyPart] = [:]

    var body: some View {
        List {
            // Day title section
            Section {
                TextField("タイトル (例: Push)", text: Binding(
                    get: { day.name ?? "" },
                    set: { day.name = $0.isEmpty ? nil : $0 }
                ))
                .foregroundColor(AppColors.textPrimary)
            } header: {
                Text("Day情報")
            }

            // Exercises section
            Section {
                if exercises.isEmpty {
                    emptyStateView
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(exercises, id: \.id) { planExercise in
                        let exercise = exercisesMap[planExercise.exerciseId]
                        let bodyPartId = exercise?.bodyPartId
                        let bodyPart = bodyPartId.flatMap { bodyPartsMap[$0] }

                        PlanExerciseRowView(
                            planExercise: planExercise,
                            exercise: exercise,
                            bodyPart: bodyPart,
                            isExpanded: expandedExerciseId == planExercise.id,
                            onToggleExpand: {
                                toggleExerciseExpansion(planExercise.id)
                            },
                            onDelete: {
                                deleteExercise(planExercise)
                            },
                            onDuplicate: {
                                duplicateExercise(planExercise)
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteExercise(planExercise)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                    .onMove(perform: moveExercises)
                }

                // Add exercise button
                NavigationLink(value: PlanDayEditorDestination.exercisePicker) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("種目を追加")
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
                    Text("種目")
                    Spacer()
                    Text("\(exercises.count)種目")
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
        .navigationTitle(day.fullTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(for: PlanDayEditorDestination.self) { destination in
            // Use a wrapper view to ensure profile is loaded
            PlanDayEditorDestinationView(
                destination: destination,
                dayTitle: day.fullTitle,
                onExerciseSelected: { exercise in
                    addExercise(exercise)
                }
            )
        }
        .onAppear {
            loadData()
            syncExercises()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textMuted)

            Text("種目がありません")
                .font(.headline)
                .foregroundColor(AppColors.textSecondary)

            Text("種目を追加してトレーニング内容を設定しましょう")
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

    private func addExercise(_ exercise: Exercise) {
        let planExercise = day.createExercise(exerciseId: exercise.id, plannedSetCount: 3)
        syncExercises()
        loadLookupData()

        // Auto-expand the newly added exercise
        expandedExerciseId = planExercise.id
        onChanged()
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
            plannedSetCount: planExercise.plannedSetCount
        )

        // Copy planned sets
        for plannedSet in planExercise.sortedPlannedSets {
            newExercise.createPlannedSet(
                weight: plannedSet.targetWeight,
                reps: plannedSet.targetReps
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

// MARK: - Navigation Destination Wrapper

/// Wrapper view that ensures profile is loaded before displaying destination views
private struct PlanDayEditorDestinationView: View {
    let destination: PlanDayEditorDestination
    let dayTitle: String
    let onExerciseSelected: (Exercise) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var profile: LocalProfile?

    var body: some View {
        Group {
            if let profile = profile {
                switch destination {
                case .exercisePicker:
                    ExercisePickerView(
                        profile: profile,
                        dayTitle: dayTitle,
                        onSelect: onExerciseSelected
                    )
                case .newExercise:
                    NewExerciseFlowView(
                        profile: profile,
                        onCreated: onExerciseSelected
                    )
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            if profile == nil {
                profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
            }
        }
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
