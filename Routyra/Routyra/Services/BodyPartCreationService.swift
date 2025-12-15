//
//  BodyPartCreationService.swift
//  Routyra
//
//  Service for creating user body parts with validation.
//

import Foundation
import SwiftData

// MARK: - Domain Errors

/// Errors that can occur during body part creation.
enum BodyPartCreationError: LocalizedError {
    /// The body part name is empty or contains only whitespace.
    case emptyName
    /// A body part with the same name already exists.
    case duplicateBodyPart(existingName: String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "部位名を入力してください"
        case .duplicateBodyPart(let name):
            return "「\(name)」は既に登録されています"
        }
    }
}

// MARK: - BodyPartCreationService

/// Service for creating and managing user body parts.
enum BodyPartCreationService {
    // MARK: - Body Part Creation

    /// Creates a new user body part.
    /// - Parameters:
    ///   - profile: The local profile (owner).
    ///   - name: The display name of the body part.
    ///   - modelContext: The SwiftData model context.
    /// - Returns: The created body part.
    /// - Throws: `BodyPartCreationError` if validation fails.
    @MainActor
    static func createUserBodyPart(
        profile: LocalProfile,
        name: String,
        modelContext: ModelContext
    ) throws -> BodyPart {
        // Trim whitespace
        let trimmedName = name.trimmed

        // Validate non-empty
        guard !trimmedName.isEmpty else {
            throw BodyPartCreationError.emptyName
        }

        // Check for duplicates (both global and user body parts)
        let normalizedName = trimmedName.normalizedForComparison()
        if let existingBodyPart = findDuplicateBodyPart(
            profileId: profile.id,
            normalizedName: normalizedName,
            modelContext: modelContext
        ) {
            throw BodyPartCreationError.duplicateBodyPart(existingName: existingBodyPart.name)
        }

        // Calculate sortOrder: place after existing body parts
        let nextSortOrder = calculateNextSortOrder(
            profileId: profile.id,
            modelContext: modelContext
        )

        // Create the body part
        let bodyPart = BodyPart.userBodyPart(
            name: trimmedName,
            profileId: profile.id,
            sortOrder: nextSortOrder
        )

        modelContext.insert(bodyPart)
        return bodyPart
    }

    // MARK: - Duplicate Checking

    /// Finds a duplicate body part by normalized name.
    /// Checks both global body parts and user body parts for this profile.
    @MainActor
    private static func findDuplicateBodyPart(
        profileId: UUID,
        normalizedName: String,
        modelContext: ModelContext
    ) -> BodyPart? {
        let descriptor = FetchDescriptor<BodyPart>()

        do {
            let bodyParts = try modelContext.fetch(descriptor)
            return bodyParts.first { bodyPart in
                // Not archived
                !bodyPart.isArchived &&
                // Normalized name matches
                bodyPart.normalizedName == normalizedName &&
                // Either global OR user-owned by this profile
                (bodyPart.scope == .global || bodyPart.ownerProfileId == profileId)
            }
        } catch {
            print("Error checking for duplicate body part: \(error)")
            return nil
        }
    }

    // MARK: - Sort Order Calculation

    /// Calculates the next sortOrder for a new user body part.
    /// Returns (max sortOrder among visible body parts) + 1.
    @MainActor
    private static func calculateNextSortOrder(
        profileId: UUID,
        modelContext: ModelContext
    ) -> Int {
        let descriptor = FetchDescriptor<BodyPart>()

        do {
            let bodyParts = try modelContext.fetch(descriptor)
            let visibleBodyParts = bodyParts.filter { bodyPart in
                !bodyPart.isArchived &&
                (bodyPart.scope == .global || bodyPart.ownerProfileId == profileId)
            }

            let maxSortOrder = visibleBodyParts.map(\.sortOrder).max() ?? 0
            return maxSortOrder + 1
        } catch {
            print("Error calculating sort order: \(error)")
            return 999 // Default fallback
        }
    }
}
