//
//  UseCaseAndRepositoryTests.swift
//  FocusForestAdventureTests
//
//  Integration-style unit tests against an in-memory SwiftData container.
//

import XCTest
import SwiftData
@testable import FocusForestAdventure

@MainActor
final class UseCaseTests: XCTestCase {

    var container: ModelContainer!
    var deps: AppDependencies!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: ModelContainerFactory.schema, configurations: [config])
        deps = AppDependencies(modelContainer: container)
    }

    override func tearDown() async throws {
        container = nil
        deps = nil
    }

    func testActiveChildIsCreatedOnFirstAccess() throws {
        let child = try deps.childRepository.activeChild()
        XCTAssertNotNil(child.forest, "New children must start with a forest")

        let again = try deps.childRepository.activeChild()
        XCTAssertEqual(child.persistentModelID, again.persistentModelID,
                       "activeChild must be idempotent")
    }

    func testCompleteMissionPersistsAndRewards() throws {
        let child = try deps.childRepository.activeChild()
        let plan = deps.missionGenerator.generateMission(adventure: .numbers, difficulty: 2)

        let result = try deps.completeMissionUseCase.execute(
            plan: plan, child: child,
            correct: 5, wrong: 1,
            responseTimes: [3, 4, 3.5, 4.2, 3.8, 5],
            endedEarly: false,
            elapsed: 240
        )

        XCTAssertGreaterThanOrEqual(result.rewards.stars, 1)
        XCTAssertGreaterThan(result.rewards.forestXP, 0)
        XCTAssertEqual(try deps.missionRepository.missions(for: child, since: nil).count, 1)

        // First mission achievement must fire.
        XCTAssertTrue(result.rewards.newAchievements.contains(.firstMission))

        // Goal progress advanced.
        let goal = try deps.statisticsRepository.todayGoal(for: child)
        XCTAssertEqual(goal.completedMissions, 1)
        XCTAssertEqual(goal.totalFocusSeconds, 240, accuracy: 0.01)
    }

    func testForestXPAccumulatesAcrossMissions() throws {
        let child = try deps.childRepository.activeChild()
        for _ in 0..<3 {
            let plan = deps.missionGenerator.generateMission(adventure: .shapes, difficulty: 1)
            _ = try deps.completeMissionUseCase.execute(
                plan: plan, child: child,
                correct: 5, wrong: 0,
                responseTimes: [3, 3, 3, 3, 3],
                endedEarly: false, elapsed: 200
            )
        }
        let forest = try deps.forestRepository.forest(for: child)
        XCTAssertGreaterThan(forest.experience, 0)
        XCTAssertGreaterThanOrEqual(forest.level, 2, "Three good missions should reach level 2")
    }

    func testPerformanceSummaryAggregatesBySubject() throws {
        let child = try deps.childRepository.activeChild()
        let plan = deps.missionGenerator.generateMission(adventure: .colors, difficulty: 1)
        _ = try deps.completeMissionUseCase.execute(
            plan: plan, child: child, correct: 4, wrong: 1,
            responseTimes: [2, 3, 2, 3, 4], endedEarly: false, elapsed: 180
        )

        let summary = try deps.statisticsRepository.performanceSummary(for: child, days: 7)
        XCTAssertEqual(summary.totalMissions, 1)
        XCTAssertNotNil(summary.perSubject[.colors])
        XCTAssertEqual(summary.perSubject[.colors]?.accuracy ?? 0, 0.8, accuracy: 0.001)
    }

    func testStartMissionUsesAdaptiveDifficulty() throws {
        let child = try deps.childRepository.activeChild()

        // Seed two strong alphabet missions.
        for _ in 0..<2 {
            let record = MissionRecord(adventureKind: .alphabet, missionType: "findLetter", difficulty: 1)
            record.correctAnswers = 9
            record.wrongAnswers = 0
            record.averageResponseTime = 3
            try deps.missionRepository.save(record, for: child)
        }

        let plan = try deps.startMissionUseCase.execute(
            adventure: .alphabet,
            child: child,
            difficultyEngine: deps.difficultyEngine,
            preference: .automatic,
            duration: 240
        )
        XCTAssertEqual(plan.difficulty, 2, "Sustained mastery should promote to difficulty 2")
    }

    func testAchievementsAreNeverDuplicated() throws {
        let child = try deps.childRepository.activeChild()
        try deps.achievementRepository.award(.firstMission, to: child)
        try deps.achievementRepository.award(.firstMission, to: child)
        XCTAssertEqual(try deps.achievementRepository.earned(for: child).count, 1)
    }

    // MARK: Listening Corner

    func testCustomWordRepositoryAddListDelete() throws {
        let child = try deps.childRepository.activeChild()
        XCTAssertTrue(try deps.customWordRepository.words(for: child).isEmpty)

        try deps.customWordRepository.add("bunny", for: child)
        try deps.customWordRepository.add("forest", for: child)
        let words = try deps.customWordRepository.words(for: child)
        XCTAssertEqual(words.count, 2)
        XCTAssertEqual(Set(words.map(\.text)), ["bunny", "forest"])

        try deps.customWordRepository.delete(words[0])
        XCTAssertEqual(try deps.customWordRepository.words(for: child).count, 1)
    }

    func testForcedMissionTypeOverridesDefault() throws {
        let child = try deps.childRepository.activeChild()
        let plan = try deps.startMissionUseCase.execute(
            adventure: .listening,
            child: child,
            difficultyEngine: deps.difficultyEngine,
            preference: .automatic,
            duration: 240,
            forcedMissionType: .repeatPattern
        )
        XCTAssertEqual(plan.missionType, .repeatPattern)
    }
}

// MARK: - PIN hashing

final class PINHasherTests: XCTestCase {
    func testHashIsDeterministicAndNotPlaintext() {
        let hash = PINHasher.hash("1234")
        XCTAssertEqual(hash, PINHasher.hash("1234"))
        XCTAssertNotEqual(hash, "1234")
        XCTAssertEqual(hash.count, 64)   // SHA-256 hex
        XCTAssertNotEqual(hash, PINHasher.hash("1235"))
    }
}
