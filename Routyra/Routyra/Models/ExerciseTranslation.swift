//
//  ExerciseTranslation.swift
//  Routyra
//
//  Localized name for an exercise.
//  Used for system-defined exercises to support multiple languages.
//

import Foundation
import SwiftData

@Model
final class ExerciseTranslation {
    /// Unique identifier.
    var id: UUID

    /// Locale code (e.g., "ja", "en").
    var locale: String

    /// Localized name in this locale.
    var name: String

    /// Parent exercise (relationship).
    var exercise: Exercise?

    // MARK: - Initialization

    init(locale: String, name: String) {
        self.id = UUID()
        self.locale = locale
        self.name = name
    }
}
