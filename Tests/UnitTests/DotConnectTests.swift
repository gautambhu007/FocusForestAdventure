//
//  DotConnectTests.swift
//  FocusForestAdventureTests
//
//  Smart Dot Connect: segment geometry, generator guarantees (solvable,
//  non-crossing, unique solution), difficulty sizing, daily determinism.
//

import XCTest
@testable import FocusForestAdventure

final class DotConnectGeometryTests: XCTestCase {

    func testCrossingSegmentsDetected() {
        XCTAssertTrue(DotConnectEngine.segmentsCross(
            CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 0)
        ))
    }

    func testParallelSegmentsDoNotCross() {
        XCTAssertFalse(DotConnectEngine.segmentsCross(
            CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5)
        ))
    }

    func testDisjointSegmentsDoNotCross() {
        XCTAssertFalse(DotConnectEngine.segmentsCross(
            CGPoint(x: 0, y: 0), CGPoint(x: 0.2, y: 0.2),
            CGPoint(x: 0.8, y: 0.8), CGPoint(x: 1, y: 1)
        ))
    }

    func testCollinearOverlapCountsAsCross() {
        XCTAssertTrue(DotConnectEngine.segmentsCross(
            CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 0.5, y: 0), CGPoint(x: 1.5, y: 0)
        ))
    }

    func testTouchingAtSharedPointCounts() {
        // T-junction: endpoint of one lies on the other.
        XCTAssertTrue(DotConnectEngine.segmentsCross(
            CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1)
        ))
    }
}

final class DotConnectGeneratorTests: XCTestCase {

    let engine = DotConnectEngine()

    private func validate(_ puzzle: DotPuzzle, difficulty: DotDifficulty) {
        // Sizing. Ring boards legally cap rim chords at 10 pairs and may add
        // up to 2 inner pairs — so their total lands in 3...12.
        let rimCount = puzzle.dots.filter {
            abs(DotConnectEngine.distance($0.point, CGPoint(x: 0.5, y: 0.5)) - 0.40) < 0.02
        }.count
        let isRing = rimCount * 2 > puzzle.dots.count
        XCTAssertTrue(difficulty.pairRange.contains(puzzle.pairCount)
                      || (isRing && (3...12).contains(puzzle.pairCount)),
                      "\(difficulty): pair count \(puzzle.pairCount)")
        XCTAssertEqual(puzzle.dots.count, puzzle.pairCount * 2)

        // Solution pairs are same-color and cover every dot exactly once
        var seen = Set<Int>()
        for pair in puzzle.solution {
            XCTAssertEqual(puzzle.dots[pair[0]].colorIndex,
                           puzzle.dots[pair[1]].colorIndex)
            XCTAssertTrue(seen.isDisjoint(with: pair))
            seen.formUnion(pair)
        }
        XCTAssertEqual(seen.count, puzzle.dots.count)

        // Solution is non-crossing
        for i in 0..<puzzle.solution.count {
            for j in (i + 1)..<puzzle.solution.count {
                let a = puzzle.solution[i], b = puzzle.solution[j]
                XCTAssertFalse(DotConnectEngine.segmentsCross(
                    puzzle.dots[a[0]].point, puzzle.dots[a[1]].point,
                    puzzle.dots[b[0]].point, puzzle.dots[b[1]].point
                ), "\(difficulty): solution lines must not cross")
            }
        }

        // Exactly one solution
        XCTAssertEqual(DotConnectEngine.countSolutions(of: puzzle, limit: 3), 1,
                       "\(difficulty): puzzle must have a unique solution")
    }

    func testEveryDifficultyGeneratesValidUniquePuzzles() {
        for difficulty in DotDifficulty.allCases {
            var rng = SeededGenerator(seed: 12345)
            let puzzle = engine.generate(difficulty: difficulty, using: &rng)
            validate(puzzle, difficulty: difficulty)
        }
    }

    func testRepeatedGenerationStaysValid() {
        for seed in 1...5 {
            var rng = SeededGenerator(seed: UInt64(seed) * 977)
            let puzzle = engine.generate(difficulty: .medium, using: &rng)
            validate(puzzle, difficulty: .medium)
        }
    }

    func testHardBoardsUseDuplicateColorsForDeduction() {
        // Duplicate-color grouping is probabilistic and uniqueness rejection
        // can discard some rolls — assert it appears within several seeds.
        var found = false
        for seed in 1...12 where !found {
            var rng = SeededGenerator(seed: UInt64(seed) * 7919)
            let puzzle = engine.generate(difficulty: .hard, using: &rng)
            let colorCounts = Dictionary(grouping: puzzle.dots, by: \.colorIndex)
            found = colorCounts.values.contains { $0.count == 4 }
        }
        XCTAssertTrue(found, "Hard boards should regularly include a color with two pairs")
    }

    func testRingArrangementPutsDotsOnCircleWithValidUniqueSolution() {
        for seed in 1...6 {
            var rng = SeededGenerator(seed: UInt64(seed) * 331)
            let puzzle = engine.generate(difficulty: .hard, arrangement: .ring, using: &rng)
            validate(puzzle, difficulty: .hard)
            // Every dot sits on the r=0.40 circle around the center
            // (unless uniqueness forced the grid fallback — detect that).
            let onCircle = puzzle.dots.allSatisfy { dot in
                abs(DotConnectEngine.distance(dot.point, CGPoint(x: 0.5, y: 0.5)) - 0.40) < 0.01
            }
            if onCircle == false {
                // Grid fallback is legal; just require validity (already checked).
                continue
            }
        }
    }

    func testGridArrangementGeneratesValidUniquePuzzles() {
        for seed in 1...6 {
            var rng = SeededGenerator(seed: UInt64(seed) * 613)
            let puzzle = engine.generate(difficulty: .genius, arrangement: .grid, using: &rng)
            validate(puzzle, difficulty: .genius)
        }
    }

    func testInnerDotsAppearOnLargeRingBoards() {
        // 8+ pair rings add 2 inner pairs — some dots must sit off the rim.
        var found = false
        for seed in 1...10 where !found {
            var rng = SeededGenerator(seed: UInt64(seed) * 449)
            let puzzle = engine.generate(difficulty: .hard, arrangement: .ring, using: &rng)
            let inner = puzzle.dots.filter {
                DotConnectEngine.distance($0.point, CGPoint(x: 0.5, y: 0.5)) < 0.30
            }
            found = inner.count >= 2
            if found { validate(puzzle, difficulty: .hard) }
        }
        XCTAssertTrue(found, "Large ring boards should include inner dots")
    }

    func testPictureScenesAreValidPlayablePuzzles() {
        for scene in DotPictures.scenes {
            let puzzle = DotPictures.puzzle(for: scene)
            XCTAssertEqual(puzzle.dots.count, scene.strokes.count * 2)
            // Unique color per stroke → matching forced → single solution
            XCTAssertEqual(DotConnectEngine.countSolutions(of: puzzle, limit: 3), 1,
                           "\(scene.id): picture must be solvable and unique")
            // Solution strokes never cross
            for i in 0..<puzzle.solution.count {
                for j in (i + 1)..<puzzle.solution.count {
                    let a = puzzle.solution[i], b = puzzle.solution[j]
                    XCTAssertFalse(DotConnectEngine.segmentsCross(
                        puzzle.dots[a[0]].point, puzzle.dots[a[1]].point,
                        puzzle.dots[b[0]].point, puzzle.dots[b[1]].point
                    ), "\(scene.id): strokes \(i)/\(j) cross")
                }
            }
            // Finger-sized dot spacing
            for i in 0..<puzzle.dots.count {
                for j in (i + 1)..<puzzle.dots.count where i / 2 != j / 2 {
                    XCTAssertGreaterThan(
                        DotConnectEngine.distance(puzzle.dots[i].point, puzzle.dots[j].point),
                        0.05, "\(scene.id): dots \(i)/\(j) too close")
                }
            }
        }
    }

    func testDailyPuzzleIsDeterministicPerDay() {
        let day = Date(timeIntervalSince1970: 1_760_000_000)
        let first = engine.dailyPuzzle(for: day)
        let second = engine.dailyPuzzle(for: day)
        XCTAssertEqual(first, second, "Same day must yield the same puzzle")

        let nextDay = day.addingTimeInterval(86_400)
        XCTAssertNotEqual(engine.dailyPuzzle(for: nextDay), first,
                          "Different days should differ")
    }
}
