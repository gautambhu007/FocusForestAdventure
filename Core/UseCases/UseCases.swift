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
        additionSection: AdditionSection? = nil,
        forcedMissionType: MissionType? = nil
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
            additionSection: additionSection,
            forcedType: forcedMissionType
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
    let treasureEngine: TreasureEngine

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

        DailyStreak.recordActivity()   // missions count toward the streak too
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

        // 3a. Earn treasures — and with them, the right to visit the
        // Magic Forest. One earned thing buys one four-minute visit.
        let treasures = treasureEngine.award(
            alreadyEarned: forest.earnedTreasureIDs,
            accuracy: outcome.accuracy,
            questionsAnswered: correct + wrong
        )
        forest.earnedTreasureIDsRaw += treasures.map(\.id)
        forest.forestPasses += treasureEngine.passesEarned(for: treasures)
        rewards.newTreasures = treasures

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

// MARK: - Start Puzzle Run

@MainActor
struct StartPuzzleRunUseCase {
    let puzzleRepository: any PuzzleRepository
    let generator: PuzzleGeneratorEngine
    let progressionEngine: PuzzleProgressionEngine

    /// Build the next level for a world at the child's current rung.
    /// A never-played world starts from an age-appropriate rung rather than
    /// from 2×2 colour matching.
    func execute(
        world: PuzzleWorld,
        child: ChildProfile,
        age: Int,
        preference: DifficultyPreference,
        puzzleCount: Int = 5
    ) throws -> PuzzleRun {
        let snapshot = try puzzleRepository.snapshot(for: child)
        let hasHistory = snapshot.completed(world) > 0
        let current = hasHistory
            ? snapshot.rung(world)
            : progressionEngine.startingDifficulty(age: age, world: world)
        let difficulty = progressionEngine.nextDifficulty(
            current: current,
            recentResults: snapshot.recentResults.filter { $0.world == world },
            preference: preference
        )
        let level = progressionEngine.nextLevel(in: world, snapshot: snapshot)
        var rng = SystemRandomNumberGenerator()
        return generator.generateRun(
            world: world,
            level: level,
            difficulty: difficulty,
            age: age,
            count: puzzleCount,
            using: &rng
        )
    }
}

// MARK: - Complete Puzzle Run

/// Everything the celebration screen needs after a level.
struct PuzzleRunCompletion: Sendable {
    let result: PuzzleRunResult
    let newBadges: [PuzzleBadge]
    let nextDifficulty: Int
    let totalCoins: Int
    /// True when this level opened the next world.
    let unlockedWorld: PuzzleWorld?
}

@MainActor
struct CompletePuzzleRunUseCase {
    let puzzleRepository: any PuzzleRepository
    let progressionEngine: PuzzleProgressionEngine

    func execute(
        run: PuzzleRun,
        attempts: [PuzzleAttempt],
        child: ChildProfile,
        age: Int,
        preference: DifficultyPreference
    ) throws -> PuzzleRunCompletion {
        let before = try puzzleRepository.snapshot(for: child)
        let result = progressionEngine.makeResult(
            world: run.world,
            level: run.level,
            difficulty: run.difficulty,
            attempts: attempts
        )
        let nextDifficulty = progressionEngine.nextDifficulty(
            current: run.difficulty,
            recentResults: [result] + before.recentResults.filter { $0.world == run.world },
            preference: preference
        )
        let badges = try puzzleRepository.record(result, nextDifficulty: nextDifficulty, for: child)

        DailyStreak.recordActivity()   // puzzles count toward the streak too

        let after = try puzzleRepository.snapshot(for: child)
        let unlocked = PuzzleWorld.allCases.first { world in
            !progressionEngine.isUnlocked(world, age: age, snapshot: before) &&
            progressionEngine.isUnlocked(world, age: age, snapshot: after)
        }

        return PuzzleRunCompletion(
            result: result,
            newBadges: badges,
            nextDifficulty: nextDifficulty,
            totalCoins: after.coins,
            unlockedWorld: unlocked
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
