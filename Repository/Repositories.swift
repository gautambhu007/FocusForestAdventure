//
//  Repositories.swift
//  Focus Forest Adventure
//
//  Repository protocols (domain layer) + SwiftData implementations (data layer).
//  ViewModels and UseCases depend only on the protocols, so tests can inject
//  in-memory fakes without touching SwiftData.
//

import Foundation
import SwiftData

// MARK: - Protocols

@MainActor
protocol ChildRepository {
    func activeChild() throws -> ChildProfile
    func createChild(name: String, avatarEmoji: String) throws -> ChildProfile
    /// Persist in-place edits to the active child (name, avatar).
    func saveChanges() throws
}

@MainActor
protocol MissionRepository {
    func save(_ mission: MissionRecord, for child: ChildProfile) throws
    func missions(for child: ChildProfile, since: Date?) throws -> [MissionRecord]
}

@MainActor
protocol ForestRepository {
    func forest(for child: ChildProfile) throws -> ForestState
    func save() throws
}

@MainActor
protocol StatisticsRepository {
    func todayGoal(for child: ChildProfile) throws -> DailyGoal
    func performanceSummary(for child: ChildProfile, days: Int) throws -> PerformanceSummary
    func beginSession(for child: ChildProfile) throws -> SessionRecord
    func save() throws
}

@MainActor
protocol AchievementRepository {
    func earned(for child: ChildProfile) throws -> [AchievementRecord]
    func award(_ id: AchievementID, to child: ChildProfile) throws
}

@MainActor
protocol StoryRepository {
    func save(_ story: StoryRecord, for child: ChildProfile) throws
    func stories(for child: ChildProfile) throws -> [StoryRecord]
    func latestStory(for child: ChildProfile) throws -> StoryRecord?
}

@MainActor
protocol CustomWordRepository {
    func words(for child: ChildProfile) throws -> [CustomWord]
    func add(_ text: String, for child: ChildProfile) throws
    func delete(_ word: CustomWord) throws
}

@MainActor
protocol PuzzleRepository {
    /// Everything the progression engine needs, in one read.
    func snapshot(for child: ChildProfile) throws -> PuzzleProgressSnapshot
    /// Apply a finished level: progress, per-skill tallies, coins, badges.
    /// Returns the badges newly earned so the UI can celebrate them.
    func record(_ result: PuzzleRunResult, nextDifficulty: Int, for child: ChildProfile) throws -> [PuzzleBadge]
}

// MARK: - Domain value types

/// Aggregated performance snapshot consumed by the AI engines and parent dashboard.
struct PerformanceSummary: Sendable, Equatable {
    var perSubject: [AdventureKind: SubjectStats] = [:]
    var totalMissions: Int = 0
    var totalFocusSeconds: TimeInterval = 0
    var averageAttentionScore: Double = 0
    var dailyFocus: [Date: TimeInterval] = [:]   // for weekly/monthly graphs

    struct SubjectStats: Sendable, Equatable {
        var missions: Int = 0
        var accuracy: Double = 0
        var averageResponseTime: TimeInterval = 0
        var currentDifficulty: Int = 1
        var lastPlayed: Date?
    }
}

// MARK: - SwiftData implementations

@MainActor
final class SwiftDataChildRepository: ChildRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func activeChild() throws -> ChildProfile {
        let descriptor = FetchDescriptor<ChildProfile>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        return try createChild(name: String(localized: "Explorer"), avatarEmoji: "🐰")
    }

    func createChild(name: String, avatarEmoji: String) throws -> ChildProfile {
        let child = ChildProfile(name: name, avatarEmoji: avatarEmoji)
        child.forest = ForestState()
        context.insert(child)
        try context.save()
        return child
    }

    func saveChanges() throws {
        try context.save()
    }
}

@MainActor
final class SwiftDataMissionRepository: MissionRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func save(_ mission: MissionRecord, for child: ChildProfile) throws {
        mission.child = child
        context.insert(mission)
        try context.save()
    }

    func missions(for child: ChildProfile, since: Date?) throws -> [MissionRecord] {
        let all = (child.missions ?? []).sorted { $0.startedAt > $1.startedAt }
        guard let since else { return all }
        return all.filter { $0.startedAt >= since }
    }
}

@MainActor
final class SwiftDataForestRepository: ForestRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func forest(for child: ChildProfile) throws -> ForestState {
        if let forest = child.forest { return forest }
        let forest = ForestState()
        child.forest = forest
        try context.save()
        return forest
    }

    func save() throws { try context.save() }
}

@MainActor
final class SwiftDataStatisticsRepository: StatisticsRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func todayGoal(for child: ChildProfile) throws -> DailyGoal {
        if let goal = child.dailyGoals?.first(where: { $0.date.isSameDay(as: .now) }) {
            return goal
        }
        let goal = DailyGoal(date: .now.startOfDay)
        goal.child = child
        context.insert(goal)
        try context.save()
        return goal
    }

    func performanceSummary(for child: ChildProfile, days: Int) throws -> PerformanceSummary {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        let missions = (child.missions ?? []).filter { $0.startedAt >= cutoff }
        let sessions = (child.sessions ?? []).filter { $0.startedAt >= cutoff }

        var summary = PerformanceSummary()
        summary.totalMissions = missions.count
        summary.averageAttentionScore = sessions.isEmpty
            ? 0
            : sessions.map(\.attentionScore).reduce(0, +) / Double(sessions.count)

        for kind in AdventureKind.allCases {
            let subset = missions.filter { $0.adventureKind == kind }
            guard !subset.isEmpty else { continue }
            var stats = PerformanceSummary.SubjectStats()
            stats.missions = subset.count
            stats.accuracy = subset.map(\.accuracy).reduce(0, +) / Double(subset.count)
            stats.averageResponseTime = subset.map(\.averageResponseTime).reduce(0, +) / Double(subset.count)
            stats.currentDifficulty = subset.max(by: { $0.startedAt < $1.startedAt })?.difficulty ?? 1
            stats.lastPlayed = subset.map(\.startedAt).max()
            summary.perSubject[kind] = stats
        }

        for goal in (child.dailyGoals ?? []) where goal.date >= cutoff {
            summary.dailyFocus[goal.date.startOfDay] = goal.totalFocusSeconds
            summary.totalFocusSeconds += goal.totalFocusSeconds
        }
        return summary
    }

    func beginSession(for child: ChildProfile) throws -> SessionRecord {
        let session = SessionRecord()
        session.child = child
        context.insert(session)
        try context.save()
        return session
    }

    func save() throws { try context.save() }
}

@MainActor
final class SwiftDataStoryRepository: StoryRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func save(_ story: StoryRecord, for child: ChildProfile) throws {
        story.child = child
        context.insert(story)
        try context.save()
    }

    func stories(for child: ChildProfile) throws -> [StoryRecord] {
        (child.stories ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    func latestStory(for child: ChildProfile) throws -> StoryRecord? {
        try stories(for: child).first
    }
}

@MainActor
final class SwiftDataAchievementRepository: AchievementRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func earned(for child: ChildProfile) throws -> [AchievementRecord] {
        (child.achievements ?? []).sorted { $0.earnedAt > $1.earnedAt }
    }

    func award(_ id: AchievementID, to child: ChildProfile) throws {
        guard !(child.achievements ?? []).contains(where: { $0.achievementID == id }) else { return }
        let record = AchievementRecord(achievementID: id)
        record.child = child
        context.insert(record)
        try context.save()
    }
}

@MainActor
final class SwiftDataCustomWordRepository: CustomWordRepository {
    private let context: ModelContext
    init(context: ModelContext) { self.context = context }

    func words(for child: ChildProfile) throws -> [CustomWord] {
        (child.customWords ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    func add(_ text: String, for child: ChildProfile) throws {
        let word = CustomWord(text: text)
        word.child = child
        context.insert(word)
        try context.save()
    }

    func delete(_ word: CustomWord) throws {
        context.delete(word)
        try context.save()
    }
}

@MainActor
final class SwiftDataPuzzleRepository: PuzzleRepository {
    private let context: ModelContext
    private let engine: PuzzleProgressionEngine

    init(context: ModelContext, engine: PuzzleProgressionEngine = PuzzleProgressionEngine()) {
        self.context = context
        self.engine = engine
    }

    func snapshot(for child: ChildProfile) throws -> PuzzleProgressSnapshot {
        var snapshot = PuzzleProgressSnapshot()
        for row in child.puzzleProgress ?? [] {
            snapshot.completedLevels[row.world] = row.completedLevels
            snapshot.difficulty[row.world] = row.difficulty
            snapshot.totalStars += row.starsEarned
            if row.crystalEarned { snapshot.crystals.insert(row.world) }
            // Rebuild the adaptive window from the compact history.
            for (index, accuracy) in row.recentAccuracy.enumerated() {
                snapshot.recentResults.append(
                    PuzzleRunResult(
                        world: row.world,
                        level: row.completedLevels,
                        difficulty: row.difficulty,
                        attempts: [],
                        stars: index < row.recentStars.count ? row.recentStars[index] : 1,
                        gems: 0,
                        accuracy: accuracy
                    )
                )
            }
        }
        snapshot.tallies = (child.puzzleSkillStats ?? []).map {
            PuzzleSkillTally(skill: $0.skill, attempted: $0.attempted, solved: $0.solved)
        }
        snapshot.gems = child.puzzleGems
        snapshot.pieces = child.puzzlePieces
        snapshot.badges = child.puzzleBadges
        snapshot.puzzlesAttempted = child.puzzlesAttempted
        snapshot.puzzlesSolved = child.puzzlesSolved
        snapshot.speedRatioSum = child.puzzleSpeedRatioSum
        snapshot.hintsUsed = child.puzzleHintsUsed
        return snapshot
    }

    func record(
        _ result: PuzzleRunResult,
        nextDifficulty: Int,
        for child: ChildProfile
    ) throws -> [PuzzleBadge] {
        let earned = engine.newBadges(after: result, snapshot: try snapshot(for: child))

        let row = progressRow(for: child, world: result.world)
        // Levels only ever move forward — replaying an old level never
        // rewinds the map.
        row.completedLevels = max(row.completedLevels, result.level)
        row.difficulty = nextDifficulty
        row.starsEarned += result.stars
        if result.earnsCrystal { row.crystalEarned = true }
        row.updatedAt = Date()
        row.recentAccuracy = Array(([result.accuracy] + row.recentAccuracy).prefix(PuzzleProgress.historyLength))
        row.recentStars = Array(([result.stars] + row.recentStars).prefix(PuzzleProgress.historyLength))

        for attempt in result.attempts {
            let stat = skillRow(for: child, skill: attempt.skill)
            stat.attempted += 1
            if attempt.solved { stat.solved += 1 }

            child.puzzlesAttempted += 1
            if attempt.solved { child.puzzlesSolved += 1 }
            if attempt.usedHint { child.puzzleHintsUsed += 1 }
            if attempt.timeLimit > 0 {
                child.puzzleSpeedRatioSum += attempt.duration / attempt.timeLimit
            }
        }

        child.puzzleGems += result.gems
        child.puzzlePieces += result.pieces
        if !earned.isEmpty {
            child.puzzleBadges = child.puzzleBadges.union(earned)
        }

        try context.save()
        return earned
    }

    private func progressRow(for child: ChildProfile, world: PuzzleWorld) -> PuzzleProgress {
        if let existing = (child.puzzleProgress ?? []).first(where: { $0.world == world }) {
            return existing
        }
        let row = PuzzleProgress(world: world)
        row.child = child
        context.insert(row)
        return row
    }

    private func skillRow(for child: ChildProfile, skill: PuzzleSkill) -> PuzzleSkillStat {
        if let existing = (child.puzzleSkillStats ?? []).first(where: { $0.skill == skill }) {
            return existing
        }
        let row = PuzzleSkillStat(skill: skill)
        row.child = child
        context.insert(row)
        return row
    }
}
