//
//  ExerciseOrderEditorView.swift
//  Routyra
//
//  Dedicated view for reordering exercises within a day using List + onMove.
//  Provides stable drag-to-reorder functionality.
//

import SwiftUI
import SwiftData

struct ExerciseOrderEditorView: View {
    @Bindable var day: PlanDay
    let onChanged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var exercises: [PlanExercise] = []

    // Cached lookups
    @State private var exercisesMap: [UUID: Exercise] = [:]
    @State private var bodyPartsMap: [UUID: BodyPart] = [:]

    var body: some View {
        List {
            Section {
                ForEach(exercises, id: \.id) { planExercise in
                    exerciseRow(planExercise)
                }
                .onMove(perform: moveExercises)
            } header: {
                Text("\(exercises.count)種目")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("種目の並び替え")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .environment(\.editMode, .constant(.active))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完了") {
                    dismiss()
                }
                .fontWeight(.medium)
            }
        }
        .onAppear {
            loadData()
        }
    }

    // MARK: - Exercise Row

    @ViewBuilder
    private func exerciseRow(_ planExercise: PlanExercise) -> some View {
        let exercise = exercisesMap[planExercise.exerciseId]
        let bodyPartId = exercise?.bodyPartId
        let bodyPart = bodyPartId.flatMap { bodyPartsMap[$0] }

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise?.localizedName ?? "不明な種目")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)

                if let bodyPart = bodyPart {
                    Text(bodyPart.localizedName)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            // Set count badge
            Text("\(planExercise.plannedSets.count)セット")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func loadData() {
        exercises = day.sortedExercises
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

    private func moveExercises(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)

        // Reindex all exercises
        for (index, exercise) in exercises.enumerated() {
            exercise.orderIndex = index
        }

        // Save changes
        try? modelContext.save()
        onChanged()
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

        let exercise2 = PlanExercise(exerciseId: UUID(), orderIndex: 1, plannedSetCount: 4)
        day.addExercise(exercise2)

        let exercise3 = PlanExercise(exerciseId: UUID(), orderIndex: 2, plannedSetCount: 3)
        day.addExercise(exercise3)

        return ExerciseOrderEditorView(day: day, onChanged: {})
            .modelContainer(for: [
                PlanDay.self,
                PlanExercise.self,
                PlannedSet.self,
                Exercise.self,
                BodyPart.self,
                BodyPartTranslation.self,
                ExerciseTranslation.self
            ], inMemory: true)
    }
    .preferredColorScheme(.dark)
}
