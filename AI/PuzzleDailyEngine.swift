//
//  PuzzleDailyEngine.swift
//  Focus Forest Adventure
//
//  The come-back-tomorrow layer: today's puzzle, the mystery chest, the
//  streak ladder, and the weekend challenge. Pure and Sendable — dates come
//  in as parameters so every rule is testable without waiting for Saturday.
//
//  Deliberately gentle: a missed day costs the streak *multiplier*, never
//  anything the child already owns, and there is no countdown timer anywhere.
//  The reward for coming back is a bigger welcome, not relief from a
//  punishment.
//

import Foundation

/// One entry on the seven-day ladder.
struct StreakReward: Hashable, Sendable {
    let day: Int
    let gems: Int
    let emoji: String

    var isChest: Bool { day == 7 }
}

/// What today looks like on the map screen.
struct DailyActivities: Hashable, Sendable {
    var streakDays: Int
    /// Today's puzzle, if a world is open.
    var hasDailyPuzzle: Bool
    var dailyPuzzleDone: Bool
    /// The chest is opened by finishing today's puzzle.
    var chestAvailable: Bool
    var chestOpened: Bool
    /// Saturday and Sunday: a longer challenge worth double gems.
    var isWeekend: Bool
    var weekendChallengeDone: Bool
    var todaysReward: StreakReward
    var nextReward: StreakReward?
}

struct PuzzleDailyEngine: Sendable {

    /// Seven rungs, then it loops. Day 7 is the mystery chest.
    static let ladder: [StreakReward] = [
        StreakReward(day: 1, gems: 10, emoji: "💎"),
        StreakReward(day: 2, gems: 15, emoji: "💎"),
        StreakReward(day: 3, gems: 20, emoji: "✨"),
        StreakReward(day: 4, gems: 25, emoji: "✨"),
        StreakReward(day: 5, gems: 35, emoji: "🌟"),
        StreakReward(day: 6, gems: 45, emoji: "🌟"),
        StreakReward(day: 7, gems: 100, emoji: "🎁")
    ]

    func reward(forStreakDay day: Int) -> StreakReward {
        guard day > 0 else { return Self.ladder[0] }
        let index = (day - 1) % Self.ladder.count
        return Self.ladder[index]
    }

    func isWeekend(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDateInWeekend(date)
    }

    /// The mystery chest: a small pile of gems, weighted so a big win is rare
    /// enough to feel like one. Seeded by the day, so shaking the device (or
    /// relaunching) can't reroll it.
    func chestReward(day: Date, streakDays: Int, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        let seed = UInt64((components.year ?? 2000) * 10_000
                          + (components.month ?? 1) * 100
                          + (components.day ?? 1))
        var rng = SeededGenerator(seed: seed &* 6_364_136_223_846_793_005)
        let roll = Int.random(in: 0..<100, using: &rng)
        let base: Int
        switch roll {
        case ..<50: base = 20
        case ..<80: base = 40
        case ..<95: base = 75
        default:    base = 150
        }
        // A long streak nudges the floor up — turning up matters more than luck.
        return base + min(streakDays, 14) * 5
    }

    /// Weekend challenges are longer and pay double.
    func weekendChallengeCount(difficulty: Int) -> Int {
        8 + min(difficulty, 8) / 2
    }

    func weekendBonusMultiplier() -> Int { 2 }

    func activities(
        streakDays: Int,
        hasUnlockedWorld: Bool,
        dailyPuzzleDone: Bool,
        chestOpened: Bool,
        weekendChallengeDone: Bool,
        date: Date,
        calendar: Calendar = .current
    ) -> DailyActivities {
        DailyActivities(
            streakDays: streakDays,
            hasDailyPuzzle: hasUnlockedWorld,
            dailyPuzzleDone: dailyPuzzleDone,
            // The chest is the reward for showing up *and* playing, so it
            // needs today's puzzle finished first.
            chestAvailable: dailyPuzzleDone && !chestOpened,
            chestOpened: chestOpened,
            isWeekend: isWeekend(date, calendar: calendar),
            weekendChallengeDone: weekendChallengeDone,
            todaysReward: reward(forStreakDay: max(streakDays, 1)),
            nextReward: reward(forStreakDay: max(streakDays, 1) + 1)
        )
    }
}

// MARK: - Per-day flags

/// Small day-scoped flags (today's puzzle done, chest opened). These are
/// UI state, not progress, so they live in UserDefaults rather than in the
/// synced store — a chest opened on the iPad shouldn't vanish because the
/// iPhone synced later.
@MainActor
enum DailyPuzzleLog {

    private static let defaults = UserDefaults.standard

    private static func key(_ name: String, for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "puzzle.daily.\(name).\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    static func isDone(_ name: String, on date: Date = .now) -> Bool {
        defaults.bool(forKey: key(name, for: date))
    }

    static func markDone(_ name: String, on date: Date = .now) {
        defaults.set(true, forKey: key(name, for: date))
    }

    static let dailyPuzzle = "puzzle"
    static let chest = "chest"
    static let weekend = "weekend"
}
