//
//  PlanExerciseRowView.swift
//  Routyra
//
//  Displays an exercise within a plan day.
//  Collapsible: shows summary when collapsed, inline set editing when expanded.
//

import SwiftUI
import SwiftData

struct PlanExerciseRowView: View {
    @Bindable var planExercise: PlanExercise
    let exercise: Exercise?
    let bodyPart: BodyPart?
    let isExpanded: Bool
    var isGrouped: Bool = false
    let onToggleExpand: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    var onEditSets: (() -> Void)? = nil
    var weightUnit: WeightUnit = .kg

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row (always visible)
            headerRow

            // Expanded content (set editing)
            if isExpanded {
                expandedContent
                    .transition(.opacity.animation(.easeOut(duration: 1)))
            }
        }
        .padding(.vertical, isGrouped ? 8 : 12)
        .padding(.horizontal, 12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onDuplicate()
            } label: {
                Label("duplicate", systemImage: "doc.on.doc")
            }

            if isGrouped {
                // For grouped exercises, show "Remove from Group" instead of delete
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(L10n.tr("remove_from_group"), systemImage: "rectangle.stack.badge.minus")
                }
            } else {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 12) {
            // Expand/collapse button area
            Button {
                onToggleExpand()
            } label: {
                HStack(spacing: 12) {
                    // Chevron (left side like PlanDayCardView)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textMuted)
                        .frame(width: 16)

                    // Exercise info
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            // Body part color dot
                            if let bodyPart = bodyPart {
                                Circle()
                                    .fill(bodyPart.color)
                                    .frame(width: 8, height: 8)
                            }

                            Text(exercise?.localizedName ?? L10n.tr("unknown_exercise"))
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)

                            // Body part chip
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

                        // Summary
                        Text(planExercise.setsSummary(weightUnit: weightUnit))
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Set list (read-only, tappable for editing)
            let sets = planExercise.sortedPlannedSets
            if sets.isEmpty {
                Text("no_sets_configured")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
                    .padding(.vertical, 4)
            } else {
                Button {
                    onEditSets?()
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(sets.enumerated()), id: \.element.id) { index, plannedSet in
                            PlannedSetDisplayRow(
                                plannedSet: plannedSet,
                                setIndex: index + 1,
                                weightUnit: weightUnit
                            )

                            // Thin separator line (not after last row)
                            if index < sets.count - 1 {
                                Color.white.opacity(0.08)
                                    .frame(height: 1)
                                    .padding(.leading, 56)
                                    .padding(.trailing, 16)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
    }
}

#Preview {
    let planExercise = PlanExercise(exerciseId: UUID(), orderIndex: 0, plannedSetCount: 3)
    planExercise.createPlannedSet(weight: 60, reps: 10)
    planExercise.createPlannedSet(weight: 60, reps: 10)
    planExercise.createPlannedSet(weight: 60, reps: 8)

    return VStack(spacing: 8) {
        PlanExerciseRowView(
            planExercise: planExercise,
            exercise: nil,
            bodyPart: nil,
            isExpanded: false,
            onToggleExpand: {},
            onDelete: {},
            onDuplicate: {}
        )

        PlanExerciseRowView(
            planExercise: planExercise,
            exercise: nil,
            bodyPart: nil,
            isExpanded: true,
            onToggleExpand: {},
            onDelete: {},
            onDuplicate: {}
        )
    }
    .padding()
    .background(AppColors.cardBackground)
    .preferredColorScheme(.dark)
}
