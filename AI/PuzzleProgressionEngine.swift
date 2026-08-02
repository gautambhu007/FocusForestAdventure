//
//  PuzzleProgressionEngine.swift
//  Focus Forest Adventure
//
//  Scoring, crystals, unlocking, the adaptive rung, and the parent-facing
//  cognitive profile for Puzzle Adventure World. Pure and Sendable — no I/O,
//  no dates, no persistence types.
//
//  The child-psychology rules from the mission engines hold here too: a run
//  never scores zero stars, difficulty moves at most one rung at a time, and
//  the clock only ever *adds* a star.
//

import Foundation

// MARK: - Results

/// One finished level and what it earned.
struct PuzzleRunResult: Hashable, Sendable {
    var world: PuzzleWorld
    var level: Int
    var difficulty: Int
    var attempts: [PuzzleAttempt]
    var stars: Int
    /// 💎 Magic gems.
    var gems: Int
    /// 🧩 Puzzle pieces — one per level, more for a boss.
    var pieces: Int
    var isBoss: Bool
    /// First-try success rate. Stored rather than computed so a run can be
    /// rebuilt from the compact history on `PuzzleProgress`.
    var accuracy: Double

    init(
        world: PuzzleWorld,
        level: Int,
        difficulty: Int,
        attempts: [PuzzleAttempt],
        stars: Int,
        gems: Int,
        pieces: Int = 1,
        isBoss: Bool = false,
        accuracy: Double? = nil
    ) {
        self.world = world
        self.level = level
        self.difficulty = difficulty
        self.attempts = attempts
        self.stars = stars
        self.gems = gems
        self.pieces = pieces
        self.isBoss = isBoss
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

    /// Beating a boss wins that world's crystal.
    var earnsCrystal: Bool { isBoss }
}

// MARK: - Badges

enum PuzzleBadge: String, CaseIterable, Codable, Sendable, Hashable {
    case firstPuzzle, patternMaster, symmetrySeeker, rotationRanger
    case logicExplorer, memoryKeeper, crystalHunter, brainlandHero

    var localizedTitle: String {
        switch self {
        case .firstPuzzle: String(localized: "First Steps")
        case .patternMaster: String(localized: "Pattern Master")
        case .symmetrySeeker: String(localized: "Symmetry Seeker")
        case .rotationRanger: String(localized: "Rotation Ranger")
        case .logicExplorer: String(localized: "Logic Explorer")
        case .memoryKeeper: String(localized: "Memory Keeper")
        case .crystalHunter: String(localized: "Crystal Hunter")
        case .brainlandHero: String(localized: "Master Puzzle Explorer")
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
        case .crystalHunter: "💎"
        case .brainlandHero: "👑"
        }
    }

    /// Solving this many puzzles of the matching skill earns the badge.
    var requirement: (skill: PuzzleSkill, solved: Int)? {
        switch self {
        case .firstPuzzle, .crystalHunter, .brainlandHero: nil
        case .patternMaster: (.completePattern, 25)
        case .symmetrySeeker: (.mirrorSymmetry, 20)
        case .rotationRanger: (.rotation, 20)
        case .logicExplorer: (.multiRule, 20)
        case .memoryKeeper: (.memoryLogic, 20)
        }
    }
}

// MARK: - Snapshot

struct PuzzleSkillTally: Hashable, Sendable {
    var skill: PuzzleSkill
    var attempted: Int
    var solved: Int

    var mastery: Double {
        attempted == 0 ? 0 : Double(solved) / Double(attempted)
    }
}

/// Everything the engine needs about a child's campaign.
struct PuzzleProgressSnapshot: Hashable, Sendable {
    /// Highest level *completed* per world (0 = untouched).
    var completedLevels: [PuzzleWorld: Int] = [:]
    /// Current rung per world, 1…8.
    var difficulty: [PuzzleWorld: Int] = [:]
    /// Worlds whose boss has fallen.
    var crystals: Set<PuzzleWorld> = []
    var totalStars: Int = 0
    var gems: Int = 0
    var pieces: Int = 0
    var tallies: [PuzzleSkillTally] = []
    var badges: Set<PuzzleBadge> = []
    /// Most-recent-first results, for the adaptive rung.
    var recentResults: [PuzzleRunResult] = []

    // Aggregate signals for the cognitive profile.
    var puzzlesAttempted: Int = 0
    var puzzlesSolved: Int = 0
    /// Sum of (duration ÷ time limit) over every puzzle — the speed signal.
    var speedRatioSum: Double = 0
    var hintsUsed: Int = 0

    func completed(_ world: PuzzleWorld) -> Int { completedLevels[world] ?? 0 }
    func rung(_ world: PuzzleWorld) -> Int { (difficulty[world] ?? 1).clamped(to: 1...8) }
    func hasCrystal(_ world: PuzzleWorld) -> Bool { crystals.contains(world) }
    func tally(_ skill: PuzzleSkill) -> PuzzleSkillTally {
        tallies.first { $0.skill == skill } ?? PuzzleSkillTally(skill: skill, attempted: 0, solved: 0)
    }

    var earnedCrystals: [MagicCrystal] {
        PuzzleWorld.allCases.filter { crystals.contains($0) }.map(\.crystal)
    }

    /// Have the seven story crystals been gathered? (The Volcano Lab is a
    /// bonus world and doesn't gate the finale.)
    var hasAllKeyCrystals: Bool {
        PuzzleWorld.allCases
            .filter { $0 != .rainbow && $0 != .volcano }
            .allSatisfy { crystals.contains($0) }
    }

    var averageSpeedRatio: Double {
        puzzlesAttempted == 0 ? 1 : speedRatioSum / Double(puzzlesAttempted)
    }

    var hintRate: Double {
        puzzlesAttempted == 0 ? 0 : Double(hintsUsed) / Double(puzzlesAttempted)
    }

    var solveRate: Double {
        puzzlesAttempted == 0 ? 0 : Double(puzzlesSolved) / Double(puzzlesAttempted)
    }
}

/// One row of the parent dashboard's skill table.
struct CognitiveRating: Hashable, Sendable, Identifiable {
    var skill: CognitiveSkill
    /// 0…1. `nil` stars when there isn't enough play to say anything.
    var score: Double
    var samples: Int

    var id: CognitiveSkill { skill }

    /// 1–5 filled stars, or nil when untested.
    var stars: Int? {
        guard samples >= 5 else { return nil }
        return max(1, min(5, Int((score * 5).rounded())))
    }

    var starDisplay: String {
        guard let stars else { return String(localized: "not enough play yet") }
        return String(repeating: "⭐️", count: stars) + String(repeating: "☆", count: 5 - stars)
    }
}

// MARK: - Engine

struct PuzzleProgressionEngine: Sendable {

    struct Thresholds: Sendable {
        var promoteAccuracy: Double = 0.8
        var promoteMinRuns: Int = 2
        var demoteAccuracy: Double = 0.4
        var range: ClosedRange<Int> = 1...8
        /// Fraction of the time limit that still counts as "quick".
        var speedStarFraction: Double = 0.6
        /// Levels of the previous world that count as "ready" when a child is
        /// old enough but hasn't beaten its boss yet.
        var readyLevels: Int = 5
    }

    var thresholds = Thresholds()

    // MARK: Scoring

    /// 1–3 stars, floored at 1: finishing is the achievement, and a child who
    /// struggled still leaves with something.
    func stars(for attempts: [PuzzleAttempt]) -> Int {
        guard !attempts.isEmpty else { return 1 }
        let solved = attempts.filter(\.solved).count
        let firstTry = attempts.filter { $0.solved && $0.missedTaps == 0 }.count
        let solvedRatio = Double(solved) / Double(attempts.count)
        let firstTryRatio = Double(firstTry) / Double(attempts.count)
        let quick = attempts.filter {
            $0.solved && $0.duration <= $0.timeLimit * thresholds.speedStarFraction
        }.count
        let quickRatio = Double(quick) / Double(attempts.count)

        if solvedRatio >= 1.0 && firstTryRatio >= 0.8 && quickRatio >= 0.5 { return 3 }
        if solvedRatio >= 0.8 && firstTryRatio >= 0.5 { return 2 }
        return 1
    }

    /// Gems scale with effort (puzzles attempted), not just accuracy, so a
    /// slow careful child still fills their pouch.
    func gems(for attempts: [PuzzleAttempt], stars: Int, isBoss: Bool) -> Int {
        let effort = attempts.reduce(0) { total, attempt in
            total + (attempt.solved ? 10 : 4) - (attempt.usedHint ? 2 : 0)
        }
        let base = max(0, effort) + stars * 5
        return isBoss ? base * 2 : base
    }

    func makeResult(
        world: PuzzleWorld,
        level: Int,
        difficulty: Int,
        attempts: [PuzzleAttempt],
        isBoss: Bool = false
    ) -> PuzzleRunResult {
        let earnedStars = stars(for: attempts)
        return PuzzleRunResult(
            world: world,
            level: level,
            difficulty: difficulty.clamped(to: thresholds.range),
            attempts: attempts,
            stars: earnedStars,
            gems: gems(for: attempts, stars: earnedStars, isBoss: isBoss),
            pieces: isBoss ? 3 : 1,
            isBoss: isBoss
        )
    }

    // MARK: Adaptive rung

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

    /// Where a child starts a world they've never played. Age sets the floor
    /// so an older child doesn't have to grind 2×2 color matching; the world
    /// sets a second floor so later worlds never open trivially easy.
    func startingDifficulty(age: Int, world: PuzzleWorld) -> Int {
        let byAge: Int
        switch age {
        case ..<5: byAge = 1
        case 5: byAge = 2
        case 6: byAge = 3
        case 7: byAge = 5
        default: byAge = 6
        }
        let byWorld = ((PuzzleWorld.allCases.firstIndex(of: world) ?? 0) * 8) / PuzzleWorld.allCases.count + 1
        return max(byAge, byWorld).clamped(to: thresholds.range)
    }

    // MARK: Unlocking

    /// Worlds are earned. The previous world's crystal is the key; a child
    /// who is old enough and already well into the previous world may pass
    /// early, so a stuck boss never ends the campaign.
    func isUnlocked(_ world: PuzzleWorld, age: Int, snapshot: PuzzleProgressSnapshot) -> Bool {
        guard let previous = world.previous else { return true }
        if world.requiresAllCrystals { return snapshot.hasAllKeyCrystals }
        if snapshot.hasCrystal(previous) { return true }
        return age >= world.minAge && snapshot.completed(previous) >= thresholds.readyLevels
    }

    func lockReason(_ world: PuzzleWorld, age: Int, snapshot: PuzzleProgressSnapshot) -> String? {
        guard !isUnlocked(world, age: age, snapshot: snapshot) else { return nil }
        if world.requiresAllCrystals {
            let missing = PuzzleWorld.allCases
                .filter { $0 != .rainbow && $0 != .volcano && !snapshot.hasCrystal($0) }
                .count
            return String(localized: "Win \(missing) more crystal(s) to face the Shadow Wizard!")
        }
        guard let previous = world.previous else { return nil }
        if snapshot.completed(previous) > 0 {
            let remaining = max(1, thresholds.readyLevels - snapshot.completed(previous))
            return String(localized: "Play \(remaining) more \(previous.shortTitle) level(s) to open this!")
        }
        return String(localized: "Win the \(previous.crystal.localizedName) to open this!")
    }

    /// The level to play next in a world (1-based), capped at its boss.
    func nextLevel(in world: PuzzleWorld, snapshot: PuzzleProgressSnapshot) -> Int {
        min(snapshot.completed(world) + 1, world.levelCount)
    }

    /// Worlds the child may pick a daily puzzle from.
    func unlockedWorlds(age: Int, snapshot: PuzzleProgressSnapshot) -> [PuzzleWorld] {
        PuzzleWorld.allCases.filter { isUnlocked($0, age: age, snapshot: snapshot) }
    }

    // MARK: Badges

    func newBadges(after result: PuzzleRunResult, snapshot: PuzzleProgressSnapshot) -> [PuzzleBadge] {
        var earned: [PuzzleBadge] = []
        let solvedTotal = snapshot.tallies.reduce(0) { $0 + $1.solved }

        if !snapshot.badges.contains(.firstPuzzle),
           solvedTotal + result.attempts.filter(\.solved).count > 0 {
            earned.append(.firstPuzzle)
        }
        for badge in PuzzleBadge.allCases {
            guard let requirement = badge.requirement, !snapshot.badges.contains(badge) else { continue }
            let solved = snapshot.tally(requirement.skill).solved
                + result.attempts.filter { $0.skill == requirement.skill && $0.solved }.count
            if solved >= requirement.solved { earned.append(badge) }
        }

        var crystals = snapshot.crystals
        if result.earnsCrystal { crystals.insert(result.world) }
        if !snapshot.badges.contains(.crystalHunter), crystals.count >= 3 {
            earned.append(.crystalHunter)
        }
        if !snapshot.badges.contains(.brainlandHero), crystals.contains(.rainbow) {
            earned.append(.brainlandHero)
        }
        return earned
    }

    // MARK: Parent-facing profile

    /// The seven-skill table. Each row blends the mastery of the rungs that
    /// feed it; concentration and processing speed come from *how* the child
    /// plays rather than from any single puzzle type.
    func cognitiveProfile(snapshot: PuzzleProgressSnapshot) -> [CognitiveRating] {
        CognitiveSkill.allCases.map { skill in
            switch skill {
            case .concentration:
                // Solving without reaching for hints.
                let score = (snapshot.solveRate * 0.7) + ((1 - snapshot.hintRate.clamped(to: 0...1)) * 0.3)
                return CognitiveRating(skill: skill, score: score.clamped(to: 0...1),
                                       samples: snapshot.puzzlesAttempted)
            case .processingSpeed:
                // Fast relative to the (generous) time limit.
                let ratio = snapshot.averageSpeedRatio.clamped(to: 0...1.5)
                return CognitiveRating(skill: skill, score: (1 - ratio / 1.5).clamped(to: 0...1),
                                       samples: snapshot.puzzlesAttempted)
            default:
                let feeding = PuzzleSkill.allCases.filter { $0.cognitiveSkills.contains(skill) }
                let tallies = feeding.map { snapshot.tally($0) }
                let attempted = tallies.reduce(0) { $0 + $1.attempted }
                let solved = tallies.reduce(0) { $0 + $1.solved }
                let score = attempted == 0 ? 0 : Double(solved) / Double(attempted)
                return CognitiveRating(skill: skill, score: score, samples: attempted)
            }
        }
    }

    /// Plain-language lines for the dashboard, strongest first, plus a
    /// concrete "play this next" recommendation.
    func parentSummary(snapshot: PuzzleProgressSnapshot, age: Int) -> [String] {
        let rated = cognitiveProfile(snapshot: snapshot).filter { $0.stars != nil }
        guard !rated.isEmpty else {
            return [String(localized: "No puzzles yet — the Forest of Patterns is a gentle place to start.")]
        }
        let ranked = rated.sorted { $0.score > $1.score }
        var lines: [String] = []
        if let best = ranked.first {
            lines.append(String(localized: "Strongest right now: \(best.skill.localizedName)."))
        }
        if let weakest = ranked.last, ranked.count > 1, weakest.score < 0.7 {
            lines.append(String(localized: "Still growing into \(weakest.skill.localizedName)."))
            if let world = worldToPractise(weakest.skill, age: age, snapshot: snapshot) {
                lines.append(String(localized: "Try \(world.emoji) \(world.localizedTitle) next — it practises exactly that."))
            }
        }
        if !snapshot.crystals.isEmpty {
            lines.append(String(localized: "Crystals won: \(snapshot.crystals.count) of \(PuzzleWorld.allCases.count)."))
        }
        return lines
    }

    /// An unlocked world whose chapters lean on the given skill.
    private func worldToPractise(
        _ skill: CognitiveSkill,
        age: Int,
        snapshot: PuzzleProgressSnapshot
    ) -> PuzzleWorld? {
        unlockedWorlds(age: age, snapshot: snapshot).max { left, right in
            weight(of: left, for: skill) < weight(of: right, for: skill)
        }
        .flatMap { weight(of: $0, for: skill) > 0 ? $0 : nil }
    }

    private func weight(of world: PuzzleWorld, for skill: CognitiveSkill) -> Int {
        world.kinds.filter { $0.skill.cognitiveSkills.contains(skill) }.count
    }
}
