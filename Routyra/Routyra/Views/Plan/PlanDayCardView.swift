//
//  PlanDayCardView.swift
//  Routyra
//
//  Displays a day within the plan editor.
//  Collapsible: shows summary when collapsed, exercises when expanded.
//  Supports drag-to-reorder for exercises.
//

import SwiftUI
import SwiftData

struct PlanDayCardView: View {
    @Bindable var day: PlanDay
    let exercises: [UUID: Exercise]
    let bodyParts: [UUID: BodyPart]
    let isExpanded: Bool
    let expandedExerciseId: UUID?
    let editorMode: PlanEditorMode
    let onToggleExpand: () -> Void
    let onToggleExerciseExpand: (UUID) -> Void
    let onAddExerciseDestination: () -> PlanEditorDestination
    let onReorderExercisesDestination: () -> PlanEditorDestination
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onExerciseDeleted: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isEditingTitle: Bool = false
    @State private var editingTitle: String = ""
    @State private var exercisesList: [PlanExercise] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            headerRow

            // Expanded content (exercises)
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .contextMenu {
            Button {
                onDuplicate()
            } label: {
                Label("Dayを複製", systemImage: "doc.on.doc")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Dayを削除", systemImage: "trash")
            }
        }
        .onAppear {
            syncExercises()
        }
        .onChange(of: day.exercises.count) { _, _ in
            syncExercises()
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        Button {
            onToggleExpand()
        } label: {
            HStack(spacing: 12) {
                // Day info
                VStack(alignment: .leading, spacing: 2) {
                    if isEditingTitle {
                        TextField("タイトル (例: Push)", text: $editingTitle)
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                day.name = editingTitle.isEmpty ? nil : editingTitle
                                isEditingTitle = false
                            }
                    } else {
                        Text(day.fullTitle)
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                    }

                    if !isExpanded {
                        Text(day.summary)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.vertical, 12)
                .padding(.leading, 12)
                .onTapGesture {
                    editingTitle = day.name ?? ""
                    isEditingTitle = true
                }

                Spacer()

                // Expand/collapse indicator
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textMuted)
                    .frame(width: 32, height: 32)
                    .padding(.trailing, 8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .background(AppColors.divider)
                .padding(.horizontal, 12)

            // Reorder exercises button (only in exercise edit mode)
            if editorMode == .editExercises && exercisesList.count > 1 {
                NavigationLink(value: onReorderExercisesDestination()) {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                        Text("種目の並び替え")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)
                    }
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                Divider()
                    .background(AppColors.divider)
                    .padding(.horizontal, 12)
            }

            // Exercise list
            ForEach(exercisesList, id: \.id) { planExercise in
                let exercise = exercises[planExercise.exerciseId]
                let bodyPartId = exercise?.bodyPartId
                let bodyPart = bodyPartId.flatMap { bodyParts[$0] }

                exerciseRow(
                    planExercise: planExercise,
                    exercise: exercise,
                    bodyPart: bodyPart
                )
            }

            // Add exercise button (NavigationLink) - hide in exercise edit mode
            if editorMode != .editExercises {
                NavigationLink(value: onAddExerciseDestination()) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("種目を追加")
                    }
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            } else {
                // Bottom padding in edit mode
                Spacer()
                    .frame(height: 12)
            }
        }
    }

    @ViewBuilder
    private func exerciseRow(
        planExercise: PlanExercise,
        exercise: Exercise?,
        bodyPart: BodyPart?
    ) -> some View {
        PlanExerciseRowView(
            planExercise: planExercise,
            exercise: exercise,
            bodyPart: bodyPart,
            isExpanded: expandedExerciseId == planExercise.id,
            onToggleExpand: {
                onToggleExerciseExpand(planExercise.id)
            },
            onDelete: {
                deleteExercise(planExercise)
            },
            onDuplicate: {
                duplicateExercise(planExercise)
            }
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func syncExercises() {
        exercisesList = day.sortedExercises
    }

    private func deleteExercise(_ planExercise: PlanExercise) {
        day.removeExercise(planExercise)
        day.reindexExercises()
        syncExercises()
        onExerciseDeleted()
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

        return ScrollView {
            VStack(spacing: 12) {
                PlanDayCardView(
                    day: day,
                    exercises: [:],
                    bodyParts: [:],
                    isExpanded: false,
                    expandedExerciseId: nil,
                    editorMode: .none,
                    onToggleExpand: {},
                    onToggleExerciseExpand: { _ in },
                    onAddExerciseDestination: { .exercisePicker(dayId: day.id) },
                    onReorderExercisesDestination: { .exerciseOrder(dayId: day.id) },
                    onDelete: {},
                    onDuplicate: {},
                    onExerciseDeleted: {}
                )

                PlanDayCardView(
                    day: day,
                    exercises: [:],
                    bodyParts: [:],
                    isExpanded: true,
                    expandedExerciseId: nil,
                    editorMode: .editExercises,
                    onToggleExpand: {},
                    onToggleExerciseExpand: { _ in },
                    onAddExerciseDestination: { .exercisePicker(dayId: day.id) },
                    onReorderExercisesDestination: { .exerciseOrder(dayId: day.id) },
                    onDelete: {},
                    onDuplicate: {},
                    onExerciseDeleted: {}
                )
            }
            .padding()
        }
        .background(AppColors.background)
    }
    .preferredColorScheme(.dark)
}
