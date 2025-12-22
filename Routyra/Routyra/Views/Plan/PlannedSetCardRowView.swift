//
//  PlannedSetCardRowView.swift
//  Routyra
//
//  Mini-card row for displaying/editing a planned set.
//  Tap to enter edit mode, with ellipsis menu for actions.
//

import SwiftUI
import SwiftData

// MARK: - Constants

private enum SetRowConstants {
    static let cardHeight: CGFloat = 44
    static let cardCornerRadius: CGFloat = 10
    static let horizontalPadding: CGFloat = 12
    static let setNumberWidth: CGFloat = 40
}

// MARK: - PlannedSetCardRowView

struct PlannedSetCardRowView: View {
    @Bindable var plannedSet: PlannedSet
    let setIndex: Int
    let onDelete: () -> Void

    @State private var isEditing: Bool = false
    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case weight
        case reps
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: Set number
            Text(L10n.tr("set_label", setIndex))
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .frame(width: SetRowConstants.setNumberWidth, alignment: .leading)

            Spacer()

            // Center: Weight × Reps
            if isEditing {
                editModeContent
            } else {
                displayModeContent
            }

            Spacer()

            // Right: Ellipsis menu
            Menu {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textMuted)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, SetRowConstants.horizontalPadding)
        .frame(height: SetRowConstants.cardHeight)
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
    }

    // MARK: - Display Mode

    private var displayModeContent: some View {
        HStack(spacing: 4) {
            // Weight
            HStack(spacing: 1) {
                Text(weightDisplayText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(plannedSet.targetWeight != nil ? AppColors.textPrimary : AppColors.textMuted)
                Text("unit_kg")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Separator
            Text("/")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .padding(.horizontal, 6)

            // Reps
            HStack(spacing: 1) {
                Text(repsDisplayText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(plannedSet.targetReps != nil ? AppColors.textPrimary : AppColors.textMuted)
                Text("unit_reps")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    // MARK: - Edit Mode

    private var editModeContent: some View {
        HStack(spacing: 4) {
            // Weight input
            HStack(spacing: 1) {
                TextField("—", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 50)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(AppColors.cardBackground)
                    .cornerRadius(6)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .focused($focusedField, equals: .weight)

                Text("unit_kg")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Separator
            Text("/")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .padding(.horizontal, 6)

            // Reps input
            HStack(spacing: 1) {
                TextField("—", text: $repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 40)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(AppColors.cardBackground)
                    .cornerRadius(6)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .focused($focusedField, equals: .reps)

                Text("unit_reps")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Done button
            Button {
                exitEditMode()
            } label: {
                Text("done")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.accentBlue)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
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
        // Focus weight field after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField = .weight
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

    var body: some View {
        HStack(spacing: 0) {
            // Left: Set number
            Text(L10n.tr("set_label", setIndex))
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .frame(width: SetRowConstants.setNumberWidth, alignment: .leading)

            Spacer()

            // Center: Weight / Reps
            HStack(spacing: 4) {
                // Weight
                HStack(spacing: 1) {
                    Text(weightDisplayText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(plannedSet.targetWeight != nil ? AppColors.textPrimary : AppColors.textMuted)
                    Text("unit_kg")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                // Separator
                Text("/")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
                    .padding(.horizontal, 6)

                // Reps
                HStack(spacing: 1) {
                    Text(repsDisplayText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(plannedSet.targetReps != nil ? AppColors.textPrimary : AppColors.textMuted)
                    Text("unit_reps")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, SetRowConstants.horizontalPadding)
        .frame(height: SetRowConstants.cardHeight)
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
            onDelete: {}
        )

        PlannedSetCardRowView(
            plannedSet: plannedSet2,
            setIndex: 2,
            onDelete: {}
        )
    }
    .padding()
    .background(AppColors.cardBackground)
    .preferredColorScheme(.dark)
}
