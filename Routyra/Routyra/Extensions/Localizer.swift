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
        // Get device language code
        if let languageCode = Locale.current.language.languageCode?.identifier {
            // Check if this language is supported
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
