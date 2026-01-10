//
//  CardioTimeDistanceEntryView.swift
//  Routyra
//
//  Time/distance input sheet for cardio entries (activity already selected).
//

import SwiftUI

struct CardioTimeDistanceEntryView: View {
    let navigationTitle: String
    let confirmButtonTitle: String
    let onConfirm: (Int, Double?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var durationHours: Int
    @State private var durationMinutes: Int
    @State private var durationSeconds: Int
    @State private var distanceKm: String

    init(
        navigationTitle: String = L10n.tr("cardio_add_workout"),
        confirmButtonTitle: String = L10n.tr("save"),
        initialDurationSeconds: Int = 1800,
        initialDistanceMeters: Double? = nil,
        onConfirm: @escaping (Int, Double?) -> Void
    ) {
        self.navigationTitle = navigationTitle
        self.confirmButtonTitle = confirmButtonTitle
        self.onConfirm = onConfirm

        let hours = max(0, initialDurationSeconds) / 3600
        let minutes = (max(0, initialDurationSeconds) % 3600) / 60
        let seconds = max(0, initialDurationSeconds) % 60

        _durationHours = State(initialValue: hours)
        _durationMinutes = State(initialValue: minutes)
        _durationSeconds = State(initialValue: seconds)

        if let meters = initialDistanceMeters, meters > 0 {
            _distanceKm = State(initialValue: String(format: "%.1f", meters / 1000))
        } else {
            _distanceKm = State(initialValue: "")
        }
    }

    private var totalDurationSeconds: Int {
        durationHours * 3600 + durationMinutes * 60 + durationSeconds
    }

    private var distanceMeters: Double? {
        guard let km = Double(distanceKm.replacingOccurrences(of: ",", with: ".")),
              km > 0 else { return nil }
        return km * 1000
    }

    private var isValid: Bool {
        totalDurationSeconds > 0
    }

    var body: some View {
        Form {
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
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.tr("cancel")) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(confirmButtonTitle) {
                    onConfirm(totalDurationSeconds, distanceMeters)
                    dismiss()
                }
                .disabled(!isValid)
            }
        }
    }
}
