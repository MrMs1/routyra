//
//  AppColors.swift
//  Routyra
//

import SwiftUI

enum AppColors {
    static let background = Color(hex: "0F0F10")
    static let cardBackground = Color(hex: "1C1C1E")
    static let cardBackgroundCompleted = Color(hex: "141416")
    static let accentBlue = Color(hex: "0A84FF")
    static let mutedBlue = Color(hex: "2C5282")
    static let weekendSaturday = Color(hex: "64D2FF")
    static let weekendSunday = Color(hex: "FF453A")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "8E8E93")
    static let textMuted = Color(hex: "636366")
    static let streakOrange = Color(hex: "FF9500")
    static let divider = Color(hex: "38383A")
    static let dotEmpty = Color(hex: "48484A")
    static let dotFilled = Color(hex: "0A84FF")
}

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
