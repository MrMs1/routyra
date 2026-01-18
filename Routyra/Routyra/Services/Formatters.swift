//
//  Formatters.swift
//  Routyra
//
//  Cached DateFormatter and NumberFormatter instances for performance.
//  All formatters are lazy-initialized and thread-safe.
//  Note: nonisolated(unsafe) is safe here because formatters are read-only after initialization.
//

import Foundation

enum Formatters {

    // MARK: - DateFormatter

    /// Short date format: "Mon, Dec 15"
    nonisolated(unsafe) static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return f
    }()

    /// Full date format: "December 15, 2024" (localized long style)
    nonisolated(unsafe) static let fullDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        return f
    }()

    /// Full date with year: "December 15, 2024"
    nonisolated(unsafe) static let yearMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("yMMMMd")
        return f
    }()

    /// Year and month: "2024 December"
    nonisolated(unsafe) static let yearMonth: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("yyyy MMMM")
        return f
    }()

    /// Year and abbreviated month: "Dec 2024"
    nonisolated(unsafe) static let yearMonthShort: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("yMMMM")
        return f
    }()

    /// Month and day: "12/15"
    nonisolated(unsafe) static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("M/d")
        return f
    }()

    /// Year, month, and day with slashes: "2024/12/15"
    nonisolated(unsafe) static let yearMonthDaySlash: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/M/d"
        return f
    }()

    /// Year only: "2024"
    nonisolated(unsafe) static let year: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("y")
        return f
    }()

    // MARK: - NumberFormatter

    /// Decimal with grouping, no fraction digits
    nonisolated(unsafe) static let decimal0: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        return f
    }()

    /// Decimal with grouping, up to 1 fraction digit
    nonisolated(unsafe) static let decimal1: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f
    }()

    /// Decimal with grouping, up to 2 fraction digits
    nonisolated(unsafe) static let decimal2: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.usesGroupingSeparator = true
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    // MARK: - Convenience Methods

    /// Formats weight with appropriate decimal places (0 if whole number, 1 otherwise)
    nonisolated static func formatWeight(_ weight: Double) -> String {
        let formatter = weight.truncatingRemainder(dividingBy: 1) == 0 ? decimal0 : decimal1
        return formatter.string(from: NSNumber(value: weight)) ?? String(format: "%.0f", weight)
    }

    /// Formats a number with appropriate decimal places based on magnitude (for volume display)
    /// - value >= 100: 0 decimals
    /// - value >= 10: 1 decimal
    /// - value < 10: 2 decimals
    nonisolated static func formatVolumeNumber(_ value: Double) -> String {
        // Preserve fractional part when present (e.g., 187.5 should not become 188).
        // Use 0 decimals only for whole numbers; otherwise show 1-2 decimals depending on magnitude.
        let isWholeNumber = value.truncatingRemainder(dividingBy: 1) == 0

        let formatter: NumberFormatter
        if isWholeNumber {
            formatter = decimal0
        } else if value >= 10 {
            formatter = decimal1
        } else {
            formatter = decimal2
        }
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }
}
