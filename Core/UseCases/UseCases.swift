//
//  UseCases.swift
//  Focus Forest Adventure
//
//  Application-layer use cases. Each is a single verb the presentation layer
//  can invoke; they orchestrate repositories and engines.
//

import Foundation

// MARK: - Start Mission

@MainActor
struct StartMissionUseCase {
    let missionRepository: any MissionRepository
    let generator: MissionGeneratorEngine

    /// Generate a personalized mission for the chosen adventure.
    /// `age` switches content style (5+ gets word reading in ABC).
    func execute(
        adventure: AdventureKind,
        child: ChildProfile,
        difficultyEngine: AdaptiveDifficultyEngine,
        preference: DifficultyPreference,
        duration: TimeInterval,
        age: Int = 4,
        additionSection: AdditionSection? = nil
    ) throws -> MissionPlan {
        let history = try missionRepository
            .missions(for: child, since: nil)
            .filter { $0.adventureKind == adventure }
            .prefix(5)
            .map(MissionOutcome.init(record:))

        let current = try missionRepository
            .missions(for: child, since: nil)
            .first { $0.adventureKind == adventure }?
            .difficulty ?? 1

        let difficulty = difficultyEngine.nextDifficulty(
            current: current,
            recentMissions: Array(history),
            preference: preference
        )
        return generator.generateMission(
            adventure: adventure,
            difficulty: difficulty,
            duration: duration,
            age: age,
            usedWords: Set(child.usedWordsRaw),
            additionSection: additionSection
        )
    }
}

// MARK: - Complete Mission

/// Everything the UI needs after a mission ends.
struct MissionCompletionResult: Sendable {
    let rewards: RewardBundle
    let movementBreak: MovementBreak
    let forestLevel: Int
    let goalProgress: Double
}

@MainActor
struct CompleteMissionUseCase {
    let missionRepository: any MissionRepository
    let forestRepository: any ForestRepository
    let statisticsRepository: any StatisticsRepository
    let rewardEngine: RewardEngine
    let growthEngine: ForestGrowthEngine
    let achievementEngine: AchievementEngine
    let difficultyEngine: AdaptiveDifficultyEngine

    func execute(
        plan: MissionPlan,
        child: ChildProfile,
        correct: Int,
        wrong: Int,
        responseTimes: [TimeInterval],
        endedEarly: Bool,
        elapsed: TimeInterval
    ) throws -> MissionCompletionResult {
        // 1. Persist the mission record.
        let record = MissionRecord(
            adventureKind: plan.adventure,
            missionType: plan.missionType.rawValue,
            difficulty: plan.difficulty
        )
        record.correctAnswers = correct
        record.wrongAnswers = wrong
        record.totalQuestions = plan.questions.count
        record.completedAt = .now
        record.endedEarly = endedEarly
        record.averageResponseTime = responseTimes.isEmpty
            ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count)

        // Word missions: consume the ATTEMPTED targets so they never repeat.
        // Unattempted words (early end) stay fresh for the next mission.
        // Once the whole bank has been seen, start a new lap.
        if !plan.targetWords.isEmpty {
            let attempted = plan.targetWords.prefix(max(0, correct + wrong))
            let known = Set(child.usedWordsRaw)
            child.usedWordsRaw += attempted.filter { !known.contains($0) }
            if Set(child.usedWordsRaw).isSuperset(of: WordBank.allWords) {
                child.usedWordsRaw = Array(attempted)
            }
        }

        try missionRepository.save(record, for: child)

        // 2. Compute rewards (effort always counts).
        let outcome = MissionOutcome(record: record)
        var rewards = rewardEngine.rewards(
            for: outcome,
            difficulty: plan.difficulty,
            questionsAnswered: correct + wrong
        )
        record.starsEarned = rewards.stars

        // 3. Grow the forest.
        let forest = try forestRepository.forest(for: child)
        rewards.newlyUnlocked = growthEngine.apply(rewards, to: forest)

        // 4. Update today's goal + attention stats.
        let goal = try statisticsRepository.todayGoal(for: child)
        goal.completedMissions += 1
        goal.totalFocusSeconds += elapsed

        if let session = child.sessions?.max(by: { $0.startedAt < $1.startedAt }) {
            session.missionsCompleted += 1
            session.attentionScore = difficultyEngine.attentionScore(
                responseTimes: responseTimes, completed: !endedEarly
            )
        }

        // 5. Achievements.
        rewards.newAchievements = try achievementEngine.evaluate(child: child, forest: forest)

        try forestRepository.save()
        try statisticsRepository.save()

        return MissionCompletionResult(
            rewards: rewards,
            movementBreak: .random(),
            forestLevel: forest.level,
            goalProgress: goal.progress
        )
    }
}

// MARK: - Fetch Today Plan

@MainActor
struct FetchTodayPlanUseCase {
    let statisticsRepository: any StatisticsRepository
    let recommendationEngine: LearningRecommendationEngine

    func execute(
        child: ChildProfile,
        preference: DifficultyPreference
    ) throws -> LearningRecommendationEngine.TodayPlan {
        let summary = try statisticsRepository.performanceSummary(for: child, days: 14)
        return recommendationEngine.makeTodayPlan(summary: summary, preference: preference)
    }
}

// MARK: - Fetch Statistics (parent dashboard)

@MainActor
struct FetchStatisticsUseCase {
    let statisticsRepository: any StatisticsRepository

    func execute(child: ChildProfile, days: Int) throws -> PerformanceSummary {
        try statisticsRepository.performanceSummary(for: child, days: days)
    }
}
