//
//  GroupSetCountResolverSheet.swift
//  Routyra
//
//  Sheet for resolving set count mismatches when creating exercise groups.
//  Offers options: use maximum, use minimum, or specify manually.
//

import SwiftUI

struct GroupSetCountResolverSheet: View {
    let exercises: [PlanExercise]
    let exercisesMap: [UUID: Exercise]
    let onResolve: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var manualSetCount: Int = 3
    @State private var showManualPicker = false

    private var setCounts: [Int] {
        exercises.map(\.effectiveSetCount)
    }

    private var minCount: Int {
        setCounts.min() ?? 1
    }

    private var maxCount: Int {
        setCounts.max() ?? 3
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Explanation
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)

                    Text(L10n.tr("set_count_mismatch_title"))
                        .font(.headline)

                    Text(setCountDescription)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 10)

                Divider()

                // Options
                VStack(spacing: 12) {
                    // Use maximum
                    OptionButton(
                        title: L10n.tr("use_maximum", maxCount),
                        subtitle: "\(maxCount) \(L10n.tr("sets_unit"))",
                        action: {
                            onResolve(maxCount)
                            dismiss()
                        }
                    )

                    // Use minimum
                    OptionButton(
                        title: L10n.tr("use_minimum", minCount),
                        subtitle: "\(minCount) \(L10n.tr("sets_unit"))",
                        action: {
                            onResolve(minCount)
                            dismiss()
                        }
                    )

                    // Specify manually
                    OptionButton(
                        title: L10n.tr("specify_manually"),
                        subtitle: nil,
                        action: {
                            manualSetCount = maxCount
                            showManualPicker = true
                        }
                    )
                }
                .padding(.horizontal)

                Spacer()
            }
            .background(AppColors.background)
            .navigationTitle(L10n.tr("set_count"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("cancel")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showManualPicker) {
                ManualSetCountPicker(
                    setCount: $manualSetCount,
                    onConfirm: {
                        onResolve(manualSetCount)
                        dismiss()
                    }
                )
                .presentationDetents([.height(200)])
            }
        }
    }

    private var setCountDescription: String {
        let details = exercises.compactMap { exercise -> String? in
            guard let ex = exercisesMap[exercise.exerciseId] else { return nil }
            return "\(ex.localizedName): \(exercise.effectiveSetCount)"
        }
        return details.joined(separator: ", ")
    }
}

// MARK: - Option Button

private struct OptionButton: View {
    let title: String
    let subtitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(AppColors.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Manual Set Count Picker

private struct ManualSetCountPicker: View {
    @Binding var setCount: Int
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("\(setCount) \(L10n.tr("sets_unit"))")
                    .font(.title.weight(.semibold))

                Stepper(value: $setCount, in: 1...20) {
                    EmptyView()
                }
                .labelsHidden()
                .frame(width: 120)

                Spacer()
            }
            .padding(.top, 30)
            .background(AppColors.background)
            .navigationTitle(L10n.tr("set_count"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("done")) {
                        onConfirm()
                    }
                }
            }
        }
    }
}
