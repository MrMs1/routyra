//
//  VolumeFormatter.swift
//  Routyra
//
//  Utility for formatting volume values with appropriate unit scaling.
//  Supports kg/lb base units with scaling up to gigatons/tera-pounds.
//

import Foundation

// MARK: - Volume Scale

/// Scale levels for volume display.
/// Each level represents a 1000x increase from the previous.
enum VolumeScale: Int, CaseIterable {
    case base = 0      // kg, lb (< 10,000)
    case kilo = 1      // t, klb (10,000 - 9,999,999)
    case mega = 2      // kt, Mlb (10,000,000 - 9,999,999,999)
    case giga = 3      // Mt, Glb (10,000,000,000 - 9,999,999,999,999)
    case tera = 4      // Gt, Tlb (>= 10,000,000,000,000)

    /// The divisor to convert base units to this scale.
    var divisor: Double {
        pow(1000, Double(rawValue))
    }

    /// Threshold value at which to switch to this scale.
    var threshold: Double {
        switch self {
        case .base: return 0
        case .kilo: return 10_000
        case .mega: return 10_000_000
        case .giga: return 10_000_000_000
        case .tera: return 10_000_000_000_000
        }
    }

    /// Returns the localized unit symbol for this scale.
    func symbol(for weightUnit: WeightUnit) -> String {
        switch (self, weightUnit) {
        case (.base, .kg): return L10n.tr("unit_kg")
        case (.base, .lb): return L10n.tr("unit_lb")
        case (.kilo, .kg): return L10n.tr("unit_t")
        case (.kilo, .lb): return L10n.tr("unit_klb")
        case (.mega, .kg): return L10n.tr("unit_kt")
        case (.mega, .lb): return L10n.tr("unit_mlb")
        case (.giga, .kg): return L10n.tr("unit_mt")
        case (.giga, .lb): return L10n.tr("unit_glb")
        case (.tera, .kg): return L10n.tr("unit_gt")
        case (.tera, .lb): return L10n.tr("unit_tlb")
        }
    }
}

// MARK: - Volume Formatter

/// Utility for formatting volume values with automatic unit scaling.
enum VolumeFormatter {

    // MARK: - Public API

    /// Formats a volume value with the appropriate unit based on magnitude.
    /// - Parameters:
    ///   - value: The volume value in base units (kg or lb equivalent)
    ///   - weightUnit: The weight unit system to use for display
    /// - Returns: Formatted string with value and unit symbol (e.g., "1.5Mt", "250klb")
    static func format(_ value: Decimal, weightUnit: WeightUnit) -> String {
        let doubleValue = NSDecimalNumber(decimal: value).doubleValue
        return format(doubleValue, weightUnit: weightUnit)
    }

    /// Formats a volume value with the appropriate unit based on magnitude.
    /// - Parameters:
    ///   - value: The volume value in base units (kg or lb equivalent)
    ///   - weightUnit: The weight unit system to use for display
    /// - Returns: Formatted string with value and unit symbol (e.g., "1.5Mt", "250klb")
    static func format(_ value: Double, weightUnit: WeightUnit) -> String {
        let scale = appropriateScale(for: value)
        let scaledValue = value / scale.divisor
        let formattedNumber = formatNumber(scaledValue)
        let unitSymbol = scale.symbol(for: weightUnit)
        return "\(formattedNumber)\(unitSymbol)"
    }

    /// Determines the appropriate scale for a given value.
    /// - Parameter value: The volume value in base units
    /// - Returns: The appropriate VolumeScale for display
    static func appropriateScale(for value: Double) -> VolumeScale {
        // Find the highest scale whose threshold is <= value
        // Iterate in reverse to find the largest applicable scale
        for scale in VolumeScale.allCases.reversed() {
            if value >= scale.threshold {
                return scale
            }
        }
        return .base
    }

    // MARK: - Private Helpers

    /// Formats a number with appropriate decimal places and grouping.
    private static func formatNumber(_ value: Double) -> String {
        Formatters.formatVolumeNumber(value)
    }
}
