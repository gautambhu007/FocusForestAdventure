//
//  MissionViewModel.swift
//  Focus Forest Adventure
//
//  Runs a mission: sequences questions, times responses, applies the
//  frustration guard (auto-end with celebration before the child struggles),
//  and hands results to CompleteMissionUseCase.
//

import Foundation
import Observation

@Observable
@MainActor
final class MissionViewModel {

    // MARK: Public state (rendered by MissionContainerView)

    private(set) var plan: MissionPlan
    private(set) var questionIndex = 0
    private(set) var feedback: Feedback = .none
    private(set) var sparkleTrigger = 0
    private(set) var isFinishing = false
    private(set) var progress: Double = 0

    /// The mission flow (play → reward → story → movement break) lives INSIDE
    /// one navigation destination. Replacing NavigationStack path entries
    /// mid-transition puts the stack in a broken state where later path
    /// changes are ignored (frozen screen, dead buttons) — so we don't.
    /// `.story` is a marker case: the record itself lives in `pendingStory`
    /// (SwiftData models aren't Equatable, so it can't be an associated value).
    enum MissionPhase: Equatable {
        case playing
        case reward(RewardBundle)
        case story
        case movementBreak(MovementBreak)
    }

    private(set) var phase: MissionPhase = .playing
    private var pendingBreak: MovementBreak = .random()

    /// Story generated after mission completion (Phase 2.1). Nil when
    /// generation failed — the flow then skips straight to the movement break.
    private(set) var pendingStory: StoryRecord?

    /// Phase 2.8: which reward the celebration should spotlight today.
    private(set) var rewardEmphasis: RewardEmphasis?

    enum Feedback: Equatable { case none, correct, tryAgain }

    var currentQuestion: MissionQuestion? {
        plan.questions.indices.contains(questionIndex) ? plan.questions[questionIndex] : nil
    }

    // MARK: Private tracking

    let dependencies: AppDependencies
    private var correct = 0
    private var wrong = 0
    private var consecutiveMisses = 0
    private var responseTimes: [TimeInterval] = []
    private var questionShownAt = Date()
    private var missionStartedAt = Date()
    private var timerTask: Task<Void, Never>?

    init(plan: MissionPlan, dependencies: AppDependencies) {
        self.plan = plan
        self.dependencies = dependencies
    }

    // MARK: Lifecycle

    func onAppear() async {
        missionStartedAt = .now
        questionShownAt = .now
        startFrustrationGuardTimer()
        if let question = currentQuestion {
            await dependencies.speechService.speak(question.prompt)
        }
    }

    func onDisappear() {
        timerTask?.cancel()
    }

    /// Hard time cap: end gracefully before attention runs out.
    private func startFrustrationGuardTimer() {
        timerTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(plan.maxDuration))
            guard !Task.isCancelled, !isFinishing else { return }
            await finishMission(endedEarly: true)
        }
    }

    // MARK: Answer handling

    func submitAnswer(correct isCorrect: Bool) async {
        guard feedback == .none, !isFinishing else { return }
        responseTimes.append(Date().timeIntervalSince(questionShownAt))

        if isCorrect {
            correct += 1
            consecutiveMisses = 0
            feedback = .correct
            sparkleTrigger += 1
            dependencies.hapticsService.playSuccess()
            dependencies.soundEngine.play(.correctChime)
            await dependencies.speechService.speak(BunnyPhrase.correct.text)
            try? await Task.sleep(for: .seconds(1.2))
            await applyEngagementPacing()
            guard !isFinishing else { return }
            await advance()
        } else {
            wrong += 1
            consecutiveMisses += 1
            feedback = .tryAgain
            dependencies.hapticsService.playSoftWobble()
            dependencies.soundEngine.play(.gentleTryAgain)
            await dependencies.speechService.speak(BunnyPhrase.gentleRetry.text)
            try? await Task.sleep(for: .seconds(1.0))

            if consecutiveMisses >= plan.frustrationMissLimit {
                // Frustration guard: end on a high note, full celebration, no blame.
                await finishMission(endedEarly: true)
            } else {
                feedback = .none   // same question, gentle retry
                questionShownAt = .now
            }
        }
    }

    /// Called by non-binary games (tracing, memory) when the child completes the task.
    func completeCurrentQuestion() async {
        await submitAnswer(correct: true)
    }

    /// Phase 2.7: consent-gated pacing from interaction signals only.
    /// Low engagement → cheerful nudge; very low → celebratory early end
    /// (same graceful exit as the frustration guard — never a punishment).
    private func applyEngagementPacing() async {
        guard dependencies.appState.settings.isEngagementAdaptationEnabled,
              responseTimes.count >= 3, !isFinishing else { return }

        let score = dependencies.engagementEngine.score(
            responseTimes: responseTimes,
            consecutiveMisses: consecutiveMisses,
            secondsSinceInteraction: 0   // we just got an answer
        )
        switch dependencies.engagementEngine.advice(for: score) {
        case .keepGoing:
            break
        case .encourage:
            await dependencies.speechService.speak(
                String(localized: "You're doing so well! Just a little more!")
            )
        case .windDown:
            await finishMission(endedEarly: true)
        }
    }

    /// Home button: leave the mission early. Progress so far still counts and
    /// the child still gets a celebration — leaving is never a failure.
    func exitEarly() async {
        guard !isFinishing else { return }
        dependencies.hapticsService.playGentleTap()
        if correct + wrong == 0 {
            // Nothing attempted yet — just go home quietly, no ceremony.
            timerTask?.cancel()
            isFinishing = true
            dependencies.appState.navigationPath.removeAll()
        } else {
            await finishMission(endedEarly: true)
        }
    }

    private func advance() async {
        feedback = .none
        questionIndex += 1
        progress = Double(questionIndex) / Double(plan.questions.count)

        if questionIndex >= plan.questions.count {
            await finishMission(endedEarly: false)
        } else {
            questionShownAt = .now
            if let question = currentQuestion {
                await dependencies.speechService.speak(question.prompt)
            }
        }
    }

    // MARK: Completion

    private func finishMission(endedEarly: Bool) async {
        guard !isFinishing else { return }
        isFinishing = true
        timerTask?.cancel()

        do {
            let child = try dependencies.childRepository.activeChild()
            let result = try dependencies.completeMissionUseCase.execute(
                plan: plan,
                child: child,
                correct: correct,
                wrong: wrong,
                responseTimes: responseTimes,
                endedEarly: endedEarly,
                elapsed: Date().timeIntervalSince(missionStartedAt)
            )
            // Phase 2.1: Bunny writes a story from today's progress. Story
            // failure must never block the celebration — fall back silently.
            pendingStory = try? dependencies.storyService.generateStory(
                after: plan, child: child, rewards: result.rewards
            )
            // Phase 2.8: consume the daily recommendations — movement break
            // that fits today's focus pattern, and the reward to spotlight.
            // Failure is silent; the use case's random break is the fallback.
            pendingBreak = result.movementBreak
            if let summary = try? dependencies.statisticsRepository.performanceSummary(for: child, days: 14) {
                let daily = dependencies.recommendationEngine.makeDailyRecommendations(
                    summary: summary,
                    preference: dependencies.appState.settings.preferredDifficulty
                )
                pendingBreak = daily.movementBreak
                rewardEmphasis = daily.rewardEmphasis
            }
            // Same screen, new phase — no NavigationStack surgery.
            phase = .reward(result.rewards)
        } catch {
            dependencies.appState.navigationPath.removeAll()
        }
    }

    /// Continue button on the reward screen: story first when Bunny has one,
    /// otherwise straight to the movement break.
    func continueFromReward() {
        if pendingStory != nil {
            phase = .story
        } else {
            phase = .movementBreak(pendingBreak)
        }
    }

    /// "Wiggle Time!" — from the story reader (or reward screen fallback).
    func continueToMovementBreak() {
        phase = .movementBreak(pendingBreak)
    }

    // MARK: Support for sequence/memory games

    func playSound(named name: String) {
        guard let effect = SoundEffect(rawValue: name) else { return }
        let played = dependencies.soundEngine.play(effect)
        // No recording bundled yet? Bunny performs the sound instead
        // ("Roaaar!", "Quack quack!") so listening games always work.
        if !played, let phrase = effect.spokenFallback {
            Task { await dependencies.speechService.speak(phrase) }
        }
    }

    func speak(_ text: String) async {
        await dependencies.speechService.speak(text)
    }

    func gentleTapHaptic() {
        dependencies.hapticsService.playGentleTap()
    }

    func successHaptic() {
        dependencies.hapticsService.playSuccess()
    }

    func wobbleHaptic() {
        dependencies.hapticsService.playSoftWobble()
    }
}
