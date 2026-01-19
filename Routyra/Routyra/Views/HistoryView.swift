//
//  HistoryView.swift
//  Routyra
//

import SwiftUI
import SwiftData
import Charts
import GoogleMobileAds
import HealthKit

/// Navigation wrapper to distinguish WorkoutDay navigation from Exercise navigation
private struct DayDetailNavigation: Hashable {
    let date: Date
}

/// Navigation wrapper for month detail.
private struct MonthNavigation: Hashable {
    let month: Date
}

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutDay.date, order: .reverse) private var workoutDays: [WorkoutDay]
    @Query private var exercises: [Exercise]
    @Query private var bodyParts: [BodyPart]
    @Query(sort: \CardioWorkout.startDate, order: .reverse) private var cardioWorkouts: [CardioWorkout]

    @State private var profile: LocalProfile?
    @State private var displayedMonth: Date = DateUtilities.startOfDay(Date())
    @State private var selectedDate: Date = DateUtilities.startOfDay(Date())
    @State private var monthTransitionDirection: Int = 0
    @State private var isCardioSyncing = false
    @State private var cardioSyncResult: CardioSyncResult?
    @State private var showingCardioAuthAlert = false

    // OPTIMIZATION: Cache exercise summaries to avoid recalculation on every render
    @State private var cachedExerciseSummaries: [ExerciseMonthlySummary] = []
    @State private var cachedMonthSummary = WorkoutSummary(
        workoutDays: 0,
        exercises: 0,
        sets: 0,
        volume: .zero
    )
    @State private var cachedCardioMonthlySummary = CardioMonthlySummary(
        sessionCount: 0,
        totalDuration: 0,
        totalDistance: 0
    )
    @State private var cachedCardioActivitySummaries: [CardioActivitySummary] = []
    @State private var cachedWorkoutDates: Set<Date> = []

    // Ad manager
    @StateObject private var adManager = NativeAdManager()

    private var exercisesDict: [UUID: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    private var bodyPartsDict: [UUID: BodyPart] {
        Dictionary(uniqueKeysWithValues: bodyParts.map { ($0.id, $0) })
    }

    private var filteredWorkoutDays: [WorkoutDay] {
        guard let profile = profile else { return [] }
        return workoutDays.filter { $0.profileId == profile.id }
    }

    private var monthStart: Date {
        DateUtilities.startOfMonth(for: displayedMonth)
    }

    private var monthEnd: Date {
        calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
    }

    private var monthlyWorkoutDays: [WorkoutDay] {
        filteredWorkoutDays.filter { $0.date >= monthStart && $0.date < monthEnd }
    }

    private var selectedWorkoutDay: WorkoutDay? {
        filteredWorkoutDays.first { DateUtilities.isSameDay($0.date, selectedDate) }
    }

    private var workoutDates: Set<Date> {
        cachedWorkoutDates
    }

    private var shouldShowAd: Bool {
        guard !(profile?.isPremiumUser ?? false) else { return false }
        guard !adManager.nativeAds.isEmpty else { return false }
        return true
    }

    private var monthSummary: WorkoutSummary {
        cachedMonthSummary
    }

    private var selectedDayStrengthSummary: WorkoutSummary? {
        guard let workoutDay = selectedWorkoutDay,
              hasRelevantCompletedSets(workoutDay) else { return nil }
        return buildWorkoutSummary(for: [workoutDay])
    }

    private var selectedDayCardioWorkouts: [CardioWorkout] {
        cardioWorkouts(for: selectedDate, workoutDayId: selectedWorkoutDay?.id)
    }

    private var selectedDayCardioExerciseCount: Int {
        Set(selectedDayCardioWorkouts.map { $0.activityType }).count
    }

    private var selectedDayCardioSetCount: Int {
        selectedDayCardioWorkouts.count
    }

    private var hasSelectedDayActivity: Bool {
        selectedDayStrengthSummary != nil || !selectedDayCardioWorkouts.isEmpty
    }

    // OPTIMIZATION: Return cached summaries instead of recalculating on every access
    private var exerciseSummaries: [ExerciseMonthlySummary] {
        cachedExerciseSummaries
    }

    // MARK: - Cardio Summary

    /// Cardio workouts for the current month
    private var monthlyCardioWorkouts: [CardioWorkout] {
        guard let profile = profile else { return [] }
        return cardioWorkouts.filter { workout in
            workout.profile?.id == profile.id &&
            workout.startDate >= monthStart &&
            workout.startDate < monthEnd
        }
    }

    /// Summary of cardio workouts for the current month
    private var cardioMonthlySummary: CardioMonthlySummary {
        cachedCardioMonthlySummary
    }

    /// Summary of cardio workouts grouped by activity type
    private var cardioActivitySummaries: [CardioActivitySummary] {
        cachedCardioActivitySummaries
    }

    /// Recalculates exercise summaries for the current month
    /// Called when month changes or when view first appears
    private func recalculateMonthlySummaries() {
        cachedMonthSummary = buildWorkoutSummary(for: monthlyWorkoutDays)

        let cardioWorkoutsForMonth = monthlyCardioWorkouts
        let totalDuration = cardioWorkoutsForMonth.reduce(0.0) { $0 + $1.duration }
        let totalDistance = cardioWorkoutsForMonth.compactMap { $0.totalDistance }.reduce(0.0, +)
        cachedCardioMonthlySummary = CardioMonthlySummary(
            sessionCount: cardioWorkoutsForMonth.count,
            totalDuration: totalDuration,
            totalDistance: totalDistance
        )

        let groupedCardio = Dictionary(grouping: cardioWorkoutsForMonth) { $0.activityType }
        cachedCardioActivitySummaries = groupedCardio.map { activityType, workouts in
            let groupedDuration = workouts.reduce(0.0) { $0 + $1.duration }
            let groupedDistance = workouts.compactMap { $0.totalDistance }.reduce(0.0, +)
            let maxHeartRate = workouts.compactMap { $0.maxHeartRate }.max()
            return CardioActivitySummary(
                activityType: activityType,
                sessionCount: workouts.count,
                totalDuration: groupedDuration,
                totalDistance: groupedDistance,
                maxHeartRate: maxHeartRate
            )
        }
        .sorted {
            if $0.sessionCount != $1.sessionCount {
                return $0.sessionCount > $1.sessionCount
            }
            return $0.activityType < $1.activityType
        }

        var dates = Set(
            filteredWorkoutDays
                .filter { hasRelevantCompletedSets($0) }
                .map { DateUtilities.startOfDay($0.date) }
        )
        if let profile = profile {
            let cardioDates = cardioWorkouts
                .filter { $0.profile?.id == profile.id && $0.isCompleted }
                .map { DateUtilities.startOfDay($0.startDate) }
            dates.formUnion(cardioDates)
        }
        cachedWorkoutDates = dates

        var accumulators: [UUID: ExerciseAccumulator] = [:]

        for workoutDay in monthlyWorkoutDays {
            let dayDate = DateUtilities.startOfDay(workoutDay.date)

            for entry in workoutDay.sortedEntries {
                let completedSets = entry.activeSets.filter { set in
                    set.isCompleted && isRelevantMetric(set.metricType)
                }

                guard !completedSets.isEmpty else { continue }

                var accumulator = accumulators[entry.exerciseId, default: ExerciseAccumulator()]
                accumulator.days.insert(dayDate)
                accumulator.sets += completedSets.count

                for set in completedSets {
                    if set.metricType == .weightReps {
                        accumulator.hasWeightReps = true
                    }

                    accumulator.volume += set.volume

                    let weight = set.weightDouble
                    let reps = set.reps ?? 0
                    let epley = WorkoutService.epleyOneRM(weight: weight, reps: reps)

                    accumulator.maxWeight = max(accumulator.maxWeight, weight)
                    accumulator.maxOneRM = max(accumulator.maxOneRM, epley)
                }

                accumulators[entry.exerciseId] = accumulator
            }
        }

        var summaries: [ExerciseMonthlySummary] = []
        for (exerciseId, accumulator) in accumulators {
            guard accumulator.hasWeightReps else { continue }
            let exercise = exercisesDict[exerciseId]
            let exerciseName = exercise?.localizedName ?? L10n.tr("unknown_exercise")

            summaries.append(
                ExerciseMonthlySummary(
                    id: exerciseId,
                    name: exerciseName,
                    bodyPartId: exercise?.bodyPartId,
                    workoutDays: accumulator.days.count,
                    sets: accumulator.sets,
                    volume: accumulator.volume,
                    maxWeight: accumulator.maxWeight,
                    maxOneRM: accumulator.maxOneRM
                )
            )
        }

        cachedExerciseSummaries = summaries.sorted { lhs, rhs in
            let lhsVolume = NSDecimalNumber(decimal: lhs.volume).doubleValue
            let rhsVolume = NSDecimalNumber(decimal: rhs.volume).doubleValue
            if lhsVolume != rhsVolume {
                return lhsVolume > rhsVolume
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection

                    calendarSection

                    daySummarySection

                    monthSummarySection

                    exerciseSummarySection

                    cardioSummarySection

                    // Bottom ad
                    if shouldShowAd {
                        NativeAdCardView(nativeAd: adManager.nativeAds[0])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: MonthNavigation.self) { nav in
                HistoryMonthDetailView(
                    monthReference: nav.month,
                    workoutDays: filteredWorkoutDays,
                    weightUnit: profile?.effectiveWeightUnit ?? .kg,
                    isPremiumUser: profile?.isPremiumUser ?? false
                )
            }
            .navigationDestination(for: UUID.self) { exerciseId in
                if let exercise = exercisesDict[exerciseId] {
                    ExerciseHistoryDetailView(
                        exercise: exercise,
                        workoutDays: filteredWorkoutDays,
                        monthReference: displayedMonth,
                        weightUnit: profile?.effectiveWeightUnit ?? .kg,
                        isPremiumUser: profile?.isPremiumUser ?? false
                    )
                }
            }
            .navigationDestination(for: DayDetailNavigation.self) { nav in
                let workoutDay = filteredWorkoutDays.first { DateUtilities.isSameDay($0.date, nav.date) }
                let cardioWorkouts = cardioWorkouts(for: nav.date, workoutDayId: workoutDay?.id)
                HistoryDayDetailView(
                    date: nav.date,
                    workoutDay: workoutDay,
                    cardioWorkouts: cardioWorkouts,
                    exercisesDict: exercisesDict,
                    bodyPartsDict: bodyPartsDict,
                    weightUnit: profile?.effectiveWeightUnit ?? .kg,
                    isPremiumUser: profile?.isPremiumUser ?? false
                )
            }
            .onAppear {
                loadProfileIfNeeded()
                // OPTIMIZATION: Refresh cached summaries on tab entry
                recalculateMonthlySummaries()
                // Load ads
                if adManager.nativeAds.isEmpty {
                    adManager.loadNativeAds(count: 1)
                }
            }
            .onChange(of: displayedMonth) { _, _ in
                // Recalculate when user navigates to a different month
                recalculateMonthlySummaries()
            }
            .onChange(of: workoutDays) { _, _ in
                // Recalculate when workout data changes (real-time sync)
                recalculateMonthlySummaries()
            }
            .onChange(of: cardioWorkouts) { _, _ in
                // Recalculate when cardio data changes (real-time sync)
                recalculateMonthlySummaries()
            }
            .alert(L10n.tr("cardio_sync_complete"), isPresented: .constant(cardioSyncResult != nil)) {
                Button(L10n.tr("ok")) {
                    cardioSyncResult = nil
                }
            } message: {
                if let result = cardioSyncResult {
                    Text(result.message)
                }
            }
            .alert(L10n.tr("cardio_health_permission_title"), isPresented: $showingCardioAuthAlert) {
                Button(L10n.tr("ok")) {}
            } message: {
                Text(L10n.tr("cardio_health_permission_message"))
            }
        }
    }
}

// MARK: - Sections

private extension HistoryView {
    var headerSection: some View {
        VStack(spacing: 6) {
            Text("history")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    var calendarSection: some View {
        let cachedWorkoutDates = workoutDates
        return VStack(spacing: 12) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        changeMonth(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textMuted)
                        .frame(width: 36, height: 36)
                }

                Spacer()

                Text(monthTitle(for: displayedMonth))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        changeMonth(by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textMuted)
                        .frame(width: 36, height: 36)
                }
            }

            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundColor(weekdayColor(for: index))
                        .frame(maxWidth: .infinity)
                }
            }

            ZStack {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                    ForEach(Array(calendarDates(for: displayedMonth).enumerated()), id: \.offset) { _, date in
                        calendarDayCell(for: date, workoutDates: cachedWorkoutDates)
                    }
                }
                .id(displayedMonth)
                .transition(monthTransition)
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    // 横スワイプのみ反応
                    if abs(horizontal) > abs(vertical) && abs(horizontal) > 50 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if horizontal > 0 {
                                changeMonth(by: -1)  // 右スワイプ→前月
                            } else {
                                changeMonth(by: 1)   // 左スワイプ→次月
                            }
                        }
                    }
                }
        )
        .animation(.easeInOut(duration: 0.2), value: displayedMonth)
    }

    var daySummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(daySummaryTitle(for: selectedDate))
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                if hasSelectedDayActivity {
                    NavigationLink(value: DayDetailNavigation(date: selectedDate)) {
                        HStack(spacing: 2) {
                            Text(L10n.tr("history_detail"))
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            if hasSelectedDayActivity {
                let strengthSummary = selectedDayStrengthSummary
                let totalExercises = (strengthSummary?.exercises ?? 0) + selectedDayCardioExerciseCount
                let totalSets = (strengthSummary?.sets ?? 0) + selectedDayCardioSetCount
                let volumeText = strengthSummary == nil && !selectedDayCardioWorkouts.isEmpty
                    ? "-"
                    : formatVolumeWithUnit(strengthSummary?.volume ?? .zero)
                Grid(horizontalSpacing: 8, verticalSpacing: 0) {
                    GridRow {
                        daySummaryCard(
                            value: "\(totalExercises)",
                            label: L10n.tr("exercises")
                        )
                        .gridCellColumns(3)

                        daySummaryCard(
                            value: "\(totalSets)",
                            label: L10n.tr("history_total_sets")
                        )
                        .gridCellColumns(3)

                        daySummaryCard(
                            value: volumeText,
                            label: L10n.tr("history_total_volume"),
                            scalable: true
                        )
                        .gridCellColumns(4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(L10n.tr("history_no_workouts_day"))
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    func daySummaryCard(value: String, label: String, scalable: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(scalable ? 1 : nil)
                .minimumScaleFactor(scalable ? 0.85 : 1.0)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(AppColors.cardBackgroundSecondary)
        .cornerRadius(10)
    }

    var monthSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(monthSummaryTitle(for: displayedMonth))
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                if monthSummary.workoutDays > 0 {
                    NavigationLink(value: MonthNavigation(month: displayedMonth)) {
                        HStack(spacing: 2) {
                            Text(L10n.tr("history_detail"))
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            if monthSummary.workoutDays == 0 {
                Text(L10n.tr("history_no_workouts_month"))
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                SummaryStatsGrid(stats: [
                    SummaryStat(title: L10n.tr("history_workout_days"), value: "\(monthSummary.workoutDays)"),
                    SummaryStat(title: L10n.tr("exercises"), value: "\(monthSummary.exercises)"),
                    SummaryStat(title: L10n.tr("history_total_sets"), value: "\(monthSummary.sets)"),
                    SummaryStat(title: L10n.tr("history_total_volume"), value: formatVolumeWithUnit(monthSummary.volume))
                ], style: .carded)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    var exerciseSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("history_exercise_summary"))
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, 4)

            if exerciseSummaries.isEmpty {
                Text(L10n.tr("history_no_workouts_month"))
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cardBackground)
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(exerciseSummaries) { summary in
                        NavigationLink(value: summary.id) {
                            exerciseSummaryRow(summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var cardioSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.tr("cardio_monthly_summary"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Button {
                    syncCardioFromHealthKit()
                } label: {
                    if isCardioSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(AppColors.textSecondary)
                .disabled(isCardioSyncing)
                .accessibilityLabel(L10n.tr("cardio_sync_health"))
            }
            .padding(.horizontal, 4)

            if cardioActivitySummaries.isEmpty {
                Text(L10n.tr("cardio_no_workouts_month"))
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cardBackground)
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(cardioActivitySummaries) { summary in
                        NavigationLink {
                            CardioHistoryView(
                                profile: profile ?? LocalProfile(),
                                activityType: summary.activityType,
                                useNavigationStack: false
                            )
                        } label: {
                            cardioActivitySummaryRow(summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Helpers

private extension HistoryView {
    var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        guard symbols.count == 7 else {
            return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        }
        return Array(symbols[1...]) + [symbols[0]]
    }

    /// Returns color for weekday label (index 0-6: Mon-Sun)
    func weekdayColor(for index: Int) -> Color {
        switch index {
        case 5: return AppColors.weekendSaturday  // Saturday
        case 6: return AppColors.weekendSunday    // Sunday
        default: return AppColors.textSecondary
        }
    }

    func loadProfileIfNeeded() {
        guard profile == nil else { return }
        let loadedProfile = ProfileService.getOrCreateProfile(modelContext: modelContext)
        profile = loadedProfile

        let today = DateUtilities.todayWorkoutDate(transitionHour: loadedProfile.dayTransitionHour)
        displayedMonth = DateUtilities.startOfMonth(for: today)
        selectedDate = DateUtilities.startOfDay(today)
    }

    func monthTitle(for date: Date) -> String {
        Formatters.yearMonth.string(from: date)
    }

    func syncCardioFromHealthKit() {
        guard !isCardioSyncing else { return }
        guard HealthKitService.isHealthKitAvailable else {
            cardioSyncResult = CardioSyncResult(message: L10n.tr("cardio_health_not_available"))
            return
        }

        let activeProfile: LocalProfile
        if let profile = profile {
            activeProfile = profile
        } else {
            let loadedProfile = ProfileService.getOrCreateProfile(modelContext: modelContext)
            profile = loadedProfile
            activeProfile = loadedProfile
        }

        isCardioSyncing = true

        Task {
            let authorized = await HealthKitService.requestAuthorization()

            guard authorized else {
                await MainActor.run {
                    isCardioSyncing = false
                    showingCardioAuthAlert = true
                }
                return
            }

            do {
                let count = try await HealthKitService.syncRecentWorkouts(
                    profile: activeProfile,
                    modelContext: modelContext
                )

                await MainActor.run {
                    isCardioSyncing = false
                    if count > 0 {
                        cardioSyncResult = CardioSyncResult(
                            message: L10n.tr("cardio_sync_imported", count)
                        )
                    } else {
                        cardioSyncResult = CardioSyncResult(
                            message: L10n.tr("cardio_sync_no_new")
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isCardioSyncing = false
                    cardioSyncResult = CardioSyncResult(
                        message: L10n.tr("cardio_sync_error", error.localizedDescription)
                    )
                }
            }
        }
    }

    func changeMonth(by offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        monthTransitionDirection = offset
        displayedMonth = DateUtilities.startOfMonth(for: newMonth)
        selectedDate = displayedMonth
    }

    func changeWeek(by offset: Int) {
        guard let newDate = calendar.date(byAdding: .day, value: offset * 7, to: selectedDate) else { return }
        selectedDate = DateUtilities.startOfDay(newDate)
        displayedMonth = DateUtilities.startOfMonth(for: newDate)
    }

    private var monthTransition: AnyTransition {
        if monthTransitionDirection > 0 {
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        }
        if monthTransitionDirection < 0 {
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
        return .opacity
    }

    func calendarDates(for month: Date) -> [Date?] {
        let monthStart = DateUtilities.startOfMonth(for: month)
        guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptyCount = (firstWeekday - calendar.firstWeekday + 7) % 7

        var dates: [Date?] = Array(repeating: nil, count: leadingEmptyCount)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                dates.append(date)
            }
        }

        while dates.count % 7 != 0 {
            dates.append(nil)
        }

        return dates
    }

    func weekDates(for date: Date) -> [Date?] {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start else {
            return [date]
        }
        return (0..<7).map { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
    }

    func calendarDayCell(for date: Date?, workoutDates: Set<Date>) -> some View {
        Group {
            if let date = date {
                let isSelected = DateUtilities.isSameDay(date, selectedDate)
                let isToday = DateUtilities.isToday(date)
                let dayNumber = calendar.component(.day, from: date)
                let hasWorkout = workoutDates.contains(DateUtilities.startOfDay(date))

                VStack(spacing: 4) {
                    Text("\(dayNumber)")
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? AppColors.accentBlue.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isSelected ? AppColors.accentBlue.opacity(0.8) :
                                        (isToday ? AppColors.accentBlue.opacity(0.35) : Color.clear),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )

                    Circle()
                        .fill(hasWorkout ? AppColors.accentBlue : Color.clear)
                        .frame(width: 5, height: 5)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDate = DateUtilities.startOfDay(date)
                    if !calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
                        displayedMonth = DateUtilities.startOfMonth(for: date)
                    }
                }
            } else {
                Color.clear
                    .frame(height: 36)
            }
        }
    }

    /// Current weight unit from profile
    private var currentWeightUnit: WeightUnit {
        profile?.effectiveWeightUnit ?? .kg
    }

    /// Current weight unit symbol from profile
    private var weightUnitSymbol: String {
        currentWeightUnit.symbol
    }

    func formatVolume(_ volume: Decimal) -> String {
        let value = NSDecimalNumber(decimal: volume).doubleValue
        return Formatters.formatWeight(value)
    }

    func daySummaryTitle(for date: Date) -> String {
        L10n.tr("history_day_summary_with_date", formatDaySummaryDate(date))
    }

    func monthSummaryTitle(for date: Date) -> String {
        L10n.tr("history_month_summary_with_date", formatMonthSummaryDate(date))
    }

    func formatDaySummaryDate(_ date: Date) -> String {
        Formatters.yearMonthDay.string(from: date)
    }

    func formatMonthSummaryDate(_ date: Date) -> String {
        Formatters.yearMonthShort.string(from: date)
    }

    /// ボリュームを単位付きでフォーマット（自動スケーリング対応）
    func formatVolumeWithUnit(_ volume: Decimal) -> String {
        VolumeFormatter.format(volume, weightUnit: currentWeightUnit)
    }

    private func cardioWorkouts(for date: Date, workoutDayId: UUID?) -> [CardioWorkout] {
        guard let profile = profile else { return [] }
        return cardioWorkouts
            .filter { workout in
                guard workout.profile?.id == profile.id else { return false }
                guard workout.isCompleted else { return false }
                if let workoutDayId = workoutDayId, workout.workoutDayId == workoutDayId {
                    return true
                }
                return workout.workoutDayId == nil && DateUtilities.isSameDay(workout.startDate, date)
            }
            .sorted { $0.startDate < $1.startDate }
    }

    func cardioActivitySummaryRow(_ summary: CardioActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 1行目: アクティビティ名 + アイコン
            HStack(spacing: 8) {
                Image(systemName: summary.activityIcon)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accentBlue)
                    .frame(width: 20)

                Text(summary.activityName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            // 2行目: セッション数
            Text(L10n.tr("cardio_total_sessions", summary.sessionCount))
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            // 3行目: 指標チップ（時間 / 距離）
            HStack(spacing: 8) {
                metricChip(
                    value: summary.formattedDuration,
                    label: L10n.tr("cardio_duration")
                )

                if let distance = summary.formattedDistance {
                    metricChip(
                        value: distance,
                        label: L10n.tr("cardio_distance")
                    )
                }

                if let maxHeartRate = summary.formattedMaxHeartRate {
                    metricChip(
                        value: maxHeartRate,
                        label: L10n.tr("cardio_max_heart_rate_label")
                    )
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    func exerciseSummaryRow(_ summary: ExerciseMonthlySummary) -> some View {
        let bodyPartColor = summary.bodyPartId
            .flatMap { bodyPartsDict[$0]?.color } ?? AppColors.textMuted

        return VStack(alignment: .leading, spacing: 8) {
            // 1行目: 種目名（主役）+ BodyPartドット
            HStack(spacing: 6) {
                Circle()
                    .fill(bodyPartColor.opacity(0.8))
                    .frame(width: 6, height: 6)

                Text(summary.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            // 2行目: ワークアウト日数 / セット数（補助）
            Text("\(summary.workoutDays) \(L10n.tr("history_workout_days")) / \(summary.sets) \(L10n.tr("sets"))")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            // 3行目: 指標チップ（横並び）
            HStack(spacing: 8) {
                metricChip(
                    value: formatVolumeWithUnit(summary.volume),
                    label: L10n.tr("history_total_volume")
                )

                metricChip(
                    value: "\(Formatters.formatWeight(summary.maxWeight))\(weightUnitSymbol)",
                    label: L10n.tr("history_max_weight")
                )

                metricChip(
                    value: "\(Formatters.formatWeight(summary.maxOneRM))\(weightUnitSymbol)",
                    label: L10n.tr("history_estimated_1rm")
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    func metricChip(value: String, label: String) -> some View {
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
}

// MARK: - Detail View

private struct HistoryMonthDetailView: View {
    private struct WeekVolumeSummary: Identifiable {
        let startDate: Date
        let endDate: Date
        let volume: Decimal
        let workoutDays: Int
        let label: String
        let trendText: String?

        var id: Date { startDate }
        var volumeDouble: Double { NSDecimalNumber(decimal: volume).doubleValue }
    }

    private struct WeekdayAverage: Identifiable {
        let index: Int
        let label: String
        let averageVolume: Decimal
        let workoutDays: Int

        var id: Int { index }
        var averageVolumeDouble: Double { NSDecimalNumber(decimal: averageVolume).doubleValue }
    }

    let monthReference: Date
    let workoutDays: [WorkoutDay]
    var weightUnit: WeightUnit = .kg
    var isPremiumUser: Bool = false

    @StateObject private var adManager = NativeAdManager()

    private let barHeight: CGFloat = 6
    private let weekLabelColumnWidth: CGFloat = 72
    private let weekdayLabelColumnWidth: CGFloat = 28
    private let valueColumnWidth: CGFloat = 96

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    private var monthStart: Date {
        DateUtilities.startOfMonth(for: monthReference)
    }

    private var monthEnd: Date {
        calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
    }

    private var monthlyWorkoutDays: [WorkoutDay] {
        workoutDays.filter { $0.date >= monthStart && $0.date < monthEnd }
    }

    private var relevantWorkoutDays: [WorkoutDay] {
        monthlyWorkoutDays.filter { hasRelevantCompletedSets($0) }
    }

    private var monthSummary: WorkoutSummary {
        buildWorkoutSummary(for: monthlyWorkoutDays)
    }

    private var weeklyVolumeSummaries: [WeekVolumeSummary] {
        let firstWeekStart = DateUtilities.startOfWeekMonday(containing: monthStart) ?? monthStart
        var weekStarts: [Date] = []
        var currentStart = firstWeekStart

        while currentStart < monthEnd {
            weekStarts.append(currentStart)
            guard let nextStart = calendar.date(byAdding: .day, value: 7, to: currentStart) else { break }
            currentStart = nextStart
        }

        var summaries: [WeekVolumeSummary] = []
        for weekStart in weekStarts {
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            let days = relevantWorkoutDays.filter { workoutDay in
                workoutDay.date >= weekStart && workoutDay.date <= weekEnd
            }
            let totalVolume = days.reduce(Decimal.zero) { $0 + $1.totalVolume }
            let currentVolume = NSDecimalNumber(decimal: totalVolume).doubleValue
            let previousVolume = summaries.last?.volumeDouble ?? 0
            let trendText = weekOverWeekChangeText(
                currentVolume: currentVolume,
                previousVolume: previousVolume,
                hasWorkouts: !days.isEmpty
            )

            summaries.append(
                WeekVolumeSummary(
                    startDate: weekStart,
                    endDate: weekEnd,
                    volume: totalVolume,
                    workoutDays: days.count,
                    label: formatWeekRange(startDate: weekStart, endDate: weekEnd),
                    trendText: trendText
                )
            )
        }

        return summaries
    }

    private var weekdayAverages: [WeekdayAverage] {
        var totals = Array(repeating: Decimal.zero, count: 7)
        var counts = Array(repeating: 0, count: 7)

        for workoutDay in relevantWorkoutDays {
            let index = DateUtilities.weekdayIndex(for: workoutDay.date)
            totals[index] += workoutDay.totalVolume
            counts[index] += 1
        }

        return (0..<7).map { index in
            let count = counts[index]
            let average = count > 0 ? totals[index] / Decimal(count) : Decimal.zero
            return WeekdayAverage(
                index: index,
                label: weekdaySymbols[index],
                averageVolume: average,
                workoutDays: count
            )
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        guard symbols.count == 7 else {
            return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        }
        return Array(symbols[1...]) + [symbols[0]]
    }

    private var shouldShowAd: Bool {
        guard !isPremiumUser else { return false }
        guard !adManager.nativeAds.isEmpty else { return false }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if monthSummary.workoutDays == 0 {
                    Text(L10n.tr("history_no_workouts_month"))
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    summarySection
                    weeklyVolumeSection
                    weekdayAverageSection
                }

                // Bottom ad
                if shouldShowAd {
                    NativeAdCardView(nativeAd: adManager.nativeAds[0])
                }
            }
            .padding()
        }
        .background(AppColors.background)
        .navigationTitle(formatMonthTitle(monthReference))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if adManager.nativeAds.isEmpty {
                adManager.loadNativeAds(count: 1)
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("history_summary"))
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            SummaryStatsGrid(stats: [
                SummaryStat(title: L10n.tr("history_workout_days"), value: "\(monthSummary.workoutDays)"),
                SummaryStat(title: L10n.tr("exercises"), value: "\(monthSummary.exercises)"),
                SummaryStat(title: L10n.tr("history_total_sets"), value: "\(monthSummary.sets)"),
                SummaryStat(title: L10n.tr("history_total_volume"), value: formatVolumeWithUnit(monthSummary.volume))
            ], style: .carded)

            SummaryStatsGrid(stats: [
                SummaryStat(
                    title: L10n.tr("history_weekly_avg_workouts"),
                    value: weeklyAverageWorkoutsText
                ),
                SummaryStat(
                    title: L10n.tr("history_avg_volume_per_workout"),
                    value: averageVolumePerWorkoutText
                )
            ], style: .carded)
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    private var weeklyVolumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("history_weekly_total_volume"))
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            let maxVolume = weeklyVolumeSummaries.map(\.volumeDouble).max() ?? 0
            let scaleMax = max(1, maxVolume)
            VStack(spacing: 10) {
                ForEach(weeklyVolumeSummaries) { summary in
                    let volumeText = formatVolumeWithUnit(summary.volume)
                    let valueText = summary.workoutDays == 0
                        ? "-"
                        : (summary.trendText != nil ? "\(volumeText) \(summary.trendText!)" : volumeText)

                    barRow(
                        label: summary.label,
                        valueText: valueText,
                        valueDouble: summary.workoutDays == 0 ? 0 : summary.volumeDouble,
                        maxValue: scaleMax,
                        barColor: AppColors.accentBlue,
                        labelWidth: weekLabelColumnWidth,
                        rowSpacing: 8,
                        labelColor: AppColors.textSecondary
                    )
                }
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    private var weekdayAverageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("history_weekday_average_volume"))
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            let maxAverage = weekdayAverages.map(\.averageVolumeDouble).max() ?? 0
            let scaleMax = max(1, maxAverage)
            VStack(spacing: 10) {
                ForEach(weekdayAverages) { average in
                    barRow(
                        label: average.label,
                        valueText: average.workoutDays == 0 ? "-" : formatVolumeWithUnit(average.averageVolume),
                        valueDouble: average.workoutDays == 0 ? 0 : average.averageVolumeDouble,
                        maxValue: scaleMax,
                        barColor: AppColors.mutedBlue,
                        labelWidth: weekdayLabelColumnWidth,
                        rowSpacing: 4,
                        labelColor: AppColors.textSecondary
                    )
                }
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    private func barRow(
        label: String,
        valueText: String,
        valueDouble: Double,
        maxValue: Double,
        barColor: Color,
        labelWidth: CGFloat,
        rowSpacing: CGFloat,
        labelColor: Color
    ) -> some View {
        HStack(spacing: rowSpacing) {
            Text(label)
                .font(.caption)
                .foregroundColor(labelColor)
                .frame(width: labelWidth, alignment: .leading)
                .lineLimit(1)

            GeometryReader { proxy in
                let availableWidth = proxy.size.width
                let ratio = maxValue > 0 ? valueDouble / maxValue : 0
                let barWidth = max(0, min(availableWidth, availableWidth * ratio))

                if valueDouble > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor)
                        .frame(width: barWidth, height: barHeight)
                } else {
                    Color.clear
                        .frame(height: barHeight)
                }
            }
            .frame(height: barHeight)

            Text(valueText)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: valueColumnWidth, alignment: .trailing)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weeklyAverageWorkoutsText: String {
        let weekCount = weeklyVolumeSummaries.count
        guard weekCount > 0 else { return "-" }
        let average = Double(monthSummary.workoutDays) / Double(weekCount)
        return formatAverageCount(average)
    }

    private var averageVolumePerWorkoutText: String {
        guard monthSummary.workoutDays > 0 else { return "-" }
        let average = monthSummary.volume / Decimal(monthSummary.workoutDays)
        return formatVolumeWithUnit(average)
    }

    private func weekOverWeekChangeText(
        currentVolume: Double,
        previousVolume: Double,
        hasWorkouts: Bool
    ) -> String? {
        guard hasWorkouts, previousVolume > 0 else { return nil }

        let change = ((currentVolume - previousVolume) / previousVolume) * 100
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(formatPercent(change))%"
    }

    private func formatAverageCount(_ value: Double) -> String {
        Formatters.decimal1.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    private func formatPercent(_ value: Double) -> String {
        Formatters.decimal0.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    private func formatWeekRange(startDate: Date, endDate: Date) -> String {
        let rangeStart = max(startDate, monthStart)
        let lastDay = calendar.date(byAdding: .day, value: -1, to: monthEnd) ?? monthEnd
        let rangeEnd = min(endDate, lastDay)
        return "\(Formatters.monthDay.string(from: rangeStart))-\(Formatters.monthDay.string(from: rangeEnd))"
    }

    private func formatMonthTitle(_ date: Date) -> String {
        Formatters.yearMonthShort.string(from: date)
    }

    private func formatVolumeWithUnit(_ volume: Decimal) -> String {
        VolumeFormatter.format(volume, weightUnit: weightUnit)
    }

}

private struct ExerciseHistoryDetailView: View {
    private enum HistoryRange: String, CaseIterable, Identifiable {
        case month
        case year
        case all

        var id: String { rawValue }
    }

    let exercise: Exercise
    let workoutDays: [WorkoutDay]
    let monthReference: Date
    var weightUnit: WeightUnit = .kg
    var isPremiumUser: Bool = false

    @StateObject private var adManager = NativeAdManager()
    @State private var range: HistoryRange = .month
    @State private var selectedDate: Date = Date()

    private var calendar: Calendar {
        Calendar.current
    }

    private var filteredWorkoutDays: [WorkoutDay] {
        switch range {
        case .month:
            let start = DateUtilities.startOfMonth(for: selectedDate)
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            return workoutDays.filter { $0.date >= start && $0.date < end }
        case .year:
            let start = startOfYear(for: selectedDate)
            let end = calendar.date(byAdding: .year, value: 1, to: start) ?? start
            return workoutDays.filter { $0.date >= start && $0.date < end }
        case .all:
            return workoutDays
        }
    }

    // All-time points for PR calculation
    private var allTimePoints: [ExerciseHistoryPoint] {
        var data: [ExerciseHistoryPoint] = []
        for workoutDay in workoutDays {
            var maxWeight = 0.0
            var maxOneRM = 0.0
            var setsCount = 0
            var totalVolume = 0.0

            for entry in workoutDay.sortedEntries where entry.exerciseId == exercise.id {
                let completedSets = entry.activeSets.filter { set in
                    set.isCompleted && (set.metricType == .weightReps || set.metricType == .bodyweightReps)
                }
                guard !completedSets.isEmpty else { continue }
                setsCount += completedSets.count

                for set in completedSets {
                    let weight = set.weightDouble
                    let reps = set.reps ?? 0
                    maxWeight = max(maxWeight, weight)
                    maxOneRM = max(maxOneRM, WorkoutService.epleyOneRM(weight: weight, reps: reps))
                    totalVolume += weight * Double(reps)
                }
            }

            if setsCount > 0 {
                data.append(
                    ExerciseHistoryPoint(
                        date: workoutDay.date,
                        maxWeight: maxWeight,
                        maxOneRM: maxOneRM,
                        sets: setsCount,
                        volume: totalVolume
                    )
                )
            }
        }
        return data.sorted { $0.date < $1.date }
    }

    // Personal Records (all-time) - computed from cached allTimePoints
    private func prMaxWeight(from points: [ExerciseHistoryPoint]) -> Double {
        points.map(\.maxWeight).max() ?? 0
    }

    private func prMaxOneRM(from points: [ExerciseHistoryPoint]) -> Double {
        points.map(\.maxOneRM).max() ?? 0
    }

    private func prMaxVolume(from points: [ExerciseHistoryPoint]) -> Double {
        points.map(\.volume).max() ?? 0
    }

    private var points: [ExerciseHistoryPoint] {
        var data: [ExerciseHistoryPoint] = []

        for workoutDay in filteredWorkoutDays {
            var maxWeight = 0.0
            var maxOneRM = 0.0
            var setsCount = 0
            var totalVolume = 0.0

            for entry in workoutDay.sortedEntries where entry.exerciseId == exercise.id {
                let completedSets = entry.activeSets.filter { set in
                    set.isCompleted && (set.metricType == .weightReps || set.metricType == .bodyweightReps)
                }

                guard !completedSets.isEmpty else { continue }
                setsCount += completedSets.count

                for set in completedSets {
                    let weight = set.weightDouble
                    let reps = set.reps ?? 0
                    maxWeight = max(maxWeight, weight)
                    maxOneRM = max(maxOneRM, WorkoutService.epleyOneRM(weight: weight, reps: reps))
                    totalVolume += weight * Double(reps)
                }
            }

            if setsCount > 0 {
                data.append(
                    ExerciseHistoryPoint(
                        date: workoutDay.date,
                        maxWeight: maxWeight,
                        maxOneRM: maxOneRM,
                        sets: setsCount,
                        volume: totalVolume
                    )
                )
            }
        }

        return data.sorted { $0.date < $1.date }
    }

    // Progress calculation - computed from cached points
    private func progressInfo(from cachedPoints: [ExerciseHistoryPoint]) -> (startOneRM: Double, endOneRM: Double, startWeight: Double, endWeight: Double, startVolume: Double, endVolume: Double)? {
        guard cachedPoints.count >= 2 else { return nil }
        let sorted = cachedPoints.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return nil }
        return (first.maxOneRM, last.maxOneRM, first.maxWeight, last.maxWeight, first.volume, last.volume)
    }

    var body: some View {
        // Cache expensive computed properties once per render
        let cachedAllTimePoints = allTimePoints
        let cachedPoints = points
        let cachedPrMaxWeight = prMaxWeight(from: cachedAllTimePoints)
        let cachedPrMaxOneRM = prMaxOneRM(from: cachedAllTimePoints)
        let cachedPrMaxVolume = prMaxVolume(from: cachedAllTimePoints)
        let cachedProgressInfo = progressInfo(from: cachedPoints)

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Range picker
                Picker(L10n.tr("history_range_month"), selection: $range) {
                    Text(L10n.tr("history_range_month")).tag(HistoryRange.month)
                    Text(L10n.tr("history_range_year")).tag(HistoryRange.year)
                    Text(L10n.tr("history_range_all")).tag(HistoryRange.all)
                }
                .pickerStyle(.segmented)

                // Period navigation (hidden for "all" range)
                if range != .all {
                    periodNavigationView
                }

                // Personal Records section (all-time)
                if !cachedAllTimePoints.isEmpty {
                    prSection(maxWeight: cachedPrMaxWeight, maxOneRM: cachedPrMaxOneRM, maxVolume: cachedPrMaxVolume)
                }

                // Progress section (for selected period)
                if let progress = cachedProgressInfo {
                    progressSection(progress)
                }

                if cachedPoints.isEmpty {
                    Text(L10n.tr("history_no_workouts_month"))
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Chart section
                    VStack(alignment: .leading, spacing: 12) {
                        chartLegend

                        let chartPoints = cachedPoints.sorted { $0.date < $1.date }
                        let showLines = chartPoints.count > 1
                        Chart {
                            ForEach(chartPoints) { point in
                                // 1RM series (blue)
                                if showLines {
                                    LineMark(
                                        x: .value("Date", point.date),
                                        y: .value("Value", point.maxOneRM),
                                        series: .value("Series", "1RM")
                                    )
                                    .foregroundStyle(AppColors.accentBlue)
                                    .interpolationMethod(.linear)
                                }

                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Value", point.maxOneRM)
                                )
                                .foregroundStyle(AppColors.accentBlue)
                                .symbolSize(16)

                                // Max Weight series (gray)
                                if showLines {
                                    LineMark(
                                        x: .value("Date", point.date),
                                        y: .value("Value", point.maxWeight),
                                        series: .value("Series", "MaxWeight")
                                    )
                                    .foregroundStyle(AppColors.textSecondary)
                                    .interpolationMethod(.linear)
                                }

                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Value", point.maxWeight)
                                )
                                .foregroundStyle(AppColors.textSecondary)
                                .symbolSize(16)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: axisStrideComponent, count: axisStrideCount)) { value in
                                AxisGridLine()
                                    .foregroundStyle(AppColors.divider.opacity(0.3))
                                AxisTick()
                                    .foregroundStyle(AppColors.divider.opacity(0.6))
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(date, format: axisLabelFormat)
                                    }
                                }
                                .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        .chartLegend(.hidden)
                        .frame(height: 200)
                    }
                    .padding(12)
                    .background(AppColors.cardBackground)
                    .cornerRadius(12)

                    // Session list (table format with sticky header)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(L10n.tr("history_session_list"))
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                        ScrollView {
                            let sortedPoints = cachedPoints.sorted { $0.date > $1.date }
                            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                                Section {
                                    ForEach(sortedPoints) { point in
                                        sessionTableRow(point)
                                        if point.id != sortedPoints.last?.id {
                                            Divider()
                                                .background(AppColors.divider.opacity(0.3))
                                        }
                                    }
                                } header: {
                                    sessionTableHeader()
                                }
                            }
                        }
                        .frame(maxHeight: 250)
                        .padding(.bottom, 12)
                    }
                    .background(AppColors.cardBackground)
                    .cornerRadius(12)
                }

                // Bottom ad
                if shouldShowAd {
                    NativeAdCardView(nativeAd: adManager.nativeAds[0])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppColors.background)
        .navigationTitle(exercise.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedDate = monthReference
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
}

private extension ExerciseHistoryDetailView {
    func startOfYear(for date: Date) -> Date {
        let components = calendar.dateComponents([.year], from: date)
        return calendar.date(from: components) ?? date
    }

    var chartLegend: some View {
        HStack(spacing: 12) {
            legendItem(color: AppColors.accentBlue, label: L10n.tr("history_estimated_1rm"))
            legendItem(color: AppColors.textSecondary, label: L10n.tr("history_max_weight"))
        }
        .font(.caption2)
    }

    private var axisStrideComponent: Calendar.Component {
        switch range {
        case .month:
            return .day
        case .year, .all:
            return .month
        }
    }

    private var axisStrideCount: Int {
        switch range {
        case .month:
            return 7
        case .year:
            return 1
        case .all:
            return 3
        }
    }

    private var axisLabelFormat: Date.FormatStyle {
        switch range {
        case .month:
            return .dateTime.month().day()
        case .year:
            return .dateTime.month(.abbreviated)
        case .all:
            return .dateTime.year().month(.abbreviated)
        }
    }

    func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Period Navigation

    var periodNavigationView: some View {
        HStack {
            Button {
                navigatePeriod(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.medium))
                    .foregroundColor(AppColors.accentBlue)
            }

            Spacer()

            Text(periodLabel)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Button {
                navigatePeriod(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.medium))
                    .foregroundColor(canNavigateForward ? AppColors.accentBlue : AppColors.textMuted)
            }
            .disabled(!canNavigateForward)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
        .cornerRadius(10)
    }

    private var periodLabel: String {
        switch range {
        case .month:
            return Formatters.yearMonthShort.string(from: selectedDate)
        case .year:
            return Formatters.year.string(from: selectedDate)
        case .all:
            return ""
        }
    }

    private var canNavigateForward: Bool {
        let now = Date()
        switch range {
        case .month:
            return DateUtilities.startOfMonth(for: selectedDate) < DateUtilities.startOfMonth(for: now)
        case .year:
            return startOfYear(for: selectedDate) < startOfYear(for: now)
        case .all:
            return false
        }
    }

    private func navigatePeriod(by value: Int) {
        let component: Calendar.Component = range == .month ? .month : .year
        if let newDate = calendar.date(byAdding: component, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }

    // MARK: - PR Section

    func prSection(maxWeight: Double, maxOneRM: Double, maxVolume: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.tr("history_personal_records"))
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text(L10n.tr("history_all_time"))
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }

            HStack(spacing: 12) {
                prStatItem(
                    title: L10n.tr("history_max_weight"),
                    value: "\(Formatters.formatWeight(maxWeight))\(weightUnit.symbol)"
                )

                prStatItem(
                    title: L10n.tr("history_estimated_1rm"),
                    value: "\(Formatters.formatWeight(maxOneRM))\(weightUnit.symbol)"
                )

                prStatItem(
                    title: L10n.tr("history_max_volume"),
                    value: "\(Formatters.formatWeight(maxVolume))\(weightUnit.symbol)"
                )
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    private func prStatItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary)
            Text(title)
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

    // MARK: - Progress Section

    func progressSection(_ progress: (startOneRM: Double, endOneRM: Double, startWeight: Double, endWeight: Double, startVolume: Double, endVolume: Double)) -> some View {
        let oneRMChange = progress.endOneRM - progress.startOneRM
        let oneRMPercent = progress.startOneRM > 0 ? (oneRMChange / progress.startOneRM) * 100 : 0
        let weightChange = progress.endWeight - progress.startWeight
        let weightPercent = progress.startWeight > 0 ? (weightChange / progress.startWeight) * 100 : 0
        let volumeChange = progress.endVolume - progress.startVolume
        let volumePercent = progress.startVolume > 0 ? (volumeChange / progress.startVolume) * 100 : 0

        return VStack(alignment: .leading, spacing: 10) {
            Text(progressSectionTitle)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: 8) {
                progressChip(
                    label: L10n.tr("history_estimated_1rm"),
                    startValue: progress.startOneRM,
                    endValue: progress.endOneRM,
                    change: oneRMChange,
                    percent: oneRMPercent
                )

                progressChip(
                    label: L10n.tr("history_max_weight"),
                    startValue: progress.startWeight,
                    endValue: progress.endWeight,
                    change: weightChange,
                    percent: weightPercent
                )

                progressChip(
                    label: L10n.tr("history_total_volume"),
                    startValue: progress.startVolume,
                    endValue: progress.endVolume,
                    change: volumeChange,
                    percent: volumePercent
                )
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }

    private var progressSectionTitle: String {
        switch range {
        case .month:
            return L10n.tr("history_progress_this_month")
        case .year:
            return L10n.tr("history_progress_this_year")
        case .all:
            return L10n.tr("history_progress_all_time")
        }
    }

    private func progressChip(
        label: String,
        startValue: Double,
        endValue: Double,
        change: Double,
        percent: Double
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Text("\(Formatters.formatWeight(startValue))")
                    .font(.caption2)
                    .foregroundColor(AppColors.textMuted)

                Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundColor(AppColors.textMuted)

                Text("\(Formatters.formatWeight(endValue))\(weightUnit.symbol)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(formatChange(change, percent: percent))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(change >= 0 ? Color.green : Color.red)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(AppColors.cardBackgroundSecondary)
        )
    }

    private func formatChange(_ change: Double, percent: Double) -> String {
        let sign = change >= 0 ? "+" : ""
        let percentStr = String(format: "%.0f", abs(percent))
        return "\(sign)\(percentStr)%"
    }

    func sessionTableHeader() -> some View {
        HStack {
            Text(L10n.tr("history_date"))
                .frame(width: 70, alignment: .leading)
            Text(L10n.tr("history_max_weight"))
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(L10n.tr("history_estimated_1rm"))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption2)
        .foregroundColor(AppColors.textMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.cardBackground)
    }

    func sessionTableRow(_ point: ExerciseHistoryPoint) -> some View {
        HStack {
            Text(DateUtilities.formatShort(point.date))
                .frame(width: 70, alignment: .leading)
            Text("\(Formatters.formatWeight(point.maxWeight))\(weightUnit.symbol)")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("\(Formatters.formatWeight(point.maxOneRM))\(weightUnit.symbol)")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption)
        .foregroundColor(AppColors.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Supporting Types

private struct WorkoutSummary {
    let workoutDays: Int
    let exercises: Int
    let sets: Int
    let volume: Decimal
}

private struct CardioSyncResult {
    let message: String
}

private struct CardioMonthlySummary {
    let sessionCount: Int
    let totalDuration: Double  // seconds
    let totalDistance: Double  // meters

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var formattedDistance: String {
        let km = totalDistance / 1000.0
        return String(format: "%.1f km", km)
    }
}

private struct CardioActivitySummary: Identifiable {
    let activityType: Int
    let sessionCount: Int
    let totalDuration: Double  // seconds
    let totalDistance: Double  // meters
    let maxHeartRate: Double?

    var id: Int { activityType }

    var activityName: String {
        guard let type = HKWorkoutActivityType(rawValue: UInt(activityType)) else {
            return L10n.tr("cardio_other")
        }
        return type.displayName
    }

    var activityIcon: String {
        guard let type = HKWorkoutActivityType(rawValue: UInt(activityType)) else {
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
        case .boxing, .kickboxing: return "figure.boxing"
        case .martialArts: return "figure.martial.arts"
        default: return "figure.mixed.cardio"
        }
    }

    var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var formattedDistance: String? {
        guard totalDistance > 0 else { return nil }
        let km = totalDistance / 1000.0
        return String(format: "%.1f km", km)
    }

    var formattedMaxHeartRate: String? {
        guard let maxHeartRate, maxHeartRate > 0 else { return nil }
        return String(format: "%.0f bpm", maxHeartRate)
    }
}

private struct ExerciseMonthlySummary: Identifiable {
    let id: UUID
    let name: String
    let bodyPartId: UUID?
    let workoutDays: Int
    let sets: Int
    let volume: Decimal
    let maxWeight: Double
    let maxOneRM: Double
}

private struct ExerciseAccumulator {
    var days: Set<Date> = []
    var sets: Int = 0
    var volume: Decimal = .zero
    var maxWeight: Double = 0
    var maxOneRM: Double = 0
    var hasWeightReps: Bool = false
}

private struct ExerciseHistoryPoint: Identifiable {
    let id = UUID()
    let date: Date
    let maxWeight: Double
    let maxOneRM: Double
    let sets: Int
    var volume: Double = 0
}

private struct SummaryStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

private struct SummaryStatsGrid: View {
    enum Style {
        case plain
        case carded
    }

    let stats: [SummaryStat]
    var style: Style = .plain

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 3) {
                    Text(stat.value)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    Text(stat.title)
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(style == .carded ? 8 : 0)
                .background(
                    style == .carded
                        ? RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.cardBackgroundSecondary)
                        : nil
                )
            }
        }
    }
}

// MARK: - Shared Workout Summary Helpers

/// Checks if the metric type is relevant for workout statistics (weight/bodyweight reps).
private func isRelevantMetric(_ metricType: SetMetricType) -> Bool {
    metricType == .weightReps || metricType == .bodyweightReps
}

/// Checks if a workout day has any completed sets with relevant metrics.
private func hasRelevantCompletedSets(_ workoutDay: WorkoutDay) -> Bool {
    workoutDay.sortedEntries.contains { entry in
        entry.activeSets.contains { set in
            set.isCompleted && isRelevantMetric(set.metricType)
        }
    }
}

/// Builds a workout summary from a list of workout days.
private func buildWorkoutSummary(for workoutDays: [WorkoutDay]) -> WorkoutSummary {
    var workoutCount = 0
    var exerciseIds: Set<UUID> = []
    var totalSets = 0
    var totalVolume = Decimal.zero

    for workoutDay in workoutDays {
        var hasWorkout = false

        for entry in workoutDay.sortedEntries {
            let completedSets = entry.activeSets.filter { set in
                set.isCompleted && isRelevantMetric(set.metricType)
            }

            guard !completedSets.isEmpty else { continue }

            hasWorkout = true
            exerciseIds.insert(entry.exerciseId)
            totalSets += completedSets.count
            totalVolume += completedSets.reduce(Decimal.zero) { $0 + $1.volume }
        }

        if hasWorkout {
            workoutCount += 1
        }
    }

    return WorkoutSummary(
        workoutDays: workoutCount,
        exercises: exerciseIds.count,
        sets: totalSets,
        volume: totalVolume
    )
}

#Preview {
    HistoryView()
        .preferredColorScheme(.dark)
}
