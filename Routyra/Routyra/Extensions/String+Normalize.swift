//
//  String+Normalize.swift
//  Routyra
//
//  String normalization helpers for duplicate checking.
//  All methods are nonisolated since they're pure string operations.
//

import Foundation

extension String {
    /// Normalizes a string for comparison (duplicate checking).
    /// - Trims leading/trailing whitespace and newlines
    /// - Collapses multiple spaces into single space
    /// - Converts to lowercase
    /// - Returns: Normalized string suitable for comparison
    nonisolated func normalizedForComparison() -> String {
        // Trim whitespace and newlines
        var result = self.trimmingCharacters(in: .whitespacesAndNewlines)

        // Collapse multiple spaces into single space
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        // Lowercase for case-insensitive comparison
        result = result.lowercased()

        return result
    }

    /// Returns the trimmed version of the string.
    nonisolated var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns true if the trimmed string is empty.
    nonisolated var isBlank: Bool {
        trimmed.isEmpty
    }
}
