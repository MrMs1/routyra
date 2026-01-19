//
//  CardioEntryCardView.swift
//  Routyra
//
//  Card view for displaying cardio workouts in the main workout screen.
//  Similar layout to ExerciseEntryCardView but tailored for cardio completion tracking.
//

import SwiftUI
import HealthKit

struct CardioEntryCardView: View {
    @Bindable var cardio: CardioWorkout
    let isExpanded: Bool
    let onTap: () -> Void
    let onComplete: () -> Void
    let onUncomplete: () -> Void
    let onDelete: () -> Void
    let showsHealthKitLinkButton: Bool
    let onLinkFromHealthKit: () -> Void
    var onUpdateDuration: ((Double) -> Void)?
    var onUpdateDistance: ((Double?) -> Void)?

    @State private var showDeleteConfirmation: Bool = false
    @State private var swipeOffset: CGFloat = 0
    @State private var isSwipeOpen: Bool = false

    // Duration editing (as seconds for TimeDistanceInputView compatibility)
    @State private var durationSeconds: Int = 0

    // Distance editing (as meters for TimeDistanceInputView compatibility)
    @State private var distanceMeters: Double? = nil

    private let deleteButtonWidth: CGFloat = 80
    private let deleteButtonHeight: CGFloat = 56

    /// Activity type from raw value
    private var activityType: HKWorkoutActivityType {
        HKWorkoutActivityType(rawValue: UInt(cardio.activityType)) ?? .other
    }

    /// SF Symbol icon for the activity type
    private var activityIcon: String {
        switch activityType {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .hiking: return "figure.hiking"
        case .elliptical: return "figure.elliptical"
        case .rowing: return "figure.rowing"
        case .stairClimbing, .stairs: return "figure.stairs"
        case .stepTraining: return "figure.stairs"
        case .highIntensityIntervalTraining: return "figure.highintensity.intervaltraining"
        case .yoga: return "figure.yoga"
        case .pilates: return "figure.pilates"
        case .dance, .cardioDance, .socialDance: return "figure.dance"
        case .boxing, .kickboxing: return "figure.boxing"
        case .martialArts: return "figure.martial.arts"
        case .tennis, .badminton, .tableTennis: return "figure.tennis"
        case .basketball: return "figure.basketball"
        case .soccer: return "figure.soccer"
        case .volleyball: return "figure.volleyball"
        case .golf: return "sportscourt"
        case .crossCountrySkiing, .downhillSkiing: return "figure.skiing.downhill"
        case .snowboarding: return "figure.snowboarding"
        case .surfingSports: return "figure.surfing"
        case .climbing: return "figure.climbing"
        default: return "figure.mixed.cardio"
        }
    }

    /// Whether this is a manual entry (can be uncompleted)
    private var isManualEntry: Bool {
        cardio.source == .manual
    }

    /// Card background color based on completion state
    private var cardBackgroundColor: Color {
        cardio.isCompleted ? AppColors.cardBackgroundCompleted : AppColors.cardBackground
    }

    /// Subtitle text for collapsed state
    private var subtitleText: String? {
        let minutes = Int(cardio.duration) / 60
        let seconds = Int(cardio.duration) % 60
        
        var parts: [String] = []
        if cardio.duration > 0 {
            parts.append(String(format: "%d:%02d", minutes, seconds))
        }
        if let distance = cardio.totalDistance {
            parts.append(String(format: "%.1f km", distance / 1000))
        }
        if let energy = cardio.formattedEnergyBurned {
            parts.append(energy)
        }
        if let heartRate = cardio.formattedAverageHeartRate {
            parts.append(heartRate)
        }
        
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button (behind the card)
            deleteButton

            // Main card content
            VStack(alignment: .leading, spacing: 0) {
                if isExpanded {
                    expandedContent
                } else {
                    collapsedContent
                }
            }
            .frame(minHeight: deleteButtonHeight)
            .background(cardBackgroundColor)
            .cornerRadius(12)
            .offset(x: swipeOffset)
            .gesture(swipeGesture)
            .onTapGesture {
                if isSwipeOpen {
                    withAnimation(.easeOut(duration: 0.2)) {
                        swipeOffset = 0
                        isSwipeOpen = false
                    }
                } else if !isExpanded {
                    onTap()
                }
            }
        }
        .confirmationDialog(
            L10n.tr("workout_delete_entry_title"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.tr("delete"), role: .destructive) {
                onDelete()
            }
            Button(L10n.tr("cancel"), role: .cancel) {}
        } message: {
            Text(L10n.tr("cardio_delete_message", activityType.displayName))
        }
        .onAppear {
            syncLocalState()
        }
        .onChange(of: cardio.duration) { _, _ in
            syncLocalState()
        }
        .onChange(of: cardio.totalDistance) { _, _ in
            syncLocalState()
        }
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(action: {
            showDeleteConfirmation = true
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red)

                Image(systemName: "trash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: deleteButtonWidth, height: deleteButtonHeight)
        }
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let translation = value.translation.width
                if isSwipeOpen {
                    let newOffset = -deleteButtonWidth + translation
                    swipeOffset = min(0, max(-deleteButtonWidth, newOffset))
                } else {
                    if translation < 0 {
                        swipeOffset = max(-deleteButtonWidth, translation)
                    }
                }
            }
            .onEnded { value in
                let translation = value.translation.width
                let velocity = value.predictedEndTranslation.width - translation

                withAnimation(.easeOut(duration: 0.2)) {
                    if isSwipeOpen {
                        if translation > deleteButtonWidth / 2 || velocity > 50 {
                            swipeOffset = 0
                            isSwipeOpen = false
                        } else {
                            swipeOffset = -deleteButtonWidth
                        }
                    } else {
                        if translation < -deleteButtonWidth / 2 || velocity < -50 {
                            swipeOffset = -deleteButtonWidth
                            isSwipeOpen = true
                        } else {
                            swipeOffset = 0
                        }
                    }
                }
            }
    }

    // MARK: - Collapsed Content (ExerciseEntryCardView style)

    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // Activity icon (like body part color dot)
                Image(systemName: activityIcon)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accentBlue)
                    .frame(width: 14)

                Text(activityType.displayName)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
            }

            if let subtitle = subtitleText {
                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textMuted)

                    if cardio.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.accentBlue)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    // MARK: - Expanded Content (ExerciseEntryCardView style)

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with activity name and delete button
            HStack {
                // Activity name - tapping collapses the card
                Button(action: onTap) {
                    HStack(spacing: 8) {
                        // Activity icon
                        Image(systemName: activityIcon)
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.accentBlue)

                        Text(activityType.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Delete button
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textMuted)
                        .padding(8)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)

            HStack(alignment: .top, spacing: 20) {
                // Single dot indicator (cardio has no multiple sets)
                cardioDotView
                    .padding(.leading, 16)

                VStack(spacing: 16) {
                    // Time/Distance input (same style as ExerciseEntryCardView)
                    CardioTimeDistanceInputView(
                        durationSeconds: $durationSeconds,
                        distanceMeters: $distanceMeters,
                        allowsEditing: isManualEntry,
                        onDurationChange: { newSeconds in
                            let newDuration = Double(newSeconds)
                            if newDuration != cardio.duration {
                                onUpdateDuration?(newDuration)
                            }
                        },
                        onDistanceChange: { newMeters in
                            onUpdateDistance?(newMeters)
                        }
                    )

                    // Action buttons
                    if isManualEntry {
                        if showsHealthKitLinkButton {
                            Button(action: onLinkFromHealthKit) {
                                HStack(spacing: 6) {
                                    Image(systemName: "heart.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.red.opacity(0.7))
                                    Text(L10n.tr("cardio_link_healthkit_button"))
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AppColors.divider.opacity(0.8), lineWidth: 1)
                                )
                            }
                        }
                        if cardio.isCompleted {
                            Button(action: onUncomplete) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.subheadline.weight(.semibold))
                                    Text(L10n.tr("cardio_mark_incomplete"))
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                            }
                        } else {
                            Button(action: onComplete) {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.semibold))
                                    Text(L10n.tr("cardio_mark_complete"))
                                }
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppColors.accentBlue)
                                .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding(.trailing, 16)
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Cardio Dot View (single dot for cardio)

    private var cardioDotView: some View {
        let ringColor = cardio.isCompleted ? AppColors.accentBlue : AppColors.textSecondary
        let numberColor = cardio.isCompleted ? AppColors.accentBlue : AppColors.textPrimary
        
        return ZStack {
            // Background circle to cover any elements behind
            Circle()
                .fill(AppColors.cardBackground)
                .frame(width: 28, height: 28)

            Circle()
                .stroke(ringColor, lineWidth: 1.5)
                .frame(width: 28, height: 28)

            Text("1")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(numberColor)
        }
    }

    // MARK: - State Sync

    private func syncLocalState() {
        durationSeconds = Int(cardio.duration)
        distanceMeters = cardio.totalDistance
    }
}

// MARK: - Cardio Time/Distance Input View (styled like TimeDistanceInputView)

private struct CardioTimeDistanceInputView: View {
    @Binding var durationSeconds: Int
    @Binding var distanceMeters: Double?
    let allowsEditing: Bool
    var onDurationChange: (Int) -> Void
    var onDistanceChange: (Double?) -> Void

    @State private var minutesText = ""
    @State private var secondsText = ""
    @State private var distanceText = ""
    @State private var isEditingMinutes = false
    @State private var isEditingSeconds = false
    @State private var isEditingDistance = false

    @FocusState private var minutesFieldFocused: Bool
    @FocusState private var secondsFieldFocused: Bool
    @FocusState private var distanceFieldFocused: Bool

    private let valueFontSize: CGFloat = 32
    private let unitFontSize: CGFloat = 14

    private var minutes: Int {
        durationSeconds / 60
    }

    private var seconds: Int {
        durationSeconds % 60
    }

    private var distanceKm: Double? {
        guard let meters = distanceMeters else { return nil }
        return meters / 1000
    }

    var body: some View {
        HStack(spacing: 4) {
            // Time group (minutes : seconds)
            HStack(spacing: 2) {
                // Minutes value
                timeValueView(
                    value: minutes,
                    text: $minutesText,
                    isEditing: $isEditingMinutes,
                    focused: $minutesFieldFocused,
                    onUpdate: { newMinutes in
                        let newTotal = newMinutes * 60 + seconds
                        durationSeconds = newTotal
                        onDurationChange(newTotal)
                    }
                )

                Text(L10n.tr("unit_min"))
                    .font(.system(size: unitFontSize, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize()

                Text(":")
                    .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.textMuted)
                    .padding(.horizontal, 2)

                // Seconds value
                timeValueView(
                    value: seconds,
                    text: $secondsText,
                    isEditing: $isEditingSeconds,
                    focused: $secondsFieldFocused,
                    onUpdate: { newSeconds in
                        let newTotal = minutes * 60 + min(newSeconds, 59)
                        durationSeconds = newTotal
                        onDurationChange(newTotal)
                    }
                )

                Text(L10n.tr("unit_sec"))
                    .font(.system(size: unitFontSize, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize()
            }
            .fixedSize()

            Spacer()

            // Distance group
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                distanceValueView

                Text(L10n.tr("unit_km"))
                    .font(.system(size: unitFontSize, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize()
            }
            .fixedSize()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.tr("done")) {
                    minutesFieldFocused = false
                    secondsFieldFocused = false
                    distanceFieldFocused = false
                }
                .foregroundColor(AppColors.accentBlue)
            }
        }
        .onChange(of: allowsEditing) { _, newValue in
            if !newValue {
                minutesFieldFocused = false
                secondsFieldFocused = false
                distanceFieldFocused = false
                isEditingMinutes = false
                isEditingSeconds = false
                isEditingDistance = false
            }
        }
    }

    @ViewBuilder
    private func timeValueView(
        value: Int,
        text: Binding<String>,
        isEditing: Binding<Bool>,
        focused: FocusState<Bool>.Binding,
        onUpdate: @escaping (Int) -> Void
    ) -> some View {
        if isEditing.wrappedValue && allowsEditing {
            TextField("", text: text)
                .keyboardType(.numberPad)
                .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 50)
                .multilineTextAlignment(.center)
                .focused(focused)
                .onChange(of: text.wrappedValue) { _, newValue in
                    if let intValue = Int(newValue) {
                        onUpdate(intValue)
                    }
                }
                .onChange(of: focused.wrappedValue) { _, isFocused in
                    if !isFocused {
                        if let intValue = Int(text.wrappedValue) {
                            onUpdate(intValue)
                        }
                        isEditing.wrappedValue = false
                    }
                }
                .onAppear {
                    text.wrappedValue = "\(value)"
                    focused.wrappedValue = true
                }
        } else {
            Text(String(format: "%02d", value))
                .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
                .frame(minWidth: 50)
                .onTapGesture {
                    if allowsEditing {
                        isEditing.wrappedValue = true
                    }
                }
        }
    }

    @ViewBuilder
    private var distanceValueView: some View {
        if isEditingDistance && allowsEditing {
            TextField("", text: $distanceText)
                .keyboardType(.decimalPad)
                .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 55)
                .multilineTextAlignment(.center)
                .focused($distanceFieldFocused)
                .onChange(of: distanceText) { _, newValue in
                    if newValue.isEmpty {
                        distanceMeters = nil
                        onDistanceChange(nil)
                    } else if let km = Double(newValue) {
                        let meters = km * 1000
                        distanceMeters = meters
                        onDistanceChange(meters)
                    }
                }
                .onChange(of: distanceFieldFocused) { _, focused in
                    if !focused {
                        if distanceText.isEmpty {
                            distanceMeters = nil
                            onDistanceChange(nil)
                        } else if let km = Double(distanceText) {
                            let meters = km * 1000
                            distanceMeters = meters
                            onDistanceChange(meters)
                        }
                        isEditingDistance = false
                    }
                }
                .onAppear {
                    if let km = distanceKm {
                        distanceText = String(format: "%.1f", km)
                    } else {
                        distanceText = ""
                    }
                    distanceFieldFocused = true
                }
        } else {
            Text(distanceKm.map { String(format: "%.1f", $0) } ?? "--")
                .font(.system(size: valueFontSize, weight: .semibold, design: .rounded))
                .foregroundColor(distanceKm != nil ? AppColors.textPrimary : AppColors.textMuted)
                .frame(minWidth: 55)
                .onTapGesture {
                    if allowsEditing {
                        isEditingDistance = true
                    }
                }
        }
    }
}
