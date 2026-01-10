//
//  DateUtilities.swift
//  Routyra
//
//  Date utility functions for normalizing and comparing dates.
//  All operations use the local calendar/timezone.
//  These are pure functions with no side effects.
//

import Foundation

/// Utility functions for date handling in the workout context.
/// Uses local calendar for all operations.
/// Note: All methods are nonisolated since they're pure date calculations.
enum DateUtilities {
    /// The calendar used for all date operations (local timezone).
    private nonisolated(unsafe) static var calendar: Calendar {
        Calendar.current
    }

    // MARK: - Normalization

    /// Normalizes a date to the start of the local day (midnight).
    /// This ensures consistent date comparisons regardless of time.
    /// - Parameter date: The date to normalize.
    /// - Returns: The date normalized to 00:00:00 local time.
    nonisolated static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    /// Gets today's date normalized to start of day.
    nonisolated static var today: Date {
        startOfDay(Date())
    }

    // MARK: - Comparison

    /// Checks if two dates are on the same local day.
    /// - Parameters:
    ///   - date1: First date.
    ///   - date2: Second date.
    /// - Returns: True if both dates are on the same day.
    nonisolated static func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        Calendar.current.isDate(date1, inSameDayAs: date2)
    }

    /// Checks if the given date is today.
    /// - Parameter date: The date to check.
    /// - Returns: True if the date is today.
    nonisolated static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Checks if the given date is yesterday.
    /// - Parameter date: The date to check.
    /// - Returns: True if the date is yesterday.
    nonisolated static func isYesterday(_ date: Date) -> Bool {
        Calendar.current.isDateInYesterday(date)
    }

    // MARK: - Arithmetic

    /// Adds days to a date.
    /// - Parameters:
    ///   - days: Number of days to add (can be negative).
    ///   - date: The base date.
    /// - Returns: The resulting date, or nil if calculation fails.
    nonisolated static func addDays(_ days: Int, to date: Date) -> Date? {
        Calendar.current.date(byAdding: .day, value: days, to: date)
    }

    /// Gets the number of days between two dates.
    /// - Parameters:
    ///   - from: Start date.
    ///   - to: End date.
    /// - Returns: Number of days, or nil if calculation fails.
    nonisolated static func daysBetween(_ from: Date, and to: Date) -> Int? {
        Calendar.current.dateComponents([.day], from: startOfDay(from), to: startOfDay(to)).day
    }

    // MARK: - Week Handling

    /// Gets the start of the week containing the given date.
    /// - Parameter date: A date within the week.
    /// - Returns: The start of the week (typically Sunday or Monday depending on locale).
    nonisolated static func startOfWeek(containing date: Date) -> Date? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components)
    }

    /// Gets the start of the week (Monday) containing the given date.
    /// Always uses Monday as the first day of the week (ISO 8601).
    /// - Parameter date: A date within the week.
    /// - Returns: The Monday at 00:00:00 of the week containing the date.
    nonisolated static func startOfWeekMonday(containing date: Date) -> Date? {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components)
    }

    /// Gets the weekday index (0 = Monday, 6 = Sunday in ISO calendar).
    /// Adjusted for display where Monday = 0.
    /// - Parameter date: The date to check.
    /// - Returns: The weekday index (0-6).
    nonisolated static func weekdayIndex(for date: Date) -> Int {
        let weekday = Calendar.current.component(.weekday, from: date)
        // Adjust: Sunday = 1 in Calendar, we want Monday = 0
        return (weekday + 5) % 7
    }

    // MARK: - Workout Day Calculation

    /// Calculates the "workout date" for a given time, accounting for the day transition hour.
    /// For example, if transitionHour is 3 (3:00 AM), a time of 2:00 AM on Dec 16
    /// would return Dec 15 (still counted as the previous workout day).
    /// - Parameters:
    ///   - date: The actual date/time.
    ///   - transitionHour: The hour at which the workout day transitions (0-23).
    /// - Returns: The effective workout date (normalized to start of day).
    nonisolated static func workoutDate(for date: Date, transitionHour: Int) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        // If current time is before the transition hour, it belongs to the previous day
        if hour < transitionHour {
            if let previousDay = calendar.date(byAdding: .day, value: -1, to: date) {
                return startOfDay(previousDay)
            }
        }

        return startOfDay(date)
    }

    /// Gets today's workout date, accounting for the transition hour.
    /// - Parameter transitionHour: The hour at which the workout day transitions (0-23).
    /// - Returns: The effective workout date for right now.
    nonisolated static func todayWorkoutDate(transitionHour: Int) -> Date {
        workoutDate(for: Date(), transitionHour: transitionHour)
    }

    /// Checks if the given date falls on today's workout day, accounting for transition hour.
    /// - Parameters:
    ///   - date: The date to check.
    ///   - transitionHour: The hour at which the workout day transitions (0-23).
    /// - Returns: True if the date is on today's workout day.
    nonisolated static func isWorkoutToday(_ date: Date, transitionHour: Int) -> Bool {
        let todayWorkout = todayWorkoutDate(transitionHour: transitionHour)
        let dateWorkout = workoutDate(for: date, transitionHour: transitionHour)
        return isSameDay(todayWorkout, dateWorkout)
    }

    /// Checks if two dates are on the same workout day, accounting for transition hour.
    /// - Parameters:
    ///   - date1: First date.
    ///   - date2: Second date.
    ///   - transitionHour: The hour at which the workout day transitions (0-23).
    /// - Returns: True if both dates are on the same workout day.
    nonisolated static func isSameWorkoutDay(_ date1: Date, _ date2: Date, transitionHour: Int) -> Bool {
        let workout1 = workoutDate(for: date1, transitionHour: transitionHour)
        let workout2 = workoutDate(for: date2, transitionHour: transitionHour)
        return isSameDay(workout1, workout2)
    }

    // MARK: - Formatting

    /// Formats a date for display (e.g., "Mon, Dec 15").
    /// - Parameter date: The date to format.
    /// - Returns: Formatted date string.
    nonisolated static func formatShort(_ date: Date) -> String {
        Formatters.shortDate.string(from: date)
    }

    /// Formats a date for full display (e.g., "December 15, 2024").
    /// - Parameter date: The date to format.
    /// - Returns: Formatted date string.
    nonisolated static func formatFull(_ date: Date) -> String {
        Formatters.fullDate.string(from: date)
    }

    // MARK: - Month Utilities

    /// Gets the start of the month for the given date.
    /// - Parameters:
    ///   - date: A date within the month.
    ///   - calendar: The calendar to use (defaults to current).
    /// - Returns: The first day of the month at 00:00:00.
    nonisolated static func startOfMonth(for date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
