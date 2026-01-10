//
//  GroupCreationSheet.swift
//  Routyra
//
//  Sheet for selecting exercises to group into a superset/giant set.
//  Shows all ungrouped exercises in the plan day for selection.
//

import SwiftUI
import SwiftData

struct GroupCreationSheet: View {
    let planDay: PlanDay
    let exercisesMap: [UUID: Exercise]
    let bodyPartsMap: [UUID: BodyPart]
    let onCreateGroup: ([PlanExercise], Int, Int?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedExerciseIds: Set<UUID> = []
    @State private var showSetCountResolver = false
    @State private var resolvedSetCount: Int = 3
    @State private var restSeconds: Int? = 90

    private var ungroupedExercises: [PlanExercise] {
        planDay.sortedExercises.filter { !$0.isGrouped }
    }

    private var selectedExercises: [PlanExercise] {
        ungroupedExercises.filter { selectedExerciseIds.contains($0.id) }
    }

    private var canCreateGroup: Bool {
        selectedExerciseIds.count >= 2
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selection instructions
                if ungroupedExercises.count < 2 {
                    ContentUnavailableView {
                        Label(L10n.tr("group_requires_two"), systemImage: "rectangle.stack")
                    } description: {
                        Text(L10n.tr("add_exercise"))
                    }
                } else {
                    List {
                        Section {
                            ForEach(ungroupedExercises, id: \.id) { planExercise in
                                let exercise = exercisesMap[planExercise.exerciseId]
                                let bodyPartId = exercise?.bodyPartId
                                let bodyPart = bodyPartId.flatMap { bodyPartsMap[$0] }

                                ExerciseSelectionRow(
                                    planExercise: planExercise,
                                    exercise: exercise,
                                    bodyPart: bodyPart,
                                    isSelected: selectedExerciseIds.contains(planExercise.id),
                                    onToggle: {
                                        if selectedExerciseIds.contains(planExercise.id) {
                                            selectedExerciseIds.remove(planExercise.id)
                                        } else {
                                            selectedExerciseIds.insert(planExercise.id)
                                        }
                                    }
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        } header: {
                            Text(L10n.tr("select_exercises_to_group"))
                                .textCase(nil)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppColors.background)
            .navigationTitle(L10n.tr("create_group"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("next")) {
                        checkSetCountMismatch()
                    }
                    .disabled(!canCreateGroup)
                }
            }
            .sheet(isPresented: $showSetCountResolver) {
                GroupSetCountResolverSheet(
                    exercises: selectedExercises,
                    exercisesMap: exercisesMap,
                    onResolve: { setCount in
                        resolvedSetCount = setCount
                        createGroup()
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }

    private func checkSetCountMismatch() {
        if GroupService.hasSetCountMismatch(selectedExercises) {
            showSetCountResolver = true
        } else {
            resolvedSetCount = selectedExercises.first?.effectiveSetCount ?? 3
            createGroup()
        }
    }

    private func createGroup() {
        onCreateGroup(selectedExercises, resolvedSetCount, restSeconds)
        dismiss()
    }
}

// MARK: - Exercise Selection Row

private struct ExerciseSelectionRow: View {
    let planExercise: PlanExercise
    let exercise: Exercise?
    let bodyPart: BodyPart?
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? AppColors.accentBlue : AppColors.textMuted)

                // Exercise info
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise?.localizedName ?? "Unknown")
                        .font(.body)
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: 8) {
                        if let bodyPart = bodyPart {
                            Text(bodyPart.localizedName)
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Text("\(planExercise.effectiveSetCount) \(L10n.tr("sets_unit"))")
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isSelected ? AppColors.accentBlue.opacity(0.1) : AppColors.cardBackground)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}
