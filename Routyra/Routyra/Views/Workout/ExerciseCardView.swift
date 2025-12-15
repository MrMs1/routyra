//
//  ExerciseCardView.swift
//  Routyra
//

import SwiftUI

struct ExerciseEntryCardView: View {
    @Bindable var entry: WorkoutExerciseEntry
    let exerciseName: String
    let isExpanded: Bool
    @Binding var currentWeight: Double
    @Binding var currentReps: Int
    let onTap: () -> Void
    let onLogSet: () -> Void
    let onAddSet: () -> Void
    let onRemovePlannedSet: (WorkoutSet) -> Void
    let onDeleteSet: (WorkoutSet) -> Void
    let onChangeExercise: () -> Void

    @State private var selectedSetIndex: Int?

    private var activeSetIndex: Int? {
        sortedSets.firstIndex { !$0.isCompleted }
    }

    private var sortedSets: [WorkoutSet] {
        entry.sortedSets
    }

    private var selectedSet: WorkoutSet? {
        guard let index = selectedSetIndex, index < sortedSets.count else { return nil }
        return sortedSets[index]
    }

    private var allSetsCompleted: Bool {
        !sortedSets.isEmpty && sortedSets.allSatisfy { $0.isCompleted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isExpanded {
                expandedContent
            } else {
                collapsedContent
            }
        }
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .onTapGesture {
            if !isExpanded {
                onTap()
            }
        }
        .onChange(of: isExpanded) { _, newValue in
            if !newValue {
                selectedSetIndex = nil
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with exercise name and delete button (always same size)
            HStack {
                Button(action: onChangeExercise) {
                    HStack(spacing: 4) {
                        Text(exerciseName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.textMuted)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: {
                    if let set = selectedSet, set.isCompleted {
                        onDeleteSet(set)
                        selectedSetIndex = nil
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textMuted)
                        .padding(8)
                }
                .opacity(selectedSet?.isCompleted == true ? 1 : 0)
                .disabled(selectedSet?.isCompleted != true)
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)

            HStack(alignment: .top, spacing: 20) {
                SetDotsView(
                    sets: sortedSets,
                    activeSetIndex: activeSetIndex,
                    selectedSetIndex: $selectedSetIndex,
                    onCompletedSetTap: handleCompletedSetTap,
                    onFutureSetLongPress: handleFutureSetLongPress
                )
                .padding(.leading, 16)

                VStack(spacing: 16) {
                    WeightRepsInputView(
                        weight: $currentWeight,
                        reps: $currentReps
                    )

                    if allSetsCompleted && selectedSetIndex == nil {
                        Button(action: {
                            onAddSet()
                        }) {
                            Text("+ Add Set")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.accentBlue.opacity(0.8))
                                .cornerRadius(10)
                        }
                    } else {
                        Button(action: {
                            selectedSetIndex = nil
                            onLogSet()
                        }) {
                            Text("+ Log Set")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.accentBlue)
                                .cornerRadius(10)
                        }
                    }

                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Text("Rest Timer")
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "play.fill")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .padding(.trailing, 16)
            }
            .padding(.bottom, 16)
        }
    }

    private var subtitleText: String? {
        let completed = entry.completedSetsCount
        let total = entry.plannedSetCount

        if entry.isPlannedSetsCompleted && total > 0 {
            return "\(total) sets completed"
        } else if completed > 0 {
            return "\(completed)/\(total) sets"
        } else {
            return nil
        }
    }

    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exerciseName)
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            if let subtitle = subtitleText {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private func handleCompletedSetTap(_ index: Int) {
        if selectedSetIndex == index {
            selectedSetIndex = nil
        } else {
            selectedSetIndex = index
        }
    }

    private func handleFutureSetLongPress(_ index: Int) {
        guard index < sortedSets.count else { return }
        let set = sortedSets[index]
        onRemovePlannedSet(set)
    }
}

// MARK: - Weight/Reps Input View with editable appearance

struct WeightRepsInputView: View {
    @Binding var weight: Double
    @Binding var reps: Int

    @State private var weightText = ""
    @State private var repsText = ""
    @State private var isEditingWeight = false
    @State private var isEditingReps = false

    @FocusState private var weightFieldFocused: Bool
    @FocusState private var repsFieldFocused: Bool

    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            // Weight input
            VStack(spacing: 2) {
                if isEditingWeight {
                    TextField("", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 85)
                        .multilineTextAlignment(.center)
                        .focused($weightFieldFocused)
                        .onChange(of: weightFieldFocused) { _, focused in
                            if !focused {
                                if let value = Double(weightText) {
                                    weight = value
                                }
                                isEditingWeight = false
                            }
                        }
                        .onAppear {
                            weightText = formatWeight(weight)
                            weightFieldFocused = true
                        }
                } else {
                    Text(formatWeight(weight))
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(minWidth: 60)
                }

                Rectangle()
                    .fill(isEditingWeight ? AppColors.accentBlue : AppColors.divider)
                    .frame(width: 70, height: 2)
                    .cornerRadius(1)
            }
            .onTapGesture {
                isEditingWeight = true
            }

            Text("kg")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textMuted)
                .padding(.leading, 2)

            Text("×")
                .font(.system(size: 18))
                .foregroundColor(AppColors.textMuted)
                .padding(.horizontal, 8)

            // Reps input
            VStack(spacing: 2) {
                if isEditingReps {
                    TextField("", text: $repsText)
                        .keyboardType(.numberPad)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 65)
                        .multilineTextAlignment(.center)
                        .focused($repsFieldFocused)
                        .onChange(of: repsFieldFocused) { _, focused in
                            if !focused {
                                if let value = Int(repsText) {
                                    reps = value
                                }
                                isEditingReps = false
                            }
                        }
                        .onAppear {
                            repsText = "\(reps)"
                            repsFieldFocused = true
                        }
                } else {
                    Text("\(reps)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(minWidth: 40)
                }

                Rectangle()
                    .fill(isEditingReps ? AppColors.accentBlue : AppColors.divider)
                    .frame(width: 50, height: 2)
                    .cornerRadius(1)
            }
            .onTapGesture {
                isEditingReps = true
            }

            Text("reps")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textMuted)
                .padding(.leading, 2)
        }
    }
}

// MARK: - Set Dots View (Simplified)

struct SetDotsView: View {
    let sets: [WorkoutSet]
    let activeSetIndex: Int?
    @Binding var selectedSetIndex: Int?
    let onCompletedSetTap: (Int) -> Void
    let onFutureSetLongPress: (Int) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                let isActive = activeSetIndex == index && selectedSetIndex == nil
                let isSelected = selectedSetIndex == index

                ZStack {
                    if isActive || isSelected {
                        Circle()
                            .stroke(isSelected ? AppColors.accentBlue : AppColors.textSecondary, lineWidth: 1.5)
                            .frame(width: 26, height: 26)

                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(isSelected ? AppColors.accentBlue : AppColors.textPrimary)
                    } else {
                        Circle()
                            .fill(set.isCompleted ? AppColors.dotFilled : AppColors.dotEmpty)
                            .frame(width: 10, height: 10)
                    }
                }
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
                .onTapGesture {
                    if set.isCompleted {
                        onCompletedSetTap(index)
                    }
                }
                .onLongPressGesture(minimumDuration: 0.3) {
                    if !set.isCompleted && index != activeSetIndex {
                        onFutureSetLongPress(index)
                    }
                }
            }
        }
    }
}

#Preview {
    let entry = WorkoutExerciseEntry(
        exerciseId: UUID(),
        orderIndex: 0,
        source: .free,
        plannedSetCount: 5
    )
    for i in 1...5 {
        let set = WorkoutSet(setIndex: i, weight: Decimal(60), reps: 8, isCompleted: i < 3)
        entry.addSet(set)
    }

    return ExerciseEntryCardView(
        entry: entry,
        exerciseName: "Bench Press",
        isExpanded: true,
        currentWeight: .constant(60),
        currentReps: .constant(8),
        onTap: {},
        onLogSet: {},
        onAddSet: {},
        onRemovePlannedSet: { _ in },
        onDeleteSet: { _ in },
        onChangeExercise: {}
    )
    .padding()
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
