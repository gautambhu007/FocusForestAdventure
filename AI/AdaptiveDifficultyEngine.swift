//
//  AdaptiveDifficultyEngine.swift
//  Focus Forest Adventure
//
//  Adaptive difficulty for 4–6 year olds. Core principles:
//  • Difficulty NEVER jumps — it moves at most one step at a time.
//  • Promotion needs sustained mastery (high accuracy AND fast responses).
//  • Demotion is quick and quiet — a struggling child gets easier games
//    immediately, framed as a new adventure, never as failure.
//  • Targets the "flow channel": ~80% success rate keeps young children engaged.
//

import Foundation

struct AdaptiveDifficultyEngine: Sendable {

    struct Thresholds: Sendable {
        var promoteAccuracy: Double = 0.85
        var promoteMaxResponseTime: TimeInterval = 6.0
        var promoteMinMissions: Int = 2       // need ≥2 strong missions in a row
        var demoteAccuracy: Double = 0.5
        var difficultyRange: ClosedRange<Int> = 1...5
    }

    var thresholds = Thresholds()

    /// Decide the difficulty for the child's next mission in a subject.
    /// - Parameters:
    ///   - current: last-used difficulty for this subject.
    ///   - recentMissions: most-recent-first mission results for this subject.
    ///   - preference: parent override (gentle caps at 2, adventurous floors at 2).
    func nextDifficulty(
        current: Int,
        recentMissions: [MissionOutcome],
        preference: DifficultyPreference = .automatic
    ) -> Int {
        let clamped = current.clamped(to: thresholds.difficultyRange)
        var next = clamped

        if shouldDemote(recentMissions) {
            next = clamped - 1                 // ease off immediately
        } else if shouldPromote(recentMissions) {
            next = clamped + 1                 // one gentle step up
        }

        next = next.clamped(to: thresholds.difficultyRange)

        switch preference {
        case .gentle: return min(next, 2)
        case .adventurous: return max(next, 2)
        case .automatic: return next
        }
    }

    private func shouldPromote(_ recent: [MissionOutcome]) -> Bool {
        let window = Array(recent.prefix(thresholds.promoteMinMissions))
        guard window.count >= thresholds.promoteMinMissions else { return false }
        return window.allSatisfy {
            $0.accuracy >= thresholds.promoteAccuracy &&
            $0.averageResponseTime <= thresholds.promoteMaxResponseTime &&
            !$0.endedEarly
        }
    }

    private func shouldDemote(_ recent: [MissionOutcome]) -> Bool {
        guard let last = recent.first else { return false }
        return last.accuracy < thresholds.demoteAccuracy || last.endedEarly
    }

    // MARK: Attention span

    /// Estimated attention span (seconds) — grows slowly with successful sessions.
    /// Ages 4–6 typically hold focus for 1 minute per year of age on a novel task;
    /// we start at 3 minutes and extend toward 5 as consistency improves.
    func recommendedMissionDuration(attentionScore: Double) -> TimeInterval {
        let base: TimeInterval = 180                      // 3 min floor
        let bonus = attentionScore.clamped(to: 0...1) * 120
        return base + bonus                               // 3–5 min
    }

    /// Attention score from a finished mission: consistency of response times
    /// weighted by completion. Wandering attention → highly variable timings.
    func attentionScore(responseTimes: [TimeInterval], completed: Bool) -> Double {
        guard responseTimes.count > 1 else { return completed ? 0.6 : 0.3 }
        let mean = responseTimes.reduce(0, +) / Double(responseTimes.count)
        guard mean > 0 else { return 0.3 }
        let variance = responseTimes.map { pow($0 - mean, 2) }.reduce(0, +) / Double(responseTimes.count)
        let coefficientOfVariation = sqrt(variance) / mean
        let consistency = (1.0 - coefficientOfVariation).clamped(to: 0...1)
        return (consistency * 0.7 + (completed ? 0.3 : 0.0)).clamped(to: 0...1)
    }
}

/// Minimal mission result the engine needs (decoupled from SwiftData).
struct MissionOutcome: Sendable, Equatable {
    var accuracy: Double
    var averageResponseTime: TimeInterval
    var endedEarly: Bool

    init(accuracy: Double, averageResponseTime: TimeInterval, endedEarly: Bool = false) {
        self.accuracy = accuracy
        self.averageResponseTime = averageResponseTime
        self.endedEarly = endedEarly
    }

    @MainActor
    init(record: MissionRecord) {
        self.accuracy = record.accuracy
        self.averageResponseTime = record.averageResponseTime
        self.endedEarly = record.endedEarly
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
