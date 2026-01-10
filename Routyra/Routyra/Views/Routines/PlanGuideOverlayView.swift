//
//  PlanGuideOverlayView.swift
//  Routyra
//
//  4-step guide overlay explaining the workout plan concept.
//  Displayed as a centered card with semi-transparent background.
//

import SwiftUI

struct PlanGuideOverlayView: View {
    @Binding var isPresented: Bool
    @Binding var hasSeenGuide: Bool
    @State private var currentStep = 0

    private let totalSteps = 4

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // Centered card
            VStack(spacing: 0) {
                // Close button row
                HStack {
                    Spacer()
                    Button {
                        closeGuide()
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

                // Step content
                Group {
                    switch currentStep {
                    case 0: step1View
                    case 1: step2View
                    case 2: step3View
                    default: step4View
                    }
                }
                .frame(minHeight: 200)

                // Progress dots
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? AppColors.accentBlue : AppColors.textMuted.opacity(0.4))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.vertical, 16)

                // Navigation buttons
                HStack(spacing: 12) {
                    if currentStep > 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentStep -= 1
                            }
                        } label: {
                            Text(L10n.tr("plan_guide_back"))
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppColors.cardBackground)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppColors.textMuted.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }

                    Button {
                        if currentStep < totalSteps - 1 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentStep += 1
                            }
                        } else {
                            closeGuide()
                        }
                    } label: {
                        Text(currentStep < totalSteps - 1
                             ? L10n.tr("plan_guide_next")
                             : L10n.tr("plan_guide_close"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColors.accentBlue)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(20)
            .background(AppColors.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.textMuted.opacity(0.3), lineWidth: 1)
            )
            .frame(maxWidth: min(360, UIScreen.main.bounds.width * 0.9))
        }
    }

    private func closeGuide() {
        hasSeenGuide = true
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }

    // MARK: - Step 1: Value Proposition

    private var step1View: some View {
        VStack(spacing: 16) {
            // Title
            Text(L10n.tr("plan_guide_step1_title"))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            // Subtitle
            Text(L10n.tr("plan_guide_step1_body"))
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            // Diagram: Simple menu list
            VStack(spacing: 10) {
                menuRow(text: L10n.tr("plan_guide_exercise_bench_press"), sets: 3)
                menuRow(text: L10n.tr("plan_guide_exercise_incline_press"), sets: 3)
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

    private func menuRow(text: String, sets: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textMuted)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Text(L10n.tr("sets_with_unit", sets))
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
        }
    }

    // MARK: - Step 2: Plan → Multiple Days

    private var step2View: some View {
        VStack(spacing: 16) {
            // Title
            Text(L10n.tr("plan_guide_step2_title"))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            // Subtitle
            Text(L10n.tr("plan_guide_step2_body"))
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            // Diagram: Plan with multiple days
            VStack(spacing: 10) {
                nodeCard(text: L10n.tr("plan_guide_node_plan"), icon: "doc.text")
                arrowDown
                HStack(spacing: 8) {
                    dayChip(text: "Day 1")
                    dayChip(text: "Day 2")
                    Text("...")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }
            }
        }
    }

    // MARK: - Step 3: Day → Multiple Exercises

    private var step3View: some View {
        VStack(spacing: 16) {
            // Title
            Text(L10n.tr("plan_guide_step3_title"))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            // Subtitle
            Text(L10n.tr("plan_guide_step3_body"))
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            // Diagram: Day with exercises
            VStack(spacing: 10) {
                nodeCard(text: "Day 1", icon: "calendar")
                arrowDown
                HStack(spacing: 8) {
                    exerciseChip(text: L10n.tr("plan_guide_exercise_bench"))
                    exerciseChip(text: L10n.tr("plan_guide_exercise_squat"))
                    Text("...")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }
            }
        }
    }

    // MARK: - Step 4: Usage Types

    private var step4View: some View {
        VStack(spacing: 16) {
            // Title
            Text(L10n.tr("plan_guide_step4_title"))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            // Two option cards
            VStack(spacing: 10) {
                usageCard(icon: "doc.text", title: L10n.tr("plan_guide_single"))
                usageCard(icon: "arrow.triangle.2.circlepath", title: L10n.tr("plan_guide_cycle"))
            }
        }
    }

    // MARK: - Shared Components

    private func nodeCard(text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(AppColors.textPrimary)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppColors.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColors.textMuted.opacity(0.3), lineWidth: 1)
        )
    }

    private func dayChip(text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppColors.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.textMuted.opacity(0.3), lineWidth: 1)
            )
    }

    private func exerciseChip(text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(AppColors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(AppColors.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.textMuted.opacity(0.2), lineWidth: 1)
            )
    }

    private var arrowDown: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 14))
            .foregroundColor(AppColors.textMuted)
    }

    private func usageCard(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppColors.accentBlue)
                .frame(width: 32)

            Text(title)
                .font(.subheadline)
                .foregroundColor(AppColors.textPrimary)

            Spacer()
        }
        .padding(14)
        .background(AppColors.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColors.textMuted.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        AppColors.background.ignoresSafeArea()
        PlanGuideOverlayView(
            isPresented: .constant(true),
            hasSeenGuide: .constant(false)
        )
    }
    .preferredColorScheme(.dark)
}
