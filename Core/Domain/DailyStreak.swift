//
//  DailyStreak.swift
//  Focus Forest Adventure
//
//  Daily learning streak: any completed mission, quiz, or traced letter
//  counts as activity for the day. Pure date logic with injectable
//  "now" for testability; storage is UserDefaults (device-local).
//

import Foundation

enum DailyStreak {

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Call whenever the child completes something. Same-day calls are
    /// no-ops; consecutive days extend the streak; gaps reset it to 1.
    static func recordActivity(on date: Date = .now, calendar: Calendar = .current) {
        let defaults = UserDefaults.standard
        let today = dayKey(date, calendar: calendar)
        let last = defaults.string(forKey: "streak.lastDay")
        guard last != today else { return }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: date)
            .map { dayKey($0, calendar: calendar) }
        let count = (last == yesterday) ? defaults.integer(forKey: "streak.count") + 1 : 1
        defaults.set(count, forKey: "streak.count")
        defaults.set(today, forKey: "streak.lastDay")
    }

    /// Current streak in days; 0 when the chain is broken (no activity
    /// today or yesterday).
    static func current(asOf date: Date = .now, calendar: Calendar = .current) -> Int {
        let defaults = UserDefaults.standard
        guard let last = defaults.string(forKey: "streak.lastDay") else { return 0 }
        let today = dayKey(date, calendar: calendar)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date)
            .map { dayKey($0, calendar: calendar) }
        guard last == today || last == yesterday else { return 0 }
        return defaults.integer(forKey: "streak.count")
    }
}

// MARK: - Daily usage (screen-time limit support)

enum DailyUsage {

    static func addSeconds(_ seconds: Int, on date: Date = .now) {
        let key = "usage.\(DailyStreak.dayKey(date))"
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: key) + seconds, forKey: key)
    }

    static func todayMinutes(asOf date: Date = .now) -> Int {
        UserDefaults.standard.integer(forKey: "usage.\(DailyStreak.dayKey(date))") / 60
    }
}
