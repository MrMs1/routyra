//
//  BodyPartTranslation.swift
//  Routyra
//
//  Localized name for a body part.
//  Used for system-defined body parts to support multiple languages.
//

import Foundation
import SwiftData

@Model
final class BodyPartTranslation {
    /// Unique identifier.
    var id: UUID

    /// Locale code (e.g., "ja", "en").
    var locale: String

    /// Localized name in this locale.
    var name: String

    /// Parent body part (relationship).
    var bodyPart: BodyPart?

    // MARK: - Initialization

    init(locale: String, name: String) {
        self.id = UUID()
        self.locale = locale
        self.name = name
    }
}
