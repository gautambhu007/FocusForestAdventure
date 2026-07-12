//
//  EngagementEngine.swift
//  Focus Forest Adventure
//
//  Phase 2.7 engagement estimation — deliberately CAMERA-FREE.
//
//  The plan allows on-device camera estimation; we chose interaction signals
//  instead (response times, misses, idle gaps). Rationale: identical benefit
//  (pacing adaptation) with a categorically stronger privacy story for a
//  kids' app — there is no image pipeline to audit because none exists.
//
//  Privacy invariants (Phase 2.7 acceptance criteria):
//  - Off by default; enabled only by explicit parent consent in Settings.
//  - No camera, no images, no biometrics — interaction timing only.
//  - The signal is used solely for pacing, difficulty, and encouragement.
//  - Nothing leaves the device; nothing is persisted beyond the session.
//

import Foundation

struct EngagementEngine: Sendable {

    /// What the mission should do right now.
    enum PacingAdvice: Equatable, Sendable {
        case keepGoing        // engaged — don't interrupt
        case encourage        // dipping — a cheerful Bunny nudge
        case windDown         // low — steer to a graceful, celebratory end
    }

    /// Engagement 0…1 from session-local interaction signals.
    ///
    /// - responseTimes: recent answer times, newest last (last ~5 matter)
    /// - consecutiveMisses: wrong answers in a row
    /// - secondsSinceInteraction: idle time since the last tap
    func score(
        responseTimes: [TimeInterval],
        consecutiveMisses: Int,
        secondsSinceInteraction: TimeInterval
    ) -> Double {
        // Speed component: 3s answers ≈ locked in, 10s+ ≈ drifting.
        let recent = responseTimes.suffix(5)
        let speed: Double
        if recent.isEmpty {
            speed = 0.7   // no data yet — assume fine, don't nag at the start
        } else {
            let average = recent.reduce(0, +) / Double(recent.count)
            speed = (1.0 - ((average - 3.0) / 7.0)).clamped(to: 0...1)
        }

        // Trend component: each recent answer slower than the one before
        // signals fading attention even while the average still looks fine.
        var slowingSteps = 0
        let pairs = Array(recent)
        if pairs.count >= 2 {
            for index in 1..<pairs.count where pairs[index] > pairs[index - 1] {
                slowingSteps += 1
            }
        }
        let trend = 1.0 - (Double(slowingSteps) / 4.0).clamped(to: 0...1)

        // Miss component: consecutive misses drain engagement fast.
        let misses = (1.0 - Double(consecutiveMisses) * 0.34).clamped(to: 0...1)

        // Idle component: > 20s without touching anything ≈ gone.
        let idle = (1.0 - (secondsSinceInteraction / 20.0)).clamped(to: 0...1)

        return (speed * 0.35 + trend * 0.15 + misses * 0.30 + idle * 0.20)
            .clamped(to: 0...1)
    }

    func advice(for score: Double) -> PacingAdvice {
        switch score {
        case ..<0.30: .windDown
        case ..<0.55: .encourage
        default: .keepGoing
        }
    }
}
