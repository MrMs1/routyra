//
//  GroupSetCountResolverSheet.swift
//  Routyra
//
//  Sheet for resolving set count mismatches when creating exercise groups.
//  Offers options: use maximum, use minimum, or specify manually.
//

import SwiftUI

struct GroupSetCountResolverSheet: View {
    @Binding var isPresented: Bool
    let exercises: [PlanExercise]
    let exercisesMap: [UUID: Exercise]
    let onResolve: (Int) -> Void

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
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                // Centered card (scrollable)
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button {
                            close()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(AppColors.cardBackground)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.bottom, 8)

                    ScrollView {
                        VStack(spacing: 16) {
                            // Explanation
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)

                                Text(L10n.tr("set_count_mismatch_title"))
                                    .font(.headline)
                                    .foregroundColor(AppColors.textPrimary)

                                Text(setCountDescription)
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Divider()

                            // Options
                            VStack(spacing: 12) {
                                OptionButton(
                                    title: L10n.tr("use_maximum_title"),
                                    subtitle: L10n.tr("align_to_sets", maxCount),
                                    action: {
                                        onResolve(maxCount)
                                        close()
                                    }
                                )

                                OptionButton(
                                    title: L10n.tr("use_minimum_title"),
                                    subtitle: L10n.tr("align_to_sets", minCount),
                                    action: {
                                        onResolve(minCount)
                                        close()
                                    }
                                )

                                OptionButton(
                                    title: L10n.tr("specify_manually"),
                                    subtitle: nil,
                                    action: {
                                        manualSetCount = maxCount
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            showManualPicker = true
                                        }
                                    }
                                )
                            }

                            if showManualPicker {
                                VStack(spacing: 10) {
                                    Text("\(manualSetCount) \(L10n.tr("sets_unit"))")
                                        .font(.title3.weight(.semibold))
                                        .foregroundColor(AppColors.textPrimary)

                                    Stepper(value: $manualSetCount, in: 1...20) {
                                        EmptyView()
                                    }
                                    .labelsHidden()
                                    .frame(width: 140)

                                    Button {
                                        onResolve(manualSetCount)
                                        close()
                                    } label: {
                                        Text(L10n.tr("done"))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(AppColors.accentBlue)
                                            .cornerRadius(10)
                                    }
                                    .padding(.top, 6)
                                }
                                .padding(14)
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.textMuted.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(20)
                .contentShape(Rectangle())
                .background(AppColors.cardBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.textMuted.opacity(0.3), lineWidth: 1)
                )
                .frame(maxWidth: min(360, proxy.size.width * 0.9))
                .frame(maxHeight: proxy.size.height * 0.85)
            }
        }
    }

    private var setCountDescription: String {
        let details = exercises.compactMap { exercise -> String? in
            guard let ex = exercisesMap[exercise.exerciseId] else { return nil }
            return "\(ex.localizedName): \(exercise.effectiveSetCount)"
        }
        return details.joined(separator: "\n")
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
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
                        .font(.body.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()
            }
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppColors.textMuted.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
