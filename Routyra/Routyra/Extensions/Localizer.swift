//
//  Localizer.swift
//  Routyra
//
//  Utility for resolving localized names based on device language settings.
//

import Foundation

enum Localizer {
    /// Supported language codes for the app.
    nonisolated static let supportedLanguages = ["ja", "en"]

    /// Default language code when device language is not supported.
    nonisolated static let defaultLanguageCode = "en"

    private nonisolated static func normalizedLanguageCode(from identifier: String) -> String? {
        let locale = Locale(identifier: identifier)
        if let code = locale.language.languageCode?.identifier {
            return code
        }
        return identifier.split(separator: "-").first.map(String.init)
    }

    /// Returns the current device language code.
    /// Falls back to "en" if the device language is not supported.
    nonisolated static var currentLanguageCode: String {
        // First check the app's preferred localizations.
        if let preferredLocalization = Bundle.main.preferredLocalizations.first,
           let code = normalizedLanguageCode(from: preferredLocalization),
           supportedLanguages.contains(code) {
            return code
        }

        // Then check preferred languages (most reliable for device language order).
        for preferred in Locale.preferredLanguages {
            if let code = normalizedLanguageCode(from: preferred),
               supportedLanguages.contains(code) {
                return code
            }
        }

        // Fallback to Locale.current
        if let languageCode = Locale.current.language.languageCode?.identifier,
           supportedLanguages.contains(languageCode) {
            return languageCode
        }

        return defaultLanguageCode
    }

    /// Returns whether the current device language is Japanese.
    nonisolated static var isJapanese: Bool {
        currentLanguageCode == "ja"
    }

    /// Returns whether the current device language is English.
    nonisolated static var isEnglish: Bool {
        currentLanguageCode == "en"
    }
}
