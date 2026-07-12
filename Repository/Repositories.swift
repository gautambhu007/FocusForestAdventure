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
