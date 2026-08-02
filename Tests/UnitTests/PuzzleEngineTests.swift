//
//  PuzzleEngineTests.swift
//  FocusForestAdventureTests
//
//  Property-style coverage of the puzzle generator: every kind, every rung,
//  every world, many seeds. The two invariants that matter for a child are
//  "exactly one answer is right" and "no two choices look the same".
//

import XCTest
import SwiftData
@testable import FocusForestAdventure

final class PuzzleGeneratorTests: XCTestCase {

    private let engine = PuzzleGeneratorEngine()

    // MARK: Structure

    func testEveryKindAndRungProducesAWellFormedPuzzle() {
        for kind in PuzzleKind.allCases {
            for world in kind.worlds {
                for rung in 1...8 {
                    for seed in UInt64(1)...12 {
                        let spec = PuzzleSpec(world: world, kind: kind, difficulty: rung)
                        let puzzle = engine.generate(spec: spec, seed: seed &* 6_364_136_223_846_793_005)
                        let context = "\(kind.rawValue) w:\(world.rawValue) d:\(rung) s:\(seed)"

                        XCTAssertEqual(
                            puzzle.grid.tiles.count, puzzle.grid.rows * puzzle.grid.columns,
                            "grid size mismatch — \(context)"
                        )
                        XCTAssertGreaterThan(puzzle.grid.rows, 0, "empty grid — \(context)")
                        XCTAssertGreaterThan(puzzle.grid.columns, 0, "empty grid — \(context)")
                        // Same-or-different asks about the board as a whole,
                        // so it is the one kind with no gap to fill.
                        let expectedTargets = kind == .sameOrDifferent ? 0 : 1
                        XCTAssertEqual(
                            puzzle.grid.tiles.filter(\.isTarget).count, expectedTargets,
                            "wrong number of target tiles — \(context)"
                        )
                        XCTAssertGreaterThan(puzzle.reward, 0, "no reward — \(context)")
                        XCTAssertGreaterThan(puzzle.timeLimit, 0, "no time limit — \(context)")
                        XCTAssertFalse(puzzle.prompt.isEmpty, "no prompt — \(context)")
                        XCTAssertFalse(puzzle.hint.isEmpty, "no hint — \(context)")
                    }
                }
            }
        }
    }

    /// The correct id always resolves — to an option chip, or to a board tile
    /// in tap-the-odd-one-out mode.
    func testCorrectAnswerIsAlwaysReachable() {
        forEachPuzzle { puzzle, context in
            switch puzzle.answerMode {
            case .options:
                XCTAssertGreaterThanOrEqual(puzzle.options.count, 2, "too few options — \(context)")
                XCTAssertEqual(
                    puzzle.options.filter { $0.id == puzzle.correctID }.count, 1,
                    "exactly one option must be the answer — \(context)"
                )
            case .tapTile:
                XCTAssertTrue(puzzle.options.isEmpty, "tap-tile puzzles have no chips — \(context)")
                XCTAssertEqual(
                    puzzle.grid.tiles.filter { $0.id == puzzle.correctID }.count, 1,
                    "exactly one tile must be the answer — \(context)"
                )
                XCTAssertTrue(
                    puzzle.grid.tiles.first { $0.id == puzzle.correctID }?.isTarget == true,
                    "the answer tile must be the target — \(context)"
                )
            }
        }
    }

    /// Two identical-looking chips would make a correct tap a coin flip.
    func testOptionsAreVisuallyDistinct() {
        forEachPuzzle { puzzle, context in
            guard puzzle.answerMode == .options else { return }
            let glyphs = puzzle.options.compactMap(\.glyph)
            XCTAssertEqual(Set(glyphs).count, glyphs.count, "duplicate glyph options — \(context)")
            let texts = puzzle.options.compactMap(\.text)
            XCTAssertEqual(Set(texts).count, texts.count, "duplicate text options — \(context)")
        }
    }

    func testOptionCountMatchesSpec() {
        for rung in 1...8 {
            let spec = PuzzleSpec(world: .forest, kind: .completePattern, difficulty: rung)
            let puzzle = engine.generate(spec: spec, seed: UInt64(rung) &* 99)
            XCTAssertEqual(puzzle.options.count, spec.options)
        }
    }

    // MARK: Rule correctness

    /// The pattern kinds must be solvable by reading the row: the answer is
    /// exactly the glyph the repeating unit calls for.
    func testPatternAnswerRestoresTheRepeatingUnit() {
        for kind in [PuzzleKind.completePattern, .continueSequence, .missingColor] {
            for seed in UInt64(1)...40 {
                let spec = PuzzleSpec(world: .forest, kind: kind, difficulty: 2)
                let puzzle = engine.generate(spec: spec, seed: seed &* 7_919)
                guard let targetIndex = puzzle.grid.targetIndex,
                      let answer = puzzle.options.first(where: { $0.id == puzzle.correctID })?.glyph
                else { return XCTFail("no target/answer for \(kind.rawValue)") }

                var restored = puzzle.grid.tiles.map(\.glyph)
                restored[targetIndex] = answer
                let glyphs = restored.compactMap { $0 }
                XCTAssertEqual(glyphs.count, restored.count, "\(kind.rawValue) should have no other gaps")

                // Find the period, then check the whole row obeys it.
                let period = (1...glyphs.count).first { candidate in
                    glyphs.indices.allSatisfy { glyphs[$0] == glyphs[$0 % candidate] }
                }
                XCTAssertNotNil(period, "\(kind.rawValue) row is not periodic")
                XCTAssertLessThanOrEqual(period ?? 99, 3, "\(kind.rawValue) period is too long to read")
            }
        }
    }

    /// Odd-one-out: the tapped tile must be the only one that differs.
    func testOddOneOutHasExactlyOneDifferentTile() {
        for rung in 2...8 {
            for seed in UInt64(1)...25 {
                let spec = PuzzleSpec(world: .jungle, kind: .oddOneOut, difficulty: rung)
                let puzzle = engine.generate(spec: spec, seed: seed &* 331)
                let glyphs = puzzle.grid.tiles.compactMap(\.glyph)
                let counts = Dictionary(grouping: glyphs, by: { $0 }).mapValues(\.count)
                XCTAssertEqual(counts.count, 2, "board should hold exactly two distinct glyphs")
                XCTAssertEqual(counts.values.filter { $0 == 1 }.count, 1, "exactly one glyph is unique")

                let odd = puzzle.grid.tiles.first { $0.id == puzzle.correctID }?.glyph
                XCTAssertEqual(counts[odd ?? glyphs[0]], 1, "the answer tile must be the unique one")
            }
        }
    }

    /// Visual sudoku: filling the answer in must leave every row and column
    /// free of repeated colors.
    func testVisualSudokuAnswerKeepsRowsAndColumnsUnique() {
        for seed in UInt64(1)...40 {
            let spec = PuzzleSpec(world: .dragon, kind: .visualSudoku, difficulty: 8)
            let puzzle = engine.generate(spec: spec, seed: seed &* 613)
            guard let targetIndex = puzzle.grid.targetIndex,
                  let answer = puzzle.options.first(where: { $0.id == puzzle.correctID })?.glyph
            else { return XCTFail("no target/answer") }

            var colors = puzzle.grid.tiles.map { $0.glyph?.color }
            colors[targetIndex] = answer.color
            let side = puzzle.grid.columns
            for row in 0..<puzzle.grid.rows {
                let line = (0..<side).compactMap { colors[row * side + $0] }
                XCTAssertEqual(Set(line).count, side, "row \(row) repeats a color")
            }
            for column in 0..<side {
                let line = (0..<puzzle.grid.rows).compactMap { colors[$0 * side + column] }
                XCTAssertEqual(Set(line).count, line.count, "column \(column) repeats a color")
            }
        }
    }

    /// Raven matrix: shape comes from the row, color from the column, and
    /// only one chip satisfies both.
    func testRavenMatrixAnswerSatisfiesBothRules() {
        for seed in UInt64(1)...40 {
            let spec = PuzzleSpec(world: .dragon, kind: .ravenMatrix, difficulty: 7)
            let puzzle = engine.generate(spec: spec, seed: seed &* 449)
            guard let targetIndex = puzzle.grid.targetIndex,
                  let answer = puzzle.options.first(where: { $0.id == puzzle.correctID })?.glyph
            else { return XCTFail("no target/answer") }

            let side = puzzle.grid.columns
            let row = targetIndex / side
            let column = targetIndex % side
            let rowMate = (0..<side).compactMap { puzzle.grid.tile(row: row, column: $0)?.glyph }.first
            let columnMate = (0..<puzzle.grid.rows).compactMap { puzzle.grid.tile(row: $0, column: column)?.glyph }.first
            XCTAssertEqual(answer.symbol, rowMate?.symbol, "shape must match its row")
            XCTAssertEqual(answer.color, columnMate?.color, "color must match its column")

            let alsoValid = puzzle.options.filter {
                $0.glyph?.symbol == rowMate?.symbol && $0.glyph?.color == columnMate?.color
            }
            XCTAssertEqual(alsoValid.count, 1, "only one chip may satisfy both rules")
        }
    }

    /// Rotation: each step turns the same way by the same amount.
    func testRotateShapeContinuesTheTurn() {
        for seed in UInt64(1)...30 {
            let spec = PuzzleSpec(world: .space, kind: .rotateShape, difficulty: 4)
            let puzzle = engine.generate(spec: spec, seed: seed &* 977)
            let shown = puzzle.grid.tiles.compactMap(\.glyph)
            guard shown.count >= 2,
                  let answer = puzzle.options.first(where: { $0.id == puzzle.correctID })?.glyph
            else { return XCTFail("not enough steps") }

            let step = (shown[1].rotation - shown[0].rotation + 360).truncatingRemainder(dividingBy: 360)
            let expected = (shown[shown.count - 1].rotation + step).truncatingRemainder(dividingBy: 360)
            XCTAssertEqual(answer.rotation, expected, accuracy: 0.001)
            XCTAssertEqual(Set(puzzle.options.compactMap { $0.glyph?.rotation }).count,
                           puzzle.options.count, "two chips point the same way")
        }
    }

    /// Symmetry: the answer equals its mirror partner across the middle column.
    func testBuildSymmetryAnswerMirrorsItsPartner() {
        for seed in UInt64(1)...30 {
            let spec = PuzzleSpec(world: .castle, kind: .buildSymmetry, difficulty: 3)
            let puzzle = engine.generate(spec: spec, seed: seed &* 131)
            guard let targetIndex = puzzle.grid.targetIndex,
                  let answer = puzzle.options.first(where: { $0.id == puzzle.correctID })?.glyph
            else { return XCTFail("no target/answer") }
            let side = puzzle.grid.columns
            let row = targetIndex / side
            let column = targetIndex % side
            let mirror = puzzle.grid.tile(row: row, column: side - 1 - column)?.glyph
            XCTAssertEqual(answer, mirror, "the answer must mirror the other side")
        }
    }

    // MARK: Determinism & selection

    func testSameSeedProducesTheSameBoard() {
        for kind in PuzzleKind.allCases {
            let spec = PuzzleSpec(world: kind.worlds[0], kind: kind, difficulty: 4)
            let first = engine.generate(spec: spec, seed: 4242)
            let second = engine.generate(spec: spec, seed: 4242)
            // Ids are fresh per generation, so compare what's drawn.
            XCTAssertEqual(first.grid.tiles.map(\.glyph), second.grid.tiles.map(\.glyph), kind.rawValue)
            XCTAssertEqual(first.options.map(\.glyph), second.options.map(\.glyph), kind.rawValue)
            XCTAssertEqual(first.options.map(\.text), second.options.map(\.text), kind.rawValue)
        }
    }

    func testEligibleKindsRespectAgeAndNeverReturnEmpty() {
        for world in PuzzleWorld.allCases {
            for age in 3...9 {
                for rung in 1...8 {
                    let kinds = engine.eligibleKinds(world: world, difficulty: rung, age: age)
                    XCTAssertFalse(kinds.isEmpty, "\(world.rawValue) age \(age) rung \(rung)")
                    if age >= 8 { continue }   // the widening fallback may exceed age at the top
                    let ageAppropriate = world.kinds.contains { $0.minAge <= max(age, 4) }
                    if ageAppropriate {
                        XCTAssertTrue(
                            kinds.allSatisfy { $0.minAge <= max(age, 4) },
                            "\(world.rawValue) offered a too-old kind at age \(age)"
                        )
                    }
                }
            }
        }
    }

    func testRunRampsUpAndAvoidsBackToBackRepeats() {
        var rng = SeededGenerator(seed: 20250802)
        for world in PuzzleWorld.allCases {
            let run = engine.generateRun(world: world, level: 3, difficulty: 4, age: 7, count: 5, using: &rng)
            XCTAssertEqual(run.puzzles.count, 5, world.rawValue)
            XCTAssertTrue(run.puzzles.allSatisfy { $0.world == world })
            // Opens a rung below the target so the first puzzle is a win.
            XCTAssertLessThanOrEqual(run.puzzles[0].difficulty, run.difficulty)
            if world.kinds.count > 1 {
                for (previous, next) in zip(run.puzzles, run.puzzles.dropFirst()) {
                    XCTAssertNotEqual(previous.kind, next.kind, "\(world.rawValue) repeated a kind back to back")
                }
            }
        }
    }

    // MARK: Spec contract

    func testSpecRoundTripsThroughJSON() throws {
        let spec = PuzzleSpec(world: .lab, kind: .missingTile, difficulty: 5)
        let data = try JSONEncoder().encode(spec)
        let decoded = try JSONDecoder().decode(PuzzleSpec.self, from: data)
        XCTAssertEqual(decoded, spec)
        XCTAssertEqual(decoded.world, .lab)
        XCTAssertEqual(decoded.kind, .missingTile)
        XCTAssertEqual(decoded.gridSize, "6x6")
    }

    func testSpecClampsDifficultyAndParsesGridSize() {
        XCTAssertEqual(PuzzleSpec(world: .forest, kind: .completePattern, difficulty: 99).difficulty, 8)
        XCTAssertEqual(PuzzleSpec(world: .forest, kind: .completePattern, difficulty: -3).difficulty, 1)
        var spec = PuzzleSpec(world: .forest, kind: .completePattern, difficulty: 3)
        spec.gridSize = "nonsense"
        XCTAssertEqual(spec.maxSide, PuzzleSkill.forLevel(3).maxGridSide)
    }

    // MARK: Helper

    private func forEachPuzzle(_ check: (Puzzle, String) -> Void) {
        for kind in PuzzleKind.allCases {
            for world in kind.worlds {
                for rung in 1...8 {
                    for seed in UInt64(1)...10 {
                        let spec = PuzzleSpec(world: world, kind: kind, difficulty: rung)
                        let puzzle = engine.generate(spec: spec, seed: seed &* 2_654_435_761)
                        check(puzzle, "\(kind.rawValue) w:\(world.rawValue) d:\(rung) s:\(seed)")
                    }
                }
            }
        }
    }
}

// MARK: - Progression

final class PuzzleProgressionEngineTests: XCTestCase {

    private let engine = PuzzleProgressionEngine()

    private func attempt(
        solved: Bool,
        missed: Int = 0,
        duration: TimeInterval = 5,
        skill: PuzzleSkill = .completePattern,
        hint: Bool = false
    ) -> PuzzleAttempt {
        PuzzleAttempt(
            kind: .completePattern, skill: skill, solved: solved,
            missedTaps: missed, duration: duration, usedHint: hint, timeLimit: 40
        )
    }

    func testStarsNeverDropBelowOne() {
        XCTAssertEqual(engine.stars(for: []), 1)
        XCTAssertEqual(engine.stars(for: (0..<5).map { _ in attempt(solved: false, missed: 3) }), 1)
    }

    func testThreeStarsNeedFastFirstTrySolves() {
        let perfect = (0..<5).map { _ in attempt(solved: true, duration: 8) }
        XCTAssertEqual(engine.stars(for: perfect), 3)

        let slow = (0..<5).map { _ in attempt(solved: true, duration: 39) }
        XCTAssertEqual(engine.stars(for: slow), 2, "correct but slow is still worth two stars")
    }

    func testCoinsRewardEffortNotJustAccuracy() {
        let struggled = (0..<5).map { _ in attempt(solved: false, missed: 3) }
        XCTAssertGreaterThan(engine.coins(for: struggled, stars: 1), 0)

        let solvedWithHints = (0..<5).map { _ in attempt(solved: true, hint: true) }
        let solvedAlone = (0..<5).map { _ in attempt(solved: true) }
        XCTAssertLessThan(
            engine.coins(for: solvedWithHints, stars: 2),
            engine.coins(for: solvedAlone, stars: 2)
        )
    }

    func testDifficultyMovesOneRungAtATime() {
        let strong = PuzzleRunResult(
            world: .forest, level: 1, difficulty: 3, attempts: [], stars: 3, coins: 0, accuracy: 1.0
        )
        XCTAssertEqual(engine.nextDifficulty(current: 3, recentResults: [strong, strong]), 4)
        XCTAssertEqual(
            engine.nextDifficulty(current: 3, recentResults: [strong]), 3,
            "one strong run is not enough to promote"
        )

        let weak = PuzzleRunResult(
            world: .forest, level: 1, difficulty: 3, attempts: [], stars: 1, coins: 0, accuracy: 0.2
        )
        XCTAssertEqual(engine.nextDifficulty(current: 3, recentResults: [weak, strong]), 2)
    }

    func testDifficultyStaysInRange() {
        let strong = PuzzleRunResult(
            world: .forest, level: 1, difficulty: 8, attempts: [], stars: 3, coins: 0, accuracy: 1.0
        )
        XCTAssertEqual(engine.nextDifficulty(current: 8, recentResults: [strong, strong]), 8)

        let weak = PuzzleRunResult(
            world: .forest, level: 1, difficulty: 1, attempts: [], stars: 1, coins: 0, accuracy: 0.0
        )
        XCTAssertEqual(engine.nextDifficulty(current: 1, recentResults: [weak]), 1)
    }

    func testGentlePreferenceNeverRaisesTheRung() {
        let strong = PuzzleRunResult(
            world: .forest, level: 1, difficulty: 4, attempts: [], stars: 3, coins: 0, accuracy: 1.0
        )
        XCTAssertEqual(
            engine.nextDifficulty(current: 4, recentResults: [strong, strong], preference: .gentle), 4
        )
    }

    func testStartingDifficultyGrowsWithAge() {
        let byAge = (4...8).map { engine.startingDifficulty(age: $0, world: .forest) }
        XCTAssertEqual(byAge, byAge.sorted(), "older children must not start lower")
        XCTAssertEqual(engine.startingDifficulty(age: 4, world: .forest), 1)
        XCTAssertGreaterThanOrEqual(engine.startingDifficulty(age: 8, world: .dragon), 6)
    }

    func testWorldUnlockingByAgeOrProgress() {
        var snapshot = PuzzleProgressSnapshot()
        XCTAssertTrue(engine.isUnlocked(.forest, age: 4, snapshot: snapshot), "the first world is always open")
        XCTAssertFalse(engine.isUnlocked(.castle, age: 4, snapshot: snapshot))
        XCTAssertNotNil(engine.lockReason(.castle, age: 4, snapshot: snapshot))

        snapshot.completedLevels[.jungle] = 10
        XCTAssertTrue(
            engine.isUnlocked(.castle, age: 4, snapshot: snapshot),
            "a younger child can still earn their way in"
        )
        XCTAssertTrue(engine.isUnlocked(.castle, age: 6, snapshot: PuzzleProgressSnapshot()))
        XCTAssertNil(engine.lockReason(.castle, age: 6, snapshot: PuzzleProgressSnapshot()))
    }

    func testNextLevelAdvancesAndCaps() {
        var snapshot = PuzzleProgressSnapshot()
        XCTAssertEqual(engine.nextLevel(in: .forest, snapshot: snapshot), 1)
        snapshot.completedLevels[.forest] = 7
        XCTAssertEqual(engine.nextLevel(in: .forest, snapshot: snapshot), 8)
        snapshot.completedLevels[.forest] = PuzzleWorld.forest.levelCount
        XCTAssertEqual(engine.nextLevel(in: .forest, snapshot: snapshot), PuzzleWorld.forest.levelCount)
    }

    func testBadgesAreEarnedOnceAndOnMerit() {
        var snapshot = PuzzleProgressSnapshot()
        snapshot.tallies = [PuzzleSkillTally(skill: .completePattern, attempted: 24, solved: 24)]
        let result = PuzzleRunResult(
            world: .forest, level: 2, difficulty: 2,
            attempts: [attempt(solved: true)], stars: 3, coins: 20
        )
        let earned = engine.newBadges(after: result, snapshot: snapshot)
        XCTAssertTrue(earned.contains(.patternMaster))
        XCTAssertTrue(earned.contains(.firstPuzzle))

        snapshot.badges = Set(earned)
        XCTAssertTrue(
            engine.newBadges(after: result, snapshot: snapshot).isEmpty,
            "badges are never awarded twice"
        )
    }

    func testParentSummaryDegradesGracefullyWithNoHistory() {
        let lines = engine.parentSummary(snapshot: PuzzleProgressSnapshot())
        XCTAssertEqual(lines.count, 1)
        XCTAssertFalse(lines[0].isEmpty)
    }

    func testParentSummaryRanksStrongestSkillFirst() {
        var snapshot = PuzzleProgressSnapshot()
        snapshot.tallies = [
            PuzzleSkillTally(skill: .rotation, attempted: 10, solved: 3),
            PuzzleSkillTally(skill: .completePattern, attempted: 10, solved: 9)
        ]
        let lines = engine.parentSummary(snapshot: snapshot)
        XCTAssertTrue(lines[0].contains(PuzzleSkill.completePattern.localizedName))
    }
}

// MARK: - Persistence & use cases

@MainActor
final class PuzzleRepositoryTests: XCTestCase {

    private func makeContext() throws -> (ModelContext, ChildProfile) {
        let container = try ModelContainer(
            for: ModelContainerFactory.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let child = ChildProfile(name: "Test")
        context.insert(child)
        return (context, child)
    }

    func testRecordingARunUpdatesProgressCoinsAndSkills() throws {
        let (context, child) = try makeContext()
        let repository = SwiftDataPuzzleRepository(context: context)
        let attempts = [
            PuzzleAttempt(kind: .completePattern, skill: .completePattern, solved: true,
                          missedTaps: 0, duration: 4, usedHint: false, timeLimit: 40),
            PuzzleAttempt(kind: .oddOneOut, skill: .completePattern, solved: false,
                          missedTaps: 3, duration: 20, usedHint: true, timeLimit: 40)
        ]
        let result = PuzzleProgressionEngine().makeResult(
            world: .forest, level: 1, difficulty: 2, attempts: attempts
        )
        _ = try repository.record(result, nextDifficulty: 3, for: child)

        let snapshot = try repository.snapshot(for: child)
        XCTAssertEqual(snapshot.completed(.forest), 1)
        XCTAssertEqual(snapshot.rung(.forest), 3)
        XCTAssertEqual(snapshot.coins, result.coins)
        XCTAssertEqual(snapshot.totalStars, result.stars)
        XCTAssertEqual(snapshot.tally(.completePattern).attempted, 2)
        XCTAssertEqual(snapshot.tally(.completePattern).solved, 1)
        XCTAssertEqual(snapshot.recentResults.count, 1)
        XCTAssertEqual(snapshot.recentResults[0].accuracy, result.accuracy, accuracy: 0.0001)
    }

    func testReplayingAnEarlierLevelNeverRewindsProgress() throws {
        let (context, child) = try makeContext()
        let repository = SwiftDataPuzzleRepository(context: context)
        let engine = PuzzleProgressionEngine()
        let attempts = [PuzzleAttempt(kind: .completePattern, skill: .completePattern, solved: true,
                                      missedTaps: 0, duration: 4, usedHint: false, timeLimit: 40)]

        _ = try repository.record(
            engine.makeResult(world: .forest, level: 5, difficulty: 2, attempts: attempts),
            nextDifficulty: 2, for: child
        )
        _ = try repository.record(
            engine.makeResult(world: .forest, level: 2, difficulty: 2, attempts: attempts),
            nextDifficulty: 2, for: child
        )
        XCTAssertEqual(try repository.snapshot(for: child).completed(.forest), 5)
    }

    func testHistoryStaysBounded() throws {
        let (context, child) = try makeContext()
        let repository = SwiftDataPuzzleRepository(context: context)
        let engine = PuzzleProgressionEngine()
        let attempts = [PuzzleAttempt(kind: .completePattern, skill: .completePattern, solved: true,
                                      missedTaps: 0, duration: 4, usedHint: false, timeLimit: 40)]
        for level in 1...12 {
            _ = try repository.record(
                engine.makeResult(world: .forest, level: level, difficulty: 2, attempts: attempts),
                nextDifficulty: 2, for: child
            )
        }
        XCTAssertEqual(try repository.snapshot(for: child).recentResults.count, PuzzleProgress.historyLength)
    }

    func testStartAndCompleteRunRoundTrip() throws {
        let (context, child) = try makeContext()
        let repository = SwiftDataPuzzleRepository(context: context)
        let progression = PuzzleProgressionEngine()
        let start = StartPuzzleRunUseCase(
            puzzleRepository: repository,
            generator: PuzzleGeneratorEngine(),
            progressionEngine: progression
        )
        let complete = CompletePuzzleRunUseCase(
            puzzleRepository: repository, progressionEngine: progression
        )

        let run = try start.execute(world: .forest, child: child, age: 5, preference: .automatic)
        XCTAssertEqual(run.level, 1)
        XCTAssertEqual(run.puzzles.count, 5)

        let attempts = run.puzzles.map { puzzle in
            PuzzleAttempt(kind: puzzle.kind, skill: puzzle.skill, solved: true,
                          missedTaps: 0, duration: 3, usedHint: false, timeLimit: puzzle.timeLimit)
        }
        let completion = try complete.execute(
            run: run, attempts: attempts, child: child, age: 5, preference: .automatic
        )
        XCTAssertEqual(completion.result.stars, 3)
        XCTAssertGreaterThan(completion.totalCoins, 0)
        XCTAssertTrue(completion.newBadges.contains(.firstPuzzle))

        // Second level starts where the first left off.
        let next = try start.execute(world: .forest, child: child, age: 5, preference: .automatic)
        XCTAssertEqual(next.level, 2)
    }
}
