//
//  PuzzleEngineTests.swift
//  FocusForestAdventureTests
//
//  Property-style coverage of Puzzle Adventure World: every kind, every rung,
//  every world, many seeds. The two invariants that matter to a child are
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
            for world in PuzzleWorld.allCases {
                for rung in 1...8 {
                    for seed in UInt64(1)...6 {
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

    /// Picture glyphs are drawn as-is, so two options that differ only by
    /// color would look identical on screen.
    func testPictureOptionsNeverDifferByColorAlone() {
        forEachPuzzle { puzzle, context in
            let pictures = puzzle.options.compactMap(\.glyph).filter { !$0.motif.isTintable }
            let motifs = pictures.map(\.motif)
            XCTAssertEqual(Set(motifs).count, motifs.count,
                           "two picture chips differ only by color — \(context)")
        }
    }

    /// A world's boards are drawn from that world's own cast.
    func testPuzzlesUseTheirWorldsMotifs() {
        for world in PuzzleWorld.allCases {
            let allowed = Set(world.story.motifs)
            for kind in Set(world.kinds) where !kind.needsTintableShapes {
                for seed in UInt64(1)...8 {
                    let spec = PuzzleSpec(world: world, kind: kind, difficulty: 3)
                    let puzzle = engine.generate(spec: spec, seed: seed &* 7_919)
                    let motifs = (puzzle.grid.tiles.compactMap(\.glyph) + puzzle.options.compactMap(\.glyph))
                        .map(\.motif)
                        .filter { !$0.isTintable }
                    for motif in motifs {
                        XCTAssertTrue(allowed.contains(motif),
                                      "\(world.rawValue)/\(kind.rawValue) drew a motif from another world")
                    }
                }
            }
        }
    }

    /// Rules that are *about* color must use tintable shapes — "the red one"
    /// has to mean something.
    func testColorRuleKindsAlwaysUseShapes() {
        for kind in PuzzleKind.allCases where kind.needsTintableShapes {
            for world in PuzzleWorld.allCases {
                let spec = PuzzleSpec(world: world, kind: kind, difficulty: 5)
                let puzzle = engine.generate(spec: spec, seed: 8_675_309)
                let glyphs = puzzle.grid.tiles.compactMap(\.glyph) + puzzle.options.compactMap(\.glyph)
                XCTAssertTrue(glyphs.allSatisfy { $0.motif.isTintable },
                              "\(kind.rawValue) in \(world.rawValue) used an untintable picture")
            }
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

                let period = (1...glyphs.count).first { candidate in
                    glyphs.indices.allSatisfy { glyphs[$0] == glyphs[$0 % candidate] }
                }
                XCTAssertNotNil(period, "\(kind.rawValue) row is not periodic")
                XCTAssertLessThanOrEqual(period ?? 99, 3, "\(kind.rawValue) period is too long to read")
            }
        }
    }

    func testOddOneOutHasExactlyOneDifferentTile() {
        for world in PuzzleWorld.allCases {
            for rung in 2...8 {
                for seed in UInt64(1)...10 {
                    let spec = PuzzleSpec(world: world, kind: .oddOneOut, difficulty: rung)
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
    }

    func testVisualSudokuAnswerKeepsRowsAndColumnsUnique() {
        for seed in UInt64(1)...40 {
            let spec = PuzzleSpec(world: .ice, kind: .visualSudoku, difficulty: 8)
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

    func testRavenMatrixAnswerSatisfiesBothRules() {
        for seed in UInt64(1)...40 {
            let spec = PuzzleSpec(world: .ocean, kind: .ravenMatrix, difficulty: 7)
            let puzzle = engine.generate(spec: spec, seed: seed &* 449)
            guard let targetIndex = puzzle.grid.targetIndex,
                  let answer = puzzle.options.first(where: { $0.id == puzzle.correctID })?.glyph
            else { return XCTFail("no target/answer") }

            let side = puzzle.grid.columns
            let row = targetIndex / side
            let column = targetIndex % side
            let rowMate = (0..<side).compactMap { puzzle.grid.tile(row: row, column: $0)?.glyph }.first
            let columnMate = (0..<puzzle.grid.rows).compactMap { puzzle.grid.tile(row: $0, column: column)?.glyph }.first
            XCTAssertEqual(answer.motif, rowMate?.motif, "shape must match its row")
            XCTAssertEqual(answer.color, columnMate?.color, "color must match its column")

            let alsoValid = puzzle.options.filter {
                $0.glyph?.motif == rowMate?.motif && $0.glyph?.color == columnMate?.color
            }
            XCTAssertEqual(alsoValid.count, 1, "only one chip may satisfy both rules")
        }
    }

    func testRotateShapeContinuesTheTurn() {
        for seed in UInt64(1)...30 {
            let spec = PuzzleSpec(world: .pirate, kind: .rotateShape, difficulty: 4)
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

    func testBuildSymmetryAnswerMirrorsItsPartner() {
        for seed in UInt64(1)...30 {
            let spec = PuzzleSpec(world: .space, kind: .buildSymmetry, difficulty: 3)
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

    // MARK: Determinism, runs, and the daily puzzle

    func testSameSeedProducesTheSameBoard() {
        for kind in PuzzleKind.allCases {
            let spec = PuzzleSpec(world: .castle, kind: kind, difficulty: 4)
            let first = engine.generate(spec: spec, seed: 4242)
            let second = engine.generate(spec: spec, seed: 4242)
            // Ids are fresh per generation, so compare what's drawn.
            XCTAssertEqual(first.grid.tiles.map(\.glyph), second.grid.tiles.map(\.glyph), kind.rawValue)
            XCTAssertEqual(first.options.map(\.glyph), second.options.map(\.glyph), kind.rawValue)
            XCTAssertEqual(first.options.map(\.text), second.options.map(\.text), kind.rawValue)
        }
    }

    func testEligibleKindsNeverReturnEmpty() {
        for world in PuzzleWorld.allCases {
            for age in 3...9 {
                for rung in 1...8 {
                    XCTAssertFalse(
                        engine.eligibleKinds(world: world, difficulty: rung, age: age).isEmpty,
                        "\(world.rawValue) age \(age) rung \(rung)"
                    )
                }
            }
        }
    }

    /// A chapter level leads with its own puzzle type — that's what makes
    /// "Hidden Acorns" mean something.
    func testChapterLevelsLeadWithTheirOwnKind() {
        var rng = SeededGenerator(seed: 20260802)
        for world in PuzzleWorld.allCases {
            let story = world.story
            for level in 1...story.chapters.count {
                let run = engine.generateRun(
                    world: world, level: level, difficulty: 4, age: 7, count: 5, using: &rng
                )
                XCTAssertEqual(run.chapter?.id, story.chapters[level - 1].id, world.rawValue)
                XCTAssertEqual(run.puzzles.first?.kind, story.chapters[level - 1].kind,
                               "\(world.rawValue) level \(level) didn't open with its chapter's puzzle")
                XCTAssertFalse(run.isBoss, "\(world.rawValue) level \(level) should not be the boss")
                XCTAssertTrue(run.puzzles.allSatisfy { !$0.title.isEmpty })
            }
        }
    }

    /// The last level of every world is a longer, harder boss.
    func testBossRunsAreLongerAndHarder() {
        var rng = SeededGenerator(seed: 99)
        for world in PuzzleWorld.allCases {
            let boss = engine.generateRun(
                world: world, level: world.bossLevel, difficulty: 4, age: 8, count: 5, using: &rng
            )
            XCTAssertTrue(boss.isBoss, world.rawValue)
            XCTAssertGreaterThanOrEqual(boss.puzzles.count, 8, "\(world.rawValue) boss is too short")
            let chapterRun = engine.generateRun(
                world: world, level: 1, difficulty: 4, age: 8, count: 5, using: &rng
            )
            XCTAssertGreaterThan(
                boss.puzzles.map(\.reward).reduce(0, +),
                chapterRun.puzzles.map(\.reward).reduce(0, +),
                "\(world.rawValue) boss should pay more"
            )
        }
    }

    func testRunRampsUpAndAvoidsBackToBackRepeats() {
        var rng = SeededGenerator(seed: 20250802)
        for world in PuzzleWorld.allCases {
            let run = engine.generateRun(world: world, level: 3, difficulty: 4, age: 7, count: 5, using: &rng)
            XCTAssertEqual(run.puzzles.count, 5, world.rawValue)
            XCTAssertTrue(run.puzzles.allSatisfy { $0.world == world })
            XCTAssertLessThanOrEqual(run.puzzles[0].difficulty, run.difficulty)
        }
    }

    /// The daily challenge must be the same board all day, and a different
    /// one tomorrow.
    func testDailyPuzzleIsStablePerDay() {
        let today = Date(timeIntervalSince1970: 1_800_000_000)
        let tomorrow = today.addingTimeInterval(86_400)
        let first = engine.generateDailyPuzzle(world: .forest, difficulty: 3, day: today)
        let again = engine.generateDailyPuzzle(world: .forest, difficulty: 3, day: today)
        let next = engine.generateDailyPuzzle(world: .forest, difficulty: 3, day: tomorrow)

        XCTAssertEqual(first.grid.tiles.map(\.glyph), again.grid.tiles.map(\.glyph))
        XCTAssertNotEqual(
            first.grid.tiles.map(\.glyph) + first.options.map(\.glyph),
            next.grid.tiles.map(\.glyph) + next.options.map(\.glyph),
            "the daily puzzle should change overnight"
        )
    }

    // MARK: Spec contract

    func testSpecRoundTripsThroughJSON() throws {
        let spec = PuzzleSpec(world: .ice, kind: .missingTile, difficulty: 5)
        let data = try JSONEncoder().encode(spec)
        let decoded = try JSONDecoder().decode(PuzzleSpec.self, from: data)
        XCTAssertEqual(decoded, spec)
        XCTAssertEqual(decoded.world, .ice)
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
            for world in PuzzleWorld.allCases {
                for rung in 1...8 {
                    for seed in UInt64(1)...5 {
                        let spec = PuzzleSpec(world: world, kind: kind, difficulty: rung)
                        let puzzle = engine.generate(spec: spec, seed: seed &* 2_654_435_761)
                        check(puzzle, "\(kind.rawValue) w:\(world.rawValue) d:\(rung) s:\(seed)")
                    }
                }
            }
        }
    }
}

// MARK: - Story

final class BrainlandStoryTests: XCTestCase {

    func testEveryWorldHasACompleteScript() {
        for world in PuzzleWorld.allCases {
            let story = world.story
            XCTAssertEqual(story.world, world)
            XCTAssertFalse(story.premise.isEmpty, world.rawValue)
            XCTAssertFalse(story.quest.isEmpty, world.rawValue)
            XCTAssertFalse(story.characters.isEmpty, "\(world.rawValue) has no characters")
            XCTAssertFalse(story.chapters.isEmpty, "\(world.rawValue) has no chapters")
            XCTAssertFalse(story.bossTitle.isEmpty, world.rawValue)
            XCTAssertFalse(story.victory.isEmpty, world.rawValue)
            XCTAssertGreaterThanOrEqual(story.motifs.count, 4, "\(world.rawValue) needs more pictures")
            XCTAssertEqual(Set(story.motifs).count, story.motifs.count,
                           "\(world.rawValue) repeats a picture")
            XCTAssertEqual(Set(story.chapters.map(\.id)).count, story.chapters.count,
                           "\(world.rawValue) repeats a chapter id")
            for chapter in story.chapters {
                XCTAssertFalse(chapter.title.isEmpty)
                XCTAssertFalse(chapter.blurb.isEmpty)
            }
        }
    }

    func testChapterIDsAreUniqueAcrossTheWholeCampaign() {
        let ids = PuzzleWorld.allCases.flatMap { $0.story.chapters.map(\.id) }
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testCrystalsAreOnePerWorld() {
        let crystals = PuzzleWorld.allCases.map(\.crystal)
        XCTAssertEqual(Set(crystals.map(\.world)).count, PuzzleWorld.allCases.count)
        XCTAssertEqual(BrainlandStory.keyCrystals.count, 7, "seven crystals power the Rainbow Castle")
        XCTAssertFalse(BrainlandStory.keyCrystals.contains { $0.world == .rainbow || $0.world == .volcano })
    }

    func testLevelCountIsChaptersPlusABoss() {
        for world in PuzzleWorld.allCases {
            XCTAssertEqual(world.levelCount, world.story.chapters.count + 1, world.rawValue)
            XCTAssertTrue(world.isBossLevel(world.levelCount))
            XCTAssertFalse(world.isBossLevel(world.levelCount - 1))
        }
    }

    func testCharactersRotateThroughLevels() {
        let story = PuzzleWorld.forest.story
        let names = (1...story.chapters.count).compactMap { story.character(forLevel: $0)?.name }
        XCTAssertEqual(Set(names).count, story.characters.count,
                       "every character should get a turn")
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
        XCTAssertEqual(engine.stars(for: (0..<5).map { _ in attempt(solved: true, duration: 8) }), 3)
        XCTAssertEqual(engine.stars(for: (0..<5).map { _ in attempt(solved: true, duration: 39) }), 2,
                       "correct but slow is still worth two stars")
    }

    func testGemsRewardEffortAndBossesPayDouble() {
        let struggled = (0..<5).map { _ in attempt(solved: false, missed: 3) }
        XCTAssertGreaterThan(engine.gems(for: struggled, stars: 1, isBoss: false), 0)

        let solved = (0..<5).map { _ in attempt(solved: true) }
        XCTAssertEqual(
            engine.gems(for: solved, stars: 2, isBoss: true),
            engine.gems(for: solved, stars: 2, isBoss: false) * 2
        )

        let withHints = (0..<5).map { _ in attempt(solved: true, hint: true) }
        XCTAssertLessThan(
            engine.gems(for: withHints, stars: 2, isBoss: false),
            engine.gems(for: solved, stars: 2, isBoss: false)
        )
    }

    func testBossResultEarnsACrystalAndMorePieces() {
        let attempts = (0..<8).map { _ in attempt(solved: true) }
        let boss = engine.makeResult(world: .forest, level: 11, difficulty: 3, attempts: attempts, isBoss: true)
        let chapter = engine.makeResult(world: .forest, level: 3, difficulty: 3, attempts: attempts)
        XCTAssertTrue(boss.earnsCrystal)
        XCTAssertFalse(chapter.earnsCrystal)
        XCTAssertGreaterThan(boss.pieces, chapter.pieces)
    }

    func testDifficultyMovesOneRungAtATime() {
        let strong = PuzzleRunResult(
            world: .forest, level: 1, difficulty: 3, attempts: [], stars: 3, gems: 0, accuracy: 1.0
        )
        XCTAssertEqual(engine.nextDifficulty(current: 3, recentResults: [strong, strong]), 4)
        XCTAssertEqual(engine.nextDifficulty(current: 3, recentResults: [strong]), 3,
                       "one strong run is not enough to promote")

        let weak = PuzzleRunResult(
            world: .forest, level: 1, difficulty: 3, attempts: [], stars: 1, gems: 0, accuracy: 0.2
        )
        XCTAssertEqual(engine.nextDifficulty(current: 3, recentResults: [weak, strong]), 2)
    }

    func testDifficultyStaysInRange() {
        let strong = PuzzleRunResult(
            world: .ice, level: 1, difficulty: 8, attempts: [], stars: 3, gems: 0, accuracy: 1.0
        )
        XCTAssertEqual(engine.nextDifficulty(current: 8, recentResults: [strong, strong]), 8)

        let weak = PuzzleRunResult(
            world: .forest, level: 1, difficulty: 1, attempts: [], stars: 1, gems: 0, accuracy: 0.0
        )
        XCTAssertEqual(engine.nextDifficulty(current: 1, recentResults: [weak]), 1)
    }

    func testStartingDifficultyGrowsWithAgeAndWorld() {
        let byAge = (4...8).map { engine.startingDifficulty(age: $0, world: .forest) }
        XCTAssertEqual(byAge, byAge.sorted(), "older children must not start lower")
        XCTAssertEqual(engine.startingDifficulty(age: 4, world: .forest), 1)
        XCTAssertGreaterThan(
            engine.startingDifficulty(age: 4, world: .ice),
            engine.startingDifficulty(age: 4, world: .forest),
            "later worlds never open trivially easy"
        )
    }

    // MARK: Crystals & unlocking

    func testWorldsUnlockByCrystalOrReadiness() {
        var snapshot = PuzzleProgressSnapshot()
        XCTAssertTrue(engine.isUnlocked(.forest, age: 4, snapshot: snapshot), "the first world is always open")
        XCTAssertFalse(engine.isUnlocked(.pirate, age: 5, snapshot: snapshot))
        XCTAssertNotNil(engine.lockReason(.pirate, age: 5, snapshot: snapshot))

        // The crystal is the key.
        snapshot.crystals.insert(.forest)
        XCTAssertTrue(engine.isUnlocked(.pirate, age: 5, snapshot: snapshot))
        XCTAssertNil(engine.lockReason(.pirate, age: 5, snapshot: snapshot))

        // Or: old enough and already well into the previous world, so a
        // stuck boss never ends the campaign.
        var stuck = PuzzleProgressSnapshot()
        stuck.completedLevels[.forest] = 5
        XCTAssertTrue(engine.isUnlocked(.pirate, age: 5, snapshot: stuck))
        XCTAssertFalse(engine.isUnlocked(.pirate, age: 4, snapshot: stuck), "too young to skip ahead")
    }

    func testRainbowKingdomNeedsEveryKeyCrystal() {
        var snapshot = PuzzleProgressSnapshot()
        snapshot.crystals = Set(BrainlandStory.keyCrystals.map(\.world))
        snapshot.crystals.remove(.ice)
        XCTAssertFalse(engine.isUnlocked(.rainbow, age: 8, snapshot: snapshot))
        XCTAssertNotNil(engine.lockReason(.rainbow, age: 8, snapshot: snapshot))

        snapshot.crystals.insert(.ice)
        XCTAssertTrue(snapshot.hasAllKeyCrystals)
        XCTAssertTrue(engine.isUnlocked(.rainbow, age: 8, snapshot: snapshot))
        XCTAssertTrue(
            engine.isUnlocked(.rainbow, age: 4, snapshot: snapshot),
            "the finale is earned, not aged into"
        )
    }

    func testNextLevelAdvancesAndStopsAtTheBoss() {
        var snapshot = PuzzleProgressSnapshot()
        XCTAssertEqual(engine.nextLevel(in: .forest, snapshot: snapshot), 1)
        snapshot.completedLevels[.forest] = 7
        XCTAssertEqual(engine.nextLevel(in: .forest, snapshot: snapshot), 8)
        snapshot.completedLevels[.forest] = PuzzleWorld.forest.levelCount
        XCTAssertEqual(engine.nextLevel(in: .forest, snapshot: snapshot), PuzzleWorld.forest.levelCount)
    }

    // MARK: Badges

    func testBadgesAreEarnedOnceAndOnMerit() {
        var snapshot = PuzzleProgressSnapshot()
        snapshot.tallies = [PuzzleSkillTally(skill: .completePattern, attempted: 24, solved: 24)]
        let result = PuzzleRunResult(
            world: .forest, level: 2, difficulty: 2,
            attempts: [attempt(solved: true)], stars: 3, gems: 20
        )
        let earned = engine.newBadges(after: result, snapshot: snapshot)
        XCTAssertTrue(earned.contains(.patternMaster))
        XCTAssertTrue(earned.contains(.firstPuzzle))

        snapshot.badges = Set(earned)
        XCTAssertTrue(engine.newBadges(after: result, snapshot: snapshot).isEmpty,
                      "badges are never awarded twice")
    }

    func testCrystalBadges() {
        var snapshot = PuzzleProgressSnapshot()
        snapshot.crystals = [.forest, .pirate]
        let bossWin = PuzzleRunResult(
            world: .space, level: 11, difficulty: 5, attempts: [], stars: 3, gems: 0, isBoss: true
        )
        XCTAssertTrue(engine.newBadges(after: bossWin, snapshot: snapshot).contains(.crystalHunter))

        snapshot.crystals = Set(BrainlandStory.keyCrystals.map(\.world))
        snapshot.badges = [.crystalHunter]
        let finale = PuzzleRunResult(
            world: .rainbow, level: 6, difficulty: 8, attempts: [], stars: 3, gems: 0, isBoss: true
        )
        XCTAssertTrue(engine.newBadges(after: finale, snapshot: snapshot).contains(.brainlandHero))
    }

    // MARK: Cognitive profile

    func testCognitiveProfileCoversEverySkillAndWithholdsUntestedOnes() {
        let profile = engine.cognitiveProfile(snapshot: PuzzleProgressSnapshot())
        XCTAssertEqual(profile.count, CognitiveSkill.allCases.count)
        XCTAssertTrue(profile.allSatisfy { $0.stars == nil }, "no play means no rating")
        XCTAssertTrue(profile.allSatisfy { $0.starDisplay.isEmpty == false })
    }

    func testCognitiveProfileRatesStrongPlayHighly() {
        var snapshot = PuzzleProgressSnapshot()
        snapshot.tallies = [
            PuzzleSkillTally(skill: .completePattern, attempted: 20, solved: 20),
            PuzzleSkillTally(skill: .rotation, attempted: 20, solved: 6)
        ]
        snapshot.puzzlesAttempted = 40
        snapshot.puzzlesSolved = 36
        snapshot.speedRatioSum = 40 * 0.2      // fast
        snapshot.hintsUsed = 2

        let profile = engine.cognitiveProfile(snapshot: snapshot)
        func rating(_ skill: CognitiveSkill) -> CognitiveRating {
            profile.first { $0.skill == skill }!
        }
        XCTAssertEqual(rating(.patternRecognition).stars, 5)
        XCTAssertGreaterThanOrEqual(rating(.processingSpeed).stars ?? 0, 4)
        XCTAssertGreaterThanOrEqual(rating(.concentration).stars ?? 0, 4)
        XCTAssertLessThan(rating(.spatialReasoning).score, rating(.patternRecognition).score)
    }

    func testSlowPlayScoresLowerOnProcessingSpeed() {
        var fast = PuzzleProgressSnapshot()
        fast.puzzlesAttempted = 20
        fast.puzzlesSolved = 20
        fast.speedRatioSum = 20 * 0.2
        var slow = fast
        slow.speedRatioSum = 20 * 1.2

        func speed(_ snapshot: PuzzleProgressSnapshot) -> Double {
            engine.cognitiveProfile(snapshot: snapshot).first { $0.skill == .processingSpeed }?.score ?? 0
        }
        XCTAssertGreaterThan(speed(fast), speed(slow))
    }

    func testParentSummaryDegradesGracefullyAndRecommends() {
        let cold = engine.parentSummary(snapshot: PuzzleProgressSnapshot(), age: 5)
        XCTAssertEqual(cold.count, 1)
        XCTAssertFalse(cold[0].isEmpty)

        var snapshot = PuzzleProgressSnapshot()
        snapshot.tallies = [
            PuzzleSkillTally(skill: .completePattern, attempted: 20, solved: 19),
            PuzzleSkillTally(skill: .rotation, attempted: 20, solved: 4)
        ]
        snapshot.puzzlesAttempted = 40
        snapshot.puzzlesSolved = 23
        snapshot.crystals = [.forest]
        let lines = engine.parentSummary(snapshot: snapshot, age: 6)
        XCTAssertTrue(lines.contains { $0.contains(CognitiveSkill.patternRecognition.localizedName) })
        XCTAssertTrue(lines.contains { $0.contains("1") }, "crystal count should be reported")
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

    private func attempts(count: Int, solved: Bool = true, hint: Bool = false) -> [PuzzleAttempt] {
        (0..<count).map { _ in
            PuzzleAttempt(kind: .completePattern, skill: .completePattern, solved: solved,
                          missedTaps: solved ? 0 : 3, duration: 4, usedHint: hint, timeLimit: 40)
        }
    }

    func testRecordingARunUpdatesProgressGemsAndSkills() throws {
        let (context, child) = try makeContext()
        let repository = SwiftDataPuzzleRepository(context: context)
        let mixed = [
            PuzzleAttempt(kind: .completePattern, skill: .completePattern, solved: true,
                          missedTaps: 0, duration: 4, usedHint: false, timeLimit: 40),
            PuzzleAttempt(kind: .oddOneOut, skill: .completePattern, solved: false,
                          missedTaps: 3, duration: 20, usedHint: true, timeLimit: 40)
        ]
        let result = PuzzleProgressionEngine().makeResult(
            world: .forest, level: 1, difficulty: 2, attempts: mixed
        )
        _ = try repository.record(result, nextDifficulty: 3, for: child)

        let snapshot = try repository.snapshot(for: child)
        XCTAssertEqual(snapshot.completed(.forest), 1)
        XCTAssertEqual(snapshot.rung(.forest), 3)
        XCTAssertEqual(snapshot.gems, result.gems)
        XCTAssertEqual(snapshot.pieces, result.pieces)
        XCTAssertEqual(snapshot.totalStars, result.stars)
        XCTAssertEqual(snapshot.tally(.completePattern).attempted, 2)
        XCTAssertEqual(snapshot.tally(.completePattern).solved, 1)
        XCTAssertEqual(snapshot.puzzlesAttempted, 2)
        XCTAssertEqual(snapshot.puzzlesSolved, 1)
        XCTAssertEqual(snapshot.hintsUsed, 1)
        XCTAssertEqual(snapshot.speedRatioSum, (4.0 / 40) + (20.0 / 40), accuracy: 0.0001)
        XCTAssertFalse(snapshot.hasCrystal(.forest))
    }

    func testBeatingABossPersistsTheCrystal() throws {
        let (context, child) = try makeContext()
        let repository = SwiftDataPuzzleRepository(context: context)
        let result = PuzzleProgressionEngine().makeResult(
            world: .forest, level: PuzzleWorld.forest.bossLevel, difficulty: 3,
            attempts: attempts(count: 8), isBoss: true
        )
        _ = try repository.record(result, nextDifficulty: 3, for: child)

        let snapshot = try repository.snapshot(for: child)
        XCTAssertTrue(snapshot.hasCrystal(.forest))
        XCTAssertEqual(snapshot.earnedCrystals.map(\.world), [.forest])
    }

    func testReplayingAnEarlierLevelNeverRewindsProgress() throws {
        let (context, child) = try makeContext()
        let repository = SwiftDataPuzzleRepository(context: context)
        let engine = PuzzleProgressionEngine()
        _ = try repository.record(
            engine.makeResult(world: .forest, level: 5, difficulty: 2, attempts: attempts(count: 1)),
            nextDifficulty: 2, for: child
        )
        _ = try repository.record(
            engine.makeResult(world: .forest, level: 2, difficulty: 2, attempts: attempts(count: 1)),
            nextDifficulty: 2, for: child
        )
        XCTAssertEqual(try repository.snapshot(for: child).completed(.forest), 5)
    }

    func testHistoryStaysBounded() throws {
        let (context, child) = try makeContext()
        let repository = SwiftDataPuzzleRepository(context: context)
        let engine = PuzzleProgressionEngine()
        for level in 1...12 {
            _ = try repository.record(
                engine.makeResult(world: .forest, level: level, difficulty: 2, attempts: attempts(count: 1)),
                nextDifficulty: 2, for: child
            )
        }
        XCTAssertEqual(try repository.snapshot(for: child).recentResults.count, PuzzleProgress.historyLength)
    }

    func testCampaignRoundTripFromFirstChapterToCrystal() throws {
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

        // Chapter 1.
        let run = try start.execute(world: .forest, child: child, age: 5, preference: .automatic)
        XCTAssertEqual(run.level, 1)
        XCTAssertFalse(run.isBoss)
        XCTAssertNotNil(run.chapter)

        let solved = run.puzzles.map { puzzle in
            PuzzleAttempt(kind: puzzle.kind, skill: puzzle.skill, solved: true,
                          missedTaps: 0, duration: 3, usedHint: false, timeLimit: puzzle.timeLimit)
        }
        let completion = try complete.execute(
            run: run, attempts: solved, child: child, age: 5, preference: .automatic
        )
        XCTAssertEqual(completion.result.stars, 3)
        XCTAssertNil(completion.crystal, "a chapter is not a boss")
        XCTAssertTrue(completion.newBadges.contains(.firstPuzzle))
        XCTAssertFalse(completion.storyLine.isEmpty)

        // Straight to the boss.
        let boss = try start.execute(
            world: .forest, child: child, age: 5, preference: .automatic,
            level: PuzzleWorld.forest.bossLevel
        )
        XCTAssertTrue(boss.isBoss)
        let bossAttempts = boss.puzzles.map { puzzle in
            PuzzleAttempt(kind: puzzle.kind, skill: puzzle.skill, solved: true,
                          missedTaps: 0, duration: 3, usedHint: false, timeLimit: puzzle.timeLimit)
        }
        let bossCompletion = try complete.execute(
            run: boss, attempts: bossAttempts, child: child, age: 5, preference: .automatic
        )
        XCTAssertEqual(bossCompletion.crystal?.world, .forest)
        XCTAssertEqual(bossCompletion.unlockedWorld, .pirate, "the crystal opens the next world")
        XCTAssertEqual(bossCompletion.storyLine, PuzzleWorld.forest.story.victory)
        XCTAssertFalse(bossCompletion.finishedCampaign)
    }

    func testDailyPuzzleComesFromAnUnlockedWorld() throws {
        let (context, child) = try makeContext()
        let repository = SwiftDataPuzzleRepository(context: context)
        let start = StartPuzzleRunUseCase(
            puzzleRepository: repository,
            generator: PuzzleGeneratorEngine(),
            progressionEngine: PuzzleProgressionEngine()
        )
        let daily = try start.dailyPuzzle(child: child, age: 5)
        XCTAssertEqual(daily?.world, .forest, "only the first world is open at the start")
    }
}
