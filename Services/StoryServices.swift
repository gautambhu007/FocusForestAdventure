//
//  StoryServices.swift
//  Focus Forest Adventure
//
//  Phase 2.1 story orchestration: cache, narration, and persistence.
//

import Foundation
import Observation

@Observable
@MainActor
final class StoryCache {
    private(set) var latestStory: StoryRecord?

    func store(_ story: StoryRecord) {
        latestStory = story
    }

    func clear() {
        latestStory = nil
    }
}

@MainActor
final class StoryNarrator {
    private let speechService: any SpeechServiceProtocol

    init(speechService: any SpeechServiceProtocol) {
        self.speechService = speechService
    }

    func narrate(_ page: String) async {
        await speechService.speak(page)
    }

    func narrate(_ story: StoryRecord) async {
        guard let firstPage = story.pages.first else { return }
        await speechService.speak(firstPage)
    }

    func stop() {
        speechService.stop()
    }
}

@MainActor
final class StoryService {
    private let storyRepository: any StoryRepository
    private let missionRepository: any MissionRepository
    private let forestRepository: any ForestRepository
    private let achievementRepository: any AchievementRepository
    private let statisticsRepository: any StatisticsRepository
    private let recommendationEngine: LearningRecommendationEngine
    private let engine: StoryEngine
    private let cache: StoryCache

    init(
        storyRepository: any StoryRepository,
        missionRepository: any MissionRepository,
        forestRepository: any ForestRepository,
        achievementRepository: any AchievementRepository,
        statisticsRepository: any StatisticsRepository,
        recommendationEngine: LearningRecommendationEngine,
        engine: StoryEngine,
        cache: StoryCache
    ) {
        self.storyRepository = storyRepository
        self.missionRepository = missionRepository
        self.forestRepository = forestRepository
        self.achievementRepository = achievementRepository
        self.statisticsRepository = statisticsRepository
        self.recommendationEngine = recommendationEngine
        self.engine = engine
        self.cache = cache
    }

    func generateStory(
        after plan: MissionPlan,
        child: ChildProfile,
        rewards: RewardBundle
    ) throws -> StoryRecord {
        let forest = try forestRepository.forest(for: child)
        let achievements = try achievementRepository.earned(for: child)
        let favoriteActivity = try favoriteActivity(for: child) ?? plan.adventure
        // Phase 2.8: today's recommended story theme flavors the story.
        // Never let recommendation failure block a story — default flavor.
        let theme = (try? statisticsRepository.performanceSummary(for: child, days: 14))
            .map { recommendationEngine.makeDailyRecommendations(summary: $0).storyTheme }
            ?? .friendship
        let context = StoryContext(
            childNickname: child.name,
            completedAdventure: plan.adventure,
            forestLevel: forest.level,
            treesPlanted: estimatedTreesPlanted(in: forest),
            unlockedAnimals: animalElements(from: forest.unlockedElements),
            achievementIDs: achievements.compactMap(\.achievementID),
            favoriteActivity: favoriteActivity,
            starsEarned: rewards.stars,
            theme: theme
        )
        let draft = engine.generateStory(context: context)
        let record = StoryRecord(
            title: draft.title,
            pages: draft.pages,
            adventureKind: draft.adventureKind,
            forestLevel: draft.forestLevel,
            treesPlanted: draft.treesPlanted,
            unlockedAnimals: draft.unlockedAnimals,
            achievementIDs: draft.achievementIDs,
            childNickname: draft.childNickname,
            favoriteActivity: draft.favoriteActivity,
            isOfflineGenerated: true,
            theme: draft.theme
        )
        try storyRepository.save(record, for: child)
        cache.store(record)
        return record
    }

    func storyHistory(for child: ChildProfile) throws -> [StoryRecord] {
        try storyRepository.stories(for: child)
    }

    private func favoriteActivity(for child: ChildProfile) throws -> AdventureKind? {
        let missions = try missionRepository.missions(for: child, since: nil)
        let grouped = Dictionary(grouping: missions, by: \.adventureKind)
        return grouped.max { lhs, rhs in lhs.value.count < rhs.value.count }?.key
    }

    private func animalElements(from unlocked: [ForestElement]) -> [ForestElement] {
        let animals: [ForestElement] = [.animals, .butterflies, .dragon]
        let filtered = unlocked.filter { animals.contains($0) }
        return filtered.isEmpty ? [.animals] : filtered
    }

    private func estimatedTreesPlanted(in forest: ForestState) -> Int {
        guard forest.unlockedElements.contains(.trees) else { return max(1, forest.level) }
        return max(1, forest.seeds + forest.level)
    }
}
