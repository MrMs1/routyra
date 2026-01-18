//
//  WatchThemeManager.swift
//  Routyra Watch App Watch App
//
//  Observable theme manager for Watch app.
//  Reads theme from App Groups and provides reactive color updates.
//

import Combine
import SwiftUI
import os

// MARK: - Watch Theme Manager

@MainActor
final class WatchThemeManager: ObservableObject {
    // MARK: - Singleton

    static let shared = WatchThemeManager()

    // MARK: - App Groups

    private let appGroupID = "group.com.mrms.routyra"
    private let themeKey = "selectedTheme"
    private let localThemeKey = "lastSelectedTheme"

    #if DEBUG
    private let logger = Logger(subsystem: "com.mrms.routyra", category: "WatchTheme")
    #endif

    // MARK: - Published Colors

    @Published private(set) var background: Color = Color(hex: "0F0F10")
    @Published private(set) var cardBackground: Color = Color(hex: "1C1C1E")
    @Published private(set) var accentBlue: Color = Color(hex: "0A84FF")
    @Published private(set) var textPrimary: Color = .white
    @Published private(set) var textSecondary: Color = Color(hex: "8E8E93")
    @Published private(set) var successGreen: Color = Color(hex: "30D158")
    @Published private(set) var alertRed: Color = Color(hex: "FF453A")

    // MARK: - State

    private var currentThemeRaw: String?

    // MARK: - Initialization

    private init() {
        refreshTheme()
    }

    // MARK: - Public API

    /// Refreshes colors from App Groups UserDefaults.
    func refreshTheme() {
        #if DEBUG
        logger.debug("refreshTheme() called")
        #endif
        guard let themeRaw = resolveThemeRaw() else {
            // If we already applied a theme, keep it when App Group is not ready.
            if currentThemeRaw != nil {
                return
            }
            applyTheme(DarkWatchTheme())
            currentThemeRaw = nil
            return
        }

        if themeRaw == currentThemeRaw {
            return
        }

        if let themeType = ThemeType(rawValue: themeRaw) {
            applyTheme(themeType.watchTheme)
            currentThemeRaw = themeRaw
        } else {
            #if DEBUG
            logger.warning("Unknown themeRaw='\(themeRaw, privacy: .public)' -> keeping current theme")
            #endif
        }
    }

    // MARK: - Private Methods

    private func resolveThemeRaw() -> String? {
        if let defaults = UserDefaults(suiteName: appGroupID) {
            if let themeRaw = defaults.string(forKey: themeKey) {
                if ThemeType(rawValue: themeRaw) != nil {
                    persistLocalThemeRaw(themeRaw)
                    #if DEBUG
                    logger.debug("Loaded app group themeRaw='\(themeRaw, privacy: .public)'")
                    #endif
                    return themeRaw
                }
                #if DEBUG
                logger.warning("Unknown app group themeRaw='\(themeRaw, privacy: .public)'")
                #endif
            } else {
                #if DEBUG
                logger.warning("AppGroup theme missing key '\(self.themeKey, privacy: .public)'")
                #endif
            }
        } else {
            #if DEBUG
            logger.error("UserDefaults(suiteName: \(self.appGroupID, privacy: .public)) is nil")
            #endif
        }

        if let themeRaw = UserDefaults.standard.string(forKey: localThemeKey),
           ThemeType(rawValue: themeRaw) != nil {
            #if DEBUG
            logger.debug("Loaded local themeRaw='\(themeRaw, privacy: .public)'")
            #endif
            return themeRaw
        }

        return nil
    }

    private func persistLocalThemeRaw(_ themeRaw: String) {
        UserDefaults.standard.set(themeRaw, forKey: localThemeKey)
    }

    private func applyTheme(_ theme: WatchColorTheme) {
        background = theme.background
        cardBackground = theme.cardBackground
        accentBlue = theme.accentBlue
        textPrimary = theme.textPrimary
        textSecondary = theme.textSecondary
        successGreen = theme.successGreen
        alertRed = theme.alertRed
    }

    // MARK: - Body Part Color

    /// Returns a color for the given body part code.
    func bodyPartColor(for code: String?) -> Color {
        guard let code = code else { return textSecondary }

        switch code {
        case "chest":
            return Color(red: 0.95, green: 0.3, blue: 0.3)   // Red
        case "back":
            return Color(red: 0.3, green: 0.6, blue: 0.95)   // Blue
        case "shoulders":
            return Color(red: 0.95, green: 0.6, blue: 0.2)   // Orange
        case "arms":
            return Color(red: 0.6, green: 0.4, blue: 0.9)    // Purple
        case "abs":
            return Color(red: 0.95, green: 0.8, blue: 0.2)   // Yellow
        case "legs":
            return Color(red: 0.3, green: 0.8, blue: 0.5)    // Green
        case "glutes":
            return Color(red: 0.95, green: 0.5, blue: 0.6)   // Pink
        case "full_body":
            return Color(red: 0.4, green: 0.8, blue: 0.9)    // Cyan
        case "cardio":
            return Color(red: 0.6, green: 0.6, blue: 0.6)    // Gray
        default:
            return textSecondary
        }
    }
}
