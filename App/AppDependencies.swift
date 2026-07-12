//
//  AppDependencies.swift
//  Focus Forest Adventure
//
//  Composition root. All dependencies are constructed here and passed down
//  via initializer injection / the SwiftUI Environment. No singletons —
//  the only shared instances are the ones this graph owns.
//

import Foundation
import SwiftData
import Observation

/// The app-wide dependency graph. `@Observable` so views can pull it from the
/// environment; all members are constructor-injected protocols so every layer
/// is testable in isolation.
@Observable
@MainActor
final class AppDependencies {

    // MARK: State
    let appState: AppState

    // MARK: Repositories
    let childRepository: any ChildRepository
    let missionRepository: any MissionRepository
    let forestRepository: any ForestRepository
    let statisticsRepository: any StatisticsRepository
    let achievementRepository: any AchievementRepository
    let storyRepository: any StoryRepository

    // MARK: Engines & Services
    let soundEngine: any SoundEngineProtocol
    let speechService: any SpeechServiceProtocol
    let hapticsService: any HapticsServiceProtocol
    let difficultyEngine: AdaptiveDifficultyEngine
    let recommendationEngine: LearningRecommendationEngine
    let missionGenerator: MissionGeneratorEngine
    let rewardEngine: RewardEngine
    let forestGrowthEngine: ForestGrowthEngine
    let achievementEngine: AchievementEngine
    let storyEngine: StoryEngine
    let storyCache: StoryCache
    let storyNarrator: StoryNarrator
    let storyService: StoryService
    let premiumStore: PremiumStore

    // MARK: Use Cases
    let startMissionUseCase: StartMissionUseCase
    let completeMissionUseCase: CompleteMissionUseCase
    let fetchTodayPlanUseCase: FetchTodayPlanUseCase
    let fetchStatisticsUseCase: FetchStatisticsUseCase

    init(modelContainer: ModelContainer) {
        let context = modelContainer.mainContext
        self.appState = AppState()

        // Repositories (SwiftData-backed)
        let childRepo = SwiftDataChildRepository(context: context)
        let missionRepo = SwiftDataMissionRepository(context: context)
        let forestRepo = SwiftDataForestRepository(context: context)
        let statsRepo = SwiftDataStatisticsRepository(context: context)
        let storyRepo = SwiftDataStoryRepository(context: context)
        let achievementRepo = SwiftDataAchievementRepository(context: context)
        self.childRepository = childRepo
        self.missionRepository = missionRepo
        self.forestRepository = forestRepo
        self.statisticsRepository = statsRepo
        self.achievementRepository = achievementRepo
        self.storyRepository = storyRepo

        // Services
        let sound = SoundEngine()
        let speech = SpeechService()
        let haptics = HapticsService()
        self.soundEngine = sound
        self.speechService = speech
        self.hapticsService = haptics

        // Engines
        let difficulty = AdaptiveDifficultyEngine()
        let recommendation = LearningRecommendationEngine(difficultyEngine: difficulty)
        let generator = MissionGeneratorEngine(difficultyEngine: difficulty)
        let reward = RewardEngine()
        let growth = ForestGrowthEngine()
        let achievements = AchievementEngine(repository: achievementRepo)
        let storyEngine = StoryEngine()
        let storyCache = StoryCache()
        let storyNarrator = StoryNarrator(speechService: speech)
        let storyService = StoryService(
            storyRepository: storyRepo,
            missionRepository: missionRepo,
            forestRepository: forestRepo,
            achievementRepository: achievementRepo,
            engine: storyEngine,
            cache: storyCache
        )
        self.difficultyEngine = difficulty
        self.recommendationEngine = recommendation
        self.missionGenerator = generator
        self.rewardEngine = reward
        self.forestGrowthEngine = growth
        self.achievementEngine = achievements
        self.storyEngine = storyEngine
        self.storyCache = storyCache
        self.storyNarrator = storyNarrator
        self.storyService = storyService
        self.premiumStore = PremiumStore()

        // Use cases
        self.startMissionUseCase = StartMissionUseCase(
            missionRepository: missionRepo,
            generator: generator
        )
        self.completeMissionUseCase = CompleteMissionUseCase(
            missionRepository: missionRepo,
            forestRepository: forestRepo,
            statisticsRepository: statsRepo,
            rewardEngine: reward,
            growthEngine: growth,
            achievementEngine: achievements,
            difficultyEngine: difficulty
        )
        self.fetchTodayPlanUseCase = FetchTodayPlanUseCase(
            statisticsRepository: statsRepo,
            recommendationEngine: recommendation
        )
        self.fetchStatisticsUseCase = FetchStatisticsUseCase(statisticsRepository: statsRepo)
    }
}

/// Lightweight cross-feature UI state (navigation, active child, settings snapshot).
@Observable
@MainActor
final class AppState {
    var navigationPath: [AppRoute] = []
    var activeChildID: PersistentIdentifier?
    var settings = AppSettings()
}

/// Type-safe navigation routes for the root NavigationStack.
/// Note: reward & movement-break are NOT routes — they are phases inside the
/// mission screen (replacing path entries mid-transition wedges NavigationStack).
enum AppRoute: Hashable {
    case adventureSelect
    case mission(MissionPlan)
    case forest
    case parentGate
    case parentDashboard
    case storyHistory
    case settings
}

/// User-adjustable settings, persisted via AppStorage keys in SettingsViewModel.
struct AppSettings: Equatable {
    var isSpeechEnabled = true
    var isMusicEnabled = true
    var isSoundEffectsEnabled = true
    var isReduceMotionEnabled = false
    var isColorBlindModeEnabled = false
    var preferredDifficulty: DifficultyPreference = .automatic
    var language: AppLanguage = .system
}

enum DifficultyPreference: String, CaseIterable, Codable {
    case gentle, automatic, adventurous
}

enum AppLanguage: String, CaseIterable, Codable {
    case system, english, spanish, hindi, french
}
