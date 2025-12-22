//
//  L10n.swift
//  Routyra
//
//  Lightweight localization helper for string formatting.
//

import Foundation

enum L10n {
    nonisolated static func tr(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    nonisolated static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        return String(format: format, locale: Locale.current, arguments: args)
    }
}
