//
//  GameEngines.swift
//  Focus Forest Adventure
//
//  RewardEngine, ForestGrowthEngine, AchievementEngine — pure game logic,
//  fully deterministic and unit-testable.
//

import Foundation

// MARK: - Reward Engine

struct RewardEngine: Sendable {

    /// Compute the reward bundle for a finished mission.
    /// Effort is always rewarded — even an early-ended mission earns something.
    func rewards(
        for outcome: MissionOutcome,
        difficulty: Int,
        questionsAnswered: Int
    ) -> RewardBundle {
        var bundle = RewardBundle()

        // Stars: 1 for playing, up to 3 for mastery. Never zero.
        bundle.stars = switch outcome.accuracy {
        case 0.85...: 3
        case 0.6..<0.85: 2
        default: 1
        }

        // Seeds grow with effort (questions answered), not perfection.
        bundle.seeds = max(1, questionsAnswered / 2)

        // Flowers reward accuracy streaks; magic dust rewards harder levels.
        bundle.flowers = outcome.accuracy >= 0.7 ? difficulty : 1
        bundle.magicDust = difficulty >= 3 ? difficulty - 2 : 0

        // Forest XP is the growth currency: effort + a mastery bonus.
        bundle.forestXP = questionsAnswered * 3
            + bundle.stars * 5
            + difficulty * 2

        bundle.bunnyPhrase = BunnyPhrase.celebration.text
        return bundle
    }
}

// MARK: - Forest Growth Engine

struct ForestGrowthEngine: Sendable {

    /// Forest levels 1–8: empty land → grass → flowers → trees → animals → river → castle → magic forest.
    static let levelThresholds = [0, 50, 140, 280, 460, 700, 1000, 1400]

    func level(forXP xp: Int) -> Int {
        var level = 1
        for (index, threshold) in Self.levelThresholds.enumerated() where xp >= threshold {
            level = index + 1
        }
        return level
    }

    /// Progress (0...1) toward the next level.
    func progressToNextLevel(xp: Int) -> Double {
        let current = level(forXP: xp)
        guard current < Self.levelThresholds.count else { return 1 }
        let floor = Self.levelThresholds[current - 1]
        let ceiling = Self.levelThresholds[current]
        return (Double(xp - floor) / Double(ceiling - floor)).clamped(to: 0...1)
    }

    /// Apply a reward to the forest; returns newly unlocked elements.
    @MainActor
    func apply(_ bundle: RewardBundle, to forest: ForestState) -> [ForestElement] {
        forest.stars += bundle.stars
        forest.seeds += bundle.seeds
        forest.flowers += bundle.flowers
        forest.magicDust += bundle.magicDust
        forest.experience += bundle.forestXP
        forest.level = level(forXP: forest.experience)

        var newlyUnlocked: [ForestElement] = []
        for element in ForestElement.allCases
        where forest.experience >= element.requiredXP && !forest.unlockedElements.contains(element) {
            forest.unlockedElements.append(element)
            newlyUnlocked.append(element)
        }
        return newlyUnlocked
    }

    func localizedLevelName(_ level: Int) -> String {
        switch level {
        case 1: String(localized: "Sleepy Meadow")
        case 2: String(localized: "Green Grassland")
        case 3: String(localized: "Flower Field")
        case 4: String(localized: "Young Woods")
        case 5: String(localized: "Friendly Forest")
        case 6: String(localized: "River Valley")
        case 7: String(localized: "Castle Grove")
        default: String(localized: "Magic Forest")
        }
    }
}

// MARK: - Achievement Engine

@MainActor
struct AchievementEngine {
    let repository: any AchievementRepository

    /// Evaluate all achievement rules after a mission; returns newly earned IDs.
    func evaluate(child: ChildProfile, forest: ForestState) throws -> [AchievementID] {
        let missions = child.missions ?? []
        let earnedIDs = Set((child.achievements ?? []).compactMap(\.achievementID))
        var newlyEarned: [AchievementID] = []

        func check(_ id: AchievementID, _ condition: @autoclosure () -> Bool) throws {
            guard !earnedIDs.contains(id), condition() else { return }
            try repository.award(id, to: child)
            newlyEarned.append(id)
        }

        try check(.firstMission, missions.count >= 1)
        try check(.tenMissions, missions.count >= 10)
        try check(.fiftyMissions, missions.count >= 50)
        try check(.forestLevel3, forest.level >= 3)
        try check(.forestLevel5, forest.level >= 5)
        try check(.magicForest, forest.level >= 8)
        try check(.threeDayStreak, streak(days: 3, missions: missions))
        try check(.sevenDayStreak, streak(days: 7, missions: missions))

        let subjectBadges: [(AchievementID, AdventureKind)] = [
            (.letterExplorer, .alphabet), (.numberWizard, .numbers),
            (.shapeMaster, .shapes), (.colorArtist, .colors),
            (.memoryChampion, .memory), (.listeningStar, .listening),
            (.animalFriend, .animals)
        ]
        for (badge, kind) in subjectBadges {
            try check(badge, missions.filter { $0.adventureKind == kind }.count >= 5)
        }
        return newlyEarned
    }

    private func streak(days: Int, missions: [MissionRecord]) -> Bool {
        let calendar = Calendar.current
        let playedDays = Set(missions.map { calendar.startOfDay(for: $0.startedAt) })
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: .now.startOfDay),
                  playedDays.contains(day) else { return false }
        }
        return true
    }
}
