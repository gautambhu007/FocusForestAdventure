//
//  LearningRecommendationEngine.swift
//  Focus Forest Adventure
//
//  On-device personalization. Scores every subject on four signals and blends
//  them into "today's plan": which adventure to suggest first, what to practice,
//  and when to celebrate strengths. Struggling subjects get MORE (gentler) games;
//  strong subjects get slow difficulty growth. Favorites keep motivation high.
//

import Foundation

struct LearningRecommendationEngine: Sendable {

    let difficultyEngine: AdaptiveDifficultyEngine

    struct Weights: Sendable {
        var needsPractice: Double = 0.40   // low accuracy → surface more often, easier
        var enjoyment: Double = 0.25       // favorite → keeps the child coming back
        var freshness: Double = 0.20       // not played recently → variety
        var momentum: Double = 0.15        // improving → ride the wave
    }

    var weights = Weights()

    struct TodayPlan: Sendable, Equatable {
        var recommendedAdventures: [AdventureKind]   // ordered, best first
        var difficultyPerSubject: [AdventureKind: Int]
        var targetMissions: Int
        var missionDuration: TimeInterval
        var encouragementFocus: AdventureKind?       // subject to celebrate today
    }

    init(difficultyEngine: AdaptiveDifficultyEngine) {
        self.difficultyEngine = difficultyEngine
    }

    /// Build today's personalized plan from the performance summary.
    func makeTodayPlan(
        summary: PerformanceSummary,
        preference: DifficultyPreference = .automatic
    ) -> TodayPlan {
        var scores: [(AdventureKind, Double)] = []
        var difficulties: [AdventureKind: Int] = [:]

        for kind in AdventureKind.allCases {
            let stats = summary.perSubject[kind]
            scores.append((kind, score(for: kind, stats: stats)))
            difficulties[kind] = difficultyEngine.nextDifficulty(
                current: stats?.currentDifficulty ?? 1,
                recentMissions: [],                    // per-mission history applied at start time
                preference: preference
            )
        }

        let ordered = scores.sorted { $0.1 > $1.1 }.map(\.0)

        // Celebrate the strongest subject to reinforce confidence.
        let strongest = summary.perSubject
            .filter { $0.value.missions >= 2 }
            .max { $0.value.accuracy < $1.value.accuracy }?.key

        return TodayPlan(
            recommendedAdventures: ordered,
            difficultyPerSubject: difficulties,
            targetMissions: targetMissions(attention: summary.averageAttentionScore),
            missionDuration: difficultyEngine.recommendedMissionDuration(
                attentionScore: summary.averageAttentionScore
            ),
            encouragementFocus: strongest
        )
    }

    // MARK: Scoring

    func score(for kind: AdventureKind, stats: PerformanceSummary.SubjectStats?) -> Double {
        guard let stats, stats.missions > 0 else {
            return 0.7   // unexplored subjects rank high — encourage discovery
        }

        // 1. Needs practice: accuracy below the 80% flow target boosts priority,
        //    but truly frustrated subjects (<40%) are eased in, not spammed.
        let gap = (0.8 - stats.accuracy).clamped(to: 0...0.8) / 0.8
        let needsPractice = stats.accuracy < 0.4 ? gap * 0.6 : gap

        // 2. Enjoyment proxy: played often → the child likes it.
        let enjoyment = Double(stats.missions).squareRoot() / 5.0

        // 3. Freshness: days since last played (caps at 5 days).
        let days = stats.lastPlayed.map { -$0.timeIntervalSinceNow / 86_400 } ?? 5
        let freshness = (days / 5.0).clamped(to: 0...1)

        // 4. Momentum: fast responders at current difficulty are ready for more.
        let momentum = stats.averageResponseTime > 0
            ? (1.0 - (stats.averageResponseTime / 10.0)).clamped(to: 0...1)
            : 0.5

        return needsPractice * weights.needsPractice
             + enjoyment.clamped(to: 0...1) * weights.enjoyment
             + freshness * weights.freshness
             + momentum * weights.momentum
    }

    private func targetMissions(attention: Double) -> Int {
        switch attention {
        case ..<0.35: 2
        case ..<0.7: 3
        default: 4
        }
    }

    // MARK: Parent recommendations

    /// Plain-language recommendations for the parent dashboard.
    func parentRecommendations(summary: PerformanceSummary) -> [String] {
        var tips: [String] = []

        for (kind, stats) in summary.perSubject where stats.missions >= 2 {
            if stats.accuracy < 0.5 {
                tips.append(String(localized:
                    "\(kind.localizedTitle) is still budding 🌱 — the app will offer gentler \(kind.localizedTitle) games this week. A few minutes of real-world practice (e.g. spotting them on walks) helps too."))
            } else if stats.accuracy > 0.85 {
                tips.append(String(localized:
                    "\(kind.localizedTitle) is a superpower ⭐ — difficulty will rise gently to keep it fun."))
            }
        }

        if summary.averageAttentionScore < 0.4 && summary.totalMissions >= 3 {
            tips.append(String(localized:
                "Focus sessions work best when short. Try one or two missions at a time, ideally at the same time each day."))
        }
        if tips.isEmpty {
            tips.append(String(localized:
                "Everything looks great! Keep sessions playful and celebrate effort, not results."))
        }
        return tips
    }
}

// MARK: - Phase 2.8: Daily recommendations (mission, story, reward, break, schedule)

/// Story flavor the StoryEngine can lean into.
enum StoryTheme: String, CaseIterable, Sendable {
    case discovery      // new explorer / unexplored subjects
    case courage        // struggling somewhere — stories about brave tries
    case celebration    // on a roll — stories that celebrate
    case friendship     // steady default

    var localizedTitle: String {
        switch self {
        case .discovery: String(localized: "Discovery")
        case .courage: String(localized: "Courage")
        case .celebration: String(localized: "Celebration")
        case .friendship: String(localized: "Friendship")
        }
    }
}

/// Which reward the celebration screen should spotlight.
enum RewardEmphasis: String, Sendable {
    case stars      // instant gratification for short attention spans
    case seeds      // growth framing for steady players
    case magicDust  // rare-feeling reward for high mastery
}

struct ScheduleSlot: Sendable, Equatable {
    let hour: Int          // 24h clock, local time
    let label: String
}

/// Everything the app adapts for today, in one explainable bundle.
struct DailyRecommendations: Sendable {
    var mission: AdventureKind
    var difficulty: Int
    var storyTheme: StoryTheme
    var rewardEmphasis: RewardEmphasis
    var movementBreak: MovementBreak
    var favoriteActivity: AdventureKind?
    var schedule: [ScheduleSlot]
    /// Plain-language, non-judgmental notes for the parent dashboard.
    var parentExplanations: [String]
}

extension LearningRecommendationEngine {

    /// Deterministic daily bundle. Degrades gracefully with little or no
    /// history: unexplored profiles get discovery framing and gentle defaults.
    func makeDailyRecommendations(
        summary: PerformanceSummary,
        preference: DifficultyPreference = .automatic
    ) -> DailyRecommendations {
        let plan = makeTodayPlan(summary: summary, preference: preference)
        let mission = plan.recommendedAdventures.first ?? .alphabet
        let difficulty = plan.difficultyPerSubject[mission] ?? 1

        let playedSubjects = summary.perSubject.filter { $0.value.missions >= 2 }
        let lowest = playedSubjects.min { $0.value.accuracy < $1.value.accuracy }
        let highest = playedSubjects.max { $0.value.accuracy < $1.value.accuracy }

        let theme: StoryTheme
        if summary.totalMissions < 3 {
            theme = .discovery
        } else if let lowest, lowest.value.accuracy < 0.5 {
            theme = .courage
        } else if let highest, highest.value.accuracy > 0.85 {
            theme = .celebration
        } else {
            theme = .friendship
        }

        let reward: RewardEmphasis
        if summary.averageAttentionScore < 0.4 {
            reward = .stars
        } else if let highest, highest.value.accuracy > 0.85 {
            reward = .magicDust
        } else {
            reward = .seeds
        }

        // Calm breathing break when attention runs low; a dance when energy
        // is there to burn. Indexed into the fixed catalog, so deterministic.
        let breaks = MovementBreak.all
        let movementBreak = summary.averageAttentionScore < 0.5
            ? breaks[min(3, breaks.count - 1)]     // "Grow Like a Tree" breathing
            : breaks[breaks.count - 1]             // "Dance Party!"

        let favorite = summary.perSubject
            .max { $0.value.missions < $1.value.missions }
            .flatMap { $0.value.missions > 0 ? $0.key : nil }

        // Short sessions, spread out: morning slot always; afternoon when the
        // plan targets 3+; early evening only for 4-mission days.
        var schedule = [ScheduleSlot(hour: 9, label: String(localized: "Morning adventure"))]
        if plan.targetMissions >= 3 {
            schedule.append(ScheduleSlot(hour: 16, label: String(localized: "Afternoon mission")))
        }
        if plan.targetMissions >= 4 {
            schedule.append(ScheduleSlot(hour: 18, label: String(localized: "One more before dinner")))
        }

        var explanations: [String] = []
        explanations.append(String(localized:
            "Today's suggested adventure is \(mission.localizedTitle) at level \(difficulty) — chosen from recent accuracy, variety, and what \(favorite.map(\.localizedTitle) ?? String(localized: "your child")) enjoys."))
        explanations.append(String(localized:
            "Stories will lean into \(theme.localizedTitle.lowercased()) themes, and movement breaks will be \(summary.averageAttentionScore < 0.5 ? String(localized: "calm and breathing-based") : String(localized: "energetic"))."))
        if summary.totalMissions < 3 {
            explanations.append(String(localized:
                "The app is still getting to know your child — recommendations become more personal after a few missions."))
        }

        return DailyRecommendations(
            mission: mission,
            difficulty: difficulty,
            storyTheme: theme,
            rewardEmphasis: reward,
            movementBreak: movementBreak,
            favoriteActivity: favorite,
            schedule: schedule,
            parentExplanations: explanations
        )
    }
}
