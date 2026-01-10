//
//  RestTimerProgressBar.swift
//  Routyra
//
//  A fixed progress bar displayed at the top of WorkoutView when a rest timer is running.
//  Shows remaining time, progress bar, +30s button, and cancel button.
//

import SwiftUI

struct RestTimerProgressBar: View {
    @ObservedObject var timer = RestTimerService.shared

    var body: some View {
        if timer.isRunning || timer.isCompleted {
            VStack(spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    // Remaining time
                    Text(timer.formattedRemaining)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(timer.isCompleted ? AppColors.accentBlue : AppColors.textPrimary)
                        .monospacedDigit()

                    Spacer()

                    // +30s button
                    if timer.isRunning {
                        Button {
                            RestTimerService.addTime(30)
                        } label: {
                            Text("rest_timer_add_30s")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppColors.background)
                                .cornerRadius(8)
                        }
                    }

                    // Cancel/Dismiss button
                    Button {
                        if timer.isCompleted {
                            RestTimerService.dismiss()
                        } else {
                            RestTimerService.cancel()
                        }
                    } label: {
                        Image(systemName: timer.isCompleted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(timer.isCompleted ? AppColors.accentBlue : AppColors.textMuted)
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.background)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(timer.isCompleted ? AppColors.accentBlue : AppColors.accentBlue.opacity(0.8))
                            .frame(width: geo.size.width * timer.progress, height: 6)
                            .animation(.linear(duration: 0.5), value: timer.progress)
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColors.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    VStack {
        RestTimerProgressBar()
        Spacer()
    }
    .background(AppColors.background)
    .preferredColorScheme(.dark)
    .onAppear {
        // Start a timer for preview
        Task { @MainActor in
            _ = RestTimerService.start(duration: 90)
        }
    }
}
