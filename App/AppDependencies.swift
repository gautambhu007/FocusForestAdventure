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
    let engagementEngine: EngagementEngine
    let storyCache: StoryCache
    let storyNarrator: StoryNarrator
    let storyService: StoryService
    let intentDetector: IntentDetector
    let conversationEngine: ConversationEngine
    let conversationHistory: ConversationHistory
    let voiceManager: any VoiceManagerProtocol
    let handTrackingService: any HandTrackingServiceProtocol
    let breakMusicEngine: BreakMusicEngine
    let premiumStore: PremiumStore

    // MARK: Use Cases
    let startMissionUseCase: StartMissionUseCase
    let completeMissionUseCase: CompleteMissionUseCase
    let fetchTodayPlanUseCase: FetchTodayPlanUseCase
    let fetchStatisticsUseCase: FetchStatisticsUseCase

    init(modelContainer: ModelContainer) {
        let context = modelContainer.mainContext
        self.appState = AppState()

        // Pull cross-device learning scores from iCloud key-value store.
        SyncedScoreStore.synchronize()

        // Hydrate persisted settings at launch (previously they only synced
        // when the Settings screen was opened — a latent inconsistency).
        let defaults = UserDefaults.standard
        appState.settings.isSpeechEnabled = defaults.object(forKey: "settings.speech") as? Bool ?? true
        appState.settings.isMusicEnabled = defaults.object(forKey: "settings.music") as? Bool ?? true
        appState.settings.isSoundEffectsEnabled = defaults.object(forKey: "settings.effects") as? Bool ?? true
        appState.settings.isColorBlindModeEnabled = defaults.bool(forKey: "settings.colorblind")
        appState.settings.isEngagementAdaptationEnabled = defaults.bool(forKey: "settings.engagement")
        appState.settings.preferredDifficulty = DifficultyPreference(
            rawValue: defaults.string(forKey: "settings.difficulty") ?? ""
        ) ?? .automatic
        let savedAge = defaults.integer(forKey: "settings.childAge")
        appState.settings.childAge = savedAge == 0 ? 4 : savedAge
        appState.settings.dailyLimitMinutes = defaults.integer(forKey: "settings.dailyLimit")

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
        speech.isEnabled = appState.settings.isSpeechEnabled
        sound.isMusicEnabled = appState.settings.isMusicEnabled
        sound.isEffectsEnabled = appState.settings.isSoundEffectsEnabled
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
            statisticsRepository: statsRepo,
            recommendationEngine: recommendation,
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
        self.engagementEngine = EngagementEngine()
        self.storyCache = storyCache
        self.storyNarrator = storyNarrator
        self.storyService = storyService

        // Phase 2.2 Bunny assistant (all offline: engines are pure values,
        // history is session-only, voice recognition is on-device)
        self.intentDetector = IntentDetector()
        self.conversationEngine = ConversationEngine()
        self.conversationHistory = ConversationHistory()
        self.voiceManager = VoiceManager()
        self.handTrackingService = HandTrackingService()
        self.breakMusicEngine = BreakMusicEngine()

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
    /// Bumped by the usage meter so the screen-time gate re-evaluates.
    var usageTick = 0
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
    case bunnyAssistant
    case arForest
    case starCatch
    case hindiAlphabet
    case hindiLearning
    case hindiModule(String)
    case barakhadi
    case multiplicationTables
    case rhymes
    case moralStories
    case hindiTracing
    case clockGame
    case learningRewards
    case leafCatch
    case bubblePop
    case settings
}

/// User-adjustable settings, persisted via AppStorage keys in SettingsViewModel.
struct AppSettings: Equatable {
    var isSpeechEnabled = true
    var isMusicEnabled = true
    var isSoundEffectsEnabled = true
    var isReduceMotionEnabled = false
    var isColorBlindModeEnabled = false
    /// Phase 2.7: interaction-based engagement adaptation. OFF by default;
    /// requires explicit parent consent in Settings.
    var isEngagementAdaptationEnabled = false
    /// Parent-controlled daily play limit in minutes (0 = off). Set from
    /// the PIN-protected parent dashboard.
    var dailyLimitMinutes: Int = 0
    var preferredDifficulty: DifficultyPreference = .automatic
    var language: AppLanguage = .system
    /// Age-based content: 4 = letter recognition in ABC, 5 = word reading
    /// (4 word options, non-repeating 350+ word bank).
    var childAge: Int = 4
}

enum DifficultyPreference: String, CaseIterable, Codable {
    case gentle, automatic, adventurous
}

enum AppLanguage: String, CaseIterable, Codable {
    case system, english, spanish, hindi, french
}
