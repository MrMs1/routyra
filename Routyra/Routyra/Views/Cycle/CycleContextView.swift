//
//  CycleContextView.swift
//  Routyra
//
//  Displays the current cycle context (cycle name, plan name, day info).
//  Used in WorkoutView to show what the user is currently working on.
//

import SwiftUI

struct CycleContextView: View {
    let cycleName: String
    let planName: String
    let dayInfo: String
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Cycle icon
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.accentBlue)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(cycleName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textSecondary)

                        Text("›")
                            .font(.caption)
                            .foregroundColor(AppColors.textMuted)

                        Text(planName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textPrimary)
                    }

                    Text(dayInfo)
                        .font(.caption2)
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                // Complete button
                Button {
                    onComplete()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("done")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.accentBlue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(AppColors.cardBackground)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        CycleContextView(
            cycleName: "メインサイクル",
            planName: "Push Pull Legs",
            dayInfo: "Day 1 / 6",
            onComplete: {}
        )

        Spacer()
    }
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
