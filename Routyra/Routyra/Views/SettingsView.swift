//
//  SettingsView.swift
//  Routyra
//

import SwiftUI
import SwiftData
import StoreKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutDays: [WorkoutDay]
    @Query private var workoutPlans: [WorkoutPlan]
    @Query private var planCycles: [PlanCycle]
    @Query private var exercises: [Exercise]
    @Query private var bodyParts: [BodyPart]

    @State private var profile: LocalProfile?
    @StateObject private var storeKitManager = StoreKitManager.shared

    @State private var showingDeleteConfirmation = false
    @State private var showingRestoreResult = false
    @State private var restoreResultMessage = ""

    // Language-based URLs
    private var privacyPolicyURL: URL {
        let preferredLanguage = Locale.preferredLanguages.first ?? ""
        let urlString: String
        if preferredLanguage.hasPrefix("ja") {
            urlString = "https://routyra-policy.pages.dev/privacy-policy-ja"
        } else {
            urlString = "https://routyra-policy.pages.dev/privacy-policy-en"
        }
        return URL(string: urlString)!
    }

    private var termsOfServiceURL: URL {
        let preferredLanguage = Locale.preferredLanguages.first ?? ""
        let urlString: String
        if preferredLanguage.hasPrefix("ja") {
            urlString = "https://routyra-policy.pages.dev/terms-of-service-ja"
        } else {
            urlString = "https://routyra-policy.pages.dev/terms-of-service-en"
        }
        return URL(string: urlString)!
    }

    private var feedbackURL: URL {
        let preferredLanguage = Locale.preferredLanguages.first ?? ""
        let urlString: String
        if preferredLanguage.hasPrefix("ja") {
            urlString = "https://forms.gle/routyra-feedback-ja"
        } else {
            urlString = "https://forms.gle/routyra-feedback-en"
        }
        return URL(string: urlString)!
    }

    var body: some View {
        List {
            // Premium Section
            premiumSection

            // Notification Section
            notificationSection

            // Workout Settings Section
            Section {
                dayTransitionPicker
                    .listRowBackground(AppColors.cardBackground)
            } header: {
                Text("settings_workout_section")
                    .foregroundColor(AppColors.textSecondary)
            } footer: {
                Text("settings_workout_footer")
                    .foregroundColor(AppColors.textMuted)
            }

            // Display Settings Section
            Section {
                themePicker
                    .listRowBackground(AppColors.cardBackground)
                weightUnitPicker
                    .listRowBackground(AppColors.cardBackground)
            } header: {
                Text("settings_display_section")
                    .foregroundColor(AppColors.textSecondary)
            } footer: {
                Text("settings_display_footer")
                    .foregroundColor(AppColors.textMuted)
            }

            // Plan Update Settings Section
            Section {
                planUpdateConfirmationToggle
                    .listRowBackground(AppColors.cardBackground)
                planUpdateIncreasePicker
                    .listRowBackground(AppColors.cardBackground)
                planUpdateDecreasePicker
                    .listRowBackground(AppColors.cardBackground)
            } header: {
                Text("settings_plan_update_section")
                    .foregroundColor(AppColors.textSecondary)
            } footer: {
                Text("settings_plan_update_footer")
                    .foregroundColor(AppColors.textMuted)
            }

            // Rest Timer Settings Section
            Section {
                defaultRestTimePicker
                    .listRowBackground(AppColors.cardBackground)
                combineRecordTimerToggle
                    .listRowBackground(AppColors.cardBackground)
                if !(profile?.combineRecordAndTimerStart ?? false) &&
                   (profile?.hasShownCombinationAnnouncement ?? false) {
                    reShowAnnouncementButton
                        .listRowBackground(AppColors.cardBackground)
                }
            } header: {
                Text("settings_rest_timer_section")
                    .foregroundColor(AppColors.textSecondary)
            } footer: {
                Text("settings_rest_timer_footer")
                    .foregroundColor(AppColors.textMuted)
            }

            // App Info Section
            Section {
                HStack {
                    Text("settings_version")
                    Spacer()
                    Text(appVersion)
                        .foregroundColor(AppColors.textSecondary)
                }
                .listRowBackground(AppColors.cardBackground)
            } header: {
                Text("settings_app_info")
                    .foregroundColor(AppColors.textSecondary)
            }

            // Other Section (Terms, Privacy, Feedback)
            otherSection

            // Data Management Section
            dataManagementSection
        }
        .listStyle(.insetGrouped)
        .foregroundColor(AppColors.textPrimary)
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("settings_title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadProfile()
            Task {
                await storeKitManager.loadProducts()
            }
        }
        .alert(L10n.tr("settings_delete_all_confirm_title"), isPresented: $showingDeleteConfirmation) {
            Button(L10n.tr("common_cancel"), role: .cancel) {}
            Button(L10n.tr("common_delete"), role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("settings_delete_all_confirm_message")
        }
        .alert(restoreResultMessage, isPresented: $showingRestoreResult) {
            Button(L10n.tr("common_ok"), role: .cancel) {}
        }
    }

    // MARK: - Premium Section

    private var premiumSection: some View {
        Section {
            if storeKitManager.isPurchased(.removeAds) {
                // Already purchased
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("premium_purchased")
                        .foregroundColor(AppColors.textPrimary)
                }
                .listRowBackground(AppColors.cardBackground)
            } else {
                // Purchase button
                if let product = storeKitManager.product(for: .removeAds) {
                    Button {
                        Task {
                            do {
                                try await storeKitManager.purchase(product)
                            } catch {
                                // Error handled by StoreKitManager
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("premium_remove_ads_title")
                                    .foregroundColor(AppColors.textPrimary)
                                Text("premium_remove_ads_description")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                            if storeKitManager.isLoading {
                                ProgressView()
                            } else {
                                Text(product.displayPrice)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.accentBlue)
                            }
                        }
                    }
                    .disabled(storeKitManager.isLoading)
                    .listRowBackground(AppColors.cardBackground)
                }

                // Restore button
                Button {
                    Task {
                        await storeKitManager.restorePurchases()
                        if storeKitManager.isPurchased(.removeAds) {
                            restoreResultMessage = L10n.tr("premium_restore_success")
                        } else {
                            restoreResultMessage = L10n.tr("premium_restore_no_products")
                        }
                        showingRestoreResult = true
                    }
                } label: {
                    HStack {
                        Spacer()
                        if storeKitManager.isLoading {
                            ProgressView()
                        } else {
                            Text("premium_restore_button")
                                .foregroundColor(AppColors.accentBlue)
                        }
                        Spacer()
                    }
                }
                .disabled(storeKitManager.isLoading)
                .listRowBackground(AppColors.cardBackground)
            }
        } header: {
            Text("settings_premium_section")
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Notification Section

    private var notificationSection: some View {
        Section {
            // Open system notification settings
            Button {
                openNotificationSettings()
            } label: {
                HStack {
                    Text("settings_open_system_notifications")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }
            }
            .listRowBackground(AppColors.cardBackground)

            // Notification toggle
            Toggle(isOn: Binding(
                get: { profile?.notificationsEnabled ?? false },
                set: { newValue in
                    profile?.notificationsEnabled = newValue
                    try? modelContext.save()
                    if newValue {
                        requestNotificationPermission()
                    }
                }
            )) {
                Text("settings_enable_notifications")
            }
            .tint(AppColors.accentBlue)
            .listRowBackground(AppColors.cardBackground)
        } header: {
            Text("settings_notification_section")
                .foregroundColor(AppColors.textSecondary)
        } footer: {
            Text("settings_notification_footer")
                .foregroundColor(AppColors.textMuted)
        }
    }

    // MARK: - Other Section

    private var otherSection: some View {
        Section {
            // Terms of Service
            Link(destination: termsOfServiceURL) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(AppColors.accentBlue)
                    Text("settings_terms_of_service")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }
            }
            .listRowBackground(AppColors.cardBackground)

            // Privacy Policy
            Link(destination: privacyPolicyURL) {
                HStack {
                    Image(systemName: "hand.raised")
                        .foregroundColor(AppColors.accentBlue)
                    Text("settings_privacy_policy")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }
            }
            .listRowBackground(AppColors.cardBackground)

            // Feedback
            Link(destination: feedbackURL) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .foregroundColor(AppColors.accentBlue)
                    Text("settings_feedback")
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textMuted)
                }
            }
            .listRowBackground(AppColors.cardBackground)
        } header: {
            Text("settings_other_section")
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        Section {
            Button {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                    Text("settings_delete_all_data")
                        .foregroundColor(.red)
                }
            }
            .listRowBackground(AppColors.cardBackground)
        } header: {
            Text("settings_data_management_section")
                .foregroundColor(AppColors.textSecondary)
        } footer: {
            Text("settings_delete_all_footer")
                .foregroundColor(AppColors.textMuted)
        }
    }

    // MARK: - Display Settings

    private var themePicker: some View {
        Picker("settings_theme", selection: Binding(
            get: { profile?.effectiveThemeType ?? .dark },
            set: { newValue in
                profile?.themeType = newValue
                ThemeManager.shared.setTheme(newValue)
                try? modelContext.save()
            }
        )) {
            Section {
                ForEach(ThemeType.darkThemes, id: \.self) { themeType in
                    Text(themeType.localizedName)
                        .tag(themeType)
                }
            } header: {
                Text("theme_group_dark")
                    .foregroundColor(AppColors.textSecondary)
            }

            Section {
                ForEach(ThemeType.lightThemes, id: \.self) { themeType in
                    Text(themeType.localizedName)
                        .tag(themeType)
                }
            } header: {
                Text("theme_group_light")
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private var weightUnitPicker: some View {
        Picker("settings_weight_unit", selection: Binding(
            get: { profile?.effectiveWeightUnit ?? .kg },
            set: { newValue in
                profile?.weightUnit = newValue
                try? modelContext.save()
            }
        )) {
            ForEach(WeightUnit.allCases, id: \.self) { unit in
                Text(unit.localizedName)
                    .tag(unit)
            }
        }
    }

    // MARK: - Day Transition Picker

    private var dayTransitionPicker: some View {
        Picker("settings_day_transition_time", selection: Binding(
            get: { profile?.dayTransitionHour ?? 3 },
            set: { newValue in
                profile?.dayTransitionHour = newValue
                try? modelContext.save()
            }
        )) {
            ForEach(0..<24, id: \.self) { hour in
                Text(formatHour(hour))
                    .tag(hour)
            }
        }
    }

    // MARK: - Helpers

    private func loadProfile() {
        profile = ProfileService.getOrCreateProfile(modelContext: modelContext)
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("j:mm")
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Plan Update Settings

    private var planUpdateConfirmationToggle: some View {
        Toggle(isOn: Binding(
            get: { profile?.planUpdateConfirmationEnabled ?? true },
            set: { newValue in
                profile?.planUpdateConfirmationEnabled = newValue
                try? modelContext.save()
            }
        )) {
            Text("settings_plan_update_confirm_toggle")
        }
        .tint(AppColors.accentBlue)
    }

    private var planUpdateIncreasePicker: some View {
        Picker("settings_plan_update_increase", selection: Binding(
            get: { profile?.planUpdatePolicyIncrease ?? .confirm },
            set: { newValue in
                profile?.planUpdatePolicyIncrease = newValue
                try? modelContext.save()
            }
        )) {
            ForEach(PlanUpdatePolicy.allCases, id: \.self) { policy in
                Text(policy.localizedName)
                    .tag(policy)
            }
        }
    }

    private var planUpdateDecreasePicker: some View {
        Picker("settings_plan_update_decrease", selection: Binding(
            get: { profile?.planUpdatePolicyDecrease ?? .confirm },
            set: { newValue in
                profile?.planUpdatePolicyDecrease = newValue
                try? modelContext.save()
            }
        )) {
            ForEach(PlanUpdatePolicy.allCases, id: \.self) { policy in
                Text(policy.localizedName)
                    .tag(policy)
            }
        }
    }

    // MARK: - Rest Timer Settings

    private var defaultRestTimePicker: some View {
        let totalSeconds = profile?.defaultRestTimeSeconds ?? 90
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return HStack {
            Text("settings_default_rest_time")

            Spacer()

            // Minutes picker (0-20)
            Picker("", selection: Binding(
                get: { minutes },
                set: { newMinutes in
                    let currentSeconds = (profile?.defaultRestTimeSeconds ?? 90) % 60
                    profile?.defaultRestTimeSeconds = newMinutes * 60 + currentSeconds
                    try? modelContext.save()
                }
            )) {
                ForEach(0...20, id: \.self) { min in
                    Text("\(min)").tag(min)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 50, height: 100)
            .clipped()

            Text(":")
                .foregroundColor(AppColors.textSecondary)

            // Seconds picker (0-59)
            Picker("", selection: Binding(
                get: { seconds },
                set: { newSeconds in
                    let currentMinutes = (profile?.defaultRestTimeSeconds ?? 90) / 60
                    profile?.defaultRestTimeSeconds = currentMinutes * 60 + newSeconds
                    try? modelContext.save()
                }
            )) {
                ForEach(0..<60, id: \.self) { sec in
                    Text(String(format: "%02d", sec)).tag(sec)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 50, height: 100)
            .clipped()
        }
    }

    private var combineRecordTimerToggle: some View {
        Toggle(isOn: Binding(
            get: { profile?.combineRecordAndTimerStart ?? false },
            set: { newValue in
                profile?.combineRecordAndTimerStart = newValue
                try? modelContext.save()
            }
        )) {
            VStack(alignment: .leading, spacing: 4) {
                Text("settings_combine_record_timer")
                Text("settings_combine_record_timer_hint")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .tint(AppColors.accentBlue)
    }

    private var reShowAnnouncementButton: some View {
        Button {
            profile?.hasShownCombinationAnnouncement = false
            try? modelContext.save()
        } label: {
            Text("settings_reshow_announcement")
                .foregroundColor(AppColors.accentBlue)
        }
    }

    // MARK: - Notification Methods

    private func openNotificationSettings() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            await MainActor.run {
                switch settings.authorizationStatus {
                case .notDetermined:
                    requestNotificationPermission()
                case .denied, .authorized, .provisional, .ephemeral:
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                @unknown default:
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                profile?.notificationsEnabled = granted
                try? modelContext.save()
            }
        }
    }

    // MARK: - Data Management Methods

    private func deleteAllData() {
        // Delete all workout days
        for workoutDay in workoutDays {
            modelContext.delete(workoutDay)
        }

        // Delete all workout plans
        for plan in workoutPlans {
            modelContext.delete(plan)
        }

        // Delete all plan cycles
        for cycle in planCycles {
            modelContext.delete(cycle)
        }

        // Delete custom exercises (keep system ones)
        for exercise in exercises where !exercise.isSystem {
            modelContext.delete(exercise)
        }

        // Reset profile settings
        if let profile = profile {
            profile.activePlanId = nil
            profile.scheduledPlanStartDate = nil
            profile.scheduledPlanStartDayIndex = nil
            profile.scheduledPlanId = nil
            profile.scheduledCycleStartDate = nil
            profile.scheduledCyclePlanIndex = nil
            profile.scheduledCycleDayIndex = nil
            profile.scheduledCycleId = nil
            profile.executionMode = .single
        }

        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: [LocalProfile.self], inMemory: true)
    .preferredColorScheme(.dark)
}
