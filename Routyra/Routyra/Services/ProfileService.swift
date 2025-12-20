//
//  ProfileService.swift
//  Routyra
//
//  Service for managing the local user profile.
//  Handles profile creation on first launch.
//

import Foundation
import SwiftData

/// Service for local profile management.
enum ProfileService {
    // MARK: - Profile Management

    /// Gets the existing profile or creates one if none exists.
    /// This should be called on app launch to ensure a profile exists.
    /// - Parameter modelContext: The SwiftData model context.
    /// - Returns: The local profile (existing or newly created).
    @MainActor
    static func getOrCreateProfile(modelContext: ModelContext) -> LocalProfile {
        // Try to fetch existing profile
        let descriptor = FetchDescriptor<LocalProfile>()

        do {
            let profiles = try modelContext.fetch(descriptor)
            if let existingProfile = profiles.first {
                return existingProfile
            }
        } catch {
            // Log error but continue to create new profile
            print("Error fetching profile: \(error)")
        }

        // Create new profile
        let newProfile = LocalProfile()
        modelContext.insert(newProfile)

        // Seed system data (body parts and exercises) on first launch
        ExerciseCreationService.seedSystemDataIfNeeded(modelContext: modelContext)

        return newProfile
    }

    /// Gets the current profile without creating one.
    /// - Parameter modelContext: The SwiftData model context.
    /// - Returns: The local profile if it exists, nil otherwise.
    @MainActor
    static func getProfile(modelContext: ModelContext) -> LocalProfile? {
        let descriptor = FetchDescriptor<LocalProfile>()

        do {
            let profiles = try modelContext.fetch(descriptor)
            return profiles.first
        } catch {
            print("Error fetching profile: \(error)")
            return nil
        }
    }

    // MARK: - Active Plan

    /// Sets the active workout plan for the profile.
    /// - Parameters:
    ///   - profile: The profile to update.
    ///   - planId: The workout plan ID to set as active, or nil for free mode.
    static func setActivePlan(_ profile: LocalProfile, planId: UUID?) {
        profile.activePlanId = planId
    }

    /// Clears the active plan (switches to free mode).
    /// - Parameter profile: The profile to update.
    static func clearActivePlan(_ profile: LocalProfile) {
        profile.activePlanId = nil
    }
}
