//
//  CardioHistoryView.swift
//  Routyra
//
//  Displays cardio workout history with HealthKit sync.
//

import SwiftUI
import SwiftData
import HealthKit

struct CardioHistoryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CardioWorkout.startDate, order: .reverse)
    private var cardioWorkouts: [CardioWorkout]

    let profile: LocalProfile
    let activityType: Int?
    let useNavigationStack: Bool

    init(profile: LocalProfile, activityType: Int? = nil, useNavigationStack: Bool = true) {
        self.profile = profile
        self.activityType = activityType
        self.useNavigationStack = useNavigationStack
    }

    // MARK: - State

    @State private var isSyncing = false
    @State private var syncResult: SyncResult?
    @State private var showingAuthAlert = false

    // MARK: - Body

    var body: some View {
        Group {
            if useNavigationStack {
                NavigationStack {
                    content
                }
            } else {
                content
            }
        }
        .preferredColorScheme(.dark)
    }

    private var content: some View {
        Group {
            if filteredWorkouts.isEmpty {
                emptyStateView
            } else {
                workoutListView
            }
        }
        .background(AppColors.background)
        .navigationTitle(navigationTitle)
        .alert(L10n.tr("cardio_sync_complete"), isPresented: .constant(syncResult != nil)) {
            Button(L10n.tr("ok")) {
                syncResult = nil
            }
        } message: {
            if let result = syncResult {
                Text(result.message)
            }
        }
        .alert(L10n.tr("cardio_health_permission_title"), isPresented: $showingAuthAlert) {
            Button(L10n.tr("ok")) {}
        } message: {
            Text(L10n.tr("cardio_health_permission_message"))
        }
    }

    // MARK: - Views

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textMuted)

            Text(L10n.tr("cardio_no_workouts"))
                .font(.headline)
                .foregroundColor(AppColors.textSecondary)

            Text(L10n.tr("cardio_no_workouts_hint"))
                .font(.subheadline)
                .foregroundColor(AppColors.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button {
                    syncFromHealthKit()
                } label: {
                    Label(L10n.tr("cardio_sync_health"), systemImage: "heart.fill")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var workoutListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(groupedWorkouts, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        // Section header
                        Text(formatDate(group.date))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        // Workout cards
                        VStack(spacing: 8) {
                            ForEach(group.workouts) { workout in
                                CardioWorkoutRowView(
                                    workout: workout,
                                    showsActivityName: activityType == nil,
                                    onDelete: {
                                        deleteWorkout(workout)
                                    }
                                )
                                .background(AppColors.cardBackground)
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(AppColors.background)
    }

    // MARK: - Grouped Data

    private struct WorkoutGroup {
        let date: Date
        let workouts: [CardioWorkout]
    }

    private var groupedWorkouts: [WorkoutGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredWorkouts) { workout in
            calendar.startOfDay(for: workout.startDate)
        }

        return grouped
            .map { WorkoutGroup(date: $0.key, workouts: $0.value) }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private var navigationTitle: String {
        guard let activityType = activityType,
              let type = HKWorkoutActivityType(rawValue: UInt(activityType)) else {
            return L10n.tr("cardio_history_title")
        }
        return type.displayName
    }

    private var filteredWorkouts: [CardioWorkout] {
        guard let activityType = activityType else {
            return cardioWorkouts
        }
        return cardioWorkouts.filter { $0.activityType == activityType }
    }

    // MARK: - Actions

    private func syncFromHealthKit() {
        guard HealthKitService.isHealthKitAvailable else {
            syncResult = SyncResult(message: L10n.tr("cardio_health_not_available"))
            return
        }

        isSyncing = true

        Task {
            let authorized = await HealthKitService.requestAuthorization()

            guard authorized else {
                await MainActor.run {
                    isSyncing = false
                    showingAuthAlert = true
                }
                return
            }

            do {
                let count = try await HealthKitService.syncRecentWorkouts(
                    profile: profile,
                    modelContext: modelContext
                )

                await MainActor.run {
                    isSyncing = false
                    if count > 0 {
                        syncResult = SyncResult(
                            message: L10n.tr("cardio_sync_imported", count)
                        )
                    } else {
                        syncResult = SyncResult(
                            message: L10n.tr("cardio_sync_no_new")
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncResult = SyncResult(
                        message: L10n.tr("cardio_sync_error", error.localizedDescription)
                    )
                }
            }
        }
    }

    private func deleteWorkout(_ workout: CardioWorkout) {
        modelContext.delete(workout)
        try? modelContext.save()
    }
}

// MARK: - Supporting Types

private struct SyncResult {
    let message: String
}

// MARK: - Row View

struct CardioWorkoutRowView: View {
    let workout: CardioWorkout
    let showsActivityName: Bool
    var onDelete: (() -> Void)? = nil

    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack {
            // Activity icon
            Image(systemName: activityIcon)
                .font(.title2)
                .foregroundColor(AppColors.accentBlue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 6) {
                if showsActivityName {
                    Text(activityName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                }

                // Start time (top-left)
                Text(startTimeText)
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)

                // Metrics summary
                metricsView
            }

            Spacer()

            // Source indicator
            if workout.source == .healthKit {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.6))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .contextMenu {
            if onDelete != nil {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(L10n.tr("delete"), systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            L10n.tr("workout_delete_entry_title"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.tr("delete"), role: .destructive) {
                onDelete?()
            }
            Button(L10n.tr("cancel"), role: .cancel) {}
        }
    }

    private var activityName: String {
        guard let type = HKWorkoutActivityType(rawValue: UInt(workout.activityType)) else {
            return "Other"
        }
        return type.displayName
    }

    private struct MetricValue: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    @ViewBuilder
    private var metricsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                metricCard(durationMetric)

                if let distanceMetric = distanceMetric {
                    metricCard(distanceMetric)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let energyMetric = energyMetric {
                metricCard(energyMetric)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !heartRateMetrics.isEmpty {
                HStack(spacing: 8) {
                    ForEach(heartRateMetrics) { metric in
                        metricCard(metric)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func metricCard(_ metric: MetricValue) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.label)
                .font(.caption2)
                .foregroundColor(AppColors.textMuted)
            Text(metric.value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.cardBackgroundSecondary)
        )
    }

    private var durationMetric: MetricValue {
        MetricValue(
            label: L10n.tr("cardio_detail_duration_label"),
            value: workout.formattedDuration
        )
    }

    private var distanceMetric: MetricValue? {
        guard let distance = workout.formattedDistance else { return nil }
        return MetricValue(
            label: L10n.tr("cardio_detail_distance_label"),
            value: distance
        )
    }

    private var energyMetric: MetricValue? {
        guard let energy = workout.formattedEnergyBurned else { return nil }
        return MetricValue(
            label: L10n.tr("cardio_detail_energy_burned_label"),
            value: energy
        )
    }

    private var heartRateMetrics: [MetricValue] {
        var metrics: [MetricValue] = []
        if let maxHeartRate = workout.formattedMaxHeartRateValue {
            metrics.append(
                MetricValue(
                    label: L10n.tr("cardio_detail_max_heart_rate_label"),
                    value: maxHeartRate
                )
            )
        }
        if let averageHeartRate = workout.formattedAverageHeartRate {
            metrics.append(
                MetricValue(
                    label: L10n.tr("cardio_detail_avg_heart_rate_label"),
                    value: averageHeartRate
                )
            )
        }
        return metrics
    }

    private var startTimeText: String {
        L10n.tr("cardio_start_time", formatTime(workout.startDate))
    }

    private var activityIcon: String {
        guard let type = HKWorkoutActivityType(rawValue: UInt(workout.activityType)) else {
            return "figure.mixed.cardio"
        }

        switch type {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .hiking: return "figure.hiking"
        case .elliptical: return "figure.elliptical"
        case .rowing: return "figure.rower"
        case .stairClimbing, .stairs: return "figure.stairs"
        case .stepTraining: return "figure.stairs"
        case .highIntensityIntervalTraining: return "figure.highintensity.intervaltraining"
        case .yoga: return "figure.yoga"
        case .pilates: return "figure.pilates"
        case .dance, .cardioDance, .socialDance: return "figure.dance"
        case .tennis, .tableTennis: return "figure.tennis"
        case .basketball: return "figure.basketball"
        case .soccer: return "figure.soccer"
        case .volleyball: return "figure.volleyball"
        case .baseball, .softball: return "figure.baseball"
        case .golf: return "figure.golf"
        case .boxing, .kickboxing: return "figure.boxing"
        case .martialArts: return "figure.martial.arts"
        case .snowboarding, .snowSports: return "figure.snowboarding"
        case .crossCountrySkiing, .downhillSkiing: return "figure.skiing.downhill"
        case .surfingSports: return "figure.surfing"
        case .jumpRope: return "figure.jumprope"
        default: return "figure.mixed.cardio"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
