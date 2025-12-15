//
//  RoutyraApp.swift
//  Routyra
//
//  Created by 村田昌知 on 2025/12/14.
//

import SwiftUI
import SwiftData

@main
struct RoutyraApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Core entities
            LocalProfile.self,
            BodyPart.self,
            BodyPartTranslation.self,
            Exercise.self,
            ExerciseTranslation.self,

            // Workout entities
            WorkoutDay.self,
            WorkoutExerciseEntry.self,
            WorkoutSet.self,

            // Plan entities
            WorkoutPlan.self,
            PlanDay.self,
            PlanExercise.self,
            PlannedSet.self,
            PlanProgress.self,

            // Cycle entities
            PlanCycle.self,
            PlanCycleItem.self,
            PlanCycleProgress.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
