//
//  WorkoutSetEditorView.swift
//  Routyra
//
//  View for adding sets to an exercise before adding it to the workout.
//  User can add multiple sets with weight and reps, then confirm to add.
//

import SwiftUI

struct WorkoutSetEditorView: View {
    let exercise: Exercise
    let bodyPart: BodyPart?
    let initialWeight: Double
    let initialReps: Int
    let onConfirm: ([(weight: Double, reps: Int)]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sets: [SetData] = []

    struct SetData: Identifiable {
        let id = UUID()
        var weight: Double
        var reps: Int
    }

    var body: some View {
        VStack(spacing: 0) {
            // Exercise header
            exerciseHeader
                .padding()
                .background(AppColors.cardBackground)

            // Sets list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(sets.enumerated()), id: \.element.id) { index, _ in
                        SetEditorRow(
                            index: index + 1,
                            weight: $sets[index].weight,
                            reps: $sets[index].reps,
                            onDelete: {
                                if sets.count > 1 {
                                    sets.remove(at: index)
                                }
                            },
                            canDelete: sets.count > 1
                        )
                    }

                    // Add set button
                    Button {
                        addSet()
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("もう1セット")
                        }
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.cardBackground)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }

            // Confirm button
            Button {
                let setsData = sets.map { (weight: $0.weight, reps: $0.reps) }
                onConfirm(setsData)
            } label: {
                Text("ワークアウトに追加")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.accentBlue)
                    .cornerRadius(12)
            }
            .padding()
            .background(AppColors.background)
        }
        .background(AppColors.background)
        .navigationTitle("セットを追加")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Start with one set
            if sets.isEmpty {
                sets.append(SetData(weight: initialWeight, reps: initialReps))
            }
        }
    }

    // MARK: - Exercise Header

    private var exerciseHeader: some View {
        HStack(spacing: 12) {
            // Body part color dot
            if let bodyPart = bodyPart {
                Circle()
                    .fill(bodyPart.color)
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.localizedName)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)

                if let bodyPart = bodyPart {
                    Text(bodyPart.localizedName)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Actions

    private func addSet() {
        // Copy weight/reps from last set
        let lastSet = sets.last
        sets.append(SetData(
            weight: lastSet?.weight ?? initialWeight,
            reps: lastSet?.reps ?? initialReps
        ))
    }
}

// MARK: - Set Editor Row

private struct SetEditorRow: View {
    let index: Int
    @Binding var weight: Double
    @Binding var reps: Int
    let onDelete: () -> Void
    let canDelete: Bool

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case weight, reps
    }

    var body: some View {
        HStack(spacing: 8) {
            // Set number
            Text("Set \(index)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 40, alignment: .leading)

            // Weight input
            TextField("--", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 55)
                .padding(.horizontal, 6)
                .padding(.vertical, 10)
                .background(AppColors.background)
                .cornerRadius(8)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
                .focused($focusedField, equals: .weight)
                .onChange(of: weightText) { _, newValue in
                    if let value = Double(newValue) {
                        weight = value
                    }
                }

            Text("kg")
                .font(.caption2)
                .foregroundColor(AppColors.textMuted)
                .frame(width: 20)

            Text("×")
                .font(.caption)
                .foregroundColor(AppColors.textMuted)

            // Reps input
            TextField("--", text: $repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 45)
                .padding(.horizontal, 6)
                .padding(.vertical, 10)
                .background(AppColors.background)
                .cornerRadius(8)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
                .focused($focusedField, equals: .reps)
                .onChange(of: repsText) { _, newValue in
                    if let value = Int(newValue) {
                        reps = value
                    }
                }

            Text("reps")
                .font(.caption2)
                .foregroundColor(AppColors.textMuted)
                .frame(width: 28)

            Spacer(minLength: 4)

            // Delete button
            if canDelete {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.textMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
        .cornerRadius(10)
        .onAppear {
            weightText = formatWeight(weight)
            repsText = "\(reps)"
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
    }
}

#Preview {
    NavigationStack {
        WorkoutSetEditorView(
            exercise: Exercise(name: "Bench Press", scope: .global),
            bodyPart: nil,
            initialWeight: 60,
            initialReps: 8,
            onConfirm: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}
