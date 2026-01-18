//
//  WorkoutShareCardView.swift
//  Routyra
//

import SwiftUI

struct WorkoutShareExerciseSummary: Identifiable {
    let id = UUID()
    let name: String
    let dotColor: Color?
    let setsText: String
    let detailText: String?
}

struct WorkoutShareCardioSummary: Identifiable {
    let id = UUID()
    let name: String
    let detailText: String
}

struct WorkoutShareCardView: View {
    let date: Date
    let exercises: [WorkoutShareExerciseSummary]
    let cardio: [WorkoutShareCardioSummary]
    let totalSetsText: String?
    let totalVolumeText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(Formatters.yearMonthDay.string(from: date))
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(L10n.tr("workout_share_powered_by_format", "Routyra"))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textMuted)
            }

            Text(L10n.tr("workout_share_title"))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            if totalSetsText != nil || totalVolumeText != nil {
                HStack(spacing: 10) {
                    if let totalSetsText {
                        statPill(title: L10n.tr("workout_share_total_sets"), value: totalSetsText)
                    }
                    if let totalVolumeText {
                        statPill(title: L10n.tr("workout_share_total_volume"), value: totalVolumeText)
                    }
                }
            }

            if !exercises.isEmpty {
                sectionHeader(L10n.tr("workout_share_strength_section"))
                VStack(spacing: 10) {
                    ForEach(exercises) { item in
                        row(
                            title: item.name,
                            dotColor: item.dotColor,
                            subtitle: item.setsText,
                            trailing: item.detailText
                        )
                    }
                }
            }

            if !cardio.isEmpty {
                sectionHeader(L10n.tr("workout_share_cardio_section"))
                VStack(spacing: 10) {
                    ForEach(cardio) { item in
                        row(
                            title: item.name,
                            dotColor: nil,
                            subtitle: item.detailText,
                            trailing: nil
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.background) // avoid transparent images
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(AppColors.textMuted)
            .padding(.top, 2)
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(AppColors.textMuted)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.textMuted.opacity(0.22), lineWidth: 1)
        )
    }

    private func row(title: String, dotColor: Color?, subtitle: String, trailing: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    if let dotColor {
                        Circle()
                            .fill(dotColor)
                            .frame(width: 8, height: 8)
                    }

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.textMuted.opacity(0.18), lineWidth: 1)
        )
    }
}

#Preview {
    WorkoutShareCardView(
        date: Date(),
        exercises: [
            WorkoutShareExerciseSummary(name: "Bench Press", dotColor: .red, setsText: "3 sets", detailText: "60kg × 8\n1RM 75kg"),
            WorkoutShareExerciseSummary(name: "Squat", dotColor: .green, setsText: "5 sets", detailText: "100kg × 5\n1RM 117kg")
        ],
        cardio: [
            WorkoutShareCardioSummary(name: "Running", detailText: "25:00 / 5.0km")
        ],
        totalSetsText: "8",
        totalVolumeText: "9,120"
    )
    .preferredColorScheme(.dark)
}

