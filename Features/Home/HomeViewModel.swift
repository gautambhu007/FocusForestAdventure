//
//  HomeViewModel.swift
//  Focus Forest Adventure
//

import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {

    private let dependencies: AppDependencies

    private(set) var child: ChildProfile?
    private(set) var forest: ForestState?
    private(set) var goalProgress: Double = 0
    private(set) var stars: Int = 0
    private(set) var forestLevelName: String = ""
    private(set) var bunnyGreeting: String = BunnyPhrase.welcome.text
    /// Unspent visits to the Magic Forest — the child's headline goal.
    private(set) var forestPasses: Int = 0
    private(set) var nextTreasure: ForestTreasure?
    var isLoading = true

    var canEnterMagicForest: Bool { MagicForestRules.canEnter(passes: forestPasses) }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func onAppear() async {
        do {
            let child = try dependencies.childRepository.activeChild()
            self.child = child
            let forest = try dependencies.forestRepository.forest(for: child)
            self.forest = forest
            self.stars = forest.stars
            self.forestLevelName = dependencies.forestGrowthEngine.localizedLevelName(forest.level)
            self.forestPasses = forest.forestPasses
            self.nextTreasure = TreasureCatalog.next(after: forest.earnedTreasureIDs)

            let goal = try dependencies.statisticsRepository.todayGoal(for: child)
            self.goalProgress = goal.progress

            // Begin a play session if none is active today.
            _ = try dependencies.statisticsRepository.beginSession(for: child)

            dependencies.soundEngine.playAmbience()
            isLoading = false

            await dependencies.speechService.speak(bunnyGreeting)
        } catch {
            isLoading = false
            // Non-fatal: home renders with defaults; errors here are recoverable.
            assertionFailure("Home load failed: \(error)")
        }
    }

    var forestDensity: AnimatedForestBackground.Density {
        switch forest?.level ?? 1 {
        case ..<3: .light
        case ..<6: .medium
        default: .lush
        }
    }

    func startAdventureTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        dependencies.appState.navigationPath.append(.adventureSelect)
    }

    func forestTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.appState.navigationPath.append(.forest)
    }

    func talkToBunnyTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        dependencies.appState.navigationPath.append(.bunnyAssistant)
    }

    func hindiLearningTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        dependencies.appState.navigationPath.append(.hindiLearning)
    }

    func listeningCornerTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        dependencies.appState.navigationPath.append(.listeningHub)
    }

    func puzzleQuestTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        dependencies.appState.navigationPath.append(.puzzleWorlds)
    }

    func magicChestTapped() {
        dependencies.hapticsService.playSuccess()
        dependencies.soundEngine.play(.chestOpen)
    }

    func parentButtonTapped() {
        dependencies.appState.navigationPath.append(.parentGate)
    }

    func settingsTapped() {
        dependencies.appState.navigationPath.append(.settings)
    }
}
