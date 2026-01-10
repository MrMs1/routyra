//
//  RestTimePickerCompact.swift
//  Routyra
//
//  A compact inline picker for rest time that opens a sheet with min/sec picker.
//  Used in set editors for configuring rest time per set.
//

import SwiftUI

struct RestTimePickerCompact: View {
    @Binding var restTimeSeconds: Int
    @State private var isEditing = false

    private var formatted: String {
        let mins = restTimeSeconds / 60
        let secs = restTimeSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var body: some View {
        Button {
            isEditing = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.caption2)
                Text(formatted)
                    .font(.caption)
                    .lineLimit(1)
            }
            .fixedSize()
            .foregroundColor(restTimeSeconds > 0 ? AppColors.textSecondary : AppColors.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppColors.background)
            .cornerRadius(6)
        }
        .sheet(isPresented: $isEditing) {
            RestTimePickerSheet(restTimeSeconds: $restTimeSeconds)
        }
    }
}

struct RestTimePickerSheet: View {
    @Binding var restTimeSeconds: Int
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMinutes: Int = 0
    @State private var selectedSeconds: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("rest_time_picker_title")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.top)

                HStack(spacing: 16) {
                    // Minutes picker
                    VStack(spacing: 4) {
                        Text("rest_time_minutes")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Picker("", selection: $selectedMinutes) {
                            ForEach(0...20, id: \.self) { min in
                                Text("\(min)").tag(min)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 150)
                        .clipped()
                    }

                    Text(":")
                        .font(.title)
                        .foregroundColor(AppColors.textSecondary)

                    // Seconds picker
                    VStack(spacing: 4) {
                        Text("rest_time_seconds")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Picker("", selection: $selectedSeconds) {
                            ForEach(0..<60, id: \.self) { sec in
                                Text(String(format: "%02d", sec)).tag(sec)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80, height: 150)
                        .clipped()
                    }
                }

                // Preview
                Text(formattedPreview)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()
            }
            .padding()
            .background(AppColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") {
                        restTimeSeconds = selectedMinutes * 60 + selectedSeconds
                        dismiss()
                    }
                    .foregroundColor(AppColors.accentBlue)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            selectedMinutes = restTimeSeconds / 60
            selectedSeconds = restTimeSeconds % 60
        }
    }

    private var formattedPreview: String {
        String(format: "%d:%02d", selectedMinutes, selectedSeconds)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var restTime = 90

        var body: some View {
            VStack(spacing: 20) {
                RestTimePickerCompact(restTimeSeconds: $restTime)
                Text("Rest: \(restTime) seconds")
            }
            .padding()
            .background(AppColors.cardBackground)
        }
    }

    return PreviewWrapper()
        .preferredColorScheme(.dark)
}
