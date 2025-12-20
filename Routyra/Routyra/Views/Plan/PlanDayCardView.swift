//
//  PlanDayCardView.swift
//  Routyra
//
//  Displays a day card within the plan editor.
//  Supports expansion to show exercises, with edit button for navigation.
//

import SwiftUI
import SwiftData

struct PlanDayCardView<Destination: Hashable>: View {
    let day: PlanDay
    let exercises: [UUID: Exercise]
    let bodyParts: [UUID: BodyPart]
    let isExpanded: Bool
    let editDestination: Destination
    let onToggleExpand: () -> Void

    @State private var expandedExerciseIds: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            headerRow

            // Expanded content (exercise cards)
            if isExpanded {
                expandedContent
                    .transition(.opacity.animation(.easeOut(duration: 1)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .clipped()
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 12) {
            // Expand/collapse button area
            Button {
                onToggleExpand()
            } label: {
                HStack(spacing: 12) {
                    // Chevron
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textMuted)
                        .frame(width: 16)

                    // Day info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.fullTitle)
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)

                        HStack(spacing: 4) {
                            // Body part color dots (collapsed state)
                            if !isExpanded {
                                let uniqueBodyParts = getUniqueBodyParts()
                                if !uniqueBodyParts.isEmpty {
                                    HStack(spacing: 4) {
                                        ForEach(uniqueBodyParts, id: \.id) { bodyPart in
                                            Circle()
                                                .fill(bodyPart.color)
                                                .frame(width: 6, height: 6)
                                        }
                                    }
                                }
                            }

                            Text(day.summary)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Edit button (NavigationLink hidden to prevent disclosure indicator)
            Image(systemName: "pencil.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(AppColors.accentBlue)
                .background(
                    NavigationLink(value: editDestination) {
                        EmptyView()
                    }
                    .opacity(0)
                )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            let sortedExercises = day.sortedExercises

            if sortedExercises.isEmpty {
                // Empty state
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("種目がありません")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textMuted)
                        Text("編集ボタンから追加")
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
            } else {
                // Exercise cards
                VStack(spacing: 8) {
                    ForEach(sortedExercises, id: \.id) { planExercise in
                        let exercise = exercises[planExercise.exerciseId]
                        let bodyPartId = exercise?.bodyPartId
                        let bodyPart = bodyPartId.flatMap { bodyParts[$0] }

                        PlanExerciseCardView(
                            planExercise: planExercise,
                            exercise: exercise,
                            bodyPart: bodyPart,
                            isExpanded: expandedExerciseIds.contains(planExercise.id),
                            onToggle: {
                                toggleExercise(planExercise.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Actions

    private func toggleExercise(_ id: UUID) {
        if expandedExerciseIds.contains(id) {
            expandedExerciseIds.remove(id)
        } else {
            expandedExerciseIds.insert(id)
        }
    }

    // MARK: - Helpers

    /// Returns unique body parts for exercises in this day, maintaining order
    private func getUniqueBodyParts() -> [BodyPart] {
        var seen = Set<UUID>()
        var result: [BodyPart] = []

        for planExercise in day.sortedExercises {
            if let exercise = exercises[planExercise.exerciseId],
               let bodyPartId = exercise.bodyPartId,
               let bodyPart = bodyParts[bodyPartId],
               !seen.contains(bodyPart.id) {
                seen.insert(bodyPart.id)
                result.append(bodyPart)
            }
        }

        return result
    }
}

#Preview {
    NavigationStack {
        let day = PlanDay(dayIndex: 1, name: "胸・三頭")
        let exercise1 = PlanExercise(exerciseId: UUID(), orderIndex: 0, plannedSetCount: 3)
        exercise1.createPlannedSet(weight: 60, reps: 10)
        exercise1.createPlannedSet(weight: 60, reps: 10)
        exercise1.createPlannedSet(weight: 65, reps: 8)
        day.addExercise(exercise1)

        let exercise2 = PlanExercise(exerciseId: UUID(), orderIndex: 1, plannedSetCount: 4)
        exercise2.createPlannedSet(weight: 80, reps: 8)
        exercise2.createPlannedSet(weight: 80, reps: 8)
        exercise2.createPlannedSet(weight: 85, reps: 6)
        exercise2.createPlannedSet(weight: 85, reps: 6)
        day.addExercise(exercise2)

        return ScrollView {
            VStack(spacing: 12) {
                PlanDayCardView(
                    day: day,
                    exercises: [:],
                    bodyParts: [:],
                    isExpanded: false,
                    editDestination: "edit1",
                    onToggleExpand: {}
                )

                PlanDayCardView(
                    day: day,
                    exercises: [:],
                    bodyParts: [:],
                    isExpanded: true,
                    editDestination: "edit2",
                    onToggleExpand: {}
                )

                let emptyDay = PlanDay(dayIndex: 2, name: nil)
                PlanDayCardView(
                    day: emptyDay,
                    exercises: [:],
                    bodyParts: [:],
                    isExpanded: true,
                    editDestination: "edit3",
                    onToggleExpand: {}
                )
            }
            .padding()
        }
        .background(AppColors.background)
    }
    .preferredColorScheme(.dark)
}
