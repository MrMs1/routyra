//
//  DayChangeDialogView.swift
//  Routyra
//
//  Confirmation dialog for changing the current workout day.
//  When day is changed, the next workout will automatically use the following day.
//

import SwiftUI

struct DayChangeDialogView: View {
    let targetDayIndex: Int
    let totalDays: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    /// The day that will be shown next time (after completing the target day)
    private var nextDayIndex: Int {
        (targetDayIndex % totalDays) + 1
    }

    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text(L10n.tr("day_change_title"))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            // Message
            Text(L10n.tr("day_change_message", targetDayIndex))
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            // Note about next day behavior
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(AppColors.accentBlue)

                Text(L10n.tr("day_change_note", nextDayIndex))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.accentBlue.opacity(0.1))
            .cornerRadius(10)

            // Buttons
            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text(L10n.tr("cancel"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.cardBackground)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button {
                    onConfirm()
                } label: {
                    Text(L10n.tr("day_change_confirm"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.accentBlue)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(AppColors.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.textMuted.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
        .padding(.horizontal, 24)
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.5)
            .ignoresSafeArea()

        DayChangeDialogView(
            targetDayIndex: 3,
            totalDays: 5,
            onConfirm: {
                print("Confirmed")
            },
            onCancel: {
                print("Cancelled")
            }
        )
    }
    .preferredColorScheme(.dark)
}
