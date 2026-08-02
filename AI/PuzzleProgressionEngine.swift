//
//  PuzzleProgressionEngine.swift
//  Focus Forest Adventure
//
//  Scoring, unlocking, and the adaptive rung for Puzzle Quest. Pure and
//  Sendable — no I/O, no dates, no persistence types.
//
//  The same child-psychology rules the mission engines follow apply here:
//  a run never scores zero stars, difficulty moves at most one rung at a
//  time, and the clock only *adds* a star — it never takes one away.
//

import Foundation

// MARK: - Results

/// One finished level: the attempts plus the score they earned.
struct PuzzleRunResult: Hashable, Sendable {
    var world: PuzzleWorld
    var level: Int
    var difficulty: Int
    var attempts: [PuzzleAttempt]
    var stars: Int
    var coins: Int
    /// First-try success rate. Stored rather than computed so a run can be
    /// rebuilt from the compact history on `PuzzleProgress` (which keeps
    /// scores, not every attempt).
    var accuracy: Double

    init(
        world: PuzzleWorld,
        level: Int,
        difficulty: Int,
        attempts: [PuzzleAttempt],
        stars: Int,
        coins: Int,
        accuracy: Double? = nil
    ) {
        self.world = world
        self.level = level
        self.difficulty = difficulty
        self.attempts = attempts
        self.stars = stars
        self.coins = coins
        if let accuracy {
            self.accuracy = accuracy
        } else if attempts.isEmpty {
            self.accuracy = 0
        } else {
            let firstTry = attempts.filter { $0.solved && $0.missedTaps == 0 }.count
            self.accuracy = Double(firstTry) / Double(attempts.count)
        }
    }

    var averageDuration: TimeInterval {
        guard !attempts.isEmpty else { return 0 }
        return attempts.map(\.duration).reduce(0, +) / Double(attempts.count)
    }
}

/// Badges are cosmetic and cumulative — they are never taken away.
enum PuzzleBadge: String, CaseIterable, Codable, Sendable, Hashable {
    case firstPuzzle, patternMaster, symmetrySeeker, rotationRanger
    case logicExplorer, memoryKeeper, puzzleChampion

    var localizedTitle: String {
        switch self {
        case .firstPuzzle: String(localized: "First Puzzle")
        case .patternMaster: String(localized: "Pattern Master")
        case .symmetrySeeker: String(localized: "Symmetry Seeker")
        case .rotationRanger: String(localized: "Rotation Ranger")
        case .logicExplorer: String(localized: "Logic Explorer")
        case .memoryKeeper: String(localized: "Memory Keeper")
        case .puzzleChampion: String(localized: "Puzzle Champion")
        }
    }

    var emoji: String {
        switch self {
        case .firstPuzzle: "🌱"
        case .patternMaster: "🔁"
        case .symmetrySeeker: "🪞"
        case .rotationRanger: "🔄"
        case .logicExplorer: "🧠"
        case .memoryKeeper: "🎴"
        case .puzzleChampion: "👑"
        }
    }

    /// Solving this many puzzles of the matching skill earns the badge.
    var requirement: (skill: PuzzleSkill, solved: Int)? {
        switch self {
        case .firstPuzzle, .puzzleChampion: nil
        case .patternMaster: (.completePattern, 25)
        case .symmetrySeeker: (.mirrorSymmetry, 20)
        case .rotationRanger: (.rotation, 20)
        case .logicExplorer: (.multiRule, 20)
        case .memoryKeeper: (.memoryLogic, 20)
        }
    }
}

/// Per-skill totals, the unit the parent dashboard reports on.
struct PuzzleSkillTally: Hashable, Sendable {
    var skill: PuzzleSkill
    var attempted: Int
    var solved: Int

    var mastery: Double {
        attempted == 0 ? 0 : Double(solved) / Double(attempted)
    }
}

/// Everything the engine needs to know about a child's history.
struct PuzzleProgressSnapshot: Hashable, Sendable {
    /// Highest level *completed* per world (0 = untouched).
    var completedLevels: [PuzzleWorld: Int] = [:]
    /// Current rung per world, 1…8.
    var difficulty: [PuzzleWorld: Int] = [:]
    var totalStars: Int = 0
    var coins: Int = 0
    var tallies: [PuzzleSkillTally] = []
    var badges: Set<PuzzleBadge> = []
    /// Most-recent-first results, used for the adaptive rung.
    var recentResults: [PuzzleRunResult] = []

    func completed(_ world: PuzzleWorld) -> Int { completedLevels[world] ?? 0 }
    func rung(_ world: PuzzleWorld) -> Int { (difficulty[world] ?? 1).clamped(to: 1...8) }
    func tally(_ skill: PuzzleSkill) -> PuzzleSkillTally {
        tallies.first { $0.skill == skill } ?? PuzzleSkillTally(skill: skill, attempted: 0, solved: 0)
    }
}

// MARK: - Engine

struct PuzzleProgressionEngine: Sendable {

    struct Thresholds: Sendable {
        /// First-try accuracy needed to move up a rung.
        var promoteAccuracy: Double = 0.8
        /// Strong runs in a row required — no promotion off a single lucky run.
        var promoteMinRuns: Int = 2
        var demoteAccuracy: Double = 0.4
        var range: ClosedRange<Int> = 1...8
        /// Fraction of the time limit that still counts as "quick".
        var speedStarFraction: Double = 0.6
    }

    var thresholds = Thresholds()

    // MARK: Scoring

    /// 1–3 stars. One star is the floor: finishing a level is the achievement,
    /// and a child who struggled still leaves with something.
    func stars(for attempts: [PuzzleAttempt]) -> Int {
        guard !attempts.isEmpty else { return 1 }
        let solved = attempts.filter(\.solved).count
        let firstTry = attempts.filter { $0.solved && $0.missedTaps == 0 }.count
        let solvedRatio = Double(solved) / Double(attempts.count)
        let firstTryRatio = Double(firstTry) / Double(attempts.count)

        let quick = attempts.filter { attempt in
            attempt.solved && attempt.duration <= attempt.timeLimit * thresholds.speedStarFraction
        }.count
        let quickRatio = Double(quick) / Double(attempts.count)

        if solvedRatio >= 1.0 && firstTryRatio >= 0.8 && quickRatio >= 0.5 { return 3 }
        if solvedRatio >= 0.8 && firstTryRatio >= 0.5 { return 2 }
        return 1
    }

    /// Coins fund world cosmetics; they scale with effort (puzzles attempted),
    /// not just accuracy, so a slow careful child still earns.
    func coins(for attempts: [PuzzleAttempt], stars: Int) -> Int {
        let effort = attempts.reduce(0) { total, attempt in
            total + (attempt.solved ? 10 : 4) - (attempt.usedHint ? 2 : 0)
        }
        return max(0, effort) + stars * 5
    }

    func makeResult(world: PuzzleWorld, level: Int, difficulty: Int, attempts: [PuzzleAttempt]) -> PuzzleRunResult {
        let earnedStars = stars(for: attempts)
        return PuzzleRunResult(
            world: world,
            level: level,
            difficulty: difficulty.clamped(to: thresholds.range),
            attempts: attempts,
            stars: earnedStars,
            coins: coins(for: attempts, stars: earnedStars)
        )
    }

    // MARK: Adaptive rung

    /// Next rung for a world. Moves one step at most; drops immediately when
    /// a run went badly, climbs only after sustained first-try accuracy.
    func nextDifficulty(
        current: Int,
        recentResults: [PuzzleRunResult],
        preference: DifficultyPreference = .automatic
    ) -> Int {
        let clamped = current.clamped(to: thresholds.range)
        var next = clamped
        if shouldDemote(recentResults) {
            next = clamped - 1
        } else if shouldPromote(recentResults) {
            next = clamped + 1
        }
        next = next.clamped(to: thresholds.range)

        switch preference {
        case .gentle: return min(next, max(thresholds.range.lowerBound, clamped))
        case .adventurous: return max(next, min(clamped + 1, thresholds.range.upperBound))
        case .automatic: return next
        }
    }

    private func shouldPromote(_ recent: [PuzzleRunResult]) -> Bool {
        let window = Array(recent.prefix(thresholds.promoteMinRuns))
        guard window.count >= thresholds.promoteMinRuns else { return false }
        return window.allSatisfy { $0.accuracy >= thresholds.promoteAccuracy && $0.stars >= 2 }
    }

    private func shouldDemote(_ recent: [PuzzleRunResult]) -> Bool {
        guard let last = recent.first else { return false }
        return last.accuracy < thresholds.demoteAccuracy
    }

    /// Starting rung for a child who has never played a world — derived from
    /// age so an 8-year-old doesn't have to grind through 2×2 color matching.
    func startingDifficulty(age: Int, world: PuzzleWorld) -> Int {
        let byAge: Int
        switch age {
        case ..<5: byAge = 1
        case 5: byAge = 2
        case 6: byAge = 3
        case 7: byAge = 5
        default: byAge = 6
        }
        let byWorld = PuzzleWorld.allCases.firstIndex(of: world).map { $0 + 1 } ?? 1
        return max(byAge, byWorld).clamped(to: thresholds.range)
    }

    // MARK: Unlocking

    func isUnlocked(_ world: PuzzleWorld, age: Int, snapshot: PuzzleProgressSnapshot) -> Bool {
        guard let previous = world.previous else { return true }
        // Age alone opens a world the child is old enough for; otherwise they
        // can still earn their way in through the previous world.
        if age >= world.minAge { return true }
        return snapshot.completed(previous) >= world.levelsRequiredInPrevious
    }

    func lockReason(_ world: PuzzleWorld, age: Int, snapshot: PuzzleProgressSnapshot) -> String? {
        guard !isUnlocked(world, age: age, snapshot: snapshot), let previous = world.previous else { return nil }
        let remaining = world.levelsRequiredInPrevious - snapshot.completed(previous)
        return String(localized: "Finish \(max(1, remaining)) more \(previous.localizedTitle) levels to open this!")
    }

    /// The level to play next in a world (1-based), capped at the world's size.
    func nextLevel(in world: PuzzleWorld, snapshot: PuzzleProgressSnapshot) -> Int {
        min(snapshot.completed(world) + 1, world.levelCount)
    }

    // MARK: Badges

    /// Badges earned by this result that the child doesn't already hold.
    func newBadges(after result: PuzzleRunResult, snapshot: PuzzleProgressSnapshot) -> [PuzzleBadge] {
        var earned: [PuzzleBadge] = []
        let solvedTotal = snapshot.tallies.reduce(0) { $0 + $1.solved }

        if !snapshot.badges.contains(.firstPuzzle), solvedTotal + result.attempts.filter(\.solved).count > 0 {
            earned.append(.firstPuzzle)
        }
        for badge in PuzzleBadge.allCases {
            guard let requirement = badge.requirement, !snapshot.badges.contains(badge) else { continue }
            let solved = snapshot.tally(requirement.skill).solved
                + result.attempts.filter { $0.skill == requirement.skill && $0.solved }.count
            if solved >= requirement.solved { earned.append(badge) }
        }
        if !snapshot.badges.contains(.puzzleChampion),
           snapshot.completed(.dragon) + (result.world == .dragon ? 1 : 0) >= 20 {
            earned.append(.puzzleChampion)
        }
        return earned
    }

    // MARK: Parent-facing summary

    /// Plain-language lines for the parent dashboard, strongest skill first.
    func parentSummary(snapshot: PuzzleProgressSnapshot) -> [String] {
        let played = snapshot.tallies.filter { $0.attempted > 0 }
        guard !played.isEmpty else {
            return [String(localized: "No puzzles yet — the Forest world is a gentle place to start.")]
        }
        let ranked = played.sorted { $0.mastery > $1.mastery }
        var lines = ranked.prefix(3).map { tally in
            String(localized: "\(tally.skill.localizedName): \(Int(tally.mastery * 100))% solved over \(tally.attempted) puzzles")
        }
        if let weakest = ranked.last, weakest.mastery < 0.6, ranked.count > 1 {
            lines.append(String(localized: "Still growing into \(weakest.skill.localizedName) — expect more practice there."))
        }
        return lines
    }
}
