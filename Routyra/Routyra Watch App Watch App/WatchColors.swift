//
//  WatchColors.swift
//  Routyra Watch App Watch App
//
//  Simplified color definitions for watchOS.
//  Syncs theme selection from iPhone via App Groups.
//

import SwiftUI

// MARK: - Watch Colors

enum WatchColors {
    // MARK: - App Groups Key

    private static let appGroupID = "group.com.mrms.routyra"
    private static let themeKey = "selectedTheme"

    // MARK: - Current Theme

    private static var currentTheme: WatchColorTheme {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let themeRaw = defaults.string(forKey: themeKey),
              let themeType = ThemeType(rawValue: themeRaw)
        else {
            return DarkWatchTheme()
        }
        return themeType.watchTheme
    }

    // MARK: - Colors

    static var background: Color { currentTheme.background }
    static var cardBackground: Color { currentTheme.cardBackground }
    static var accentBlue: Color { currentTheme.accentBlue }
    static var textPrimary: Color { currentTheme.textPrimary }
    static var textSecondary: Color { currentTheme.textSecondary }
    static var successGreen: Color { currentTheme.successGreen }
    static var alertRed: Color { currentTheme.alertRed }

    // MARK: - Body Part Colors

    /// Returns a color for the given body part code.
    static func bodyPartColor(for code: String?) -> Color {
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

// MARK: - Watch Color Theme Protocol

protocol WatchColorTheme {
    var background: Color { get }
    var cardBackground: Color { get }
    var accentBlue: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var successGreen: Color { get }
    var alertRed: Color { get }
}

// MARK: - Theme Type Extension for Watch

extension ThemeType {
    var watchTheme: WatchColorTheme {
        switch self {
        case .dark:
            return DarkWatchTheme()
        case .midnight:
            return MidnightWatchTheme()
        case .kuromi:
            return KuromiWatchTheme()
        case .lime:
            return LimeWatchTheme()
        case .ocean:
            return OceanWatchTheme()
        case .gruvboxDark:
            return GruvboxDarkWatchTheme()
        case .light, .gruvboxLight, .serenity, .blossom, .lavenderDusk,
             .roseTea, .matchaCream, .apricotSand, .powderBlue:
            // Light themes default to dark on Watch for better readability
            return DarkWatchTheme()
        }
    }
}

// MARK: - Dark Theme

struct DarkWatchTheme: WatchColorTheme {
    let background = Color(hex: "0F0F10")
    let cardBackground = Color(hex: "1C1C1E")
    let accentBlue = Color(hex: "0A84FF")
    let textPrimary = Color.white
    let textSecondary = Color(hex: "8E8E93")
    let successGreen = Color(hex: "30D158")
    let alertRed = Color(hex: "FF453A")
}

// MARK: - Midnight Theme

struct MidnightWatchTheme: WatchColorTheme {
    let background = Color(hex: "1E1F22")
    let cardBackground = Color(hex: "2B2D31")
    let accentBlue = Color(hex: "5865F2")
    let textPrimary = Color(hex: "F2F3F5")
    let textSecondary = Color(hex: "B5BAC1")
    let successGreen = Color(hex: "3BA55D")
    let alertRed = Color(hex: "ED4245")
}

// MARK: - Kuromi Theme

struct KuromiWatchTheme: WatchColorTheme {
    let background = Color(hex: "1C1822")
    let cardBackground = Color(hex: "261E2B")
    let accentBlue = Color(hex: "FEC3EB")
    let textPrimary = Color(hex: "F4F0F8")
    let textSecondary = Color(hex: "C7BDD8")
    let successGreen = Color(hex: "646590")
    let alertRed = Color(hex: "FEC3EB")
}

// MARK: - Lime Theme

struct LimeWatchTheme: WatchColorTheme {
    let background = Color(hex: "131313")
    let cardBackground = Color(hex: "1D1D1D")
    let accentBlue = Color(hex: "00CF60")
    let textPrimary = Color(hex: "FFFFFF")
    let textSecondary = Color(hex: "AAAAAA")
    let successGreen = Color(hex: "00CF60")
    let alertRed = Color(hex: "AAAAAA")
}

// MARK: - Ocean Theme

struct OceanWatchTheme: WatchColorTheme {
    let background = Color(hex: "0A1A20")
    let cardBackground = Color(hex: "122830")
    let accentBlue = Color(hex: "4DD0E1")
    let textPrimary = Color(hex: "E0F7FA")
    let textSecondary = Color(hex: "80CBC4")
    let successGreen = Color(hex: "80DEEA")
    let alertRed = Color(hex: "F48FB1")
}

// MARK: - Gruvbox Dark Theme

struct GruvboxDarkWatchTheme: WatchColorTheme {
    let background = Color(hex: "262322")
    let cardBackground = Color(hex: "32302F")
    let accentBlue = Color(hex: "458588")
    let textPrimary = Color(hex: "FBF1C7")
    let textSecondary = Color(hex: "D5C4A1")
    let successGreen = Color(hex: "689D6A")
    let alertRed = Color(hex: "CC241D")
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
