//
//  WorkoutHeaderView.swift
//  Routyra
//

import SwiftUI

struct WorkoutHeaderView: View {
    let date: Date
    let streakCount: Int
    let isViewingToday: Bool
    let onDateTap: () -> Void

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter
    }

    var body: some View {
        ZStack {
            Text("workout")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            HStack {
                // Date display
                Button(action: onDateTap) {
                    Text(dateFormatter.string(from: date))
                        .font(.subheadline)
                        .foregroundColor(AppColors.accentBlue)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(AppColors.streakOrange)
                    Text("\(streakCount)")
                        .foregroundColor(AppColors.textPrimary)
                        .fontWeight(.medium)
                }
                .font(.subheadline)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack {
        WorkoutHeaderView(
            date: Date(),
            streakCount: 12,
            isViewingToday: true,
            onDateTap: {}
        )

        WorkoutHeaderView(
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            streakCount: 12,
            isViewingToday: false,
            onDateTap: {}
        )
    }
    .background(AppColors.background)
    .preferredColorScheme(.dark)
}
