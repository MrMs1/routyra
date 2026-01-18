//
//  WorkoutSetEditorView.swift
//  Routyra
//
//  Reusable view for adding sets to an exercise.
//  Used by both workout logging and plan creation flows.
//

import SwiftUI
import UIKit
import GoogleMobileAds

// MARK: - Candidate Types

/// Set data for copying (includes rest time)
struct CopyableSetData {
    let weight: Double
    let reps: Int
    let restTimeSeconds: Int?

    init(weight: Double, reps: Int, restTimeSeconds: Int? = nil) {
        self.weight = weight
        self.reps = reps
        self.restTimeSeconds = restTimeSeconds
    }
}

/// A plan-based candidate for copying sets
struct PlanCopyCandidate: Identifiable, Equatable {
    let id = UUID()
    let planId: UUID
    let planName: String
    let dayId: UUID
    let dayName: String
    let sets: [CopyableSetData]
    let updatedAt: Date
    let isCurrentPlan: Bool

    static func == (lhs: PlanCopyCandidate, rhs: PlanCopyCandidate) -> Bool {
        lhs.id == rhs.id
    }

    /// Subtitle: "{plan} / {day}"
    var subtitle: String {
        "\(planName) / \(dayName)"
    }

    /// Format sets for preview (e.g., "60kg×10 ×3")
    var setsPreview: String {
        formatSetsPreview(sets.map { ($0.weight, $0.reps) })
    }
}

/// A workout-based candidate for copying sets
struct WorkoutCopyCandidate: Identifiable, Equatable {
    let id = UUID()
    let workoutDate: Date
    let sets: [CopyableSetData]

    static func == (lhs: WorkoutCopyCandidate, rhs: WorkoutCopyCandidate) -> Bool {
        lhs.id == rhs.id
    }

    /// Date formatted for display
    var dateString: String {
        Formatters.monthDay.string(from: workoutDate)
    }

    /// Format sets for preview
    var setsPreview: String {
        formatSetsPreview(sets.map { ($0.weight, $0.reps) })
    }
}

/// Output data from SetEditorView
struct SetInputData {
    var metricType: SetMetricType
    var weight: Double?
    var reps: Int?
    var durationSeconds: Int?
    var distanceMeters: Double?
    var restTimeSeconds: Int?

    /// Convenience for weight/reps
    init(weight: Double, reps: Int, restTimeSeconds: Int? = nil) {
        self.metricType = .weightReps
        self.weight = weight
        self.reps = reps
        self.durationSeconds = nil
        self.distanceMeters = nil
        self.restTimeSeconds = restTimeSeconds
    }

    /// Convenience for bodyweight/reps
    init(reps: Int, restTimeSeconds: Int? = nil) {
        self.metricType = .bodyweightReps
        self.weight = nil
        self.reps = reps
        self.durationSeconds = nil
        self.distanceMeters = nil
        self.restTimeSeconds = restTimeSeconds
    }

    /// Convenience for time/distance
    init(durationSeconds: Int, distanceMeters: Double?) {
        self.metricType = .timeDistance
        self.weight = nil
        self.reps = nil
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.restTimeSeconds = nil
    }

    /// Convenience for completion
    init() {
        self.metricType = .completion
        self.weight = nil
        self.reps = nil
        self.durationSeconds = nil
        self.distanceMeters = nil
        self.restTimeSeconds = nil
    }

    /// Full initializer
    init(metricType: SetMetricType, weight: Double? = nil, reps: Int? = nil, durationSeconds: Int? = nil, distanceMeters: Double? = nil, restTimeSeconds: Int? = nil) {
        self.metricType = metricType
        self.weight = weight
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.restTimeSeconds = restTimeSeconds
    }
}

/// Collection of all candidates for an exercise
struct CopyCandidateCollection {
    /// All plan candidates (current plan first, then others)
    var planCandidates: [PlanCopyCandidate]
    /// All workout history candidates (most recent first)
    var workoutCandidates: [WorkoutCopyCandidate]

    /// Representative plan candidate (for main view)
    var representativePlanCandidate: PlanCopyCandidate? {
        planCandidates.first
    }

    /// Most recent workout candidate (for main view)
    var lastWorkoutCandidate: WorkoutCopyCandidate? {
        workoutCandidates.first
    }

    /// Whether there are more candidates beyond the main 2
    var hasMoreCandidates: Bool {
        planCandidates.count > 1 || workoutCandidates.count > 1
    }

    /// Current plan candidates (for picker sheet)
    var currentPlanCandidates: [PlanCopyCandidate] {
        planCandidates.filter { $0.isCurrentPlan }
    }

    /// Other plan candidates (for picker sheet)
    var otherPlanCandidates: [PlanCopyCandidate] {
        planCandidates.filter { !$0.isCurrentPlan }
    }

    static let empty = CopyCandidateCollection(planCandidates: [], workoutCandidates: [])
}

/// Helper to format sets preview
private func formatSetsPreview(_ sets: [(weight: Double, reps: Int)], weightUnit: WeightUnit = .kg) -> String {
    guard !sets.isEmpty else { return "" }

    // Check if all sets are identical
    let first = sets[0]
    let allSame = sets.allSatisfy { $0.weight == first.weight && $0.reps == first.reps }
    let unit = weightUnit.symbol

    let weightStr = first.weight.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", first.weight)
        : String(format: "%.1f", first.weight)

    if allSame && sets.count > 1 {
        // Format: "60kg×10 ×3"
        return "\(weightStr)\(unit)×\(first.reps) ×\(sets.count)"
    } else {
        // Format: "60kg×10 / 60kg×8 / ..."
        let formatted = sets.prefix(3).map { set in
            let w = set.weight.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", set.weight)
                : String(format: "%.1f", set.weight)
            return "\(w)\(unit)×\(set.reps)"
        }
        let result = formatted.joined(separator: " / ")
        return sets.count > 3 ? result + " ..." : result
    }
}

// MARK: - Configuration

/// Configuration for SetEditorView appearance
struct SetEditorConfig {
    let navigationTitle: String
    let confirmButtonText: String
    let initialSetCount: Int

    /// Default configuration for workout flow
    static let workout = SetEditorConfig(
        navigationTitle: L10n.tr("workout_add_sets_title"),
        confirmButtonText: L10n.tr("workout_add_to_workout"),
        initialSetCount: 1
    )

    /// Configuration for plan flow
    static let plan = SetEditorConfig(
        navigationTitle: L10n.tr("plan_add_sets_title"),
        confirmButtonText: L10n.tr("plan_add_exercise_confirm"),
        initialSetCount: 1
    )

    /// Configuration for editing existing plan sets
    static let planEdit = SetEditorConfig(
        navigationTitle: L10n.tr("plan_edit_sets_title"),
        confirmButtonText: L10n.tr("save"),
        initialSetCount: 0  // Will be overridden by existing sets
    )
}

struct SetEditorView: View {
    let exercise: Exercise
    let bodyPart: BodyPart?
    let initialWeight: Double
    let initialReps: Int
    let initialMetricType: SetMetricType
    let initialRestTimeSeconds: Int?
    let config: SetEditorConfig
    let candidateCollection: CopyCandidateCollection
    let onConfirm: ([SetInputData]) -> Void
    var weightUnit: WeightUnit = .kg
    let isSetCountEditingEnabled: Bool
    let isRestTimeEditingEnabled: Bool

    @Environment(\.dismiss) private var dismiss

    @StateObject private var adManager = NativeAdManager()

    @State private var selectedMetricType: SetMetricType = .weightReps
    @State private var sets: [SetData] = []
    @State private var previousSets: [SetData]? = nil  // For undo
    @State private var showUndoToast = false
    @State private var appliedSetCount: Int = 0
    @State private var showCandidatePicker = false

    /// Computed property for current metric type (for use in view builder)
    private var metricType: SetMetricType { selectedMetricType }

    /// Whether the body part is cardio
    private var isCardio: Bool {
        if bodyPart?.code == "cardio" {
            return true
        }
        if exercise.defaultMetricType == .timeDistance || exercise.defaultMetricType == .completion {
            return true
        }

        let localizedCardioName = L10n.tr("body_part_cardio_name").normalizedForComparison()
        let cardioNames: Set<String> = ["cardio", localizedCardioName]
        let candidates = [
            bodyPart?.normalizedName,
            bodyPart?.localizedName.normalizedForComparison(),
            exercise.category?.normalizedForComparison()
        ].compactMap { $0 }

        return candidates.contains { cardioNames.contains($0) }
    }

    /// Allowed metric types based on body part
    private var allowedMetricTypes: [SetMetricType] {
        SetMetricType.allowedTypes(isCardio: isCardio)
    }

    /// Whether to show bottom ad
    private var shouldShowAd: Bool {
        guard !adManager.nativeAds.isEmpty else { return false }
        return true
    }

    struct SetData: Identifiable {
        let id = UUID()
        var metricType: SetMetricType
        var weight: Double?
        var reps: Int?
        var durationSeconds: Int?
        var distanceMeters: Double?
        var restTimeSeconds: Int?

        /// Initialize for weight/reps
        init(weight: Double, reps: Int, restTimeSeconds: Int? = nil) {
            self.metricType = .weightReps
            self.weight = weight
            self.reps = reps
            self.durationSeconds = nil
            self.distanceMeters = nil
            self.restTimeSeconds = restTimeSeconds
        }

        /// Initialize for bodyweight/reps
        init(reps: Int, restTimeSeconds: Int? = nil) {
            self.metricType = .bodyweightReps
            self.weight = nil
            self.reps = reps
            self.durationSeconds = nil
            self.distanceMeters = nil
            self.restTimeSeconds = restTimeSeconds
        }

        /// Initialize for time/distance
        init(durationSeconds: Int, distanceMeters: Double?) {
            self.metricType = .timeDistance
            self.weight = nil
            self.reps = nil
            self.durationSeconds = durationSeconds
            self.distanceMeters = distanceMeters
            self.restTimeSeconds = nil
        }

        /// Initialize for completion only
        init() {
            self.metricType = .completion
            self.weight = nil
            self.reps = nil
            self.durationSeconds = nil
            self.distanceMeters = nil
            self.restTimeSeconds = nil
        }

        /// Full initializer
        init(metricType: SetMetricType, weight: Double? = nil, reps: Int? = nil, durationSeconds: Int? = nil, distanceMeters: Double? = nil, restTimeSeconds: Int? = nil) {
            self.metricType = metricType
            self.weight = weight
            self.reps = reps
            self.durationSeconds = durationSeconds
            self.distanceMeters = distanceMeters
            self.restTimeSeconds = restTimeSeconds
        }
    }

    /// Convenience initializer for workout flow (backward compatible - weight/reps)
    init(
        exercise: Exercise,
        bodyPart: BodyPart?,
        initialWeight: Double,
        initialReps: Int,
        initialRestTimeSeconds: Int? = nil,
        isSetCountEditingEnabled: Bool = true,
        isRestTimeEditingEnabled: Bool = true,
        candidateCollection: CopyCandidateCollection = .empty,
        onConfirm: @escaping ([(weight: Double, reps: Int)]) -> Void
    ) {
        self.exercise = exercise
        self.bodyPart = bodyPart
        self.initialWeight = initialWeight
        self.initialReps = initialReps
        self.initialMetricType = .weightReps
        self.initialRestTimeSeconds = initialRestTimeSeconds
        self.config = .workout
        self.isSetCountEditingEnabled = isSetCountEditingEnabled
        self.isRestTimeEditingEnabled = isRestTimeEditingEnabled
        self.candidateCollection = candidateCollection
        self.onConfirm = { sets in
            onConfirm(sets.map { (weight: $0.weight ?? 0, reps: $0.reps ?? 0) })
        }
    }

    /// Full initializer with config and metricType
    init(
        exercise: Exercise,
        bodyPart: BodyPart?,
        metricType: SetMetricType,
        initialWeight: Double = 60,
        initialReps: Int = 10,
        initialDurationSeconds: Int = 60,
        initialDistanceMeters: Double? = nil,
        initialRestTimeSeconds: Int? = nil,
        config: SetEditorConfig,
        isSetCountEditingEnabled: Bool = true,
        isRestTimeEditingEnabled: Bool = true,
        candidateCollection: CopyCandidateCollection = .empty,
        onConfirm: @escaping ([SetInputData]) -> Void,
        weightUnit: WeightUnit = .kg
    ) {
        self.exercise = exercise
        self.bodyPart = bodyPart
        self.initialWeight = initialWeight
        self.initialReps = initialReps
        self.initialMetricType = metricType
        self.initialRestTimeSeconds = initialRestTimeSeconds
        self.config = config
        self.isSetCountEditingEnabled = isSetCountEditingEnabled
        self.isRestTimeEditingEnabled = isRestTimeEditingEnabled
        self.candidateCollection = candidateCollection
        self.onConfirm = onConfirm
        self.weightUnit = weightUnit
    }

    /// Initializer for editing existing sets (weight/reps)
    init(
        exercise: Exercise,
        bodyPart: BodyPart?,
        existingSets: [(weight: Double, reps: Int)],
        config: SetEditorConfig,
        isSetCountEditingEnabled: Bool = true,
        isRestTimeEditingEnabled: Bool = true,
        candidateCollection: CopyCandidateCollection = .empty,
        onConfirm: @escaping ([(weight: Double, reps: Int)]) -> Void
    ) {
        self.exercise = exercise
        self.bodyPart = bodyPart
        self.initialWeight = existingSets.first?.weight ?? 60
        self.initialReps = existingSets.first?.reps ?? 10
        self.initialMetricType = .weightReps
        self.initialRestTimeSeconds = nil
        self.config = config
        self.isSetCountEditingEnabled = isSetCountEditingEnabled
        self.isRestTimeEditingEnabled = isRestTimeEditingEnabled
        self.candidateCollection = candidateCollection
        self.onConfirm = { sets in
            onConfirm(sets.map { (weight: $0.weight ?? 0, reps: $0.reps ?? 0) })
        }
        // Initialize sets state with existing data
        self._sets = State(initialValue: existingSets.map { SetData(weight: $0.weight, reps: $0.reps) })
    }

    /// Initializer for editing existing sets (all metric types)
    init(
        exercise: Exercise,
        bodyPart: BodyPart?,
        metricType: SetMetricType,
        existingSets: [SetInputData],
        config: SetEditorConfig,
        isSetCountEditingEnabled: Bool = true,
        isRestTimeEditingEnabled: Bool = true,
        candidateCollection: CopyCandidateCollection = .empty,
        onConfirm: @escaping ([SetInputData]) -> Void
    ) {
        self.exercise = exercise
        self.bodyPart = bodyPart
        self.initialWeight = existingSets.first?.weight ?? 60
        self.initialReps = existingSets.first?.reps ?? 10
        self.initialMetricType = metricType
        self.initialRestTimeSeconds = existingSets.first?.restTimeSeconds
        self.config = config
        self.isSetCountEditingEnabled = isSetCountEditingEnabled
        self.isRestTimeEditingEnabled = isRestTimeEditingEnabled
        self.candidateCollection = candidateCollection
        self.onConfirm = onConfirm
        // Initialize sets state with existing data
        self._sets = State(initialValue: existingSets.map {
            SetData(metricType: $0.metricType, weight: $0.weight, reps: $0.reps, durationSeconds: $0.durationSeconds, distanceMeters: $0.distanceMeters, restTimeSeconds: $0.restTimeSeconds)
        })
        self._selectedMetricType = State(initialValue: metricType)
    }

    private var hasCandidates: Bool {
        candidateCollection.representativePlanCandidate != nil ||
        candidateCollection.lastWorkoutCandidate != nil
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Exercise header
                exerciseHeader
                    .padding()
                    .background(AppColors.cardBackground)

                // Sets list
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            // Metric type picker (only for cardio - hide for weight/BW)
                            if allowedMetricTypes.count > 1 &&
                                !allowedMetricTypes.allSatisfy({ $0 == .weightReps || $0 == .bodyweightReps }) {
                                metricTypePicker
                            }

                            // Candidates section (if any) - only for weightReps
                            if hasCandidates && (selectedMetricType == .weightReps || selectedMetricType == .bodyweightReps) {
                                candidatesSection
                            }

                            ForEach(Array(sets.enumerated()), id: \.element.id) { index, setData in
                                setEditorRowForMetricType(
                                    index: index,
                                    setData: setData
                                )
                            }

                            // Add set button
                            if isSetCountEditingEnabled {
                                Button {
                                    addSet()
                                    // Scroll to bottom after adding
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            proxy.scrollTo("confirmButton", anchor: .bottom)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("workout_add_another_set")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(10)
                                }
                            }

                            // Confirm button
                            Button {
                                confirmSets()
                            } label: {
                                Text(config.confirmButtonText)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(AppColors.accentBlue)
                                    .cornerRadius(10)
                            }
                            .id("confirmButton")

                            // Bottom ad
                            if shouldShowAd {
                                NativeAdCardView(nativeAd: adManager.nativeAds[0])
                            }
                        }
                        .padding()
                    }
                }
            }

            // Toast overlay
            if showUndoToast {
                VStack {
                    Spacer()
                    undoToast
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(AppColors.background)
        .navigationTitle(config.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    confirmSets()
                } label: {
                    Text(config.confirmButtonText)
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Initialize metric type from initial value, with fallback for disallowed types
            let targetMetricType: SetMetricType
            if allowedMetricTypes.contains(initialMetricType) {
                targetMetricType = initialMetricType
            } else {
                // Fallback to default type for this body part
                targetMetricType = SetMetricType.defaultType(isCardio: isCardio)
            }
            if selectedMetricType != targetMetricType {
                selectedMetricType = targetMetricType
            }
            // Start with configured number of sets (only if no existing sets)
            if sets.isEmpty && config.initialSetCount > 0 {
                for _ in 0..<config.initialSetCount {
                    sets.append(createDefaultSetData())
                }
            }
            // Load ads
            if adManager.nativeAds.isEmpty {
                adManager.loadNativeAds(count: 1)
            }
        }
        .onChange(of: selectedMetricType) { oldValue, newValue in
            // Reset sets when metric type changes
            if oldValue != newValue {
                resetSetsForNewMetricType()
            }
        }
        .sheet(isPresented: $showCandidatePicker) {
            CopyCandidatePickerSheet(
                candidateCollection: candidateCollection,
                onSelect: { sets in
                    applySets(sets)
                }
            )
        }
        .toolbar {
            // Keyboard toolbar save button (for convenience when keyboard is open)
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    confirmSets()
                } label: {
                    Text(config.confirmButtonText)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accentBlue)
                }
            }
        }
    }

    // MARK: - Candidates Section

    private var candidatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("copy_candidates")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 4)

            // 1. Representative plan candidate
            if let planCandidate = candidateCollection.representativePlanCandidate {
                Button {
                    applySets(planCandidate.sets)
                } label: {
                    candidateRow(
                        title: L10n.tr("copy_from_plan"),
                        subtitle: planCandidate.subtitle,
                        preview: planCandidate.setsPreview
                    )
                }
                .buttonStyle(.plain)
            }

            // 2. Last workout candidate
            if let workoutCandidate = candidateCollection.lastWorkoutCandidate {
                Button {
                    applySets(workoutCandidate.sets)
                } label: {
                    candidateRow(
                        title: L10n.tr("last_workout_candidate"),
                        subtitle: workoutCandidate.dateString,
                        preview: workoutCandidate.setsPreview
                    )
                }
                .buttonStyle(.plain)
            }

            // 3. "Other sources..." button (only if more candidates exist)
            if candidateCollection.hasMoreCandidates {
                Button {
                    showCandidatePicker = true
                } label: {
                    HStack {
                        Text("other_copy_sources")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textMuted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(AppColors.cardBackground)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func candidateRow(title: String, subtitle: String, preview: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text(preview)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Image(systemName: "doc.on.doc")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
        .cornerRadius(10)
    }

    // MARK: - Undo Toast

    private var undoToast: some View {
        HStack(spacing: 12) {
            Text(L10n.tr("sets_applied", appliedSetCount))
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()

            Button {
                undoApply()
            } label: {
                Text("undo")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.accentBlue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.2))
        .cornerRadius(12)
    }

    // MARK: - Exercise Header

    private var exerciseHeader: some View {
        HStack(spacing: 12) {
            // Body part color dot
            if let bodyPart = bodyPart {
                Circle()
                    .fill(bodyPart.color)
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.localizedName)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)

                if let bodyPart = bodyPart {
                    Text(bodyPart.localizedName)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Metric Type Picker

    private var metricTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("metric_type_label")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 4)

            HStack(spacing: 8) {
                ForEach(allowedMetricTypes, id: \.self) { type in
                    metricTypeButton(type)
                }
            }
        }
    }

    private func metricTypeButton(_ type: SetMetricType) -> some View {
        Button {
            selectedMetricType = type
        } label: {
            Text(type.localizedName)
                .font(.caption)
                .fontWeight(selectedMetricType == type ? .semibold : .regular)
                .foregroundColor(selectedMetricType == type ? .white : AppColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedMetricType == type ? AppColors.accentBlue : AppColors.cardBackground)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Metric Type Row Builder

    @ViewBuilder
    private func setEditorRowForMetricType(index: Int, setData: SetData) -> some View {
        // Use setData.metricType for per-set branching (allows weight/bodyweight mixing)
        switch setData.metricType {
        case .weightReps, .bodyweightReps:
            WeightBodyweightEditorRow(
                index: index + 1,
                metricType: Binding(
                    get: { sets[index].metricType },
                    set: { sets[index].metricType = $0 }
                ),
                weight: Binding(
                    get: { sets[index].weight },
                    set: { sets[index].weight = $0 }
                ),
                reps: Binding(
                    get: { sets[index].reps ?? 0 },
                    set: { sets[index].reps = $0 }
                ),
                restTimeSeconds: Binding(
                    get: { sets[index].restTimeSeconds },
                    set: { sets[index].restTimeSeconds = $0 }
                ),
                initialWeight: initialWeight,
                isRestTimeEditingEnabled: isRestTimeEditingEnabled,
                onDelete: { deleteSet(at: index) },
                canDelete: isSetCountEditingEnabled && sets.count > 1,
                weightUnit: weightUnit
            )
        case .timeDistance:
            TimeDistanceEditorRow(
                index: index + 1,
                durationSeconds: Binding(
                    get: { sets[index].durationSeconds ?? 0 },
                    set: { sets[index].durationSeconds = $0 }
                ),
                distanceMeters: Binding(
                    get: { sets[index].distanceMeters },
                    set: { sets[index].distanceMeters = $0 }
                ),
                onDelete: { deleteSet(at: index) },
                canDelete: isSetCountEditingEnabled && sets.count > 1
            )
        case .completion:
            CompletionEditorRow(
                index: index + 1,
                onDelete: { deleteSet(at: index) },
                canDelete: isSetCountEditingEnabled && sets.count > 1
            )
        }
    }

    private func deleteSet(at index: Int) {
        guard isSetCountEditingEnabled else { return }
        if sets.count > 1 {
            sets.remove(at: index)
        }
    }

    private func resetSetsForNewMetricType() {
        // Keep the same number of sets but reset their data for the new metric type
        let setCount = max(sets.count, 1)
        sets.removeAll()
        for _ in 0..<setCount {
            sets.append(createDefaultSetData())
        }
    }

    // MARK: - Actions

    private func createDefaultSetData() -> SetData {
        switch metricType {
        case .weightReps:
            return SetData(weight: initialWeight, reps: initialReps, restTimeSeconds: initialRestTimeSeconds)
        case .bodyweightReps:
            return SetData(metricType: .bodyweightReps, reps: initialReps, restTimeSeconds: initialRestTimeSeconds)
        case .timeDistance:
            return SetData(metricType: .timeDistance, durationSeconds: 60, distanceMeters: nil)
        case .completion:
            return SetData(metricType: .completion)
        }
    }

    private func addSet() {
        // Copy values from last set based on metric type
        let lastSet = sets.last
        switch metricType {
        case .weightReps, .bodyweightReps:
            // Inherit metric type from last set (allows mixing weight/BW)
            let newMetricType = lastSet?.metricType ?? .weightReps
            sets.append(SetData(
                metricType: newMetricType,
                weight: lastSet?.weight ?? initialWeight,
                reps: lastSet?.reps ?? initialReps,
                restTimeSeconds: lastSet?.restTimeSeconds ?? initialRestTimeSeconds
            ))
        case .timeDistance:
            sets.append(SetData(
                metricType: .timeDistance,
                durationSeconds: lastSet?.durationSeconds ?? 60,
                distanceMeters: lastSet?.distanceMeters
            ))
        case .completion:
            sets.append(SetData(metricType: .completion))
        }
    }

    private func confirmSets() {
        let setsData = sets.map { setData in
            // Use setData.metricType for per-set metric type
            // For bodyweightReps, force weight=nil (don't infer from 0kg)
            let weight: Double? = setData.metricType == .bodyweightReps ? nil : setData.weight
            return SetInputData(
                metricType: setData.metricType,
                weight: weight,
                reps: setData.reps,
                durationSeconds: setData.durationSeconds,
                distanceMeters: setData.distanceMeters,
                restTimeSeconds: setData.restTimeSeconds
            )
        }
        onConfirm(setsData)
    }

    private func applySets(_ newSets: [CopyableSetData]) {
        // Save current sets for undo
        previousSets = sets
        appliedSetCount = newSets.count

        // Replace sets with new sets (including rest time)
        sets = newSets.map { SetData(weight: $0.weight, reps: $0.reps, restTimeSeconds: $0.restTimeSeconds) }

        // Show toast
        withAnimation(.easeInOut(duration: 0.2)) {
            showUndoToast = true
        }

        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showUndoToast = false
            }
        }
    }

    private func undoApply() {
        guard let previous = previousSets else { return }

        // Restore previous sets
        sets = previous
        previousSets = nil

        // Hide toast
        withAnimation(.easeInOut(duration: 0.2)) {
            showUndoToast = false
        }
    }
}

// MARK: - Cursor End TextField

/// A TextField wrapper that positions cursor at the end when focused
private struct CursorEndTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let keyboardType: UIKeyboardType
    let textAlignment: NSTextAlignment
    let font: UIFont
    let textColor: UIColor

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.textAlignment = textAlignment
        textField.font = font
        textField.textColor = textColor
        textField.backgroundColor = .clear
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)

        // Add keyboard toolbar with Done button
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(
            title: L10n.tr("done"),
            style: .done,
            target: context.coordinator,
            action: #selector(Coordinator.doneButtonTapped)
        )
        doneButton.tintColor = UIColor(AppColors.accentBlue)
        toolbar.items = [flexSpace, doneButton]
        textField.inputAccessoryView = toolbar

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CursorEndTextField

        init(_ parent: CursorEndTextField) {
            self.parent = parent
        }

        @objc func textChanged(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        @objc func doneButtonTapped() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            // Move cursor to end
            DispatchQueue.main.async {
                let endPosition = textField.endOfDocument
                textField.selectedTextRange = textField.textRange(from: endPosition, to: endPosition)
            }
        }
    }
}

// MARK: - Weight/Reps Editor Row

private struct WeightBodyweightEditorRow: View {
    let index: Int
    @Binding var metricType: SetMetricType
    @Binding var weight: Double?
    @Binding var reps: Int
    @Binding var restTimeSeconds: Int?
    let initialWeight: Double
    let isRestTimeEditingEnabled: Bool
    let onDelete: () -> Void
    let canDelete: Bool
    var weightUnit: WeightUnit = .kg

    @State private var weightText: String = ""
    @State private var repsText: String = ""

    private var isBodyweight: Bool {
        metricType == .bodyweightReps
    }

    private var formattedRestTime: String {
        let seconds = restTimeSeconds ?? 0
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left block: Set label + REST (vertical stack)
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("set_label", index))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)

                if isRestTimeEditingEnabled {
                    RestTimePickerCompact(restTimeSeconds: Binding(
                        get: { restTimeSeconds ?? 0 },
                        set: { restTimeSeconds = $0 > 0 ? $0 : nil }
                    ))
                    .frame(width: 60, alignment: .leading)
                }
            }
            .frame(width: 64, alignment: .leading)

            // Right block: Weight [kg/BW] × Reps 回
            HStack(spacing: 6) {
                weightOrBwDisplay

                verticalUnitToggle

                Text("×")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textMuted)
                    .frame(width: 10, alignment: .center)
                    .layoutPriority(1)
                    .fixedSize()

                HStack(spacing: 4) {
                    repsInput

                    Text(L10n.tr("unit_reps"))
                        .font(.caption2)
                        .foregroundColor(AppColors.textMuted)
                        .frame(width: 14, alignment: .leading)
                        .lineLimit(1)
                        .fixedSize()
                }
                .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Delete button (icon only)
            if canDelete {
                deleteButton
            } else {
                // Placeholder for layout balance
                Color.clear
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .onAppear {
            syncTextFromModel()
        }
    }

    // Weight input or BW chip
    private var weightOrBwDisplay: some View {
        ZStack {
            if isBodyweight {
                Text(L10n.tr("bodyweight_label"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
            } else {
                CursorEndTextField(
                    text: $weightText,
                    placeholder: "--",
                    keyboardType: .decimalPad,
                    textAlignment: .center,
                    font: .systemFont(ofSize: 18, weight: .bold),
                    textColor: UIColor(AppColors.textPrimary)
                )
                .onChange(of: weightText) { _, newValue in
                    if let value = Double(newValue) {
                        weight = value
                    }
                }
            }
        }
        .frame(width: 64, height: 40)
        .background(AppColors.background)
        .cornerRadius(8)
    }

    // Reps input
    private var repsInput: some View {
        CursorEndTextField(
            text: $repsText,
            placeholder: "--",
            keyboardType: .numberPad,
            textAlignment: .center,
            font: .systemFont(ofSize: 18, weight: .bold),
            textColor: UIColor(AppColors.textPrimary)
        )
        .frame(width: 52, height: 40)
        .background(AppColors.background)
        .cornerRadius(8)
        .onChange(of: repsText) { _, newValue in
            if let value = Int(newValue) {
                reps = value
            }
        }
    }

    // Vertical toggle: [ kg / BW ]
    private var verticalUnitToggle: some View {
        VStack(spacing: 2) {
            Button {
                if isBodyweight {
                    metricType = .weightReps
                    if weight == nil {
                        weight = initialWeight
                        weightText = formatWeight(initialWeight)
                    }
                }
            } label: {
                Text(weightUnit.symbol)
                    .font(.caption2)
                    .fontWeight(isBodyweight ? .regular : .semibold)
                    .foregroundColor(isBodyweight ? AppColors.textMuted : .white)
                    .frame(width: 32, height: 16)
                    .background(isBodyweight ? Color.clear : AppColors.accentBlue)
            }

            Button {
                if !isBodyweight {
                    metricType = .bodyweightReps
                }
            } label: {
                Text(L10n.tr("bodyweight_label"))
                    .font(.caption2)
                    .fontWeight(isBodyweight ? .semibold : .regular)
                    .foregroundColor(isBodyweight ? .white : AppColors.textMuted)
                    .frame(width: 32, height: 16)
                    .background(isBodyweight ? AppColors.accentBlue : Color.clear)
            }
        }
        .padding(2)
        .background(AppColors.background)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppColors.textMuted.opacity(0.3), lineWidth: 1)
        )
        .buttonStyle(.plain)
    }

    // Delete button (icon only)
    private var deleteButton: some View {
        Button {
            onDelete()
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textMuted)
                .frame(width: 28, height: 28)
                .background(AppColors.background)
                .cornerRadius(6)
        }
    }

    private func syncTextFromModel() {
        if let w = weight {
            weightText = formatWeight(w)
        }
        repsText = "\(reps)"
    }

    private func formatWeight(_ weight: Double) -> String {
        Formatters.formatWeight(weight)
    }
}

// MARK: - Time/Distance Editor Row

private struct TimeDistanceEditorRow: View {
    let index: Int
    @Binding var durationSeconds: Int
    @Binding var distanceMeters: Double?
    let onDelete: () -> Void
    let canDelete: Bool

    @State private var minutesText: String = ""
    @State private var secondsText: String = ""
    @State private var distanceText: String = ""

    var body: some View {
        HStack(spacing: 8) {
            // Set number
            Text(L10n.tr("set_label", index))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 40, alignment: .leading)

            // Minutes input
            CursorEndTextField(
                text: $minutesText,
                placeholder: "--",
                keyboardType: .numberPad,
                textAlignment: .center,
                font: .systemFont(ofSize: 15, weight: .semibold),
                textColor: UIColor(AppColors.textPrimary)
            )
            .frame(width: 40, height: 36)
            .background(AppColors.background)
            .cornerRadius(8)
            .onChange(of: minutesText) { _, _ in
                updateDuration()
            }

            Text("unit_min")
                .font(.caption2)
                .foregroundColor(AppColors.textMuted)
                .frame(width: 20)

            // Seconds input
            CursorEndTextField(
                text: $secondsText,
                placeholder: "--",
                keyboardType: .numberPad,
                textAlignment: .center,
                font: .systemFont(ofSize: 15, weight: .semibold),
                textColor: UIColor(AppColors.textPrimary)
            )
            .frame(width: 40, height: 36)
            .background(AppColors.background)
            .cornerRadius(8)
            .onChange(of: secondsText) { _, _ in
                updateDuration()
            }

            Text("unit_sec")
                .font(.caption2)
                .foregroundColor(AppColors.textMuted)
                .frame(width: 20)

            // Distance input (optional)
            CursorEndTextField(
                text: $distanceText,
                placeholder: "--",
                keyboardType: .decimalPad,
                textAlignment: .center,
                font: .systemFont(ofSize: 15, weight: .semibold),
                textColor: UIColor(AppColors.textPrimary)
            )
            .frame(width: 45, height: 36)
            .background(AppColors.background)
            .cornerRadius(8)
            .onChange(of: distanceText) { _, newValue in
                if newValue.isEmpty {
                    distanceMeters = nil
                } else if let km = Double(newValue) {
                    distanceMeters = km * 1000  // Convert km to meters
                }
            }

            Text("unit_km")
                .font(.caption2)
                .foregroundColor(AppColors.textMuted)
                .frame(width: 20)

            Spacer(minLength: 4)

            // Delete button
            if canDelete {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.textMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
        .cornerRadius(10)
        .onAppear {
            let minutes = durationSeconds / 60
            let seconds = durationSeconds % 60
            minutesText = "\(minutes)"
            secondsText = seconds > 0 ? "\(seconds)" : ""
            if let meters = distanceMeters {
                let km = meters / 1000
                distanceText = km.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", km)
                    : String(format: "%.1f", km)
            }
        }
    }

    private func updateDuration() {
        let minutes = Int(minutesText) ?? 0
        let seconds = Int(secondsText) ?? 0
        durationSeconds = minutes * 60 + seconds
    }
}

// MARK: - Completion Only Editor Row

private struct CompletionEditorRow: View {
    let index: Int
    let onDelete: () -> Void
    let canDelete: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Set number
            Text(L10n.tr("set_label", index))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 40, alignment: .leading)

            // Completion hint
            Text("completion_only_hint")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Spacer(minLength: 4)

            // Delete button
            if canDelete {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.textMuted)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
        .cornerRadius(10)
    }
}

// MARK: - Copy Candidate Picker Sheet

/// Sheet for browsing all copy candidates
struct CopyCandidatePickerSheet: View {
    let candidateCollection: CopyCandidateCollection
    let onSelect: ([CopyableSetData]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: CandidateTab = .plan

    enum CandidateTab: String, CaseIterable {
        case plan
        case workout

        var title: String {
            switch self {
            case .plan: return L10n.tr("copy_tab_plan")
            case .workout: return L10n.tr("copy_tab_workout")
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("", selection: $selectedTab) {
                    ForEach(CandidateTab.allCases, id: \.self) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content based on selected tab
                ScrollView {
                    switch selectedTab {
                    case .plan:
                        planCandidatesContent
                    case .workout:
                        workoutCandidatesContent
                    }
                }
            }
            .background(AppColors.background)
            .navigationTitle(L10n.tr("select_copy_source"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Plan Tab Content

    private var planCandidatesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // This plan section
            if !candidateCollection.currentPlanCandidates.isEmpty {
                candidateSection(
                    title: L10n.tr("copy_section_this_plan"),
                    candidates: candidateCollection.currentPlanCandidates
                )
            }

            // Other plans section
            if !candidateCollection.otherPlanCandidates.isEmpty {
                candidateSection(
                    title: L10n.tr("copy_section_other_plans"),
                    candidates: candidateCollection.otherPlanCandidates
                )
            }

            // Empty state
            if candidateCollection.planCandidates.isEmpty {
                emptyState(message: L10n.tr("no_plan_candidates"))
            }
        }
        .padding()
    }

    // MARK: - Workout Tab Content

    private var workoutCandidatesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !candidateCollection.workoutCandidates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("copy_section_workout_history"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 4)

                    ForEach(candidateCollection.workoutCandidates) { candidate in
                        Button {
                            onSelect(candidate.sets)
                            dismiss()
                        } label: {
                            workoutCandidateRow(candidate)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                emptyState(message: L10n.tr("no_workout_candidates"))
            }
        }
        .padding()
    }

    // MARK: - Helper Views

    private func candidateSection(title: String, candidates: [PlanCopyCandidate]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 4)

            ForEach(candidates) { candidate in
                Button {
                    onSelect(candidate.sets)
                    dismiss()
                } label: {
                    planCandidateRow(candidate)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func planCandidateRow(_ candidate: PlanCopyCandidate) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.planName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)

                Text(candidate.dayName)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(candidate.setsPreview)
                    .font(.caption)
                    .foregroundColor(AppColors.textPrimary)

                Text(formatDate(candidate.updatedAt))
                    .font(.caption2)
                    .foregroundColor(AppColors.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
        .cornerRadius(10)
    }

    private func workoutCandidateRow(_ candidate: WorkoutCopyCandidate) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatFullDate(candidate.workoutDate))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
            }

            Spacer()

            Text(candidate.setsPreview)
                .font(.caption)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
        .cornerRadius(10)
    }

    private func emptyState(message: String) -> some View {
        VStack {
            Text(message)
                .font(.subheadline)
                .foregroundColor(AppColors.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        }
    }

    private func formatDate(_ date: Date) -> String {
        Formatters.monthDay.string(from: date)
    }

    private func formatFullDate(_ date: Date) -> String {
        Formatters.yearMonthDaySlash.string(from: date)
    }
}

/// Backward compatibility alias
typealias WorkoutSetEditorView = SetEditorView

#Preview("Workout Flow") {
    NavigationStack {
        SetEditorView(
            exercise: Exercise(name: "Bench Press", scope: .global),
            bodyPart: nil,
            initialWeight: 60,
            initialReps: 8,
            onConfirm: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Plan Flow") {
    NavigationStack {
        SetEditorView(
            exercise: Exercise(name: "Bench Press", scope: .global),
            bodyPart: nil,
            metricType: .weightReps,
            initialWeight: 60,
            initialReps: 8,
            config: .plan,
            onConfirm: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Bodyweight Flow") {
    NavigationStack {
        SetEditorView(
            exercise: Exercise(name: "Pull-ups", scope: .global),
            bodyPart: nil,
            metricType: .bodyweightReps,
            initialReps: 10,
            config: .workout,
            onConfirm: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Time/Distance Flow") {
    NavigationStack {
        SetEditorView(
            exercise: Exercise(name: "Running", scope: .global),
            bodyPart: nil,
            metricType: .timeDistance,
            config: .workout,
            onConfirm: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Completion Flow") {
    NavigationStack {
        SetEditorView(
            exercise: Exercise(name: "Stretching", scope: .global),
            bodyPart: nil,
            metricType: .completion,
            config: .workout,
            onConfirm: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}
