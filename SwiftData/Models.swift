//
//  Models.swift
//  Focus Forest Adventure
//
//  SwiftData model layer. All models are CloudKit-sync compatible:
//  every attribute has a default, relationships are optional, no unique constraints.
//

import Foundation
import SwiftData

// MARK: - Child

@Model
final class ChildProfile {
    var name: String = ""
    /// Age-based content: word targets already shown in ABC word missions.
    /// Cleared automatically when the whole WordBank has been used once.
    var usedWordsRaw: [String] = []
    var avatarEmoji: String = "🐰"
    var birthYear: Int = 2021
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \MissionRecord.child)
    var missions: [MissionRecord]? = []

    @Relationship(deleteRule: .cascade, inverse: \ForestState.child)
    var forest: ForestState?

    @Relationship(deleteRule: .cascade, inverse: \DailyGoal.child)
    var dailyGoals: [DailyGoal]? = []

    @Relationship(deleteRule: .cascade, inverse: \SessionRecord.child)
    var sessions: [SessionRecord]? = []

    @Relationship(deleteRule: .cascade, inverse: \AchievementRecord.child)
    var achievements: [AchievementRecord]? = []

    @Relationship(deleteRule: .cascade, inverse: \StoryRecord.child)
    var stories: [StoryRecord]? = []

    init(name: String, avatarEmoji: String = "🐰", birthYear: Int = 2021) {
        self.name = name
        self.avatarEmoji = avatarEmoji
        self.birthYear = birthYear
    }
}

// MARK: - Mission

@Model
final class MissionRecord {
    var adventureKindRaw: String = AdventureKind.alphabet.rawValue
    var missionTypeRaw: String = ""
    var difficulty: Int = 1                 // 1...5
    var startedAt: Date = Date()
    var completedAt: Date?
    var correctAnswers: Int = 0
    var wrongAnswers: Int = 0
    var totalQuestions: Int = 0
    var averageResponseTime: TimeInterval = 0
    var starsEarned: Int = 0
    var endedEarly: Bool = false            // auto-ended before frustration
    var child: ChildProfile?

    var adventureKind: AdventureKind {
        get { AdventureKind(rawValue: adventureKindRaw) ?? .alphabet }
        set { adventureKindRaw = newValue.rawValue }
    }

    var accuracy: Double {
        let total = correctAnswers + wrongAnswers
        guard total > 0 else { return 0 }
        return Double(correctAnswers) / Double(total)
    }

    init(adventureKind: AdventureKind, missionType: String, difficulty: Int) {
        self.adventureKindRaw = adventureKind.rawValue
        self.missionTypeRaw = missionType
        self.difficulty = difficulty
    }
}

// MARK: - Forest

@Model
final class ForestState {
    var level: Int = 1                      // 1...8 (empty land → magic forest)
    var experience: Int = 0
    var seeds: Int = 0
    var flowers: Int = 0
    var magicDust: Int = 0
    var stars: Int = 0
    var unlockedElementsRaw: [String] = []  // ForestElement raw values
    var child: ChildProfile?

    var unlockedElements: [ForestElement] {
        get { unlockedElementsRaw.compactMap(ForestElement.init(rawValue:)) }
        set { unlockedElementsRaw = newValue.map(\.rawValue) }
    }

    init() {}
}

/// Unlockable forest decorations, in unlock order.
enum ForestElement: String, CaseIterable, Codable, Sendable {
    case grass, flowers, trees, butterflies, animals, river, rainbow, treehouse, castle, dragon

    var localizedName: String {
        switch self {
        case .grass: String(localized: "Soft Grass")
        case .flowers: String(localized: "Wildflowers")
        case .trees: String(localized: "Tall Trees")
        case .butterflies: String(localized: "Butterflies")
        case .animals: String(localized: "Forest Friends")
        case .river: String(localized: "Sparkling River")
        case .rainbow: String(localized: "Rainbow")
        case .treehouse: String(localized: "Treehouse")
        case .castle: String(localized: "Magic Castle")
        case .dragon: String(localized: "Friendly Dragon")
        }
    }

    var emoji: String {
        switch self {
        case .grass: "🌿"
        case .flowers: "🌸"
        case .trees: "🌳"
        case .butterflies: "🦋"
        case .animals: "🦊"
        case .river: "🏞️"
        case .rainbow: "🌈"
        case .treehouse: "🏡"
        case .castle: "🏰"
        case .dragon: "🐉"
        }
    }

    /// Forest XP needed to unlock.
    var requiredXP: Int {
        switch self {
        case .grass: 20; case .flowers: 60; case .trees: 120
        case .butterflies: 200; case .animals: 300; case .river: 430
        case .rainbow: 580; case .treehouse: 760; case .castle: 980
        case .dragon: 1250
        }
    }
}

// MARK: - Daily Goal

@Model
final class DailyGoal {
    var date: Date = Date()
    var targetMissions: Int = 3
    var completedMissions: Int = 0
    var totalFocusSeconds: TimeInterval = 0
    var child: ChildProfile?

    var isComplete: Bool { completedMissions >= targetMissions }
    var progress: Double {
        min(1, Double(completedMissions) / Double(max(1, targetMissions)))
    }

    init(date: Date = .now, targetMissions: Int = 3) {
        self.date = date
        self.targetMissions = targetMissions
    }
}

// MARK: - Session (one continuous play period)

@Model
final class SessionRecord {
    var startedAt: Date = Date()
    var endedAt: Date?
    var missionsCompleted: Int = 0
    var attentionScore: Double = 0          // 0...1, derived from response consistency
    var child: ChildProfile?

    var duration: TimeInterval {
        (endedAt ?? .now).timeIntervalSince(startedAt)
    }

    init() {}
}

// MARK: - Story

@Model
final class StoryRecord {
    var title: String = ""
    var pagesRaw: [String] = []
    var createdAt: Date = Date()
    var adventureKindRaw: String = AdventureKind.alphabet.rawValue
    var forestLevel: Int = 1
    var treesPlanted: Int = 0
    var unlockedAnimalsRaw: [String] = []
    var achievementIDsRaw: [String] = []
    var childNickname: String = ""
    var favoriteActivityRaw: String = AdventureKind.alphabet.rawValue
    var isOfflineGenerated: Bool = true
    /// Phase 2.8: recommended story flavor used for this story.
    var themeRaw: String = StoryTheme.friendship.rawValue
    var child: ChildProfile?

    var theme: StoryTheme {
        get { StoryTheme(rawValue: themeRaw) ?? .friendship }
        set { themeRaw = newValue.rawValue }
    }

    var pages: [String] {
        get { pagesRaw }
        set { pagesRaw = newValue }
    }

    var adventureKind: AdventureKind {
        get { AdventureKind(rawValue: adventureKindRaw) ?? .alphabet }
        set { adventureKindRaw = newValue.rawValue }
    }

    var favoriteActivity: AdventureKind {
        get { AdventureKind(rawValue: favoriteActivityRaw) ?? .alphabet }
        set { favoriteActivityRaw = newValue.rawValue }
    }

    var unlockedAnimals: [ForestElement] {
        get { unlockedAnimalsRaw.compactMap(ForestElement.init(rawValue:)) }
        set { unlockedAnimalsRaw = newValue.map(\.rawValue) }
    }

    var achievementIDs: [AchievementID] {
        get { achievementIDsRaw.compactMap(AchievementID.init(rawValue:)) }
        set { achievementIDsRaw = newValue.map(\.rawValue) }
    }

    init(
        title: String,
        pages: [String],
        adventureKind: AdventureKind,
        forestLevel: Int,
        treesPlanted: Int,
        unlockedAnimals: [ForestElement],
        achievementIDs: [AchievementID],
        childNickname: String,
        favoriteActivity: AdventureKind,
        isOfflineGenerated: Bool = true,
        theme: StoryTheme = .friendship
    ) {
        self.title = title
        self.pagesRaw = pages
        self.adventureKindRaw = adventureKind.rawValue
        self.forestLevel = forestLevel
        self.treesPlanted = treesPlanted
        self.unlockedAnimalsRaw = unlockedAnimals.map(\.rawValue)
        self.achievementIDsRaw = achievementIDs.map(\.rawValue)
        self.childNickname = childNickname
        self.favoriteActivityRaw = favoriteActivity.rawValue
        self.isOfflineGenerated = isOfflineGenerated
        self.themeRaw = theme.rawValue
    }
}

// MARK: - Achievement

@Model
final class AchievementRecord {
    var achievementIDRaw: String = ""
    var earnedAt: Date = Date()
    var child: ChildProfile?

    var achievementID: AchievementID? { AchievementID(rawValue: achievementIDRaw) }

    init(achievementID: AchievementID) {
        self.achievementIDRaw = achievementID.rawValue
    }
}

enum AchievementID: String, CaseIterable, Codable, Sendable {
    case firstMission, threeDayStreak, sevenDayStreak
    case tenMissions, fiftyMissions
    case letterExplorer, numberWizard, shapeMaster, colorArtist
    case memoryChampion, listeningStar, animalFriend
    case forestLevel3, forestLevel5, magicForest

    var localizedTitle: String {
        switch self {
        case .firstMission: String(localized: "First Adventure!")
        case .threeDayStreak: String(localized: "3-Day Explorer")
        case .sevenDayStreak: String(localized: "Week of Wonder")
        case .tenMissions: String(localized: "10 Missions!")
        case .fiftyMissions: String(localized: "Super Explorer")
        case .letterExplorer: String(localized: "Letter Explorer")
        case .numberWizard: String(localized: "Number Wizard")
        case .shapeMaster: String(localized: "Shape Master")
        case .colorArtist: String(localized: "Color Artist")
        case .memoryChampion: String(localized: "Memory Champion")
        case .listeningStar: String(localized: "Listening Star")
        case .animalFriend: String(localized: "Animal Friend")
        case .forestLevel3: String(localized: "Growing Forest")
        case .forestLevel5: String(localized: "Blooming Forest")
        case .magicForest: String(localized: "Magic Forest!")
        }
    }

    var emoji: String {
        switch self {
        case .firstMission: "🌟"
        case .threeDayStreak: "🔥"
        case .sevenDayStreak: "🏆"
        case .tenMissions: "🎖️"
        case .fiftyMissions: "👑"
        case .letterExplorer: "🔤"
        case .numberWizard: "🔢"
        case .shapeMaster: "🔷"
        case .colorArtist: "🎨"
        case .memoryChampion: "🧠"
        case .listeningStar: "👂"
        case .animalFriend: "🦁"
        case .forestLevel3: "🌱"
        case .forestLevel5: "🌳"
        case .magicForest: "✨"
        }
    }
}
