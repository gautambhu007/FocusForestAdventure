//
//  StoryTests.swift
//  FocusForestAdventureTests
//
//  Phase 2.1 tests: deterministic story generation, empty-data fallback,
//  persistence and fetch ordering, narration behavior, and offline flag.
//

import XCTest
import SwiftData
@testable import FocusForestAdventure

// MARK: - Story engine (pure, deterministic)

final class StoryEngineTests: XCTestCase {

    let engine = StoryEngine()

    private func makeContext(
        nickname: String = "Mira",
        animals: [ForestElement] = [.animals],
        achievements: [AchievementID] = [.firstMission]
    ) -> StoryContext {
        StoryContext(
            childNickname: nickname,
            completedAdventure: .numbers,
            forestLevel: 4,
            treesPlanted: 6,
            unlockedAnimals: animals,
            achievementIDs: achievements,
            favoriteActivity: .shapes,
            starsEarned: 3
        )
    }

    func testGenerationIsDeterministic() {
        let context = makeContext()
        let first = engine.generateStory(context: context)
        let second = engine.generateStory(context: context)
        XCTAssertEqual(first, second, "Same context must always produce the same story")
    }

    func testStoryUsesChildNickname() {
        let draft = engine.generateStory(context: makeContext(nickname: "Mira"))
        XCTAssertTrue(draft.title.contains("Mira"), "Title should feature the child's nickname")
        XCTAssertTrue(draft.pages.contains { $0.contains("Mira") },
                      "Pages should feature the child's nickname")
    }

    func testEmptyNicknameFallsBackToExplorer() {
        let draft = engine.generateStory(context: makeContext(nickname: ""))
        XCTAssertEqual(draft.childNickname, String(localized: "Explorer"),
                       "Empty nickname must fall back to a friendly default")
    }

    func testStoryAlwaysHasPages() {
        let empty = StoryContext(
            childNickname: "",
            completedAdventure: .alphabet,
            forestLevel: 1,
            treesPlanted: 0,
            unlockedAnimals: [],
            achievementIDs: [],
            favoriteActivity: .alphabet,
            starsEarned: 0
        )
        let draft = engine.generateStory(context: empty)
        XCTAssertFalse(draft.pages.isEmpty, "Even with no data the story must have pages")
        XCTAssertFalse(draft.title.isEmpty, "Even with no data the story must have a title")
        XCTAssertFalse(draft.pages.contains(where: \.isEmpty), "No page may be blank")
    }

    func testNoAchievementsUsesGentleFallbackLine() {
        let draft = engine.generateStory(context: makeContext(achievements: []))
        XCTAssertEqual(draft.pages.count,
                       engine.generateStory(context: makeContext()).pages.count,
                       "Missing achievements must not drop a page")
    }

    func testDragonOutranksOtherAnimals() {
        let dragon = engine.generateStory(context: makeContext(animals: [.animals, .dragon]))
        XCTAssertTrue(dragon.pages.contains { $0.contains(String(localized: "friendly dragon")) },
                      "The dragon is the most magical unlock and should star in the story")
    }

    func testStoryReflectsForestLevel() {
        let low = makeContext()
        let high = StoryContext(
            childNickname: low.childNickname,
            completedAdventure: low.completedAdventure,
            forestLevel: 9,
            treesPlanted: low.treesPlanted,
            unlockedAnimals: low.unlockedAnimals,
            achievementIDs: low.achievementIDs,
            favoriteActivity: low.favoriteActivity,
            starsEarned: low.starsEarned
        )
        XCTAssertNotEqual(engine.generateStory(context: low).pages,
                          engine.generateStory(context: high).pages,
                          "Different forest levels should change the story setting")
    }
}

// MARK: - Story service (persistence, cache, ordering)

@MainActor
final class StoryServiceTests: XCTestCase {

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

    private func completeMission(for child: ChildProfile) throws -> (MissionPlan, RewardBundle) {
        let plan = deps.missionGenerator.generateMission(adventure: .numbers, difficulty: 1)
        let result = try deps.completeMissionUseCase.execute(
            plan: plan, child: child,
            correct: 4, wrong: 1,
            responseTimes: [3, 3.5, 4, 3, 3.2],
            endedEarly: false, elapsed: 200
        )
        return (plan, result.rewards)
    }

    func testGenerateStoryPersistsRecord() throws {
        let child = try deps.childRepository.activeChild()
        let (plan, rewards) = try completeMission(for: child)

        let story = try deps.storyService.generateStory(after: plan, child: child, rewards: rewards)

        let history = try deps.storyService.storyHistory(for: child)
        XCTAssertEqual(history.count, 1, "The generated story must be persisted")
        XCTAssertEqual(history.first?.title, story.title)
    }

    func testGeneratedStoryIsMarkedOffline() throws {
        let child = try deps.childRepository.activeChild()
        let (plan, rewards) = try completeMission(for: child)

        let story = try deps.storyService.generateStory(after: plan, child: child, rewards: rewards)

        XCTAssertTrue(story.isOfflineGenerated,
                      "Phase 2.1 stories are generated locally and must say so")
        XCTAssertFalse(story.pages.isEmpty, "Persisted story must carry its pages")
    }

    func testGeneratedStoryCachesLatest() throws {
        let child = try deps.childRepository.activeChild()
        let (plan, rewards) = try completeMission(for: child)

        let story = try deps.storyService.generateStory(after: plan, child: child, rewards: rewards)

        XCTAssertEqual(deps.storyCache.latestStory?.persistentModelID, story.persistentModelID,
                       "The cache must hold the most recent story for offline re-reads")
    }

    func testStoryHistoryIsNewestFirst() throws {
        let child = try deps.childRepository.activeChild()
        let (plan, rewards) = try completeMission(for: child)

        let first = try deps.storyService.generateStory(after: plan, child: child, rewards: rewards)
        first.createdAt = Date(timeIntervalSinceNow: -3600)   // pretend it's an hour old
        let second = try deps.storyService.generateStory(after: plan, child: child, rewards: rewards)

        let history = try deps.storyService.storyHistory(for: child)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history.first?.persistentModelID, second.persistentModelID,
                       "History must be sorted newest first")
    }

    func testStoryUsesChildProgressSignals() throws {
        let child = try deps.childRepository.activeChild()
        child.name = "Nia"
        let (plan, rewards) = try completeMission(for: child)

        let story = try deps.storyService.generateStory(after: plan, child: child, rewards: rewards)

        XCTAssertEqual(story.childNickname, "Nia")
        XCTAssertEqual(story.adventureKind, plan.adventure)
        XCTAssertGreaterThanOrEqual(story.forestLevel, 1)
        XCTAssertFalse(story.unlockedAnimals.isEmpty,
                       "Story must always have at least one forest friend")
    }
}

// MARK: - Story narrator (speech integration)

@MainActor
final class StoryNarratorTests: XCTestCase {

    private final class SpeechServiceSpy: SpeechServiceProtocol {
        var isEnabled = true
        var hasNaturalVoice = true
        var spoken: [String] = []
        var stopCount = 0
        func speak(_ text: String) async { spoken.append(text) }
        func stop() { stopCount += 1 }
        func refreshVoice() {}
    }

    private func makeRecord(pages: [String]) -> StoryRecord {
        StoryRecord(
            title: "Test Story",
            pages: pages,
            adventureKind: .numbers,
            forestLevel: 1,
            treesPlanted: 1,
            unlockedAnimals: [.animals],
            achievementIDs: [],
            childNickname: "Test",
            favoriteActivity: .numbers
        )
    }

    func testNarratePageSpeaksText() async {
        let spy = SpeechServiceSpy()
        let narrator = StoryNarrator(speechService: spy)

        await narrator.narrate("Once upon a time in the forest.")

        XCTAssertEqual(spy.spoken, ["Once upon a time in the forest."])
    }

    func testNarrateStorySpeaksFirstPage() async {
        let spy = SpeechServiceSpy()
        let narrator = StoryNarrator(speechService: spy)
        let record = makeRecord(pages: ["Page one.", "Page two."])

        await narrator.narrate(record)

        XCTAssertEqual(spy.spoken, ["Page one."], "Narrating a story starts at page one")
    }

    func testNarrateEmptyStoryStaysSilent() async {
        let spy = SpeechServiceSpy()
        let narrator = StoryNarrator(speechService: spy)

        await narrator.narrate(makeRecord(pages: []))

        XCTAssertTrue(spy.spoken.isEmpty, "An empty story must not crash or speak")
    }

    func testStopForwardsToSpeechService() {
        let spy = SpeechServiceSpy()
        let narrator = StoryNarrator(speechService: spy)

        narrator.stop()

        XCTAssertEqual(spy.stopCount, 1)
    }
}
