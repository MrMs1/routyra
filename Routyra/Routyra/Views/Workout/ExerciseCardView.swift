//
//  ExerciseCardView.swift
//  Routyra
//

import SwiftUI

struct ExerciseEntryCardView: View {
    @Bindable var entry: WorkoutExerciseEntry
    let exerciseName: String
    let bodyPartColor: Color?
    let isExpanded: Bool
    @Binding var currentWeight: Double
    @Binding var currentReps: Int
    let onTap: () -> Void
    let onLogSet: () -> Bool
    let onAddSet: () -> Void
    let onRemovePlannedSet: (WorkoutSet) -> Void
    let onDeleteSet: (WorkoutSet) -> Void
    let onDeleteEntry: () -> Void
    let onChangeExercise: () -> Void

    @State private var selectedSetIndex: Int?
    @State private var logSuccessPulse: Bool = false
    @State private var hapticTrigger: Int = 0
    @State private var showDeleteEntryConfirmation: Bool = false
    @State private var swipeOffset: CGFloat = 0
    @State private var isSwipeOpen: Bool = false

    private let deleteButtonWidth: CGFloat = 80

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

    /// Whether there's only one set (show entry delete instead of set delete)
    private var hasOnlyOneSet: Bool {
        sortedSets.count == 1
    }

    private var canDeleteSet: Bool {
        sortedSets.count > 1
    }

    private var deletableSet: WorkoutSet? {
        guard canDeleteSet else { return nil }
        if let selectedSet {
            return selectedSet
        }
        if let activeIndex = activeSetIndex, activeIndex < sortedSets.count {
            return sortedSets[activeIndex]
        }
        return nil
    }

    private var allSetsCompleted: Bool {
        !sortedSets.isEmpty && sortedSets.allSatisfy { $0.isCompleted }
    }

    /// Returns true if any set has been completed (used to restrict exercise change)
    private var hasCompletedSets: Bool {
        sortedSets.contains { $0.isCompleted }
    }

    /// Can change exercise only when no sets have been completed yet
    private var canChangeExercise: Bool {
        !hasCompletedSets
    }

    /// Whether user is currently viewing a completed set (not the active one)
    private var isViewingCompletedSet: Bool {
        guard let selected = selectedSetIndex,
              let active = activeSetIndex else { return false }
        return selected < active
    }

    private func ensureSelection() {
        guard !sortedSets.isEmpty else {
            selectedSetIndex = nil
            return
        }

        if let activeIndex = activeSetIndex {
            if selectedSetIndex != activeIndex {
                selectedSetIndex = activeIndex
            }
            return
        }

        let lastIndex = max(sortedSets.count - 1, 0)
        if selectedSetIndex == nil || (selectedSetIndex ?? 0) >= sortedSets.count {
            selectedSetIndex = lastIndex
        }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button (behind the card)
            deleteButton

            // Main card content
            VStack(alignment: .leading, spacing: 0) {
                if isExpanded {
                    expandedContent
                } else {
                    collapsedContent
                }
            }
            .background(entry.isPlannedSetsCompleted ? AppColors.cardBackgroundCompleted : AppColors.cardBackground)
            .cornerRadius(12)
            .offset(x: swipeOffset)
            .gesture(swipeGesture)
            .onTapGesture {
                if isSwipeOpen {
                    withAnimation(.easeOut(duration: 0.2)) {
                        swipeOffset = 0
                        isSwipeOpen = false
                    }
                } else if !isExpanded {
                    onTap()
                }
            }
        }
        .confirmationDialog(
            L10n.tr("workout_delete_entry_title"),
            isPresented: $showDeleteEntryConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.tr("delete"), role: .destructive) {
                onDeleteEntry()
            }
            Button(L10n.tr("cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr("workout_delete_entry_message", exerciseName))
        }
        .onChange(of: isExpanded) { _, newValue in
            if newValue {
                ensureSelection()
            }
        }
        .onAppear {
            ensureSelection()
        }
        .onChange(of: sortedSets.count) { _, _ in
            ensureSelection()
        }
        .onChange(of: activeSetIndex) { _, _ in
            ensureSelection()
        }
    }

    private var deleteButton: some View {
        Button(action: {
            showDeleteEntryConfirmation = true
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red)

                Image(systemName: "trash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: deleteButtonWidth)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let translation = value.translation.width
                if isSwipeOpen {
                    // Already open, allow dragging back
                    let newOffset = -deleteButtonWidth + translation
                    swipeOffset = min(0, max(-deleteButtonWidth, newOffset))
                } else {
                    // Only allow left swipe (negative translation)
                    if translation < 0 {
                        swipeOffset = max(-deleteButtonWidth, translation)
                    }
                }
            }
            .onEnded { value in
                let translation = value.translation.width
                let velocity = value.predictedEndTranslation.width - translation

                withAnimation(.easeOut(duration: 0.2)) {
                    if isSwipeOpen {
                        // If swiping right fast enough or past threshold, close
                        if translation > deleteButtonWidth / 2 || velocity > 50 {
                            swipeOffset = 0
                            isSwipeOpen = false
                        } else {
                            swipeOffset = -deleteButtonWidth
                        }
                    } else {
                        // If swiping left fast enough or past threshold, open
                        if translation < -deleteButtonWidth / 2 || velocity < -50 {
                            swipeOffset = -deleteButtonWidth
                            isSwipeOpen = true
                        } else {
                            swipeOffset = 0
                        }
                    }
                }
            }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with exercise name and delete button (always same size)
            HStack {
                Button(action: {
                    // Only allow change when no completed sets exist
                    if canChangeExercise {
                        onChangeExercise()
                    }
                }) {
                    HStack(spacing: 8) {
                        // Body part color dot
                        if let color = bodyPartColor {
                            Circle()
                                .fill(color)
                                .frame(width: 10, height: 10)
                        }

                        Text(exerciseName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)

                        // Show "変更" label and chevron only when exercise can be changed
                        // (i.e., no completed sets exist)
                        if canChangeExercise {
                            Text("workout_change_exercise")
                                .font(.caption)
                                .foregroundColor(Color.white.opacity(0.55))

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.55))
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Delete button: deletes set if multiple sets, or shows entry delete confirmation if only one set
                Button(action: {
                    if hasOnlyOneSet {
                        showDeleteEntryConfirmation = true
                    } else if let set = deletableSet {
                        onDeleteSet(set)
                        ensureSelection()
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(hasOnlyOneSet ? AppColors.textMuted : AppColors.textMuted)
                        .padding(8)
                }
                .opacity(hasOnlyOneSet || deletableSet != nil ? 1 : 0)
                .disabled(!hasOnlyOneSet && deletableSet == nil)
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)

            HStack(alignment: .top, spacing: 20) {
                SetDotsView(
                    sets: sortedSets,
                    activeSetIndex: activeSetIndex,
                    selectedSetIndex: $selectedSetIndex,
                    onCompletedSetTap: handleCompletedSetTap,
                    onFutureSetLongPress: handleFutureSetLongPress,
                    pulse: logSuccessPulse
                )
                .padding(.leading, 16)

                VStack(spacing: 16) {
                    WeightRepsInputView(
                        weight: $currentWeight,
                        reps: $currentReps,
                        pulse: logSuccessPulse
                    )

                    // Show "Add Set" when all sets completed OR viewing a completed set
                    if allSetsCompleted {
                        Button(action: {
                            onAddSet()
                            ensureSelection()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.subheadline.weight(.semibold))
                                Text("workout_add_set")
                            }
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.accentBlue.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(AppColors.accentBlue.opacity(0.45), lineWidth: 1)
                            )
                            .cornerRadius(10)
                            .shadow(color: AppColors.accentBlue.opacity(0.18), radius: 6, y: 2)
                        }
                    } else if isViewingCompletedSet {
                        // Viewing a completed set - button navigates to active set
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedSetIndex = activeSetIndex
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text("workout_go_to_current_set")
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.accentBlue.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(AppColors.accentBlue.opacity(0.45), lineWidth: 1)
                            )
                            .cornerRadius(10)
                        }
                    } else {
                        Button(action: {
                            let success = onLogSet()
                            if success {
                                // Trigger success animation
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    logSuccessPulse = true
                                }
                                hapticTrigger += 1
                                ensureSelection()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        logSuccessPulse = false
                                    }
                                }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                Text("workout_log_set")
                            }
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.accentBlue)
                            .cornerRadius(10)
                        }
                        .sensoryFeedback(.success, trigger: hapticTrigger)
                    }

                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Text("workout_rest_timer")
                                .font(.subheadline)
                                .foregroundColor(Color.white.opacity(0.52))
                            Image(systemName: "play.fill")
                                .font(.caption)
                                .foregroundColor(Color.white.opacity(0.52))
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
        let total = max(entry.plannedSetCount, entry.activeSets.count)

        guard total > 0 else { return nil }

        if completed >= total {
            return L10n.tr("workout_sets_completed", total)
        } else {
            return L10n.tr("workout_sets_progress", completed, total)
        }
    }

    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Body part color dot
                if let color = bodyPartColor {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }

                Text(exerciseName)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
            }

            if let subtitle = subtitleText {
                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textMuted)

                    if entry.isPlannedSetsCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.accentBlue)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private func handleCompletedSetTap(_ index: Int) {
        selectedSetIndex = index
    }

    private func handleFutureSetLongPress(_ index: Int) {
        guard index < sortedSets.count else { return }
        let set = sortedSets[index]
        onRemovePlannedSet(set)
    }
}

// MARK: - Value With Unit View

/// Displays a numeric value with a unit label, properly aligned at baseline.
/// Used for weight (kg) and reps display in workout cards.
struct ValueWithUnitView: View {
    let value: String
    let unit: String
    let valueFont: Font
    let valueFontSize: CGFloat
    let unitFontSize: CGFloat
    var valueColor: Color = AppColors.textPrimary
    var unitColor: Color = AppColors.textSecondary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(valueFont)
                .foregroundColor(valueColor)

            Text(unit)
                .font(.system(size: unitFontSize, weight: .medium, design: .rounded))
                .foregroundColor(unitColor)
                .baselineOffset(baselineOffsetForUnit)
        }
    }

    /// Calculate baseline offset to visually align the unit with the number
    /// Smaller unit fonts need a slight upward offset to look aligned
    private var baselineOffsetForUnit: CGFloat {
        // Offset proportional to the size difference
        let sizeDiff = valueFontSize - unitFontSize
        return sizeDiff * 0.08
    }
}

// MARK: - Weight/Reps Input View with editable appearance

struct WeightRepsInputView: View {
    @Binding var weight: Double
    @Binding var reps: Int
    var pulse: Bool = false

    @State private var weightText = ""
    @State private var repsText = ""
    @State private var isEditingWeight = false
    @State private var isEditingReps = false

    @FocusState private var weightFieldFocused: Bool
    @FocusState private var repsFieldFocused: Bool

    // Font sizes
    private let weightFontSize: CGFloat = 32
    private let repsFontSize: CGFloat = 38
    private let unitFontSize: CGFloat = 14

    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Weight input group
            weightInputGroup
                .onTapGesture {
                    isEditingWeight = true
                }

            // Separator
            Text("×")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.textMuted)
                .padding(.horizontal, 10)

            // Reps input group
            repsInputGroup
                .onTapGesture {
                    isEditingReps = true
                }
        }
        .scaleEffect(pulse ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: pulse)
    }

    // MARK: - Weight Input

    private var weightInputGroup: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if isEditingWeight {
                TextField("", text: $weightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: weightFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
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
                    .font(.system(size: weightFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
            }

            Text("unit_kg")
                .font(.system(size: unitFontSize, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.textSecondary)
                .baselineOffset((weightFontSize - unitFontSize) * 0.08)
        }
    }

    // MARK: - Reps Input

    private var repsInputGroup: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if isEditingReps {
                TextField("", text: $repsText)
                    .keyboardType(.numberPad)
                    .font(.system(size: repsFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 55)
                    .multilineTextAlignment(.leading)
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
                    .font(.system(size: repsFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
            }

            Text("unit_reps")
                .font(.system(size: unitFontSize, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.textSecondary)
                .baselineOffset((repsFontSize - unitFontSize) * 0.08)
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
    var pulse: Bool = false

    private let dotSize: CGFloat = 26
    private let dotSpacing: CGFloat = 8
    private let lineWidth: CGFloat = 2

    private var completedCount: Int {
        sets.filter { $0.isCompleted }.count
    }

    private var lineSegmentCount: Int {
        // Line extends from first completed to active set (or last completed if all done)
        if let active = activeSetIndex, completedCount > 0 {
            return active // extends to active set
        } else {
            return max(0, completedCount - 1) // only between completed
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Progress line (from first completed to active set)
            if lineSegmentCount > 0 {
                let baseHeight = CGFloat(lineSegmentCount) * (dotSize + dotSpacing)
                // Stop at edge of active circle (subtract half of dotSize)
                let lineHeight = activeSetIndex != nil && completedCount > 0
                    ? baseHeight - dotSize / 2
                    : baseHeight

                RoundedRectangle(cornerRadius: 1)
                    .fill(AppColors.dotFilled)
                    .frame(width: lineWidth)
                    .frame(height: lineHeight)
                    .offset(y: dotSize / 2)
                    .opacity(pulse ? 1.0 : 0.8)
                    .scaleEffect(x: pulse ? 1.5 : 1.0, y: 1.0)
                    .animation(.easeOut(duration: 0.3), value: lineSegmentCount)
                    .animation(.easeInOut(duration: 0.15), value: pulse)
            }

            // Dots
            VStack(spacing: dotSpacing) {
                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                    SetDotView(
                        index: index,
                        set: set,
                        isActive: activeSetIndex == index && selectedSetIndex == nil,
                        isSelected: selectedSetIndex == index,
                        dotSize: dotSize
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if set.isCompleted {
                            // Allow selecting completed sets anytime
                            onCompletedSetTap(index)
                        } else if index == activeSetIndex {
                            // Tap on active set selects it
                            selectedSetIndex = index
                        }
                        // Tap on future incomplete sets (beyond active) does nothing
                    }
                    .onLongPressGesture(minimumDuration: 0.3) {
                        if sets.count > 1 && !set.isCompleted && index != activeSetIndex {
                            onFutureSetLongPress(index)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Set Dot View

/// Individual dot representing a set in the progress indicator.
/// Extracted as a separate view to ensure proper state updates.
private struct SetDotView: View {
    let index: Int
    let set: WorkoutSet
    let isActive: Bool
    let isSelected: Bool
    let dotSize: CGFloat

    private var ringColor: Color {
        if set.isCompleted {
            return AppColors.accentBlue
        }
        return AppColors.textSecondary
    }

    private var numberColor: Color {
        if set.isCompleted {
            return AppColors.accentBlue
        }
        return AppColors.textPrimary
    }

    var body: some View {
        ZStack {
            if isActive || isSelected {
                // Background circle to cover the progress line
                Circle()
                    .fill(AppColors.cardBackground)
                    .frame(width: dotSize, height: dotSize)

                Circle()
                    .stroke(ringColor, lineWidth: 1.5)
                    .frame(width: dotSize, height: dotSize)

                Text("\(index + 1)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(numberColor)
            } else {
                Circle()
                    .fill(set.isCompleted ? AppColors.dotFilled : AppColors.dotEmpty)
                    .frame(width: 10, height: 10)
            }
        }
        .frame(width: dotSize, height: dotSize)
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
        bodyPartColor: Color(red: 0.95, green: 0.3, blue: 0.3),
        isExpanded: true,
        currentWeight: .constant(60),
        currentReps: .constant(8),
        onTap: {},
        onLogSet: { true },
        onAddSet: {},
        onRemovePlannedSet: { _ in },
        onDeleteSet: { _ in },
        onDeleteEntry: {},
        onChangeExercise: {}
    )
    .padding()
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
