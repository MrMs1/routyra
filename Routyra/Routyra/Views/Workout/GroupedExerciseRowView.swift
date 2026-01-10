//
//  GroupedExerciseRowView.swift
//  Routyra
//

import SwiftUI
import SwiftData
import UIKit

struct GroupedExerciseRowView: View {
    @Bindable var entry: WorkoutExerciseEntry
    let exerciseName: String
    let bodyPartColor: Color?
    let selectedRoundIndex: Int
    let onInvalidInput: () -> Void
    var weightUnit: WeightUnit = .kg

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    private var activeSet: WorkoutSet? {
        entry.sortedSets.first { !$0.isCompleted } ?? entry.sortedSets.last
    }

    private var selectedSet: WorkoutSet? {
        let sets = entry.sortedSets
        guard selectedRoundIndex >= 0, selectedRoundIndex < sets.count else {
            return nil
        }
        return sets[selectedRoundIndex]
    }

    private var displayedSet: WorkoutSet? {
        selectedSet ?? activeSet
    }

    private var activeSetId: UUID? {
        activeSet?.id
    }

    private var totalSetCount: Int {
        let planned = entry.plannedSetCount
        return max(planned, entry.activeSets.count)
    }

    private var isSelectedRoundCompleted: Bool {
        selectedRoundIndex < entry.completedSetsCount
    }

    private var isSelectedRoundDirty: Bool {
        guard let set = displayedSet else { return false }
        switch entry.metricType {
        case .weightReps:
            let weightValue = Double(weightText) ?? 0
            let repsValue = Int(repsText) ?? 0
            let weightDiff = abs(weightValue - set.weightDouble) >= 0.01
            let repsDiff = repsValue != (set.reps ?? 0)
            return weightDiff || repsDiff
        case .bodyweightReps:
            let repsValue = Int(repsText) ?? 0
            return repsValue != (set.reps ?? 0)
        case .timeDistance, .completion:
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let color = bodyPartColor {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                }
                Text(exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            HStack(spacing: 8) {
                if totalSetCount > 0 {
                    Text(L10n.tr("workout_sets_progress", entry.completedSetsCount, totalSetCount))
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    metricEditor
                    if isSelectedRoundCompleted && isSelectedRoundDirty {
                        Button(action: applySelectedRoundUpdate) {
                            Text(L10n.tr("workout_update_set"))
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(AppColors.accentBlue)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.trailing, 4)
        }
        .padding(.vertical, 6)
        .onAppear {
            syncFields()
        }
        .onChange(of: selectedRoundIndex) { _, _ in
            syncFields()
        }
        .onChange(of: activeSetId) { _, _ in
            syncFields()
        }
        .onChange(of: entry.completedSetsCount) { _, _ in
            syncFields()
        }
    }

    @ViewBuilder
    private var metricEditor: some View {
        switch entry.metricType {
        case .weightReps:
            HStack(spacing: 6) {
                weightField
                Text(weightUnit.symbol)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text("×")
                    .font(.caption2)
                    .foregroundColor(AppColors.textMuted)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                repsField
                Text(L10n.tr("unit_reps"))
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        case .bodyweightReps:
            HStack(spacing: 6) {
                repsField
                Text(L10n.tr("unit_reps"))
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        case .timeDistance:
            if let set = activeSet {
                HStack(spacing: 6) {
                    Text(set.durationFormatted)
                    Text(set.distanceFormatted)
                }
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }
        case .completion:
            Text(L10n.tr("done"))
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private var weightField: some View {
        EndCursorTextField(
            text: $weightText,
            placeholder: "--",
            keyboardType: .decimalPad,
            textAlignment: .right,
            font: UIFont.systemFont(ofSize: 15, weight: .semibold),
            textColor: UIColor(AppColors.textPrimary),
            onEditingChanged: { focused in
                if !focused {
                    if !(isSelectedRoundCompleted && isSelectedRoundDirty) {
                        syncFields()
                    }
                }
            }
        )
        .frame(width: 50)
        .onChange(of: weightText) { _, newValue in
            guard !isSelectedRoundCompleted,
                  let set = displayedSet,
                  let value = Double(newValue) else { return }
            set.update(weight: Decimal(value))
        }
    }

    private var repsField: some View {
        EndCursorTextField(
            text: $repsText,
            placeholder: "--",
            keyboardType: .numberPad,
            textAlignment: .right,
            font: UIFont.systemFont(ofSize: 15, weight: .semibold),
            textColor: UIColor(AppColors.textPrimary),
            onEditingChanged: { focused in
                if !focused {
                    if !(isSelectedRoundCompleted && isSelectedRoundDirty) {
                        syncFields()
                    }
                }
            }
        )
        .frame(width: 36)
        .onChange(of: repsText) { _, newValue in
            guard !isSelectedRoundCompleted,
                  let set = displayedSet,
                  let value = Int(newValue) else { return }
            set.update(reps: value)
        }
    }

    private func syncFields() {
        guard let set = displayedSet else {
            weightText = ""
            repsText = ""
            return
        }

        switch entry.metricType {
        case .weightReps:
            weightText = formatWeight(set.weightDouble)
            repsText = formatReps(set.reps)
        case .bodyweightReps:
            repsText = formatReps(set.reps)
        case .timeDistance, .completion:
            break
        }
    }

    private func applySelectedRoundUpdate() {
        guard let set = displayedSet else { return }

        let weightValue = Double(weightText) ?? 0
        let repsValue = Int(repsText) ?? 0
        let durationValue = set.durationSeconds ?? 0
        let distanceValue = set.distanceMeters

        guard WorkoutService.validateSetInput(
            metricType: set.metricType,
            weight: weightValue,
            reps: repsValue,
            durationSeconds: durationValue,
            distanceMeters: distanceValue
        ) else {
            onInvalidInput()
            return
        }

        switch set.metricType {
        case .weightReps:
            set.update(weight: Decimal(weightValue), reps: repsValue)
        case .bodyweightReps:
            set.update(reps: repsValue)
        case .timeDistance, .completion:
            break
        }

        syncFields()
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight == 0 { return "" }
        return Formatters.formatWeight(weight)
    }

    private func formatReps(_ reps: Int?) -> String {
        guard let reps = reps, reps > 0 else { return "" }
        return "\(reps)"
    }
}

private struct EndCursorTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let keyboardType: UIKeyboardType
    let textAlignment: NSTextAlignment
    let font: UIFont
    let textColor: UIColor
    var onEditingChanged: ((Bool) -> Void)? = nil

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.textAlignment = textAlignment
        textField.font = font
        textField.textColor = textColor
        textField.backgroundColor = .clear
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(
            title: L10n.tr("done"),
            style: .done,
            target: context.coordinator,
            action: #selector(Coordinator.doneButtonTapped)
        )
        doneButton.tintColor = UIColor(AppColors.accentBlue)
        toolbar.items = [flexSpace, doneButton]
        textField.inputAccessoryView = toolbar

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EndCursorTextField

        init(_ parent: EndCursorTextField) {
            self.parent = parent
        }

        @objc func textChanged(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        @objc func doneButtonTapped() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onEditingChanged?(true)
            DispatchQueue.main.async {
                let endPosition = textField.endOfDocument
                textField.selectedTextRange = textField.textRange(from: endPosition, to: endPosition)
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.onEditingChanged?(false)
        }
    }
}
