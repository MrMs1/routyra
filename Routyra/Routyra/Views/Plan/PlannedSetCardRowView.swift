//
//  PlannedSetCardRowView.swift
//  Routyra
//
//  Mini-card row for displaying/editing a planned set.
//  2-tier layout: Top row for main inputs, bottom row for secondary controls.
//

import SwiftUI
import SwiftData

// MARK: - Constants

private enum SetRowConstants {
    static let cardCornerRadius: CGFloat = 12
    static let horizontalPadding: CGFloat = 14
    static let verticalPadding: CGFloat = 12
    static let setLabelWidth: CGFloat = 44
}

// MARK: - PlannedSetCardRowView

struct PlannedSetCardRowView: View {
    @Bindable var plannedSet: PlannedSet
    let setIndex: Int
    let canDelete: Bool
    let onDelete: () -> Void
    let weightUnit: WeightUnit

    @State private var isEditing: Bool = false
    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case weight
        case reps
    }

    // MARK: - Computed Properties

    private var isBodyweight: Bool {
        plannedSet.metricType == .bodyweightReps
    }

    private var isTimeDistance: Bool {
        plannedSet.metricType == .timeDistance
    }

    private var isCompletionOnly: Bool {
        plannedSet.metricType == .completion
    }

    private var supportsRestTimer: Bool {
        plannedSet.metricType == .weightReps || plannedSet.metricType == .bodyweightReps
    }

    private var supportsWeightToggle: Bool {
        plannedSet.metricType == .weightReps || plannedSet.metricType == .bodyweightReps
    }

    private var restTimeBinding: Binding<Int> {
        Binding(
            get: { plannedSet.restTimeSeconds ?? 0 },
            set: { plannedSet.restTimeSeconds = $0 > 0 ? $0 : nil }
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            // MARK: - Top Row: Main Input Area
            topRow

            // MARK: - Bottom Row: Secondary Controls
            bottomRow
        }
        .padding(.horizontal, SetRowConstants.horizontalPadding)
        .padding(.vertical, SetRowConstants.verticalPadding)
        .background(AppColors.background)
        .cornerRadius(SetRowConstants.cardCornerRadius)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                enterEditMode()
            }
        }
        .onAppear {
            syncTextFromModel()
        }
        .onChange(of: isEditing) { _, newValue in
            if !newValue {
                commitChanges()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.tr("done")) {
                    exitEditMode()
                }
                .foregroundColor(AppColors.accentBlue)
            }
        }
    }

    // MARK: - Top Row

    private var topRow: some View {
        HStack(spacing: 0) {
            // Set number (left aligned, fixed width)
            Text(L10n.tr("set_label", setIndex))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: SetRowConstants.setLabelWidth, alignment: .leading)

            // Main input: Weight × Reps (centered in remaining space)
            HStack(spacing: 8) {
                Spacer(minLength: 0)

                if isEditing {
                    editModeContent
                } else {
                    displayModeContent
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Row

    private var bottomRow: some View {
        HStack(spacing: 0) {
            // Left offset to align with top row (matches set label width)
            Color.clear
                .frame(width: SetRowConstants.setLabelWidth)

            // Centered content area (matching top row's centered layout)
            HStack(spacing: 16) {
                Spacer(minLength: 0)

                // Segmented toggle (kg/BW) - only for weight-based exercises
                if supportsWeightToggle {
                    segmentedToggle
                }

                // REST picker (if applicable)
                if supportsRestTimer {
                    RestTimePickerCompact(restTimeSeconds: restTimeBinding)
                }

                // Delete button
                if canDelete {
                    deleteButton
                } else {
                    Color.clear.frame(width: 28, height: 28)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Segmented Toggle

    private var segmentedToggle: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    plannedSet.metricType = .weightReps
                }
            } label: {
                Text(weightUnit.symbol)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(!isBodyweight ? AppColors.textPrimary : AppColors.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(!isBodyweight ? AppColors.cardBackground : Color.clear)
                    .cornerRadius(4)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    plannedSet.metricType = .bodyweightReps
                    plannedSet.targetWeight = nil
                }
            } label: {
                Text("bodyweight_label")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isBodyweight ? AppColors.accentBlue : AppColors.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isBodyweight ? AppColors.accentBlue.opacity(0.15) : Color.clear)
                    .cornerRadius(4)
            }
        }
        .padding(2)
        .background(AppColors.cardBackground.opacity(0.5))
        .cornerRadius(6)
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button {
            onDelete()
        } label: {
            Image(systemName: "trash")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .frame(width: 28, height: 28)
                .background(AppColors.cardBackground)
                .cornerRadius(6)
        }
    }

    // MARK: - Display Mode Content

    private var displayModeContent: some View {
        Group {
            if isCompletionOnly {
                // Completion only display
                Text(L10n.tr("completion_only_label"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.textMuted)
            } else if isTimeDistance {
                // Time / Distance display for cardio
                HStack(spacing: 8) {
                    // Duration
                    Text(plannedSet.durationString)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(plannedSet.targetDurationSeconds != nil ? AppColors.textPrimary : AppColors.textMuted)

                    // Separator (if has distance)
                    if plannedSet.targetDistanceMeters != nil {
                        Text("/")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textMuted)

                        // Distance
                        HStack(spacing: 2) {
                            Text(plannedSet.distanceString)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                            Text(L10n.tr("unit_km"))
                                .font(.caption)
                                .foregroundColor(AppColors.textMuted)
                        }
                    }
                }
            } else {
                // Weight × Reps display
                HStack(spacing: 8) {
                    // Weight or BW
                    if isBodyweight {
                        Text("bodyweight_label")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accentBlue)
                    } else {
                        HStack(spacing: 2) {
                            Text(weightDisplayText)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(plannedSet.targetWeight != nil ? AppColors.textPrimary : AppColors.textMuted)
                            Text(weightUnit.symbol)
                                .font(.caption)
                                .foregroundColor(AppColors.textMuted)
                        }
                    }

                    // Separator
                    Text("×")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textMuted)

                    // Reps
                    HStack(spacing: 2) {
                        Text(repsDisplayText)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(plannedSet.targetReps != nil ? AppColors.textPrimary : AppColors.textMuted)
                        Text("unit_reps")
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)
                    }
                }
            }
        }
    }

    // MARK: - Edit Mode Content

    private var editModeContent: some View {
        HStack(spacing: 8) {
            // Weight input or BW label
            if isBodyweight {
                Text("bodyweight_label")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accentBlue)
            } else {
                HStack(spacing: 2) {
                    TextField("—", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 56)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(AppColors.cardBackground)
                        .cornerRadius(8)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .focused($focusedField, equals: .weight)

                    Text(weightUnit.symbol)
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }
            }

            // Separator
            Text("×")
                .font(.subheadline)
                .foregroundColor(AppColors.textMuted)

            // Reps input
            HStack(spacing: 2) {
                TextField("—", text: $repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 48)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(AppColors.cardBackground)
                    .cornerRadius(8)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .focused($focusedField, equals: .reps)

                Text("unit_reps")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }

            // Done button
            Button {
                exitEditMode()
            } label: {
                Text("done")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accentBlue)
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
    }

    // MARK: - Display Text

    private var weightDisplayText: String {
        if let w = plannedSet.targetWeight {
            return w.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(w))"
                : String(format: "%.1f", w)
        }
        return "—"
    }

    private var repsDisplayText: String {
        if let r = plannedSet.targetReps {
            return "\(r)"
        }
        return "—"
    }

    // MARK: - Actions

    private func enterEditMode() {
        syncTextFromModel()
        withAnimation(.easeOut(duration: 0.15)) {
            isEditing = true
        }
        // Focus appropriate field after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField = isBodyweight ? .reps : .weight
        }
    }

    private func exitEditMode() {
        focusedField = nil
        withAnimation(.easeOut(duration: 0.15)) {
            isEditing = false
        }
    }

    private func syncTextFromModel() {
        if let w = plannedSet.targetWeight {
            weightText = w.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(w))"
                : String(format: "%.1f", w)
        } else {
            weightText = ""
        }
        if let r = plannedSet.targetReps {
            repsText = "\(r)"
        } else {
            repsText = ""
        }
    }

    private func commitChanges() {
        // Update model from text
        if weightText.isEmpty {
            plannedSet.targetWeight = nil
        } else if let w = Double(weightText) {
            plannedSet.targetWeight = w
        }

        if repsText.isEmpty {
            plannedSet.targetReps = nil
        } else if let r = Int(repsText) {
            plannedSet.targetReps = r
        }
    }
}

// MARK: - PlannedSetDisplayRow (Read-Only)

/// Read-only mini-card row for displaying a planned set.
/// Used in plan overview where editing is not needed.
struct PlannedSetDisplayRow: View {
    let plannedSet: PlannedSet
    let setIndex: Int
    let weightUnit: WeightUnit
    var showsRestTime: Bool = true

    private var isBodyweight: Bool {
        plannedSet.metricType == .bodyweightReps
    }

    private var isTimeDistance: Bool {
        plannedSet.metricType == .timeDistance
    }

    private var isCompletionOnly: Bool {
        plannedSet.metricType == .completion
    }

    private var formattedRestTime: String? {
        guard let seconds = plannedSet.restTimeSeconds, seconds > 0 else { return nil }
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Left: Set number (no fixed width, natural size)
            Text(L10n.tr("set_label", setIndex))
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .lineLimit(1)
                .fixedSize()

            Spacer(minLength: 0)

            // Center content
            if isCompletionOnly {
                // Completion only display
                Text(L10n.tr("completion_only_label"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.textMuted)
            } else if isTimeDistance {
                // Time / Distance display for cardio
                Text(plannedSet.durationString)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(plannedSet.targetDurationSeconds != nil ? AppColors.textPrimary : AppColors.textMuted)

                if plannedSet.targetDistanceMeters != nil {
                    Text("/")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textMuted)

                    HStack(spacing: 2) {
                        Text(plannedSet.distanceString)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                        Text(L10n.tr("unit_km"))
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)
                    }
                }
            } else {
                // Weight × Reps display
                if isBodyweight {
                    Text("bodyweight_label")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accentBlue)
                } else {
                    HStack(spacing: 2) {
                        Text(weightDisplayText)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(plannedSet.targetWeight != nil ? AppColors.textPrimary : AppColors.textMuted)
                        Text(weightUnit.symbol)
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)
                    }
                }

                Text("×")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textMuted)

                HStack(spacing: 2) {
                    Text(repsDisplayText)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(plannedSet.targetReps != nil ? AppColors.textPrimary : AppColors.textMuted)
                    Text("unit_reps")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }
            }

            Spacer(minLength: 0)

            // Right: Rest time (if set)
            if showsRestTime, let restTime = formattedRestTime {
                HStack(spacing: 2) {
                    Image(systemName: "timer")
                        .font(.caption2)
                    Text(restTime)
                        .font(.caption)
                }
                .foregroundColor(AppColors.textMuted)
                .lineLimit(1)
                .fixedSize()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SetRowConstants.horizontalPadding)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
        .cornerRadius(SetRowConstants.cardCornerRadius)
    }

    private var weightDisplayText: String {
        if let w = plannedSet.targetWeight {
            return w.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(w))"
                : String(format: "%.1f", w)
        }
        return "—"
    }

    private var repsDisplayText: String {
        if let r = plannedSet.targetReps {
            return "\(r)"
        }
        return "—"
    }
}

// MARK: - Preview

#Preview {
    let plannedSet1 = PlannedSet(orderIndex: 0, targetWeight: 60, targetReps: 10)
    let plannedSet2 = PlannedSet(orderIndex: 1, targetWeight: nil, targetReps: nil)

    return VStack(spacing: 8) {
        PlannedSetCardRowView(
            plannedSet: plannedSet1,
            setIndex: 1,
            canDelete: true,
            onDelete: {},
            weightUnit: .kg
        )

        PlannedSetCardRowView(
            plannedSet: plannedSet2,
            setIndex: 2,
            canDelete: false,
            onDelete: {},
            weightUnit: .kg
        )
    }
    .padding()
    .background(AppColors.cardBackground)
    .preferredColorScheme(.dark)
}
