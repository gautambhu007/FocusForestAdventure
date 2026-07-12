//
//  DashboardInsights.swift
//  Focus Forest Adventure
//
//  Phase 2.3: pure aggregation for the parent dashboard — week-over-week
//  trend and streaks, computed from the daily focus map. No I/O, fully
//  unit-testable.
//

import Foundation

struct DashboardInsights: Sendable, Equatable {

    /// Consecutive days (ending today or yesterday) with any focus time.
    var currentStreakDays: Int = 0
    /// Focus minutes in the last 7 days.
    var thisWeekMinutes: Int = 0
    /// Focus minutes in the 7 days before that.
    var previousWeekMinutes: Int = 0
    /// Week-over-week change in percent; nil when there's no baseline yet.
    var weeklyTrendPercent: Int?

    static func compute(
        dailyFocus: [Date: TimeInterval],
        calendar: Calendar = .current,
        today: Date = .now
    ) -> DashboardInsights {
        var insights = DashboardInsights()
        let startOfToday = calendar.startOfDay(for: today)

        // Normalize keys to start-of-day so lookups are reliable.
        var byDay: [Date: TimeInterval] = [:]
        for (date, seconds) in dailyFocus {
            byDay[calendar.startOfDay(for: date), default: 0] += seconds
        }

        // Streak: walk backwards from today; a missing TODAY doesn't break
        // the streak (the child simply hasn't played yet today).
        var cursor = startOfToday
        if byDay[cursor, default: 0] <= 0 {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while byDay[cursor, default: 0] > 0 {
            insights.currentStreakDays += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        // Week windows: [today-6, today] and [today-13, today-7].
        func minutes(daysBack range: ClosedRange<Int>) -> Int {
            var total: TimeInterval = 0
            for back in range {
                if let day = calendar.date(byAdding: .day, value: -back, to: startOfToday) {
                    total += byDay[day, default: 0]
                }
            }
            return Int(total / 60)
        }
        insights.thisWeekMinutes = minutes(daysBack: 0...6)
        insights.previousWeekMinutes = minutes(daysBack: 7...13)

        if insights.previousWeekMinutes > 0 {
            let change = Double(insights.thisWeekMinutes - insights.previousWeekMinutes)
                / Double(insights.previousWeekMinutes) * 100
            insights.weeklyTrendPercent = Int(change.rounded())
        }
        return insights
    }
}
