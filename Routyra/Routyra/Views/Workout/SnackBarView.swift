//
//  SnackBarView.swift
//  Routyra
//

import SwiftUI

struct SnackBarView: View {
    let message: String
    let onUndo: () -> Void
    let onAdjustWeight: (Double) -> Void
    let onAdjustReps: (Int) -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            HStack(spacing: 16) {
                Button(action: { onAdjustWeight(-2.5) }) {
                    Image(systemName: "minus")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(AppColors.cardBackground)
                        .cornerRadius(6)
                }

                Button(action: { onAdjustWeight(2.5) }) {
                    Image(systemName: "plus")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(AppColors.cardBackground)
                        .cornerRadius(6)
                }

                Button(action: onUndo) {
                    Text("Undo")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accentBlue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

#Preview {
    SnackBarView(
        message: "Set logged: 60 kg × 8",
        onUndo: {},
        onAdjustWeight: { _ in },
        onAdjustReps: { _ in },
        onDismiss: {}
    )
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
