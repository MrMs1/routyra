//
//  BodyPart.swift
//  Routyra
//
//  Represents a body area/muscle group (e.g., "Chest", "Back", "Legs").
//  Can be either a system-defined (with translations) or user-created.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class BodyPart {
    /// Unique identifier.
    var id: UUID

    /// Unique code for system-defined body parts (e.g., "chest", "back").
    /// Nil for user-created body parts.
    var code: String?

    /// Whether this is a system-defined body part (true) or user-created (false).
    var isSystem: Bool

    /// Whether this is a global preset or user-created body part.
    /// Kept for backward compatibility. Use isSystem for new logic.
    var scope: ExerciseScope

    /// Owner profile ID (only relevant when scope == .user).
    var ownerProfileId: UUID?

    /// Display name of the body part (used for user-created, fallback for system).
    var name: String

    /// Normalized name for duplicate checking (lowercased, trimmed, collapsed spaces).
    var normalizedName: String

    /// Sort order for display (lower numbers appear first).
    var sortOrder: Int

    /// Whether this body part is archived (hidden from selection).
    var isArchived: Bool

    /// Localized translations for system-defined body parts.
    @Relationship(deleteRule: .cascade, inverse: \BodyPartTranslation.bodyPart)
    var translations: [BodyPartTranslation]

    /// Creation timestamp.
    var createdAt: Date

    /// Last update timestamp.
    var updatedAt: Date

    // MARK: - Initialization

    init(
        name: String,
        code: String? = nil,
        isSystem: Bool = false,
        scope: ExerciseScope = .user,
        ownerProfileId: UUID? = nil,
        sortOrder: Int = 0
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = UUID()
        self.code = code
        self.isSystem = isSystem
        self.name = trimmedName
        self.normalizedName = trimmedName.normalizedForComparison()
        self.scope = scope
        self.ownerProfileId = ownerProfileId
        self.sortOrder = sortOrder
        self.isArchived = false
        self.translations = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Factory Methods

    /// Creates a system body part with translations.
    static func systemBodyPart(
        code: String,
        defaultName: String,
        sortOrder: Int = 0
    ) -> BodyPart {
        BodyPart(
            name: defaultName,
            code: code,
            isSystem: true,
            scope: .global,
            ownerProfileId: nil,
            sortOrder: sortOrder
        )
    }

    /// Creates a user body part.
    static func userBodyPart(name: String, profileId: UUID, sortOrder: Int = 999) -> BodyPart {
        BodyPart(
            name: name,
            code: nil,
            isSystem: false,
            scope: .user,
            ownerProfileId: profileId,
            sortOrder: sortOrder
        )
    }

    // MARK: - Localization

    /// Returns the localized name based on the current device language.
    /// Priority: matching locale → "en" → first translation → name → code
    var localizedName: String {
        // For user-created body parts, return the name directly
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
        return code ?? L10n.tr("unknown")
    }

    // MARK: - Translation Management

    /// Adds a translation for this body part.
    func addTranslation(locale: String, name: String) {
        let translation = BodyPartTranslation(locale: locale, name: name)
        translations.append(translation)
    }

    /// Gets translation for a specific locale.
    func translation(for locale: String) -> BodyPartTranslation? {
        translations.first { $0.locale == locale }
    }

    // MARK: - Methods

    func touch() {
        self.updatedAt = Date()
    }

    func archive() {
        self.isArchived = true
        touch()
    }

    func unarchive() {
        self.isArchived = false
        touch()
    }

    // MARK: - Color

    /// Returns a color associated with this body part based on its code.
    var color: Color {
        switch code {
        case "chest":
            return Color(red: 0.95, green: 0.3, blue: 0.3)   // Red
        case "back":
            return Color(red: 0.3, green: 0.6, blue: 0.95)   // Blue
        case "shoulders":
            return Color(red: 0.95, green: 0.6, blue: 0.2)   // Orange
        case "arms":
            return Color(red: 0.6, green: 0.4, blue: 0.9)    // Purple
        case "abs":
            return Color(red: 0.95, green: 0.8, blue: 0.2)   // Yellow
        case "legs":
            return Color(red: 0.3, green: 0.8, blue: 0.5)    // Green
        case "glutes":
            return Color(red: 0.95, green: 0.5, blue: 0.6)   // Pink
        case "full_body":
            return Color(red: 0.4, green: 0.8, blue: 0.9)    // Cyan
        case "cardio":
            return Color(red: 0.6, green: 0.6, blue: 0.6)    // Gray
        default:
            return Color(red: 0.5, green: 0.5, blue: 0.5)    // Default gray
        }
    }
}
