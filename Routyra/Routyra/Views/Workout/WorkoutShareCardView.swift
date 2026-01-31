//
//  WorkoutShareCardView.swift
//  Routyra
//

import SwiftUI

// MARK: - Data Models

struct ShareSetDetail: Identifiable {
    let id = UUID()
    let text: String       // "87.5kg × 11" or "25:00 / 5.2km"
    let rmText: String?    // "RM 80.7kg" (only for best set)
}

struct WorkoutShareExerciseSummary: Identifiable {
    let id = UUID()
    let name: String
    let dotColor: Color?
    let allSets: [ShareSetDetail]    // All set details (best set has rmText)
    let bestSetIndex: Int?           // Index of best RM set (0-indexed, after reordering)
}

struct WorkoutShareCardioSummary: Identifiable {
    let id = UUID()
    let name: String
    let allSets: [ShareSetDetail]    // All cardio entries
    let bestSetIndex: Int?           // Index of best set (longest distance/time)
}

// MARK: - Share Card View

struct WorkoutShareCardView: View {
    let date: Date
    let exercises: [WorkoutShareExerciseSummary]
    let cardio: [WorkoutShareCardioSummary]
    let totalVolumeText: String?
    var totalCardioDurationText: String?

    // MARK: - Computed Properties

    private var totalExerciseCount: Int {
        exercises.count + cardio.count
    }

    private var totalSetCount: Int {
        exercises.reduce(0) { $0 + $1.allSets.count } +
        cardio.reduce(0) { $0 + $1.allSets.count }
    }

    private var hasStrengthExercises: Bool {
        !exercises.isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            if let totalVolumeText {
                heroSection(volumeText: totalVolumeText)
            } else if let totalCardioDurationText {
                cardioDurationHero(durationText: totalCardioDurationText)
            }

            summaryStats

            if !exercises.isEmpty {
                exercisesSection
            }

            if !cardio.isEmpty {
                cardioSection
            }

            footerBranding
                .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(width: 360)
        .background(backgroundGradient)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            AppColors.background
            LinearGradient(
                colors: [.clear, AppColors.accentBlue.opacity(0.03), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Formatters.yearMonthDay.string(from: date))
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.accentBlue, AppColors.accentBlue.opacity(0.15)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
        }
    }

    // MARK: - Hero Section

    private func heroSection(volumeText: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.tr("workout_share_total_volume").uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textMuted)
                .tracking(1.5)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(volumeText)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.textPrimary, AppColors.accentBlue.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("kg")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.top, 4)
    }

    private func cardioDurationHero(durationText: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.tr("cardio_duration").uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textMuted)
                .tracking(1.5)

            Text(durationText)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.textPrimary, AppColors.accentBlue.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.top, 4)
    }

    // MARK: - Summary Stats

    private var summaryStats: some View {
        HStack(spacing: 4) {
            Text("\(totalExerciseCount)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)

            Text(L10n.tr("workout_share_strength_section").lowercased())
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            if hasStrengthExercises {
                Text("·")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
                    .padding(.horizontal, 4)

                Text("\(totalSetCount)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Text(L10n.tr("workout_share_total_sets").lowercased())
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Exercises Section

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(exercises) { exercise in
                exerciseBlock(exercise)
            }
        }
    }

    private func exerciseBlock(_ exercise: WorkoutShareExerciseSummary) -> some View {
        HStack(spacing: 0) {
            // Left accent bar using body part color
            RoundedRectangle(cornerRadius: 1.5)
                .fill(exercise.dotColor ?? AppColors.textMuted)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                if !exercise.allSets.isEmpty {
                    setsListView(
                        sets: exercise.allSets,
                        bestIndex: exercise.bestSetIndex
                    )
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Sets List

    private func setsListView(sets: [ShareSetDetail], bestIndex: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, setDetail in
                let isBest = (bestIndex == index)
                setRow(setDetail: setDetail, isBest: isBest)
            }
        }
    }

    private func setRow(setDetail: ShareSetDetail, isBest: Bool) -> some View {
        HStack(spacing: 4) {
            if isBest {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundColor(AppColors.accentBlue)

                Text(setDetail.text)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)

                if let rmText = setDetail.rmText {
                    Text(rmText)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accentBlue.opacity(0.85))
                        .padding(.leading, 6)
                }
            } else {
                Text(setDetail.text)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.leading, 12)
            }
            Spacer()
        }
    }

    // MARK: - Cardio Section

    private var cardioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("workout_share_cardio_section").uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textMuted)
                .tracking(1)

            ForEach(cardio) { cardioItem in
                cardioBlock(cardioItem)
            }
        }
    }

    private func cardioBlock(_ cardioItem: WorkoutShareCardioSummary) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(AppColors.textMuted)
                .frame(width: 3)
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(cardioItem.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                if !cardioItem.allSets.isEmpty {
                    setsListView(
                        sets: cardioItem.allSets,
                        bestIndex: cardioItem.bestSetIndex
                    )
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Footer Branding

    private var footerBranding: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(AppColors.textMuted.opacity(0.2))
                .frame(height: 0.5)

            Text("Routyra")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textMuted)
                .tracking(2)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Preview

#Preview {
    WorkoutShareCardView(
        date: Date(),
        exercises: [
            WorkoutShareExerciseSummary(
                name: "Bench Press",
                dotColor: .red,
                allSets: [
                    ShareSetDetail(text: "87.5kg × 11", rmText: "RM 119.6kg"),
                    ShareSetDetail(text: "85.0kg × 11", rmText: nil),
                    ShareSetDetail(text: "82.5kg × 11", rmText: nil),
                    ShareSetDetail(text: "80.0kg × 11", rmText: nil)
                ],
                bestSetIndex: 0
            ),
            WorkoutShareExerciseSummary(
                name: "Pull-up (Weighted)",
                dotColor: .blue,
                allSets: [
                    ShareSetDetail(text: "12.5kg × 12", rmText: "RM 16.2kg"),
                    ShareSetDetail(text: "12.5kg × 10", rmText: nil),
                    ShareSetDetail(text: "12.5kg × 8", rmText: nil)
                ],
                bestSetIndex: 0
            )
        ],
        cardio: [
            WorkoutShareCardioSummary(
                name: "Running",
                allSets: [
                    ShareSetDetail(text: "25:00 / 5.2km", rmText: nil)
                ],
                bestSetIndex: 0
            )
        ],
        totalVolumeText: "6,297"
    )
    .preferredColorScheme(.dark)
}
