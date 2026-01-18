//
//  ThemeManager.swift
//  Routyra
//
//  Manages theme selection and provides current theme colors.
//  Singleton pattern for easy access throughout the app.
//

import SwiftUI
import UIKit
import os

// MARK: - Theme Change Notification

extension Notification.Name {
    /// Posted when the app theme changes.
    static let themeDidChange = Notification.Name("themeDidChange")
}

// MARK: - Theme Manager

/// Manages the current app theme.
/// Use `ThemeManager.shared` to access the singleton instance.
@Observable
final class ThemeManager {
    // MARK: - Singleton

    /// Shared instance for app-wide theme access.
    static let shared = ThemeManager()

    // MARK: - Properties

    /// App Group identifier for sharing theme with Watch app.
    private let appGroupID = "group.com.mrms.routyra"
    private let themeKey = "selectedTheme"

    /// The currently selected theme type.
    /// Changing this will update all colors throughout the app.
    var currentThemeType: ThemeType = .dark {
        didSet {
            currentTheme = currentThemeType.theme
            saveThemeToAppGroup()
        }
    }

    /// The current theme instance providing all colors.
    private(set) var currentTheme: ColorTheme

    // MARK: - Initialization

    private init() {
        self.currentTheme = ThemeType.dark.theme
        // Ensure the App Group always has a value, even before the user opens Settings
        // or before any profile sync runs. This prevents Watch from falling back to
        // DarkWatchTheme due to a missing "selectedTheme" key.
        saveThemeToAppGroup()
    }

    // MARK: - Theme Switching

    /// Updates the theme to match the specified type.
    /// - Parameter themeType: The new theme type to apply.
    func setTheme(_ themeType: ThemeType) {
        currentThemeType = themeType
        applyNavigationAppearance()
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
    }

    /// Syncs the theme manager with a stored theme type (e.g., from LocalProfile).
    /// - Parameter themeType: The theme type to sync with, or nil to use default.
    func sync(with themeType: ThemeType?) {
        if let themeType = themeType {
            currentThemeType = themeType
        }
        applyNavigationAppearance()
        saveThemeToAppGroup()
    }

    /// Saves the current theme to App Groups for Watch app access.
    private func saveThemeToAppGroup() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(currentThemeType.rawValue, forKey: themeKey)
        #if DEBUG
        let logger = Logger(subsystem: "com.mrms.routyra", category: "Theme")
        logger.debug("Saved theme to AppGroup: key='\(self.themeKey, privacy: .public)' value='\(self.currentThemeType.rawValue, privacy: .public)'")
        #endif
    }

    // MARK: - Global Appearance

    /// Applies theme colors to navigation and system controls.
    func applyNavigationAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.background)

        let titleColor = UIColor(AppColors.textPrimary)
        appearance.titleTextAttributes = [.foregroundColor: titleColor]
        appearance.largeTitleTextAttributes = [.foregroundColor: titleColor]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(AppColors.accentBlue)

        let isGruvbox = currentThemeType.prefersTabTextTint
        let isLightTheme = currentThemeType.colorScheme == .light

        let switchAppearance = UISwitch.appearance()
        switchAppearance.onTintColor = isGruvbox
            ? UIColor(AppColors.mutedBlue)
            : UIColor(AppColors.accentBlue)
        switch currentThemeType {
        case .gruvboxLight:
            switchAppearance.thumbTintColor = UIColor(AppColors.cardBackground)
        case .gruvboxDark:
            switchAppearance.thumbTintColor = UIColor(AppColors.textPrimary)
        default:
            switchAppearance.thumbTintColor = isLightTheme
                ? UIColor(AppColors.cardBackground)
                : nil
        }

        let segmentedAppearance = UISegmentedControl.appearance()
        segmentedAppearance.setTitleTextAttributes(
            [.foregroundColor: UIColor(AppColors.textSecondary)],
            for: .normal
        )
        segmentedAppearance.setTitleTextAttributes(
            [.foregroundColor: UIColor(AppColors.textPrimary)],
            for: .selected
        )
        segmentedAppearance.backgroundColor = isGruvbox
            ? UIColor(AppColors.cardBackground)
            : nil
        segmentedAppearance.selectedSegmentTintColor = isGruvbox
            ? UIColor(AppColors.groupedCardBackground)
            : nil

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(AppColors.background)
        let normalTabColor = UIColor(AppColors.textSecondary)
        let selectedTabColor = isGruvbox
            ? UIColor(AppColors.textPrimary)
            : UIColor(AppColors.accentBlue)

        func applyTabItemAppearance(_ itemAppearance: UITabBarItemAppearance) {
            itemAppearance.normal.iconColor = normalTabColor
            itemAppearance.normal.titleTextAttributes = [
                .foregroundColor: normalTabColor
            ]
            itemAppearance.selected.iconColor = selectedTabColor
            itemAppearance.selected.titleTextAttributes = [
                .foregroundColor: selectedTabColor
            ]
        }

        applyTabItemAppearance(tabAppearance.stackedLayoutAppearance)
        applyTabItemAppearance(tabAppearance.inlineLayoutAppearance)
        applyTabItemAppearance(tabAppearance.compactInlineLayoutAppearance)

        tabAppearance.selectionIndicatorTintColor = isGruvbox
            ? UIColor(AppColors.groupedCardBackground)
            : nil

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = selectedTabColor
        UITabBar.appearance().unselectedItemTintColor = UIColor(AppColors.textSecondary)
    }
}
