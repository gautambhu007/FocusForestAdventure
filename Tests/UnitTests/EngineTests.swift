//
//  EngineTests.swift
//  FocusForestAdventureTests
//
//  Unit tests for the deterministic game/AI engines.
//

import XCTest
@testable import FocusForestAdventure

final class AdaptiveDifficultyEngineTests: XCTestCase {

    let engine = AdaptiveDifficultyEngine()

    func testPromotesAfterSustainedMastery() {
        let strong = MissionOutcome(accuracy: 0.9, averageResponseTime: 4)
        let next = engine.nextDifficulty(current: 2, recentMissions: [strong, strong])
        XCTAssertEqual(next, 3, "Two strong missions in a row should promote by exactly one")
    }

    func testNeverJumpsMoreThanOneLevel() {
        let perfect = MissionOutcome(accuracy: 1.0, averageResponseTime: 1)
        let next = engine.nextDifficulty(current: 1, recentMissions: Array(repeating: perfect, count: 10))
        XCTAssertEqual(next, 2, "Even flawless history must only step up one level")
    }

    func testSingleStrongMissionDoesNotPromote() {
        let strong = MissionOutcome(accuracy: 0.95, averageResponseTime: 3)
        let next = engine.nextDifficulty(current: 2, recentMissions: [strong])
        XCTAssertEqual(next, 2, "One good mission is not sustained mastery")
    }

    func testDemotesQuicklyWhenStruggling() {
        let struggling = MissionOutcome(accuracy: 0.3, averageResponseTime: 9)
        let next = engine.nextDifficulty(current: 3, recentMissions: [struggling])
        XCTAssertEqual(next, 2, "A struggling mission should ease difficulty immediately")
    }

    func testEarlyEndedMissionDemotes() {
        let frustrated = MissionOutcome(accuracy: 0.7, averageResponseTime: 5, endedEarly: true)
        let next = engine.nextDifficulty(current: 4, recentMissions: [frustrated])
        XCTAssertEqual(next, 3, "Frustration-guard exits should ease difficulty")
    }

    func testDifficultyStaysInRange() {
        let struggling = MissionOutcome(accuracy: 0.1, averageResponseTime: 12)
        XCTAssertEqual(engine.nextDifficulty(current: 1, recentMissions: [struggling]), 1)

        let strong = MissionOutcome(accuracy: 1.0, averageResponseTime: 2)
        XCTAssertEqual(engine.nextDifficulty(current: 5, recentMissions: [strong, strong]), 5)
    }

    func testGentlePreferenceCapsAtTwo() {
        let strong = MissionOutcome(accuracy: 1.0, averageResponseTime: 2)
        let next = engine.nextDifficulty(current: 3, recentMissions: [strong, strong], preference: .gentle)
        XCTAssertLessThanOrEqual(next, 2)
    }

    func testAttentionScoreRewardsConsistency() {
        let steady = engine.attentionScore(responseTimes: [3, 3.2, 2.9, 3.1], completed: true)
        let erratic = engine.attentionScore(responseTimes: [1, 9, 2, 12], completed: true)
        XCTAssertGreaterThan(steady, erratic)
        XCTAssertGreaterThanOrEqual(steady, 0)
        XCTAssertLessThanOrEqual(steady, 1)
    }

    func testMissionDurationStaysInThreeToFiveMinutes() {
        XCTAssertEqual(engine.recommendedMissionDuration(attentionScore: 0), 180)
        XCTAssertEqual(engine.recommendedMissionDuration(attentionScore: 1), 300)
    }
}

final class RewardEngineTests: XCTestCase {

    let engine = RewardEngine()

    func testEffortIsAlwaysRewarded() {
        let rough = MissionOutcome(accuracy: 0.1, averageResponseTime: 10, endedEarly: true)
        let bundle = engine.rewards(for: rough, difficulty: 1, questionsAnswered: 2)
        XCTAssertGreaterThanOrEqual(bundle.stars, 1, "The child must never receive zero stars")
        XCTAssertGreaterThanOrEqual(bundle.seeds, 1)
        XCTAssertGreaterThan(bundle.forestXP, 0)
    }

    func testMasteryEarnsThreeStars() {
        let great = MissionOutcome(accuracy: 0.9, averageResponseTime: 3)
        let bundle = engine.rewards(for: great, difficulty: 3, questionsAnswered: 7)
        XCTAssertEqual(bundle.stars, 3)
    }

    func testHigherDifficultyYieldsMoreXP() {
        let outcome = MissionOutcome(accuracy: 0.8, averageResponseTime: 4)
        let easy = engine.rewards(for: outcome, difficulty: 1, questionsAnswered: 6)
        let hard = engine.rewards(for: outcome, difficulty: 5, questionsAnswered: 6)
        XCTAssertGreaterThan(hard.forestXP, easy.forestXP)
    }
}

final class ForestGrowthEngineTests: XCTestCase {

    let engine = ForestGrowthEngine()

    func testLevelBoundaries() {
        XCTAssertEqual(engine.level(forXP: 0), 1)
        XCTAssertEqual(engine.level(forXP: 49), 1)
        XCTAssertEqual(engine.level(forXP: 50), 2)
        XCTAssertEqual(engine.level(forXP: 1400), 8)
        XCTAssertEqual(engine.level(forXP: 99_999), 8)
    }

    func testProgressToNextLevelIsMonotonic() {
        let low = engine.progressToNextLevel(xp: 10)
        let high = engine.progressToNextLevel(xp: 40)
        XCTAssertGreaterThan(high, low)
        XCTAssertEqual(engine.progressToNextLevel(xp: 99_999), 1)
    }

    @MainActor
    func testApplyUnlocksElementsExactlyOnce() {
        let forest = ForestState()
        var bundle = RewardBundle()
        bundle.forestXP = 250   // enough for grass, flowers, trees, butterflies

        let first = engine.apply(bundle, to: forest)
        XCTAssertTrue(first.contains(.grass))
        XCTAssertTrue(first.contains(.butterflies))

        bundle.forestXP = 1
        let second = engine.apply(bundle, to: forest)
        XCTAssertTrue(second.isEmpty, "Already-unlocked elements must not unlock again")
    }
}

final class LearningRecommendationEngineTests: XCTestCase {

    let engine = LearningRecommendationEngine(difficultyEngine: AdaptiveDifficultyEngine())

    func testUnexploredSubjectsRankHigh() {
        let score = engine.score(for: .listening, stats: nil)
        XCTAssertEqual(score, 0.7, accuracy: 0.001)
    }

    func testStrugglingSubjectOutranksMasteredSubject() {
        var struggling = PerformanceSummary.SubjectStats()
        struggling.missions = 4
        struggling.accuracy = 0.55
        struggling.averageResponseTime = 5
        struggling.lastPlayed = .now

        var mastered = PerformanceSummary.SubjectStats()
        mastered.missions = 4
        mastered.accuracy = 0.98
        mastered.averageResponseTime = 3
        mastered.lastPlayed = .now

        XCTAssertGreaterThan(
            engine.score(for: .alphabet, stats: struggling),
            engine.score(for: .numbers, stats: mastered),
            "A subject needing practice should be recommended over a mastered one"
        )
    }

    func testTodayPlanCoversAllAdventures() {
        let plan = engine.makeTodayPlan(summary: PerformanceSummary())
        XCTAssertEqual(Set(plan.recommendedAdventures), Set(AdventureKind.allCases))
        XCTAssertEqual(plan.difficultyPerSubject.count, AdventureKind.allCases.count)
        XCTAssertTrue((180...300).contains(plan.missionDuration))
    }

    func testParentRecommendationsNeverEmpty() {
        let tips = engine.parentRecommendations(summary: PerformanceSummary())
        XCTAssertFalse(tips.isEmpty)
    }
}

final class MissionGeneratorEngineTests: XCTestCase {

    let generator = MissionGeneratorEngine(difficultyEngine: AdaptiveDifficultyEngine())

    func testMissionHasConfiguredQuestionCount() {
        let easy = generator.generateMission(adventure: .shapes, difficulty: 1)
        let hard = generator.generateMission(adventure: .shapes, difficulty: 5)
        XCTAssertEqual(easy.questions.count, MissionGeneratorEngine.questionsPerMission)
        XCTAssertEqual(hard.questions.count, MissionGeneratorEngine.questionsPerMission)
    }

    func testDurationCapAllowsFullMission() {
        let mission = generator.generateMission(adventure: .shapes, difficulty: 2, duration: 180)
        let needed = TimeInterval(mission.questions.count) * MissionGeneratorEngine.secondsPerQuestion
        XCTAssertGreaterThanOrEqual(mission.maxDuration, needed,
                                    "Time cap must not cut a full mission short")
    }

    func testDifficultyIsClamped() {
        XCTAssertEqual(generator.generateMission(adventure: .colors, difficulty: 99).difficulty, 5)
        XCTAssertEqual(generator.generateMission(adventure: .colors, difficulty: -3).difficulty, 1)
    }

    func testTapCorrectQuestionsAlwaysContainTheAnswer() {
        for _ in 0..<50 {
            let mission = generator.generateMission(adventure: .alphabet, difficulty: Int.random(in: 1...5))
            for question in mission.questions {
                if case let .tapCorrect(options, correctID) = question.content {
                    XCTAssertTrue(options.contains { $0.id == correctID },
                                  "Correct answer must be among the options")
                    XCTAssertEqual(Set(options.map(\.display)).count, options.count,
                                   "Options must be visually unique")
                }
            }
        }
    }

    func testCountingChoicesIncludeTheCount() {
        for _ in 0..<50 {
            let mission = generator.generateMission(adventure: .numbers, difficulty: 1)
            for question in mission.questions {
                if case let .countObjects(_, count, choices) = question.content {
                    XCTAssertTrue(choices.contains(count))
                }
            }
        }
    }

    func testEveryMissionHasFrustrationGuard() {
        let mission = generator.generateMission(adventure: .memory, difficulty: 3)
        XCTAssertEqual(mission.frustrationMissLimit, 3)
        XCTAssertGreaterThan(mission.maxDuration, 0)
    }
}
