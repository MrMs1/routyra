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

    /// Returns the current device language code.
    /// Falls back to "en" if the device language is not supported.
    nonisolated static var currentLanguageCode: String {
        // First check preferred languages (most reliable for app language)
        for preferred in Locale.preferredLanguages {
            // Extract language code (e.g., "ja-JP" -> "ja", "en-US" -> "en")
            let code = String(preferred.prefix(2))
            if supportedLanguages.contains(code) {
                return code
            }
        }

        // Fallback to Locale.current
        if let languageCode = Locale.current.language.languageCode?.identifier {
            if supportedLanguages.contains(languageCode) {
                return languageCode
            }
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
