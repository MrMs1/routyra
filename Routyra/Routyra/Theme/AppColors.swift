//
//  AppColors.swift
//  Routyra
//
//  Provides convenient static access to current theme colors.
//  All colors are delegated to ThemeManager for dynamic theme switching.
//

import SwiftUI

// MARK: - App Colors

/// Static color accessors that delegate to the current theme.
/// Use these throughout the app for consistent theming.
enum AppColors {
    // MARK: - Theme Reference

    /// Reference to the current theme for internal use.
    private static var theme: ColorTheme {
        ThemeManager.shared.currentTheme
    }

    // MARK: - Backgrounds

    static var background: Color { theme.background }
    static var cardBackground: Color { theme.cardBackground }
    static var cardBackgroundCompleted: Color { theme.cardBackgroundCompleted }
    static var groupedCardBackground: Color { theme.groupedCardBackground }
    static var groupedCardBackgroundCompleted: Color { theme.groupedCardBackgroundCompleted }
    static var cardBackgroundSecondary: Color { theme.cardBackgroundSecondary }

    // MARK: - Accent Colors

    static var accentBlue: Color { theme.accentBlue }
    static var mutedBlue: Color { theme.mutedBlue }
    static var streakOrange: Color { theme.streakOrange }

    // MARK: - Calendar Colors

    static var weekendSaturday: Color { theme.weekendSaturday }
    static var weekendSunday: Color { theme.weekendSunday }

    // MARK: - Text Colors

    static var textPrimary: Color { theme.textPrimary }
    static var textSecondary: Color { theme.textSecondary }
    static var textMuted: Color { theme.textMuted }

    // MARK: - UI Elements

    static var divider: Color { theme.divider }
    static var dotEmpty: Color { theme.dotEmpty }
    static var dotFilled: Color { theme.dotFilled }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
