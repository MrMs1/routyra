//
//  ExercisePickerComponents.swift
//  Routyra
//
//  Shared UI components for exercise picker screens.
//  Used by both WorkoutExercisePickerView and ExercisePickerView (Plan).
//

import SwiftUI

// MARK: - Exercise Card Row

/// Card-style row for displaying an exercise in the picker.
/// Features a left accent bar colored by body part, exercise name, and metadata.
struct ExerciseCardRow: View {
    let exerciseName: String
    let bodyPartName: String?
    let bodyPartColor: Color?
    let isCustom: Bool
    var isSelected: Bool = false
    let onTap: () -> Void

    private let cardCornerRadius: CGFloat = 12
    private let accentBarWidth: CGFloat = 4

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left accent bar (body part color)
                accentBar

                // Content
                HStack(spacing: 12) {
                    // Exercise info
                    VStack(alignment: .leading, spacing: 4) {
                        // Exercise name
                        Text(exerciseName)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)

                        // Subtitle (body part + custom badge)
                        HStack(spacing: 6) {
                            if let bodyPartName = bodyPartName {
                                Text(bodyPartName)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            if isCustom {
                                Text("•")
                                    .foregroundColor(AppColors.textMuted)
                                Text("exercise_custom_badge")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(AppColors.textMuted)
                            }
                        }
                    }

                    Spacer()

                    // Show checkmark if selected (current exercise in change mode)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.accentBlue)
                    } else {
                        // Chevron
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textMuted.opacity(0.6))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .background(isSelected ? AppColors.accentBlue.opacity(0.1) : AppColors.cardBackground)
            .cornerRadius(cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius)
                    .stroke(isSelected ? AppColors.accentBlue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(ExerciseCardButtonStyle())
    }

    private var accentBar: some View {
        Rectangle()
            .fill(bodyPartColor ?? AppColors.textMuted)
            .frame(width: accentBarWidth)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: cardCornerRadius,
                    bottomLeadingRadius: cardCornerRadius,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
            )
    }
}

// MARK: - Action Card Button

/// Reusable action card with plus icon, title, optional subtitle, and chevron.
/// Used for "新しい種目を作成", "種目を追加", etc.
struct ActionCardButton: View {
    let title: String
    var subtitle: String? = nil
    var icon: String = "plus"
    var showBorder: Bool = true
    var showChevron: Bool = true

    private let cardCornerRadius: CGFloat = 12

    var body: some View {
        HStack(spacing: 12) {
            // Icon in circle
            ZStack {
                Circle()
                    .fill(AppColors.accentBlue.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.accentBlue)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.accentBlue)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(AppColors.textMuted)
                }
            }

            Spacer()

            // Chevron
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.accentBlue.opacity(0.6))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .stroke(showBorder ? AppColors.accentBlue.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - Create Exercise Card

/// Special card for creating a new exercise.
/// Styled with accent color to stand out from regular exercise cards.
struct CreateExerciseCard: View {
    var body: some View {
        ActionCardButton(
            title: L10n.tr("exercise_create_new"),
            subtitle: L10n.tr("exercise_create_new_subtitle")
        )
    }
}

// MARK: - Exercise Picker Search Bar

/// Custom search bar for exercise picker screens.
struct ExercisePickerSearchBar: View {
    @Binding var text: String
    var placeholder: String = L10n.tr("exercise_search_placeholder")

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textMuted)
                .font(.system(size: 15))

            TextField(placeholder, text: $text)
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(AppColors.textPrimary)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textMuted)
                        .font(.system(size: 15))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MARK: - Filter Chip View

/// Pill-shaped filter chip for body part filtering.
struct ExerciseFilterChip: View {
    let title: String
    var color: Color? = nil
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if let color = color {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? AppColors.accentBlue : AppColors.cardBackground)
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? Color.clear : AppColors.divider,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Body Part Filter Bar

/// Two-row filter bar for body parts, centered layout.
/// Used by both ExercisePickerView (Plan) and WorkoutExercisePickerView (Workout).
/// Can optionally include cardio (plans allow cardio exercises).
struct BodyPartFilterBar: View {
    let bodyParts: [BodyPart]
    @Binding var selectedBodyPartId: UUID?
    var includeCardio: Bool = false

    /// Body parts filtered by cardio inclusion.
    private var filteredBodyParts: [BodyPart] {
        includeCardio ? bodyParts : bodyParts.filter { $0.code != "cardio" }
    }

    var body: some View {
        let allItems = [Optional<BodyPart>.none] + filteredBodyParts.map { Optional($0) }
        let midIndex = (allItems.count + 1) / 2
        let firstRow = Array(allItems.prefix(midIndex))
        let secondRow = Array(allItems.suffix(from: midIndex))

        return VStack(spacing: 8) {
            // First row
            HStack(spacing: 8) {
                ForEach(Array(firstRow.enumerated()), id: \.offset) { _, item in
                    filterChip(for: item)
                }
            }

            // Second row (if any)
            if !secondRow.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(secondRow.enumerated()), id: \.offset) { _, item in
                        filterChip(for: item)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func filterChip(for bodyPart: BodyPart?) -> some View {
        if let bodyPart = bodyPart {
            ExerciseFilterChip(
                title: bodyPart.localizedName,
                color: bodyPart.color,
                isSelected: selectedBodyPartId == bodyPart.id
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedBodyPartId = bodyPart.id
                }
            }
        } else {
            ExerciseFilterChip(
                title: L10n.tr("filter_all"),
                isSelected: selectedBodyPartId == nil
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedBodyPartId = nil
                }
            }
        }
    }
}

// MARK: - Button Style

/// Custom button style for exercise cards with subtle press feedback.
struct ExerciseCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview("Exercise Card Row") {
    VStack(spacing: 10) {
        ExerciseCardRow(
            exerciseName: "ベンチプレス",
            bodyPartName: "胸",
            bodyPartColor: Color.red,
            isCustom: false,
            onTap: {}
        )

        ExerciseCardRow(
            exerciseName: "マイエクササイズ",
            bodyPartName: "背中",
            bodyPartColor: Color.blue,
            isCustom: true,
            onTap: {}
        )

        CreateExerciseCard()
    }
    .padding()
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
