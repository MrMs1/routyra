//
//  DayChangeDialogView.swift
//  Routyra
//
//  Confirmation dialog for changing the current workout day.
//  Includes a toggle for skipping and advancing the progress pointer.
//

import SwiftUI

struct DayChangeDialogView: View {
    let targetDayIndex: Int
    let onConfirm: (Bool) -> Void
    let onCancel: () -> Void

    @State private var skipAndAdvance = false

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

            // Skip toggle
            Toggle(isOn: $skipAndAdvance) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("day_change_skip_toggle"))
                        .font(.subheadline)
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            .tint(AppColors.accentBlue)
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(12)

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
                    onConfirm(skipAndAdvance)
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
        .background(AppColors.background)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 24)
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.5)
            .ignoresSafeArea()

        DayChangeDialogView(
            targetDayIndex: 3,
            onConfirm: { skip in
                print("Confirmed with skip: \(skip)")
            },
            onCancel: {
                print("Cancelled")
            }
        )
    }
    .preferredColorScheme(.dark)
}
