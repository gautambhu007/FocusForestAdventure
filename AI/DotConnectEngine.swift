//
//  DotConnectEngine.swift
//  Focus Forest Adventure
//
//  Smart Dot Connect puzzle engine: procedural generator + computational
//  geometry, pure and fully unit-testable.
//
//  Puzzle design: dots come in same-color pairs and every connection is a
//  straight line that must not cross any other. On higher difficulties a
//  color appears on FOUR dots (two pairs), so the child must deduce which
//  partner is correct — the generator enumerates all same-color matchings
//  and only ships puzzles with EXACTLY ONE non-crossing solution.
//

import Foundation
import CoreGraphics

// MARK: - Model

struct DotPuzzle: Sendable, Equatable {
    struct Dot: Identifiable, Sendable, Equatable {
        let id: Int
        let point: CGPoint        // normalized 0…1
        let colorIndex: Int
    }

    let dots: [Dot]
    /// The unique solution as dot-id pairs (a < b).
    let solution: [[Int]]
    var pairCount: Int { solution.count }
}

enum DotDifficulty: String, CaseIterable, Identifiable, Sendable {
    case beginner, easy, medium, hard, genius

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .beginner: String(localized: "Beginner")
        case .easy: String(localized: "Easy")
        case .medium: String(localized: "Medium")
        case .hard: String(localized: "Hard")
        case .genius: String(localized: "Genius")
        }
    }

    var stars: String {
        switch self {
        case .beginner: "🌱"
        case .easy: "⭐"
        case .medium: "⭐⭐"
        case .hard: "⭐⭐⭐"
        case .genius: "🧠"
        }
    }

    var pairRange: ClosedRange<Int> {
        switch self {
        case .beginner: 3...4
        case .easy: 5...5
        case .medium: 6...7
        case .hard: 8...10
        case .genius: 12...16
        }
    }

    /// Duplicated colors (two pairs share a color) create real deduction.
    var usesDuplicateColors: Bool {
        switch self {
        case .beginner, .easy: false
        case .medium, .hard, .genius: true
        }
    }

    /// Minimum spacing shrinks as boards get busier.
    var minDotSpacing: CGFloat {
        switch self {
        case .beginner: 0.18
        case .easy: 0.15
        case .medium: 0.13
        case .hard: 0.11
        case .genius: 0.085
        }
    }

    /// Target seconds for the three-star time bonus.
    var targetSeconds: Int {
        switch self {
        case .beginner: 25
        case .easy: 35
        case .medium: 50
        case .hard: 75
        case .genius: 120
        }
    }
}

// MARK: - Seeded RNG (daily challenge determinism)

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Engine

struct DotConnectEngine: Sendable {

    // MARK: Geometry

    /// Strict segment intersection (shared endpoints excluded by callers —
    /// puzzle dots are always distinct).
    static func segmentsCross(_ a1: CGPoint, _ a2: CGPoint,
                              _ b1: CGPoint, _ b2: CGPoint) -> Bool {
        func orient(_ p: CGPoint, _ q: CGPoint, _ r: CGPoint) -> CGFloat {
            (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)
        }
        func onSegment(_ p: CGPoint, _ q: CGPoint, _ r: CGPoint) -> Bool {
            min(p.x, r.x) - 1e-9 <= q.x && q.x <= max(p.x, r.x) + 1e-9 &&
            min(p.y, r.y) - 1e-9 <= q.y && q.y <= max(p.y, r.y) + 1e-9
        }
        let o1 = orient(a1, a2, b1), o2 = orient(a1, a2, b2)
        let o3 = orient(b1, b2, a1), o4 = orient(b1, b2, a2)

        if (o1 > 0) != (o2 > 0), (o3 > 0) != (o4 > 0),
           o1 != 0 || o2 != 0, o3 != 0 || o4 != 0 {
            return true
        }
        // Collinear overlaps count as crossings too.
        if o1 == 0, onSegment(a1, b1, a2) { return true }
        if o2 == 0, onSegment(a1, b2, a2) { return true }
        if o3 == 0, onSegment(b1, a1, b2) { return true }
        if o4 == 0, onSegment(b1, a2, b2) { return true }
        return false
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    /// Distance from point to segment (keeps dots off other lines).
    static func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return distance(p, a) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        return distance(p, CGPoint(x: a.x + t * dx, y: a.y + t * dy))
    }

    // MARK: Generation

    /// Generate a verified puzzle. Always succeeds (falls back to fewer
    /// pairs / unique colors if a constraint-heavy roll gets stuck).
    func generate<R: RandomNumberGenerator>(
        difficulty: DotDifficulty,
        using rng: inout R
    ) -> DotPuzzle {
        let pairs = Int.random(in: difficulty.pairRange, using: &rng)
        for _ in 0..<40 {
            if let puzzle = attempt(pairs: pairs,
                                    duplicates: difficulty.usesDuplicateColors,
                                    spacing: difficulty.minDotSpacing,
                                    requireUnique: true,
                                    using: &rng) {
                return puzzle
            }
        }
        // Dense boards can make uniqueness rare: relax to unique-colors
        // (matching is then forced, hence trivially unique) at full size.
        for _ in 0..<20 {
            if let puzzle = attempt(pairs: pairs, duplicates: false,
                                    spacing: difficulty.minDotSpacing,
                                    requireUnique: true, using: &rng) {
                return puzzle
            }
        }
        // Deterministic last resort.
        var fallbackRNG = SeededGenerator(seed: 42)
        return attempt(pairs: 3, duplicates: false, spacing: 0.18,
                       requireUnique: true, using: &fallbackRNG)!
    }

    /// Daily challenge: same puzzle for everyone on a given day.
    func dailyPuzzle(for date: Date = .now, calendar: Calendar = .current) -> DotPuzzle {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let seed = UInt64((parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0))
        var rng = SeededGenerator(seed: seed &* 0x2545F4914F6CDD1D)
        return generate(difficulty: .medium, using: &rng)
    }

    private func attempt<R: RandomNumberGenerator>(
        pairs: Int, duplicates: Bool, spacing: CGFloat,
        requireUnique: Bool, using rng: inout R
    ) -> DotPuzzle? {
        // 1. Lay down non-crossing solution segments by rejection sampling.
        var points: [CGPoint] = []
        var segments: [(Int, Int)] = []

        func randomPoint() -> CGPoint {
            CGPoint(x: .random(in: 0.08...0.92, using: &rng),
                    y: .random(in: 0.08...0.92, using: &rng))
        }

        var tries = 0
        while segments.count < pairs {
            tries += 1
            if tries > 600 { return nil }

            let a = randomPoint()
            let b = randomPoint()
            let length = Self.distance(a, b)
            guard length > 0.16, length < 0.6 else { continue }
            // Dot separation from every existing dot.
            guard points.allSatisfy({ Self.distance($0, a) > spacing && Self.distance($0, b) > spacing }),
                  Self.distance(a, b) > spacing else { continue }
            // No crossing with existing solution segments…
            let crosses = segments.contains { seg in
                Self.segmentsCross(points[seg.0], points[seg.1], a, b)
            }
            guard !crosses else { continue }
            // …and dots keep clear of other segments (and vice versa).
            let tooClose = segments.contains { seg in
                Self.distance(from: a, toSegment: points[seg.0], points[seg.1]) < spacing * 0.6 ||
                Self.distance(from: b, toSegment: points[seg.0], points[seg.1]) < spacing * 0.6
            } || points.indices.contains { index in
                Self.distance(from: points[index], toSegment: a, b) < spacing * 0.6
            }
            guard !tooClose else { continue }

            points.append(a)
            points.append(b)
            segments.append((points.count - 2, points.count - 1))
        }

        // 2. Colors: unique per pair, or duplicated (two pairs per color)
        //    on harder boards.
        var colorOfPair = Array(0..<pairs)
        if duplicates {
            // Pair up ~half the pairs to share colors.
            var order = Array(0..<pairs).shuffled(using: &rng)
            var nextColor = 0
            colorOfPair = Array(repeating: 0, count: pairs)
            while !order.isEmpty {
                let first = order.removeFirst()
                colorOfPair[first] = nextColor
                if order.count > 0, Bool.random(using: &rng) || order.count == 1 {
                    let second = order.removeFirst()
                    colorOfPair[second] = nextColor
                }
                nextColor += 1
            }
        }

        let dots = points.indices.map { index in
            DotPuzzle.Dot(id: index, point: points[index],
                          colorIndex: colorOfPair[index / 2])
        }
        let solution = segments.map { [$0.0, $0.1].sorted() }
        let puzzle = DotPuzzle(dots: dots, solution: solution)

        // 3. Verify: exactly one non-crossing same-color perfect matching.
        if requireUnique {
            guard Self.countSolutions(of: puzzle, limit: 2) == 1 else { return nil }
        }
        return puzzle
    }

    // MARK: Verification

    /// Count non-crossing same-color perfect matchings (early exit at limit).
    static func countSolutions(of puzzle: DotPuzzle, limit: Int = 2) -> Int {
        let groups = Dictionary(grouping: puzzle.dots, by: \.colorIndex)
            .values.map { $0.map(\.id) }
        var count = 0
        var chosen: [(Int, Int)] = []
        let position: [CGPoint] = puzzle.dots
            .sorted { $0.id < $1.id }
            .map(\.point)

        func addsCrossing(_ a: Int, _ b: Int) -> Bool {
            chosen.contains { seg in
                segmentsCross(position[seg.0], position[seg.1], position[a], position[b])
            }
        }

        func matchGroup(_ groupIndex: Int, remaining: [Int]) {
            guard count < limit else { return }
            if remaining.isEmpty {
                if groupIndex + 1 < groups.count {
                    matchGroup(groupIndex + 1, remaining: groups[groupIndex + 1])
                } else {
                    count += 1
                }
                return
            }
            let first = remaining[0]
            for partnerIndex in 1..<remaining.count {
                let partner = remaining[partnerIndex]
                guard !addsCrossing(first, partner) else { continue }
                chosen.append((first, partner))
                var rest = remaining
                rest.remove(at: partnerIndex)
                rest.removeFirst()
                matchGroup(groupIndex, remaining: rest)
                chosen.removeLast()
            }
        }

        guard let firstGroup = groups.first else { return 0 }
        matchGroup(0, remaining: firstGroup)
        return count
    }
}
