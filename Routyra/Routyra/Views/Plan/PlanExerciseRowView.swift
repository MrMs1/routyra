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
    let onToggleExpand: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void

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
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onDuplicate()
            } label: {
                Label("複製", systemImage: "doc.on.doc")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("削除", systemImage: "trash")
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

                            Text(exercise?.localizedName ?? "Unknown")
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
                        Text(planExercise.setsSummary)
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
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 4)

            // Set list
            ForEach(planExercise.sortedPlannedSets, id: \.id) { plannedSet in
                PlannedSetRowView(plannedSet: plannedSet) {
                    planExercise.removePlannedSet(plannedSet)
                    planExercise.reindexPlannedSets()
                }
            }

            // Add set button
            Button {
                // Copy weight/reps from last set if available
                let lastSet = planExercise.sortedPlannedSets.last
                planExercise.createPlannedSet(
                    weight: lastSet?.targetWeight,
                    reps: lastSet?.targetReps ?? 10
                )
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("セットを追加")
                }
                .font(.caption)
                .foregroundColor(AppColors.accentBlue)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.top, 4)
    }
}

// MARK: - Planned Set Row

private struct PlannedSetRowView: View {
    @Bindable var plannedSet: PlannedSet
    let onDelete: () -> Void

    @State private var weightText: String = ""
    @State private var repsText: String = ""

    var body: some View {
        HStack(spacing: 8) {
            // Set number
            Text("Set \(plannedSet.orderIndex + 1)")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .frame(width: 44, alignment: .leading)

            // Weight input
            HStack(spacing: 4) {
                TextField("--", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(AppColors.background)
                    .cornerRadius(6)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                    .onChange(of: weightText) { _, newValue in
                        plannedSet.targetWeight = Double(newValue)
                    }

                Text("kg")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Text("×")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)

            // Reps input
            HStack(spacing: 4) {
                TextField("--", text: $repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 40)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(AppColors.background)
                    .cornerRadius(6)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                    .onChange(of: repsText) { _, newValue in
                        plannedSet.targetReps = Int(newValue)
                    }

                Text("reps")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textMuted)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            if let w = plannedSet.targetWeight {
                weightText = w.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(w))"
                    : String(format: "%.1f", w)
            }
            if let r = plannedSet.targetReps {
                repsText = "\(r)"
            }
        }
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
