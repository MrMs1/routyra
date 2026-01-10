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
    // MARK: - Profile Cache

    /// Cached profile reference to avoid repeated DB fetches within app session
    private static var cachedProfile: LocalProfile?

    /// Invalidates the cached profile (call when profile is deleted or on logout)
    static func invalidateCache() {
        cachedProfile = nil
    }

    // MARK: - Profile Management

    /// Gets the existing profile or creates one if none exists.
    /// This should be called on app launch to ensure a profile exists.
    /// Uses session cache to avoid repeated DB fetches.
    /// - Parameter modelContext: The SwiftData model context.
    /// - Returns: The local profile (existing or newly created).
    @MainActor
    static func getOrCreateProfile(modelContext: ModelContext) -> LocalProfile {
        // Return cached profile if available
        if let cached = cachedProfile {
            return cached
        }

        // Seed system data (body parts and exercises) only on first call per session
        // This ensures new exercises are added when app is updated
        ExerciseCreationService.seedSystemDataIfNeeded(modelContext: modelContext)

        // Try to fetch existing profile
        let descriptor = FetchDescriptor<LocalProfile>()

        do {
            let profiles = try modelContext.fetch(descriptor)
            if let existingProfile = profiles.first {
                cachedProfile = existingProfile
                return existingProfile
            }
        } catch {
            // Log error but continue to create new profile
            print("Error fetching profile: \(error)")
        }

        // Create new profile
        let newProfile = LocalProfile()
        modelContext.insert(newProfile)
        cachedProfile = newProfile

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
        profile.scheduledPlanStartDate = nil
        profile.scheduledPlanStartDayIndex = nil
        profile.scheduledPlanId = nil
    }

    /// Clears the active plan (switches to free mode).
    /// - Parameter profile: The profile to update.
    static func clearActivePlan(_ profile: LocalProfile) {
        profile.activePlanId = nil
        profile.scheduledPlanStartDate = nil
        profile.scheduledPlanStartDayIndex = nil
        profile.scheduledPlanId = nil
    }
}
