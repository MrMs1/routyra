//
//  HistoryDayDetailView.swift
//  Routyra
//
//  Day detail view showing completed sets for a workout day.
//

import SwiftUI
import SwiftData
import GoogleMobileAds

struct HistoryDayDetailView: View {
    let date: Date
    let workoutDay: WorkoutDay?
    let cardioWorkouts: [CardioWorkout]
    let exercisesDict: [UUID: Exercise]
    let bodyPartsDict: [UUID: BodyPart]
    let weightUnit: WeightUnit
    var isPremiumUser: Bool = false

    @StateObject private var adManager = NativeAdManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // サマリーセクション
                summarySection

                // 種目カードリスト
                exerciseCardsSection

                // Bottom ad
                if shouldShowAd {
                    NativeAdCardView(nativeAd: adManager.nativeAds[0])
                }
            }
            .padding()
        }
        .background(AppColors.background)
        .navigationTitle(formattedDate)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if adManager.nativeAds.isEmpty {
                adManager.loadNativeAds(count: 1)
            }
        }
    }

    private var shouldShowAd: Bool {
        guard !isPremiumUser else { return false }
        guard !adManager.nativeAds.isEmpty else { return false }
        return true
    }

    // MARK: - Computed Properties

    private var formattedDate: String {
        Formatters.yearMonthDay.string(from: date)
    }

    private var completedEntries: [WorkoutExerciseEntry] {
        workoutDay?.sortedEntries.filter { $0.hasCompletedSets } ?? []
    }

    private var cardioExerciseCount: Int {
        Set(cardioWorkouts.map { $0.activityType }).count
    }

    private var totalCompletedSets: Int {
        completedEntries.reduce(0) { $0 + $1.completedSetsCount } + cardioWorkouts.count
    }

    private var totalVolume: Decimal {
        completedEntries.reduce(Decimal.zero) { $0 + $1.totalVolume }
    }

    private var totalExercises: Int {
        completedEntries.count + cardioExerciseCount
    }

    private var summaryVolumeText: String {
        if completedEntries.isEmpty && !cardioWorkouts.isEmpty {
            return "-"
        }
        return formatVolumeWithUnit(totalVolume)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        HStack(spacing: 8) {
            summaryCard(
                value: "\(totalExercises)",
                label: L10n.tr("exercises")
            )

            summaryCard(
                value: "\(totalCompletedSets)",
                label: L10n.tr("history_total_sets")
            )

            summaryCard(
                value: summaryVolumeText,
                label: L10n.tr("history_total_volume")
            )
        }
    }

    private func summaryCard(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppColors.cardBackgroundSecondary)
        .cornerRadius(10)
    }

    // MARK: - Exercise Cards Section

    private var exerciseCardsSection: some View {
        VStack(spacing: 12) {
            ForEach(completedEntries) { entry in
                exerciseCard(entry)
            }

            ForEach(cardioWorkouts) { workout in
                cardioWorkoutCard(workout)
            }
        }
    }

    private func cardioWorkoutCard(_ workout: CardioWorkout) -> some View {
        CardioWorkoutRowView(workout: workout, showsActivityName: true)
            .background(AppColors.cardBackground)
            .cornerRadius(12)
    }

    // MARK: - Exercise Card

    @ViewBuilder
    private func exerciseCard(_ entry: WorkoutExerciseEntry) -> some View {
        let exercise = exercisesDict[entry.exerciseId]
        let completedSets = entry.activeSets.filter { $0.isCompleted }.sorted { $0.setIndex < $1.setIndex }

        VStack(alignment: .leading, spacing: 12) {
            // 種目名 + BodyPartドット
            exerciseHeader(exercise: exercise)

            // メトリクス別サマリー
            metricsSummary(entry: entry, completedSets: completedSets)

            // セット明細
            Divider()
                .background(AppColors.textMuted.opacity(0.3))

            setsList(completedSets: completedSets, metricType: entry.metricType)
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    private func exerciseHeader(exercise: Exercise?) -> some View {
        let bodyPartColor = exercise?.bodyPartId
            .flatMap { bodyPartsDict[$0]?.color } ?? AppColors.textMuted

        return HStack(spacing: 6) {
            Circle()
                .fill(bodyPartColor.opacity(0.8))
                .frame(width: 8, height: 8)

            Text(exercise?.localizedName ?? L10n.tr("unknown"))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
    }

    // MARK: - Metrics Summary

    @ViewBuilder
    private func metricsSummary(entry: WorkoutExerciseEntry, completedSets: [WorkoutSet]) -> some View {
        switch entry.metricType {
        case .weightReps:
            weightRepsMetrics(completedSets: completedSets)
        case .bodyweightReps:
            bodyweightRepsMetrics(completedSets: completedSets)
        case .timeDistance:
            timeDistanceMetrics(completedSets: completedSets)
        case .completion:
            completionMetrics(completedSets: completedSets)
        }
    }

    private func weightRepsMetrics(completedSets: [WorkoutSet]) -> some View {
        let totalVol = completedSets.reduce(Decimal.zero) { $0 + $1.volume }
        let maxWeight = completedSets.compactMap { $0.weight }.max() ?? 0
        let maxOneRM = completedSets.compactMap { set -> Double? in
            guard let weight = set.weight, let reps = set.reps, reps > 0 else { return nil }
            return WorkoutService.epleyOneRM(weight: NSDecimalNumber(decimal: weight).doubleValue, reps: reps)
        }.max() ?? 0

        return HStack(spacing: 8) {
            metricChip(
                value: formatVolumeWithUnit(totalVol),
                label: L10n.tr("history_total_volume")
            )
            metricChip(
                value: "\(Formatters.formatWeight(NSDecimalNumber(decimal: maxWeight).doubleValue))\(weightUnit.symbol)",
                label: L10n.tr("history_max_weight")
            )
            metricChip(
                value: "\(Formatters.formatWeight(maxOneRM))\(weightUnit.symbol)",
                label: L10n.tr("history_estimated_1rm")
            )
        }
    }

    private func bodyweightRepsMetrics(completedSets: [WorkoutSet]) -> some View {
        let totalReps = completedSets.compactMap { $0.reps }.reduce(0, +)

        return HStack(spacing: 8) {
            metricChip(
                value: "\(totalReps)",
                label: L10n.tr("history_total_reps")
            )
        }
    }

    private func timeDistanceMetrics(completedSets: [WorkoutSet]) -> some View {
        let totalSeconds = completedSets.compactMap { $0.durationSeconds }.reduce(0, +)
        let totalMeters = completedSets.compactMap { $0.distanceMeters }.reduce(0, +)

        return HStack(spacing: 8) {
            metricChip(
                value: formatTotalDuration(totalSeconds),
                label: L10n.tr("history_total_time")
            )
            if totalMeters > 0 {
                metricChip(
                    value: formatTotalDistance(totalMeters),
                    label: L10n.tr("history_total_distance")
                )
            }
        }
    }

    private func completionMetrics(completedSets: [WorkoutSet]) -> some View {
        HStack(spacing: 8) {
            metricChip(
                value: "\(completedSets.count)",
                label: L10n.tr("history_total_sets")
            )
        }
    }

    private func metricChip(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(AppColors.cardBackgroundSecondary)
        )
    }

    // MARK: - Sets List

    private func setsList(completedSets: [WorkoutSet], metricType: SetMetricType) -> some View {
        VStack(spacing: 8) {
            ForEach(completedSets) { set in
                setRow(set)
            }
        }
    }

    @ViewBuilder
    private func setRow(_ set: WorkoutSet) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(L10n.tr("history_set_label", set.setIndex))
                .font(.caption)
                .foregroundColor(AppColors.textMuted)
                .frame(minWidth: 56, alignment: .leading)

            Group {
                switch set.metricType {
                case .weightReps:
                    Text("\(Formatters.formatWeight(set.weightDouble))\(weightUnit.symbol) × \(set.reps ?? 0)")

                case .bodyweightReps:
                    Text("\(L10n.tr("bodyweight_label")) × \(set.reps ?? 0)")

                case .timeDistance:
                    HStack(spacing: 4) {
                        Text(set.durationFormatted)
                        if let distance = set.distanceMeters, distance > 0 {
                            Text("/")
                            Text(set.distanceFormatted)
                        }
                    }

                case .completion:
                    Text(L10n.tr("history_completed"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
        .foregroundColor(AppColors.textPrimary)
    }

    // MARK: - Formatters

    private func formatVolumeWithUnit(_ volume: Decimal) -> String {
        VolumeFormatter.format(volume, weightUnit: weightUnit)
    }

    private func formatTotalDuration(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func formatTotalDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2fkm", meters / 1000)
        } else {
            return String(format: "%.0fm", meters)
        }
    }
}

#Preview {
    NavigationStack {
        Text("Preview requires WorkoutDay data")
    }
    .preferredColorScheme(.dark)
}
