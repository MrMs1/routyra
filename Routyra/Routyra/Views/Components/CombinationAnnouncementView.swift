//
//  CombinationAnnouncementView.swift
//  Routyra
//
//  A one-time announcement dialog shown when user manually starts a timer.
//  Offers to enable combination mode (auto-start timer on set log).
//

import SwiftUI

struct CombinationAnnouncementView: View {
    @Binding var dontShowAgain: Bool
    let onEnableAndRun: () -> Void
    let onRunWithoutLink: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "timer")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.accentBlue)

                // Title
                Text("combination_announcement_title")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                // Message
                Text("combination_announcement_message")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Button {
                    dontShowAgain.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                            .foregroundColor(dontShowAgain ? AppColors.accentBlue : AppColors.textMuted)
                        Text("combination_dont_show")
                            .font(.callout)
                            .foregroundColor(AppColors.textMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Buttons
                VStack(spacing: 12) {
                    // Enable + run
                    Button {
                        onEnableAndRun()
                    } label: {
                        Text("combination_enable_and_run")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.accentBlue)
                            .cornerRadius(10)
                    }

                    // Run without linking
                    Button {
                        onRunWithoutLink()
                    } label: {
                        Text("combination_run_without_link")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(AppColors.divider, lineWidth: 1)
                            )
                            .cornerRadius(10)
                    }
                }
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textMuted)
                    .padding(10)
            }
        }
        .padding(24)
        .background(AppColors.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
        .padding(.horizontal, 24)
    }
}

#Preview {
    ZStack {
        AppColors.background.ignoresSafeArea()

        CombinationAnnouncementView(
            dontShowAgain: .constant(false),
            onEnableAndRun: { print("Enable and run") },
            onRunWithoutLink: { print("Run without link") },
            onClose: { print("Close without starting") }
        )
    }
    .preferredColorScheme(.dark)
}
