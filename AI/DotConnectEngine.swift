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

/// How dots are laid out on the board. Structured arrangements make hard
/// boards look deliberate and force planning (ring chords especially).
enum DotArrangement: String, CaseIterable, Sendable {
    case scatter    // free placement (current classic look)
    case grid       // jittered grid cells
    case ring       // evenly spaced on a circle, connections are chords
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
        // Structured layouts appear from Medium up; Hard/Genius favor them.
        let arrangement: DotArrangement
        switch difficulty {
        case .beginner, .easy:
            arrangement = .scatter
        case .medium:
            arrangement = Bool.random(using: &rng) ? .scatter : .grid
        case .hard, .genius:
            arrangement = Bool.random(using: &rng) ? .ring : .grid
        }
        return generate(difficulty: difficulty, arrangement: arrangement, using: &rng)
    }

    /// Arrangement-explicit variant (also used directly by tests).
    func generate<R: RandomNumberGenerator>(
        difficulty: DotDifficulty,
        arrangement: DotArrangement,
        using rng: inout R
    ) -> DotPuzzle {
        let pairs = Int.random(in: difficulty.pairRange, using: &rng)

        if arrangement == .ring {
            // Ring boards cap at 10 pairs: beyond 20 dots the circle gets so
            // dense that chord-to-dot clearance is geometrically impossible
            // (verified empirically — 16-pair rings never pass). Genius gets
            // a pristine 10-pair ring or a full-size grid instead.
            let ringPairs = min(pairs, 10)
            for _ in 0..<40 {
                if let puzzle = ringAttempt(pairs: ringPairs,
                                            duplicates: difficulty.usesDuplicateColors,
                                            using: &rng) {
                    return puzzle
                }
            }
            // Ring uniqueness failed repeatedly → fall through to grid.
            return generate(difficulty: difficulty, arrangement: .grid, using: &rng)
        }

        for _ in 0..<40 {
            if let puzzle = attempt(pairs: pairs,
                                    duplicates: difficulty.usesDuplicateColors,
                                    spacing: difficulty.minDotSpacing,
                                    arrangement: arrangement,
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
                                    arrangement: arrangement,
                                    requireUnique: true, using: &rng) {
                return puzzle
            }
        }
        // Deterministic last resort.
        var fallbackRNG = SeededGenerator(seed: 42)
        return attempt(pairs: 3, duplicates: false, spacing: 0.18,
                       arrangement: .scatter,
                       requireUnique: true, using: &fallbackRNG)!
    }

    /// Daily challenge: same puzzle for everyone on a given day.
    func dailyPuzzle(for date: Date = .now, calendar: Calendar = .current) -> DotPuzzle {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let seed = UInt64((parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0))
        var rng = SeededGenerator(seed: seed &* 0x2545F4914F6CDD1D)
        return generate(difficulty: .medium, using: &rng)
    }

    // MARK: Ring boards (chords on a circle — pure construction, no rejection)

    /// 2N points evenly on a circle; a random non-crossing chord matching is
    /// built by recursive arc splitting (partner must leave even-sized arcs
    /// on both sides — the Catalan structure). Always valid by construction.
    private func ringAttempt<R: RandomNumberGenerator>(
        pairs: Int, duplicates: Bool, using rng: inout R
    ) -> DotPuzzle? {
        let count = pairs * 2
        let phase = Double.random(in: 0..<(2 * .pi), using: &rng)
        let gap = 2 * Double.pi / Double(count)
        // CRITICAL: constant radius + ONE angle draw per point. Chords of a
        // circle are non-crossing iff endpoints don't interleave — but that
        // theorem needs all points in convex position ON the circle. Radius
        // jitter (or separate x/y angle draws) breaks it; angle jitter under
        // half a gap preserves cyclic order and stays safe. Verified over
        // 2000 random boards.
        let ringPoints: [CGPoint] = (0..<count).map { index in
            let angle = phase + Double(index) * gap
                + Double.random(in: (-gap * 0.18)...(gap * 0.18), using: &rng)
            return CGPoint(x: 0.5 + 0.40 * cos(angle), y: 0.5 + 0.40 * sin(angle))
        }

        // Random non-crossing matching over circular order 0..<count.
        var chords: [(Int, Int)] = []
        func match(_ slice: [Int]) {
            guard !slice.isEmpty else { return }
            let first = slice[0]
            // Valid partners leave an even count inside the enclosed arc.
            let validOffsets = stride(from: 1, to: slice.count, by: 2).map { $0 }
            let offset = validOffsets.randomElement(using: &rng)!
            chords.append((first, slice[offset]))
            match(Array(slice[1..<offset]))
            match(Array(slice[(offset + 1)...]))
        }
        match(Array(0..<count))

        // Reject boards where a chord grazes an uninvolved rim dot
        // (short-span chords hug the circle) — lines must never appear
        // to touch dots they don't connect.
        for chord in chords {
            for index in 0..<count where index != chord.0 && index != chord.1 {
                if Self.distance(from: ringPoints[index],
                                 toSegment: ringPoints[chord.0], ringPoints[chord.1]) < 0.028 {
                    return nil
                }
            }
        }

        // Reorder points so ids follow the pair layout used everywhere:
        // dot 2k and 2k+1 form solution pair k.
        var points: [CGPoint] = []
        var segments: [(Int, Int)] = []
        for chord in chords {
            points.append(ringPoints[chord.0])
            points.append(ringPoints[chord.1])
            segments.append((points.count - 2, points.count - 1))
        }
        return finishPuzzle(points: points, segments: segments, pairs: pairs,
                            duplicates: duplicates, requireUnique: true, using: &rng)
    }

    // MARK: Scatter / grid boards (rejection sampling)

    private func attempt<R: RandomNumberGenerator>(
        pairs: Int, duplicates: Bool, spacing: CGFloat,
        arrangement: DotArrangement,
        requireUnique: Bool, using rng: inout R
    ) -> DotPuzzle? {
        // 1. Lay down non-crossing solution segments by rejection sampling.
        var points: [CGPoint] = []
        var segments: [(Int, Int)] = []

        // Grid arrangement: sample from jittered cell centers instead of
        // anywhere — the board reads as an intentional lattice.
        let gridSide = Int(ceil((Double(pairs * 2) * 1.7).squareRoot()))
        var gridCells: [CGPoint] = []
        if arrangement == .grid {
            for row in 0..<gridSide {
                for column in 0..<gridSide {
                    let step = 0.84 / CGFloat(max(1, gridSide - 1))
                    gridCells.append(CGPoint(
                        x: 0.08 + CGFloat(column) * step + .random(in: -0.02...0.02, using: &rng),
                        y: 0.08 + CGFloat(row) * step + .random(in: -0.02...0.02, using: &rng)
                    ))
                }
            }
            gridCells.shuffle(using: &rng)
        }

        func randomPoint() -> CGPoint {
            if arrangement == .grid, !gridCells.isEmpty {
                return gridCells[Int.random(in: 0..<gridCells.count, using: &rng)]
            }
            return CGPoint(x: .random(in: 0.08...0.92, using: &rng),
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

        return finishPuzzle(points: points, segments: segments, pairs: pairs,
                            duplicates: duplicates, requireUnique: requireUnique,
                            using: &rng)
    }

    /// Shared tail: assign colors (optionally duplicated) and verify the
    /// exactly-one-solution guarantee.
    private func finishPuzzle<R: RandomNumberGenerator>(
        points: [CGPoint], segments: [(Int, Int)], pairs: Int,
        duplicates: Bool, requireUnique: Bool, using rng: inout R
    ) -> DotPuzzle? {
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
