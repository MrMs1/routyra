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
    var isGrouped: Bool = false
    @Binding var currentWeight: Double
    @Binding var currentReps: Int
    @Binding var currentDuration: Int
    @Binding var currentDistance: Double?
    let onTap: () -> Void
    let onLogSet: () -> Bool
    let onAddSet: () -> Void
    let onRemovePlannedSet: (WorkoutSet) -> Void
    let onDeleteSet: (WorkoutSet) -> Void
    let onDeleteEntry: () -> Void
    let onChangeExercise: () -> Void
    var onUpdateSet: ((WorkoutSet) -> Bool)?
    var onApplySet: ((WorkoutSet) -> Bool)?
    var onUncompleteSet: ((WorkoutSet) -> Void)?
    var onTimerStart: ((Int) -> Void)?
    var onTimerCancel: (() -> Void)?
    var onUpdateRestTime: ((WorkoutSet, Int) -> Void)?
    var defaultRestTimeSeconds: Int = 90
    var isCombinationModeEnabled: Bool = false
    var timerManager: RestTimerManager?
    var weightUnit: WeightUnit = .kg

    @State private var selectedSetIndex: Int?
    @State private var showDeleteEntryConfirmation: Bool = false
    @State private var swipeOffset: CGFloat = 0
    @State private var isSwipeOpen: Bool = false
    @State private var logSuccessPulse: Bool = false
    @State private var hapticTrigger: Int = 0

    private let deleteButtonWidth: CGFloat = 80
    private let deleteButtonHeight: CGFloat = 56

    private var activeSetIndex: Int? {
        sortedSets.firstIndex { !$0.isCompleted }
    }

    private var activeSet: WorkoutSet? {
        guard let index = activeSetIndex, index < sortedSets.count else { return nil }
        return sortedSets[index]
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

    /// The last completed set (highest index among completed sets)
    private var lastCompletedSet: WorkoutSet? {
        sortedSets.filter { $0.isCompleted }.last
    }

    /// Whether the selected set is the last completed set (only this can be uncompleted)
    private var canUncompleteSelectedSet: Bool {
        guard let selected = selectedSet, let lastCompleted = lastCompletedSet else { return false }
        return selected.id == lastCompleted.id
    }

    /// Can change exercise only when no sets have been completed yet
    private var canChangeExercise: Bool {
        !hasCompletedSets && !isGrouped
    }

    /// Whether this exercise type supports rest timer (weightReps or bodyweightReps)
    private var supportsRestTimer: Bool {
        entry.metricType == .weightReps || entry.metricType == .bodyweightReps
    }

    /// Get rest time from currently selected/active set (in seconds), falling back to default
    private var currentRestTimeSeconds: Int {
        if let index = selectedSetIndex, index < sortedSets.count {
            return sortedSets[index].restTimeSeconds ?? defaultRestTimeSeconds
        }
        if let index = activeSetIndex, index < sortedSets.count {
            return sortedSets[index].restTimeSeconds ?? defaultRestTimeSeconds
        }
        return defaultRestTimeSeconds
    }

    /// Get the current set for rest time editing (selected or active set)
    private var currentSetForRestTime: WorkoutSet? {
        if let index = selectedSetIndex, index < sortedSets.count {
            return sortedSets[index]
        }
        if let index = activeSetIndex, index < sortedSets.count {
            return sortedSets[index]
        }
        return nil
    }

    /// Whether user is currently viewing a completed set (not the active one)
    private var isViewingCompletedSet: Bool {
        guard let selected = selectedSetIndex,
              let active = activeSetIndex else { return false }
        return selected < active
    }

    /// Whether user is selecting a completed set (including when all sets are completed)
    private var isEditingCompletedSet: Bool {
        selectedSet?.isCompleted == true
    }

    /// Whether the input values differ from the selected completed set's values
    private var isCompletedSetDirty: Bool {
        guard let set = selectedSet, set.isCompleted else { return false }

        switch set.metricType {
        case .weightReps:
            let weightDiff = abs(currentWeight - set.weightDouble) >= 0.01
            let repsDiff = currentReps != (set.reps ?? 0)
            return weightDiff || repsDiff
        case .bodyweightReps:
            return currentReps != (set.reps ?? 0)
        case .timeDistance:
            let durationDiff = currentDuration != (set.durationSeconds ?? 0)
            let distanceDiff: Bool
            if let setDistance = set.distanceMeters, let currentDist = currentDistance {
                distanceDiff = abs(currentDist - setDistance) >= 0.01
            } else {
                distanceDiff = (set.distanceMeters != nil) != (currentDistance != nil)
            }
            return durationDiff || distanceDiff
        case .completion:
            return false
        }
    }

    /// Whether the input values differ from the active (next incomplete) set's values
    private var isActiveSetDirty: Bool {
        guard let set = activeSet, !set.isCompleted else { return false }

        switch set.metricType {
        case .weightReps:
            let weightDiff = abs(currentWeight - set.weightDouble) >= 0.01
            let repsDiff = currentReps != (set.reps ?? 0)
            return weightDiff || repsDiff
        case .bodyweightReps:
            return currentReps != (set.reps ?? 0)
        case .timeDistance:
            let durationDiff = currentDuration != (set.durationSeconds ?? 0)
            let distanceDiff: Bool
            if let setDistance = set.distanceMeters, let currentDist = currentDistance {
                distanceDiff = abs(currentDist - setDistance) >= 0.01
            } else {
                distanceDiff = (set.distanceMeters != nil) != (currentDistance != nil)
            }
            return durationDiff || distanceDiff
        case .completion:
            return false
        }
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
            .background(cardBackgroundColor)
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
        Group {
            if isGrouped {
                Color.clear
                    .frame(width: deleteButtonWidth, height: deleteButtonHeight)
            } else {
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
                    .frame(width: deleteButtonWidth, height: deleteButtonHeight)
                }
            }
        }
    }

    private var cardBackgroundColor: Color {
        if isGrouped {
            return entry.isPlannedSetsCompleted
                ? AppColors.groupedCardBackgroundCompleted
                : AppColors.groupedCardBackground
        }
        return entry.isPlannedSetsCompleted ? AppColors.cardBackgroundCompleted : AppColors.cardBackground
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                guard !isGrouped else { return }
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
                guard !isGrouped else { return }
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
                // Exercise name - tapping collapses the card
                Button(action: onTap) {
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
                    }
                }
                .buttonStyle(.plain)

                // Change exercise chip - only shown when no completed sets
                if canChangeExercise {
                    Button(action: onChangeExercise) {
                        Text("workout_change_exercise")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppColors.cardBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Delete button: deletes set if multiple sets, or shows entry delete confirmation if only one set
                Button(action: {
                    let canDeleteEntry = hasOnlyOneSet && !isGrouped
                    let canDeleteSet = deletableSet != nil
                    if hasOnlyOneSet {
                        if canDeleteEntry {
                            showDeleteEntryConfirmation = true
                        }
                    } else if let set = deletableSet, canDeleteSet {
                        onDeleteSet(set)
                        ensureSelection()
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(hasOnlyOneSet ? AppColors.textMuted : AppColors.textMuted)
                        .padding(8)
                }
                .opacity((hasOnlyOneSet && !isGrouped) || deletableSet != nil ? 1 : 0)
                .disabled(!((hasOnlyOneSet && !isGrouped) || deletableSet != nil))
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)

            HStack(alignment: .top, spacing: 20) {
                SetDotsView(
                    sets: sortedSets,
                    activeSetIndex: activeSetIndex,
                    selectedSetIndex: $selectedSetIndex,
                    onCompletedSetTap: handleCompletedSetTap,
                    onActiveSetTap: handleActiveSetTap,
                    onFutureSetLongPress: handleFutureSetLongPress,
                    pulse: logSuccessPulse
                )
                .padding(.leading, 16)

                VStack(spacing: 16) {
                    // Switch input view based on metric type
                    switch entry.metricType {
                    case .weightReps:
                        WeightRepsInputView(
                            weight: $currentWeight,
                            reps: $currentReps,
                            pulse: logSuccessPulse,
                            weightUnit: weightUnit
                        )
                    case .bodyweightReps:
                        BodyweightRepsInputView(
                            reps: $currentReps,
                            pulse: logSuccessPulse
                        )
                    case .timeDistance:
                        TimeDistanceInputView(
                            durationSeconds: $currentDuration,
                            distanceMeters: $currentDistance,
                            pulse: logSuccessPulse
                        )
                    case .completion:
                        CompletionInputView(pulse: logSuccessPulse)
                    }

                    // Button conditions (4-way):
                    // 1. isEditingCompletedSet && isCompletedSetDirty → Update set
                    // 2. allSetsCompleted && !isCompletedSetDirty → Add set
                    // 3. isViewingCompletedSet → Go to current set
                    // 4. else → Log set
                    if isEditingCompletedSet && isCompletedSetDirty {
                        // Update button (value changed on completed set)
                        Button(action: {
                            if let set = selectedSet {
                                if let onUpdate = onUpdateSet, onUpdate(set) {
                                    navigateToCurrentSetOrStay()
                                }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil")
                                    .font(.subheadline.weight(.semibold))
                                Text("workout_update_set")
                            }
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.accentBlue)
                            .cornerRadius(10)
                        }
                    } else if allSetsCompleted && !isGrouped {
                        // Add set button (all sets done, no pending edits)
                        // Hidden for grouped exercises (set count controlled at group level)
                        VStack(spacing: 8) {
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

                            // Uncomplete set button (only for last completed set)
                            if canUncompleteSelectedSet, let selectedSet = selectedSet {
                                Button(action: {
                                    onUncompleteSet?(selectedSet)
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.uturn.backward")
                                            .font(.subheadline.weight(.semibold))
                                        Text("workout_uncomplete_set")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                }
                            }
                        }
                    } else if isViewingCompletedSet {
                        // Go to current set button (viewing completed, but there are incomplete sets)
                        VStack(spacing: 8) {
                            Button(action: {
                                navigateToCurrentSet()
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

                            // Uncomplete set button (only for last completed set)
                            if canUncompleteSelectedSet, let selectedSet = selectedSet {
                                Button(action: {
                                    onUncompleteSet?(selectedSet)
                                    navigateToCurrentSet()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.uturn.backward")
                                            .font(.subheadline.weight(.semibold))
                                        Text("workout_uncomplete_set")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                }
                            }
                        }
                    } else {
                        if isActiveSetDirty, let set = activeSet {
                            // Apply input values to the active set without completing it.
                            if supportsRestTimer, let manager = timerManager, !isGrouped {
                                RestTimerActionDockView(
                                    isCombinationMode: isCombinationModeEnabled,
                                    restTimeSeconds: currentRestTimeSeconds,
                                    onLog: {
                                        let success = onApplySet?(set) ?? false
                                        if success {
                                            ensureSelection()
                                        }
                                        return success
                                    },
                                    onTimerStart: {
                                        onTimerStart?(currentRestTimeSeconds)
                                    },
                                    onTimerCancel: {
                                        onTimerCancel?()
                                    },
                                    onRestTimeChange: { newTime in
                                        if let set = currentSetForRestTime {
                                            onUpdateRestTime?(set, newTime)
                                        }
                                    },
                                    timerManager: manager,
                                    logTitleKey: "workout_apply_set",
                                    logIconName: "square.and.arrow.down"
                                )
                            } else {
                                applyToSetButton(set: set)
                            }
                        } else {
                            // Action dock for log + rest timer
                            if supportsRestTimer, let manager = timerManager, !isGrouped {
                                RestTimerActionDockView(
                                    isCombinationMode: isCombinationModeEnabled,
                                    restTimeSeconds: currentRestTimeSeconds,
                                    onLog: {
                                        let success = onLogSet()
                                        if success {
                                            ensureSelection()
                                        }
                                        return success
                                    },
                                    onTimerStart: {
                                        onTimerStart?(currentRestTimeSeconds)
                                    },
                                    onTimerCancel: {
                                        onTimerCancel?()
                                    },
                                    onRestTimeChange: { newTime in
                                        if let set = currentSetForRestTime {
                                            onUpdateRestTime?(set, newTime)
                                        }
                                    },
                                    timerManager: manager
                                )
                            } else {
                                // Fallback: simple log button for non-timer exercises
                                simpleLogButton
                            }
                        }
                    }
                }
                .padding(.trailing, 16)
            }
            .padding(.bottom, 16)
        }
    }

    /// Simple log button for exercises that don't support rest timer
    private var simpleLogButton: some View {
        Button(action: {
            let success = onLogSet()
            if success {
                ensureSelection()
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
    }

    /// Apply current inputs to the active set (without completing it)
    private func applyToSetButton(set: WorkoutSet) -> some View {
        Button(action: {
            let success = onApplySet?(set) ?? false
            if success {
                ensureSelection()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down")
                    .font(.subheadline.weight(.semibold))
                Text("workout_apply_set")
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.accentBlue)
            .cornerRadius(10)
        }
    }

    private var subtitleText: String? {
        let completed = entry.completedSetsCount
        let total = entry.activeSets.count

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
        // Show the completed set's actual logged values
        if index < sortedSets.count {
            let set = sortedSets[index]
            updateCurrentValuesFromSet(set)
        }
    }

    private func handleActiveSetTap(_ index: Int) {
        selectedSetIndex = index
        // Restore the active set's planned values
        if index < sortedSets.count {
            let set = sortedSets[index]
            updateCurrentValuesFromSet(set)
        }
    }

    private func handleFutureSetLongPress(_ index: Int) {
        // Don't allow removing planned sets for grouped exercises
        guard !isGrouped else { return }
        guard index < sortedSets.count else { return }
        let set = sortedSets[index]
        onRemovePlannedSet(set)
    }

    /// Navigate to the active (next incomplete) set and restore its values
    private func navigateToCurrentSet() {
        if let activeIndex = activeSetIndex {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSetIndex = activeIndex
            }
            // Get values directly from sortedSets
            if activeIndex < sortedSets.count {
                let set = sortedSets[activeIndex]
                updateCurrentValuesFromSet(set)
            }
        }
    }

    /// Updates current input values from a set based on its metric type
    private func updateCurrentValuesFromSet(_ set: WorkoutSet) {
        switch set.metricType {
        case .weightReps:
            currentWeight = set.weightDouble
            currentReps = set.reps ?? 0
        case .bodyweightReps:
            currentReps = set.reps ?? 0
        case .timeDistance:
            currentDuration = set.durationSeconds ?? 60
            currentDistance = set.distanceMeters
        case .completion:
            break
        }
    }

    /// After a successful update: navigate to active set if available, otherwise stay
    private func navigateToCurrentSetOrStay() {
        if activeSetIndex != nil {
            navigateToCurrentSet()
        }
        // If all sets are completed, stay at the current (just updated) set
    }

    /// Format rest time for display (e.g., "1:30")
    private func formatRestTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
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
    var weightUnit: WeightUnit = .kg

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
        Formatters.formatWeight(weight)
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.tr("done")) {
                    weightFieldFocused = false
                    repsFieldFocused = false
                }
                .foregroundColor(AppColors.accentBlue)
            }
        }
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
                    .onChange(of: weightText) { _, newValue in
                        // Update binding immediately so logging works without dismissing keyboard
                        if let value = Double(newValue) {
                            weight = value
                        }
                    }
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

            Text(weightUnit.symbol)
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
                    .onChange(of: repsText) { _, newValue in
                        // Update binding immediately so logging works without dismissing keyboard
                        if let value = Int(newValue) {
                            reps = value
                        }
                    }
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
    let onActiveSetTap: (Int) -> Void
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
                            // Tap on active set - update selection and restore values
                            onActiveSetTap(index)
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

// MARK: - Bodyweight Reps Input View

struct BodyweightRepsInputView: View {
    @Binding var reps: Int
    var pulse: Bool = false

    @State private var repsText = ""
    @State private var isEditingReps = false

    @FocusState private var repsFieldFocused: Bool

    private let repsFontSize: CGFloat = 38
    private let unitFontSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 0) {
            repsInputGroup
                .onTapGesture {
                    isEditingReps = true
                }
        }
        .scaleEffect(pulse ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: pulse)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.tr("done")) {
                    repsFieldFocused = false
                }
                .foregroundColor(AppColors.accentBlue)
            }
        }
    }

    private var repsInputGroup: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if isEditingReps {
                TextField("", text: $repsText)
                    .keyboardType(.numberPad)
                    .font(.system(size: repsFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 70)
                    .multilineTextAlignment(.center)
                    .focused($repsFieldFocused)
                    .onChange(of: repsText) { _, newValue in
                        if let value = Int(newValue) {
                            reps = value
                        }
                    }
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

// MARK: - Time/Distance Input View

struct TimeDistanceInputView: View {
    @Binding var durationSeconds: Int
    @Binding var distanceMeters: Double?
    var pulse: Bool = false

    @State private var minutesText = ""
    @State private var secondsText = ""
    @State private var distanceText = ""
    @State private var isEditingMinutes = false
    @State private var isEditingSeconds = false
    @State private var isEditingDistance = false

    @FocusState private var minutesFieldFocused: Bool
    @FocusState private var secondsFieldFocused: Bool
    @FocusState private var distanceFieldFocused: Bool

    private let valueFontSize: CGFloat = 32
    private let unitFontSize: CGFloat = 14

    private var minutes: Int {
        durationSeconds / 60
    }

    private var seconds: Int {
        durationSeconds % 60
    }

    private var distanceKm: Double? {
        guard let meters = distanceMeters else { return nil }
        return meters / 1000
    }

    var body: some View {
        HStack(spacing: 4) {
            // Time group (minutes : seconds)
            HStack(spacing: 2) {
                // Minutes value
                timeValueView(
                    value: minutes,
                    text: $minutesText,
                    isEditing: $isEditingMinutes,
                    focused: $minutesFieldFocused,
                    onUpdate: { newMinutes in
                        durationSeconds = newMinutes * 60 + seconds
                    }
                )

                Text(L10n.tr("unit_min"))
                    .font(.system(size: unitFontSize, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize()

                Text(":")
                    .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.textMuted)
                    .padding(.horizontal, 2)

                // Seconds value
                timeValueView(
                    value: seconds,
                    text: $secondsText,
                    isEditing: $isEditingSeconds,
                    focused: $secondsFieldFocused,
                    onUpdate: { newSeconds in
                        durationSeconds = minutes * 60 + min(newSeconds, 59)
                    }
                )

                Text(L10n.tr("unit_sec"))
                    .font(.system(size: unitFontSize, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize()
            }
            .fixedSize()

            Spacer()

            // Distance group
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                distanceValueView

                Text(L10n.tr("unit_km"))
                    .font(.system(size: unitFontSize, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize()
            }
            .fixedSize()
        }
        .scaleEffect(pulse ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: pulse)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.tr("done")) {
                    minutesFieldFocused = false
                    secondsFieldFocused = false
                    distanceFieldFocused = false
                }
                .foregroundColor(AppColors.accentBlue)
            }
        }
    }

    @ViewBuilder
    private func timeValueView(
        value: Int,
        text: Binding<String>,
        isEditing: Binding<Bool>,
        focused: FocusState<Bool>.Binding,
        onUpdate: @escaping (Int) -> Void
    ) -> some View {
        if isEditing.wrappedValue {
            TextField("", text: text)
                .keyboardType(.numberPad)
                .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 50)
                .multilineTextAlignment(.center)
                .focused(focused)
                .onChange(of: text.wrappedValue) { _, newValue in
                    if let intValue = Int(newValue) {
                        onUpdate(intValue)
                    }
                }
                .onChange(of: focused.wrappedValue) { _, isFocused in
                    if !isFocused {
                        if let intValue = Int(text.wrappedValue) {
                            onUpdate(intValue)
                        }
                        isEditing.wrappedValue = false
                    }
                }
                .onAppear {
                    text.wrappedValue = "\(value)"
                    focused.wrappedValue = true
                }
        } else {
            Text(String(format: "%02d", value))
                .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
                .frame(minWidth: 50)
                .onTapGesture {
                    isEditing.wrappedValue = true
                }
        }
    }

    @ViewBuilder
    private var distanceValueView: some View {
        if isEditingDistance {
            TextField("", text: $distanceText)
                .keyboardType(.decimalPad)
                .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 55)
                .multilineTextAlignment(.center)
                .focused($distanceFieldFocused)
                .onChange(of: distanceText) { _, newValue in
                    if newValue.isEmpty {
                        distanceMeters = nil
                    } else if let km = Double(newValue) {
                        distanceMeters = km * 1000
                    }
                }
                .onChange(of: distanceFieldFocused) { _, focused in
                    if !focused {
                        if distanceText.isEmpty {
                            distanceMeters = nil
                        } else if let km = Double(distanceText) {
                            distanceMeters = km * 1000
                        }
                        isEditingDistance = false
                    }
                }
                .onAppear {
                    if let km = distanceKm {
                        distanceText = String(format: "%.1f", km)
                    } else {
                        distanceText = ""
                    }
                    distanceFieldFocused = true
                }
        } else {
            Text(distanceKm.map { String(format: "%.1f", $0) } ?? "--")
                .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(distanceKm != nil ? AppColors.textPrimary : AppColors.textMuted)
                .frame(minWidth: 55)
                .onTapGesture {
                    isEditingDistance = true
                }
        }
    }
}

// MARK: - Completion Input View

struct CompletionInputView: View {
    var pulse: Bool = false

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            Text("workout_completion_ready")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.textSecondary)
        }
        .scaleEffect(pulse ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: pulse)
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
        currentDuration: .constant(60),
        currentDistance: .constant(nil),
        onTap: {},
        onLogSet: { true },
        onAddSet: {},
        onRemovePlannedSet: { _ in },
        onDeleteSet: { _ in },
        onDeleteEntry: {},
        onChangeExercise: {},
        onUpdateSet: { _ in true },
        onTimerStart: { _ in }
    )
    .padding()
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
