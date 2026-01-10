//
//  CardioWorkoutEditorView.swift
//  Routyra
//
//  Manual entry form for cardio workouts.
//

import SwiftUI
import SwiftData
import HealthKit

struct CardioWorkoutEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let profile: LocalProfile
    var workoutDayId: UUID? = nil  // For linking to WorkoutDay when adding from workout screen
    var onSave: (() -> Void)? = nil

    // MARK: - State

    @State private var selectedActivityType: HKWorkoutActivityType = .running
    @State private var durationHours: Int = 0
    @State private var durationMinutes: Int = 30
    @State private var durationSeconds: Int = 0
    @State private var distanceKm: String = ""
    @State private var workoutDate: Date = Date()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Activity Type
                Section {
                    Picker(L10n.tr("cardio_activity_type"), selection: $selectedActivityType) {
                        ForEach(commonActivityTypes, id: \.rawValue) { type in
                            Text(type.displayName)
                                .tag(type)
                        }
                    }
                }

                // Duration
                Section(header: Text(L10n.tr("cardio_duration"))) {
                    HStack {
                        Picker("", selection: $durationHours) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60)

                        Text(L10n.tr("cardio_hours_short"))
                            .foregroundColor(AppColors.textSecondary)

                        Picker("", selection: $durationMinutes) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60)

                        Text(L10n.tr("cardio_minutes_short"))
                            .foregroundColor(AppColors.textSecondary)

                        Picker("", selection: $durationSeconds) {
                            ForEach(0..<60, id: \.self) { second in
                                Text("\(second)").tag(second)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 60)

                        Text(L10n.tr("cardio_seconds_short"))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(height: 120)
                }

                // Distance (optional)
                Section(header: Text(L10n.tr("cardio_distance_optional"))) {
                    HStack {
                        TextField("0.0", text: $distanceKm)
                            .keyboardType(.decimalPad)
                            .frame(width: 100)

                        Text("km")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .navigationTitle(L10n.tr("cardio_add_workout"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("save")) {
                        saveWorkout()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var isValid: Bool {
        totalDurationSeconds > 0
    }

    private var totalDurationSeconds: Double {
        Double(durationHours * 3600 + durationMinutes * 60 + durationSeconds)
    }

    private var distanceMeters: Double? {
        guard let km = Double(distanceKm.replacingOccurrences(of: ",", with: ".")),
              km > 0 else { return nil }
        return km * 1000
    }

    /// Common activity types for the picker.
    private var commonActivityTypes: [HKWorkoutActivityType] {
        [
            .running,
            .walking,
            .cycling,
            .elliptical,
            .rowing,
            .stairClimbing,
            .highIntensityIntervalTraining,
            .mixedCardio,
        ]
    }

    // MARK: - Actions

    private func saveWorkout() {
        // Calculate orderIndex for the new cardio workout
        let orderIndex = calculateNextOrderIndex()

        let workout = CardioWorkout(
            activityType: Int(selectedActivityType.rawValue),
            startDate: workoutDate,
            duration: totalDurationSeconds,
            totalDistance: distanceMeters,
            isCompleted: false,
            workoutDayId: workoutDayId,
            orderIndex: orderIndex,
            source: .manual,
            profile: profile
        )

        modelContext.insert(workout)

        do {
            try modelContext.save()
            onSave?()
            dismiss()
        } catch {
            print("CardioWorkoutEditorView: Failed to save: \(error)")
        }
    }

    /// Calculates the next order index for cardio workouts linked to the same workout day.
    private func calculateNextOrderIndex() -> Int {
        guard let dayId = workoutDayId else { return 0 }

        var descriptor = FetchDescriptor<CardioWorkout>(
            predicate: #Predicate { $0.workoutDayId == dayId }
        )
        descriptor.sortBy = [SortDescriptor(\.orderIndex, order: .reverse)]
        descriptor.fetchLimit = 1

        do {
            let existing = try modelContext.fetch(descriptor)
            return (existing.first?.orderIndex ?? -1) + 1
        } catch {
            return 0
        }
    }
}
