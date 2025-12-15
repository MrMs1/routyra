//
//  Exercise.swift
//  Routyra
//
//  Exercise definition entity. Represents a type of exercise (e.g., "Bench Press").
//  Can be either a system-defined (with translations) or user-created.
//

import Foundation
import SwiftData

@Model
final class Exercise {
    /// Unique identifier.
    var id: UUID

    /// Unique code for system-defined exercises (e.g., "bench_press").
    /// Nil for user-created exercises.
    var code: String?

    /// Whether this is a system-defined exercise (true) or user-created (false).
    var isSystem: Bool

    /// Whether this is a global preset or user-created exercise.
    /// Kept for backward compatibility. Use isSystem for new logic.
    var scope: ExerciseScope

    /// Owner profile ID (only relevant when scope == .user).
    /// Using UUID reference for simplicity.
    var ownerProfileId: UUID?

    /// Reference to the body part this exercise belongs to.
    var bodyPartId: UUID?

    /// Display name of the exercise (used for user-created, fallback for system).
    var name: String

    /// Normalized name for duplicate checking (lowercased, trimmed, collapsed spaces).
    var normalizedName: String

    /// Optional category (e.g., "Chest", "Back", "Legs").
    /// Simple string for now; can be upgraded to enum later.
    /// Note: This is kept for backward compatibility but bodyPartId is preferred.
    var category: String?

    /// Whether this exercise is archived (hidden from selection).
    var isArchived: Bool

    /// Localized translations for system-defined exercises.
    @Relationship(deleteRule: .cascade, inverse: \ExerciseTranslation.exercise)
    var translations: [ExerciseTranslation]

    /// Creation timestamp.
    var createdAt: Date

    /// Last update timestamp.
    var updatedAt: Date

    // MARK: - Initialization

    /// Creates a new exercise definition.
    /// - Parameters:
    ///   - name: Display name of the exercise.
    ///   - code: Unique code for system exercises.
    ///   - isSystem: Whether this is a system-defined exercise.
    ///   - scope: Whether global or user-created.
    ///   - ownerProfileId: Owner profile ID (required for user scope).
    ///   - bodyPartId: Reference to the body part.
    ///   - category: Optional category string (legacy).
    init(
        name: String,
        code: String? = nil,
        isSystem: Bool = false,
        scope: ExerciseScope = .user,
        ownerProfileId: UUID? = nil,
        bodyPartId: UUID? = nil,
        category: String? = nil
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = UUID()
        self.code = code
        self.isSystem = isSystem
        self.name = trimmedName
        self.normalizedName = trimmedName.normalizedForComparison()
        self.scope = scope
        self.ownerProfileId = ownerProfileId
        self.bodyPartId = bodyPartId
        self.category = category
        self.isArchived = false
        self.translations = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Factory Methods

    /// Creates a system exercise with translations.
    static func systemExercise(
        code: String,
        defaultName: String,
        bodyPartId: UUID? = nil,
        category: String? = nil
    ) -> Exercise {
        Exercise(
            name: defaultName,
            code: code,
            isSystem: true,
            scope: .global,
            ownerProfileId: nil,
            bodyPartId: bodyPartId,
            category: category
        )
    }

    /// Creates a user exercise.
    static func userExercise(
        name: String,
        profileId: UUID,
        bodyPartId: UUID? = nil,
        category: String? = nil
    ) -> Exercise {
        Exercise(
            name: name,
            code: nil,
            isSystem: false,
            scope: .user,
            ownerProfileId: profileId,
            bodyPartId: bodyPartId,
            category: category
        )
    }

    // MARK: - Localization

    /// Returns the localized name based on the current device language.
    /// Priority: matching locale → "en" → first translation → name → code
    var localizedName: String {
        // For user-created exercises, return the name directly
        if !isSystem {
            return name
        }

        let currentLocale = Localizer.currentLanguageCode

        // 1. Try to find translation matching current locale
        if let translation = translations.first(where: { $0.locale == currentLocale }) {
            return translation.name
        }

        // 2. Fallback to English
        if let englishTranslation = translations.first(where: { $0.locale == "en" }) {
            return englishTranslation.name
        }

        // 3. Any available translation
        if let anyTranslation = translations.first {
            return anyTranslation.name
        }

        // 4. Fallback to name field
        if !name.isEmpty {
            return name
        }

        // 5. Last resort: code
        return code ?? "Unknown"
    }

    // MARK: - Translation Management

    /// Adds a translation for this exercise.
    func addTranslation(locale: String, name: String) {
        let translation = ExerciseTranslation(locale: locale, name: name)
        translations.append(translation)
    }

    /// Gets translation for a specific locale.
    func translation(for locale: String) -> ExerciseTranslation? {
        translations.first { $0.locale == locale }
    }

    // MARK: - Methods

    /// Marks the exercise as updated.
    func touch() {
        self.updatedAt = Date()
    }

    /// Archives the exercise.
    func archive() {
        self.isArchived = true
        self.touch()
    }

    /// Unarchives the exercise.
    func unarchive() {
        self.isArchived = false
        self.touch()
    }

    /// Updates the name and recalculates the normalized name.
    func updateName(_ newName: String) {
        self.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.normalizedName = self.name.normalizedForComparison()
        self.touch()
    }
}
