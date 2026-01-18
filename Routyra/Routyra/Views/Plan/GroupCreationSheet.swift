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

    // Keep selection order so group order can follow it.
    @State private var selectedExerciseIds: [UUID] = []
    @State private var showSetCountResolver = false
    @State private var resolvedSetCount: Int = 3
    @State private var restSeconds: Int? = 90

    private var ungroupedExercises: [PlanExercise] {
        planDay.sortedExercises.filter { !$0.isGrouped }
    }

    private var ungroupedExerciseMap: [UUID: PlanExercise] {
        Dictionary(uniqueKeysWithValues: ungroupedExercises.map { ($0.id, $0) })
    }

    private var selectedExercises: [PlanExercise] {
        // Preserve selection order
        selectedExerciseIds.compactMap { ungroupedExerciseMap[$0] }
    }

    private var canCreateGroup: Bool {
        selectedExerciseIds.count >= 2
    }

    var body: some View {
        NavigationStack {
            ZStack {
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
                                    let selectionNumber = selectedExerciseIds.firstIndex(of: planExercise.id).map { $0 + 1 }

                                    ExerciseSelectionRow(
                                        planExercise: planExercise,
                                        exercise: exercise,
                                        bodyPart: bodyPart,
                                        selectionNumber: selectionNumber,
                                        onToggle: {
                                            if let idx = selectedExerciseIds.firstIndex(of: planExercise.id) {
                                                selectedExerciseIds.remove(at: idx)
                                            } else {
                                                selectedExerciseIds.append(planExercise.id)
                                            }
                                        }
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                            } header: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(L10n.tr("select_exercises_to_group"))
                                        .textCase(nil)

                                    Text(L10n.tr("group_selection_order_hint"))
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                        .textCase(nil)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                .allowsHitTesting(!showSetCountResolver)

                if showSetCountResolver {
                    GroupSetCountResolverSheet(
                        isPresented: $showSetCountResolver,
                        exercises: selectedExercises,
                        exercisesMap: exercisesMap,
                        onResolve: { setCount in
                            resolvedSetCount = setCount
                            createGroup()
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
            .animation(.easeOut(duration: 0.2), value: showSetCountResolver)
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
    let selectionNumber: Int?
    let onToggle: () -> Void

    var body: some View {
        let isSelected = selectionNumber != nil
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? AppColors.accentBlue : AppColors.textMuted.opacity(0.6), lineWidth: 2)
                        .frame(width: 26, height: 26)

                    if let selectionNumber = selectionNumber {
                        Circle()
                            .fill(AppColors.accentBlue)
                            .frame(width: 26, height: 26)
                        Text("\(selectionNumber)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                }

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
