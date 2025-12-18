//
//  PlanExerciseCardView.swift
//  Routyra
//
//  Read-only exercise card for Plan viewing.
//  Shows exercise summary when collapsed, full set list when expanded.
//

import SwiftUI

struct PlanExerciseCardView: View {
    let planExercise: PlanExercise
    let exercise: Exercise?
    let bodyPart: BodyPart?
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            Button {
                onToggle()
            } label: {
                headerContent
            }
            .buttonStyle(.plain)

            // Expanded content (set list)
            if isExpanded {
                expandedContent
                    .transition(.opacity.animation(.easeOut(duration: 1)))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(AppColors.cardBackground.opacity(0.6))
        .cornerRadius(10)
    }

    // MARK: - Header

    private var headerContent: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                // Exercise name + body part
                HStack(spacing: 8) {
                    // Body part color dot
                    if let bodyPart = bodyPart {
                        Circle()
                            .fill(bodyPart.color)
                            .frame(width: 8, height: 8)
                    }

                    Text(exercise?.localizedName ?? "不明な種目")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)

                    if let bodyPart = bodyPart {
                        Text(bodyPart.localizedName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.mutedBlue.opacity(0.2))
                            .foregroundColor(AppColors.textSecondary)
                            .cornerRadius(4)
                    }
                }

                // Set summary
                Text(planExercise.compactSummary)
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }

            Spacer()

            // Chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .frame(width: 20, height: 20)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .background(AppColors.divider)
                .padding(.vertical, 8)

            // Set list
            let sets = planExercise.sortedPlannedSets
            if sets.isEmpty {
                Text("セットが設定されていません")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(sets.enumerated()), id: \.element.id) { index, plannedSet in
                        setRow(index: index + 1, set: plannedSet)
                    }
                }
            }
        }
    }

    // MARK: - Set Row

    private func setRow(index: Int, set: PlannedSet) -> some View {
        HStack(spacing: 12) {
            // Set number
            Text("Set \(index)")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .frame(width: 44, alignment: .leading)

            // Weight
            HStack(spacing: 2) {
                Text(set.weightString)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(set.targetWeight != nil ? AppColors.textPrimary : AppColors.textMuted)
                Text("kg")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(width: 60, alignment: .trailing)

            Text("×")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)

            // Reps
            HStack(spacing: 2) {
                Text(set.repsString)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(set.targetReps != nil ? AppColors.textPrimary : AppColors.textMuted)
                Text("reps")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let planExercise = PlanExercise(exerciseId: UUID(), orderIndex: 0, plannedSetCount: 3)
    planExercise.createPlannedSet(weight: 60, reps: 10)
    planExercise.createPlannedSet(weight: 60, reps: 10)
    planExercise.createPlannedSet(weight: 65, reps: 8)

    return VStack(spacing: 12) {
        PlanExerciseCardView(
            planExercise: planExercise,
            exercise: nil,
            bodyPart: nil,
            isExpanded: false,
            onToggle: {}
        )

        PlanExerciseCardView(
            planExercise: planExercise,
            exercise: nil,
            bodyPart: nil,
            isExpanded: true,
            onToggle: {}
        )
    }
    .padding()
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
