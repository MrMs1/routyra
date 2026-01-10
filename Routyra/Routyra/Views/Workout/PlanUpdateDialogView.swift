//
//  PlanUpdateDialogView.swift
//  Routyra
//
//  Confirmation dialog for updating plan values from a completed exercise.
//

import SwiftUI

struct PlanUpdateDialogView: View {
    let exerciseName: String
    let skipToggleText: String?
    let onConfirm: (Bool) -> Void
    let onCancel: () -> Void

    @State private var skipConfirmation = false

    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text(L10n.tr("plan_update_title"))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            // Message
            Text(L10n.tr("plan_update_message", exerciseName))
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            if let skipToggleText {
                Toggle(isOn: $skipConfirmation) {
                    Text(skipToggleText)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textPrimary)
                }
                .tint(AppColors.accentBlue)
                .padding()
                .background(AppColors.cardBackground)
                .cornerRadius(12)
            }

            // Buttons
            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text(L10n.tr("plan_update_cancel"))
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
                    onConfirm(skipConfirmation)
                } label: {
                    Text(L10n.tr("plan_update_confirm"))
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

        PlanUpdateDialogView(
            exerciseName: "Bench Press",
            skipToggleText: L10n.tr("plan_update_skip_confirm_toggle", L10n.tr("plan_update_direction_increase")),
            onConfirm: { _ in },
            onCancel: {}
        )
    }
    .preferredColorScheme(.dark)
}
