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
                        switch kind {
                        case .sameOrDifferent:
                            // Asks about the board as a whole — no gap to fill.
                            XCTAssertEqual(puzzle.grid.tiles.filter(\.isTarget).count, 0, context)
                        case .hiddenObject:
                            // A hunt has several things to find.
                            XCTAssertEqual(
                                puzzle.grid.tiles.filter(\.isTarget).count, puzzle.correctIDs.count,
                                "every hidden thing must be a target — \(context)"
                            )
                            XCTAssertGreaterThanOrEqual(puzzle.correctIDs.count, 3, context)
                        case .maze:
                            // A maze marks its cells by role, not by target.
                            XCTAssertEqual(puzzle.grid.tiles.filter { $0.role == .start }.count, 1, context)
                            XCTAssertEqual(puzzle.grid.tiles.filter { $0.role == .goal }.count, 1, context)
                        case .assemble:
                            // Every board cell is a space to fill.
                            XCTAssertEqual(
                                puzzle.grid.tiles.filter { $0.role == .slot }.count,
                                puzzle.correctIDs.count, context
                            )
                        case .blockRotation:
                            // The board is the block itself; nothing is missing.
                            XCTAssertEqual(puzzle.grid.tiles.filter(\.isTarget).count, 0, context)
                        case .pipeConnect:
                            XCTAssertEqual(puzzle.grid.tiles.filter { $0.role == .start }.count, 1, context)
                            XCTAssertEqual(puzzle.grid.tiles.filter { $0.role == .goal }.count, 1, context)
                            XCTAssertTrue(puzzle.grid.tiles.allSatisfy { $0.pipe != nil },
                                          "every cell of a pipe board holds pipe — \(context)")
                        default:
                            XCTAssertEqual(
                                puzzle.grid.tiles.filter(\.isTarget).count, 1,
                                "wrong number of target tiles — \(context)"
                            )
                        }
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
                XCTAssertEqual(puzzle.correctIDs.count, 1, "one answer expected — \(context)")
                XCTAssertEqual(
                    puzzle.grid.tiles.filter { $0.id == puzzle.correctID }.count, 1,
                    "exactly one tile must be the answer — \(context)"
                )
                XCTAssertTrue(
                    puzzle.grid.tiles.first { $0.id == puzzle.correctID }?.isTarget == true,
                    "the answer tile must be the target — \(context)"
                )
            case .tapMany:
                XCTAssertTrue(puzzle.options.isEmpty, "hunts have no chips — \(context)")
                XCTAssertGreaterThan(puzzle.correctIDs.count, 1, "a hunt needs several — \(context)")
                let boardIDs = Set(puzzle.grid.tiles.map(\.id))
                XCTAssertTrue(puzzle.correctIDs.isSubset(of: boardIDs),
                              "every answer must be on the board — \(context)")
            case .tapPath:
                XCTAssertTrue(puzzle.options.isEmpty, "mazes have no chips — \(context)")
                XCTAssertTrue(
                    puzzle.grid.tiles.contains { $0.role == .goal && puzzle.correctIDs.contains($0.id) },
                    "the goal must be the answer — \(context)"
                )
            case .rotateTiles:
                XCTAssertTrue(puzzle.options.isEmpty, "pipe boards have no chips — \(context)")
            case .assemble:
                // Every slot needs a piece in the bank that fits it, and no
                // two slots may want the same piece.
                let slots = puzzle.grid.tiles.filter { $0.role == .slot }
                XCTAssertGreaterThanOrEqual(puzzle.options.count, slots.count, context)
                let wanted = slots.compactMap(\.glyph)
                XCTAssertEqual(Set(wanted).count, wanted.count, "two slots want the same piece — \(context)")
                for glyph in wanted {
                    XCTAssertTrue(puzzle.options.contains { $0.glyph == glyph },
                                  "no piece fits a slot — \(context)")
                }
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

    // MARK: Hunt & memory

    /// Every hidden thing looks the same as every other, and nothing else
    /// on the board does — otherwise "find them all" has no answer.
    func testHiddenObjectTargetsShareOneLookAndCluttersDont() {
        for world in PuzzleWorld.allCases {
            for rung in 1...8 {
                for seed in UInt64(1)...8 {
                    let spec = PuzzleSpec(world: world, kind: .hiddenObject, difficulty: rung)
                    let puzzle = engine.generate(spec: spec, seed: seed &* 5_557)
                    let targets = puzzle.grid.tiles.filter { puzzle.correctIDs.contains($0.id) }
                    let clutter = puzzle.grid.tiles.filter { !puzzle.correctIDs.contains($0.id) }
                    let targetGlyphs = Set(targets.compactMap(\.glyph))
                    XCTAssertEqual(targetGlyphs.count, 1, "the hidden things must all look alike")
                    guard let hidden = targetGlyphs.first else { return XCTFail("no target glyph") }
                    XCTAssertFalse(clutter.compactMap(\.glyph).contains(hidden),
                                   "a clutter tile looks like the hidden thing")
                    XCTAssertTrue((3...5).contains(puzzle.correctIDs.count),
                                  "\(puzzle.correctIDs.count) is too many to hold in mind")
                }
            }
        }
    }

    /// The memory board is fully drawn (nothing is blank) and gets a peek
    /// long enough to actually study.
    func testMemoryGridPeeksThenAsksAboutAShownTile() {
        for rung in 1...8 {
            for seed in UInt64(1)...10 {
                let spec = PuzzleSpec(world: .dinosaur, kind: .memoryGrid, difficulty: rung)
                let puzzle = engine.generate(spec: spec, seed: seed &* 1_223)
                XCTAssertNotNil(puzzle.peekDuration, "a memory puzzle must show the board first")
                XCTAssertGreaterThanOrEqual(puzzle.peekDuration ?? 0, 2)
                XCTAssertTrue(puzzle.grid.tiles.allSatisfy { $0.glyph != nil },
                              "the board is shown complete before it's covered")

                guard let target = puzzle.grid.tiles.first(where: \.isTarget),
                      let answer = puzzle.options.first(where: { $0.id == puzzle.correctID })?.glyph
                else { return XCTFail("no target/answer") }
                XCTAssertEqual(answer, target.glyph, "the answer is what was in the marked cell")
            }
        }
    }

    func testOnlyMemoryPuzzlesPeek() {
        for kind in PuzzleKind.allCases where kind != .memoryGrid {
            let spec = PuzzleSpec(world: .forest, kind: kind, difficulty: 4)
            XCTAssertNil(engine.generate(spec: spec, seed: 7).peekDuration, kind.rawValue)
        }
    }

    // MARK: Pipes

    /// Every board must be turnable into a working pipeline, and must not
    /// arrive already working — a puzzle solved before the first tap is no
    /// puzzle at all.
    func testEveryPipeBoardIsSolvableAndNotAlreadySolved() {
        for world in PuzzleWorld.allCases {
            for rung in 1...8 {
                for seed in UInt64(1)...12 {
                    let spec = PuzzleSpec(world: world, kind: .pipeConnect, difficulty: rung)
                    let puzzle = engine.generate(spec: spec, seed: seed &* 6_143)
                    let context = "\(world.rawValue) d:\(rung) s:\(seed)"

                    XCTAssertFalse(PipeRules.isConnected(puzzle.grid),
                                   "the board arrived already joined up — \(context)")
                    XCTAssertTrue(hasPipeSolution(puzzle.grid),
                                  "no way to join the pipes — \(context)")
                }
            }
        }
    }

    /// Turning a tile four times puts the board back exactly as it was.
    func testTurningATileFourTimesRestoresTheBoard() {
        let spec = PuzzleSpec(world: .ocean, kind: .pipeConnect, difficulty: 4)
        let puzzle = engine.generate(spec: spec, seed: 24_601)
        guard let first = puzzle.grid.tiles.first else { return XCTFail("empty board") }

        var grid = puzzle.grid
        for _ in 0..<4 { grid = PipeRules.rotating(grid, tileID: first.id) }
        XCTAssertEqual(grid.tiles.map(\.pipe), puzzle.grid.tiles.map(\.pipe))
    }

    /// Is there *some* set of turns that joins the tap to the bucket?
    ///
    /// Trying all 4^cells combinations would be billions on a 4×4 board, so
    /// this walks simple routes instead and asks, cell by cell, whether that
    /// cell's piece can be turned to open onto the sides the route needs.
    private func hasPipeSolution(_ grid: PuzzleGrid) -> Bool {
        guard let startIndex = grid.tiles.firstIndex(where: { $0.role == .start }),
              let goalIndex = grid.tiles.firstIndex(where: { $0.role == .goal })
        else { return false }

        func canOrient(_ pipe: PipeConnections, toOpenOnto required: PipeConnections) -> Bool {
            var turned = pipe
            for _ in 0..<4 {
                if turned.isSuperset(of: required) { return true }
                turned = turned.rotated()
            }
            return false
        }

        func neighbour(of index: Int, towards side: PipeConnections) -> Int? {
            let row = index / grid.columns
            let column = index % grid.columns
            let (nextRow, nextColumn): (Int, Int) = switch side {
            case .north: (row - 1, column)
            case .south: (row + 1, column)
            case .east:  (row, column + 1)
            default:     (row, column - 1)
            }
            guard nextRow >= 0, nextRow < grid.rows, nextColumn >= 0, nextColumn < grid.columns
            else { return nil }
            return nextRow * grid.columns + nextColumn
        }

        var visited: Set<Int> = []
        func walk(_ index: Int, entry: PipeConnections) -> Bool {
            let pipe = grid.tiles[index].pipe ?? []
            if index == goalIndex { return canOrient(pipe, toOpenOnto: entry) }

            visited.insert(index)
            defer { visited.remove(index) }

            for exit in PipeConnections.all where !entry.contains(exit) {
                guard canOrient(pipe, toOpenOnto: entry.union(exit)),
                      let next = neighbour(of: index, towards: exit),
                      !visited.contains(next)
                else { continue }
                if walk(next, entry: exit.opposite) { return true }
            }
            return false
        }
        return walk(startIndex, entry: [])
    }

    // MARK: Block rotation

    /// The answer is the shown block turned, and — the part that makes the
    /// puzzle fair — *only* the answer is.
    func testBlockRotationHasExactlyOneTurnedCopy() {
        for world in PuzzleWorld.allCases {
            for rung in 1...8 {
                for seed in UInt64(1)...10 {
                    let spec = PuzzleSpec(world: world, kind: .blockRotation, difficulty: rung)
                    let puzzle = engine.generate(spec: spec, seed: seed &* 4_099)
                    let context = "\(world.rawValue) d:\(rung) s:\(seed)"

                    let shown = shownPattern(puzzle)
                    let patterns = puzzle.options.compactMap(\.pattern)
                    XCTAssertEqual(patterns.count, puzzle.options.count, "every chip is a block — \(context)")

                    let rotations = patterns.filter { $0.isRotation(of: shown) }
                    XCTAssertEqual(rotations.count, 1, "exactly one chip may be a turn — \(context)")
                    let answer = puzzle.options.first { $0.id == puzzle.correctID }?.pattern
                    XCTAssertTrue(answer?.isRotation(of: shown) == true, "the answer must be a turn — \(context)")
                }
            }
        }
    }

    /// The answer is never the block sitting there unturned — that would be
    /// matching, not rotating.
    func testBlockRotationAnswerIsActuallyTurned() {
        for seed in UInt64(1)...30 {
            let spec = PuzzleSpec(world: .ice, kind: .blockRotation, difficulty: 5)
            let puzzle = engine.generate(spec: spec, seed: seed &* 2_063)
            let shown = shownPattern(puzzle)
            let answer = puzzle.options.first { $0.id == puzzle.correctID }?.pattern
            XCTAssertNotEqual(answer?.filled, shown.filled, "the answer was left unturned")
        }
    }

    /// A block whose turns look alike would have several right answers.
    func testBlockRotationBlocksAreAsymmetric() {
        for rung in 1...8 {
            for seed in UInt64(1)...10 {
                let spec = PuzzleSpec(world: .volcano, kind: .blockRotation, difficulty: rung)
                let puzzle = engine.generate(spec: spec, seed: seed &* 733)
                XCTAssertTrue(shownPattern(puzzle).hasDistinctRotations,
                              "a symmetric block has more than one right answer")
            }
        }
    }

    private func shownPattern(_ puzzle: Puzzle) -> PuzzlePattern {
        let side = puzzle.grid.columns
        let filled = puzzle.grid.tiles.map { $0.glyph != nil }
        return PuzzlePattern(rows: side, columns: side, filled: filled, color: .blue)
    }

    // MARK: Assembly

    /// Assembly is solvable exactly one way: each slot has one piece that
    /// fits, and spare pieces (rung 4+) fit nothing.
    func testAssemblyHasOnePiecePerSlot() {
        for rung in 1...8 {
            for seed in UInt64(1)...10 {
                let spec = PuzzleSpec(world: .dinosaur, kind: .assemble, difficulty: rung)
                let puzzle = engine.generate(spec: spec, seed: seed &* 1_579)
                let slots = puzzle.grid.tiles.filter { $0.role == .slot }
                XCTAssertTrue((3...5).contains(slots.count), "\(slots.count) slots is off")

                for slot in slots {
                    let fitting = puzzle.options.filter { $0.glyph == slot.glyph }
                    XCTAssertEqual(fitting.count, 1, "a slot must take exactly one piece")
                }
                let sparePieces = puzzle.options.filter { option in
                    !slots.contains { $0.glyph == option.glyph }
                }
                XCTAssertEqual(sparePieces.count, rung >= 4 ? 1 : 0,
                               "spare pieces should only appear from rung 4")
            }
        }
    }

    // MARK: Mazes

    /// The one thing a maze must never be: unsolvable. Every generated board
    /// is walked with a breadth-first search to prove a legal route exists.
    func testEveryMazeIsSolvable() {
        for world in PuzzleWorld.allCases {
            for rung in 1...8 {
                for seed in UInt64(1)...25 {
                    let spec = PuzzleSpec(world: world, kind: .maze, difficulty: rung)
                    let puzzle = engine.generate(spec: spec, seed: seed &* 3_571)
                    let context = "\(world.rawValue) d:\(rung) s:\(seed)"

                    guard let route = solve(puzzle.grid) else {
                        return XCTFail("no way through the maze — \(context)")
                    }
                    // The found route must satisfy the same rules the child's
                    // taps are judged by.
                    XCTAssertTrue(MazeRules.isComplete(path: route, in: puzzle.grid), context)
                    for (index, id) in route.enumerated() {
                        XCTAssertTrue(
                            MazeRules.canStep(to: id, path: Array(route.prefix(index)), in: puzzle.grid),
                            "step \(index) is illegal — \(context)"
                        )
                    }
                }
            }
        }
    }

    func testMazeStartAndGoalAreNeverDangerous() {
        for rung in 1...8 {
            for seed in UInt64(1)...20 {
                let spec = PuzzleSpec(world: .pirate, kind: .maze, difficulty: rung)
                let puzzle = engine.generate(spec: spec, seed: seed &* 811)
                let roles = puzzle.grid.tiles.map(\.role)
                XCTAssertEqual(roles.first, .start, "the child always starts in the corner")
                XCTAssertEqual(roles.last, .goal)
                XCTAssertTrue(roles.allSatisfy { $0 == .hazard ? !$0.isWalkable : $0.isWalkable })
                XCTAssertLessThanOrEqual(puzzle.grid.tiles.filter { $0.role == .key }.count, 1)
            }
        }
    }

    /// From rung 4 the treasure needs a key first — and the key is always
    /// reachable before the goal, never walled off.
    func testHigherRungsAddAReachableKey() {
        var sawKey = false
        for seed in UInt64(1)...20 {
            let spec = PuzzleSpec(world: .castle, kind: .maze, difficulty: 6)
            let puzzle = engine.generate(spec: spec, seed: seed &* 277)
            guard puzzle.grid.tiles.contains(where: { $0.role == .key }) else { continue }
            sawKey = true
            guard let route = solve(puzzle.grid) else { return XCTFail("unsolvable keyed maze") }
            let keyID = puzzle.grid.tiles.first { $0.role == .key }?.id
            XCTAssertTrue(route.contains(keyID ?? UUID()), "the route must pass the key")
        }
        XCTAssertTrue(sawKey, "rung 6 mazes should carry a key")
    }

    func testMazeHazardsGrowWithDifficulty() {
        func hazardCount(_ rung: Int) -> Int {
            (1...20).reduce(0) { total, seed in
                let spec = PuzzleSpec(world: .ice, kind: .maze, difficulty: rung)
                let puzzle = engine.generate(spec: spec, seed: UInt64(seed) &* 1_013)
                return total + puzzle.grid.tiles.filter { $0.role == .hazard }.count
            }
        }
        XCTAssertGreaterThan(hazardCount(8), hazardCount(1))
    }

    /// Breadth-first search over (cell, has-key) states — not over paths,
    /// which would be exponential. Returns a legal route, or nil if the maze
    /// is broken.
    private func solve(_ grid: PuzzleGrid) -> [UUID]? {
        guard let startIndex = grid.tiles.firstIndex(where: { $0.role == .start }) else { return nil }
        let needsKey = grid.tiles.contains { $0.role == .key }

        struct State: Hashable { let index: Int; let hasKey: Bool }
        let start = State(index: startIndex, hasKey: grid.tiles[startIndex].role == .key || !needsKey)

        var queue = [start]
        var parents: [State: State] = [:]
        var seen: Set<State> = [start]

        while !queue.isEmpty {
            let state = queue.removeFirst()
            let tile = grid.tiles[state.index]
            if tile.role == .goal && state.hasKey {
                // Walk the parents back to the start.
                var route = [tile.id]
                var cursor = state
                while let parent = parents[cursor] {
                    route.append(grid.tiles[parent.index].id)
                    cursor = parent
                }
                return route.reversed()
            }

            let row = state.index / grid.columns
            let column = state.index % grid.columns
            for (nextRow, nextColumn) in [(row - 1, column), (row + 1, column),
                                          (row, column - 1), (row, column + 1)] {
                guard nextRow >= 0, nextRow < grid.rows, nextColumn >= 0, nextColumn < grid.columns
                else { continue }
                let nextIndex = nextRow * grid.columns + nextColumn
                let nextTile = grid.tiles[nextIndex]
                guard nextTile.role.isWalkable else { continue }
                let next = State(index: nextIndex,
                                 hasKey: state.hasKey || nextTile.role == .key)
                guard seen.insert(next).inserted else { continue }
                parents[next] = state
                queue.append(next)
            }
        }
        return nil
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

    /// Held for the lifetime of the test: a `ModelContainer` that goes out of
    /// scope takes its context — and every model instance fetched from it —
    /// down with it ("this model instance was destroyed by calling
    /// ModelContext.reset").
    private var container: ModelContainer?

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private func makeContext() throws -> (ModelContext, ChildProfile) {
        // `.none` matters: without it an in-memory store still tries to stand
        // up CloudKit mirroring, which floods the log and can't succeed in a
        // test bundle that carries no iCloud entitlement.
        let configuration = ModelConfiguration(
            schema: ModelContainerFactory.schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: ModelContainerFactory.schema,
            configurations: [configuration]
        )
        self.container = container
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

    func testDailyAndWeekendRunsNeverAdvanceTheStory() throws {
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

        let daily = try XCTUnwrap(try start.dailyRun(child: child, age: 5))
        XCTAssertEqual(daily.world, .forest, "only the first world is open at the start")
        XCTAssertEqual(daily.mode, .daily)
        XCTAssertEqual(daily.level, 0)
        XCTAssertFalse(daily.mode.advancesStory)

        let dailyAttempts = daily.puzzles.map { puzzle in
            PuzzleAttempt(kind: puzzle.kind, skill: puzzle.skill, solved: true,
                          missedTaps: 0, duration: 3, usedHint: false, timeLimit: puzzle.timeLimit)
        }
        let completion = try complete.execute(
            run: daily, attempts: dailyAttempts, child: child, age: 5, preference: .automatic
        )
        XCTAssertGreaterThan(completion.result.gems, 0, "the daily puzzle still pays")
        XCTAssertEqual(
            try repository.snapshot(for: child).completed(.forest), 0,
            "a daily puzzle must not skip a story chapter"
        )

        let weekend = try XCTUnwrap(try start.weekendRun(child: child, age: 5))
        XCTAssertEqual(weekend.mode, .weekend)
        XCTAssertGreaterThanOrEqual(weekend.puzzles.count, 8)
    }

    /// The weekend challenge pays double for the same play.
    func testWeekendChallengePaysDouble() throws {
        let (context, child) = try makeContext()
        let repository = SwiftDataPuzzleRepository(context: context)
        let progression = PuzzleProgressionEngine()
        let complete = CompletePuzzleRunUseCase(
            puzzleRepository: repository, progressionEngine: progression
        )
        let generator = PuzzleGeneratorEngine()
        var rng = SeededGenerator(seed: 5)
        let weekend = generator.generateWeekendRun(world: .forest, difficulty: 3, age: 6, count: 8, using: &rng)
        let same = attempts(count: 8)

        let plain = progression.makeResult(world: .forest, level: 0, difficulty: 3, attempts: same)
        let paid = try complete.execute(
            run: weekend, attempts: same, child: child, age: 6, preference: .automatic
        )
        XCTAssertEqual(paid.result.gems, plain.gems * 2)
    }

    // MARK: Collectibles

    func testBuyingACollectibleSpendsGemsAndSticks() throws {
        let (context, child) = try makeContext()
        let repository = SwiftDataPuzzleRepository(context: context)
        let bunny = try XCTUnwrap(CollectibleCatalog.item("pet.bunny"))

        // Can't buy what you can't afford, and nothing is lost trying.
        XCTAssertFalse(try repository.purchase(bunny, for: child))
        XCTAssertEqual(try repository.snapshot(for: child).gems, 0)

        try repository.awardGems(bunny.price, to: child)
        XCTAssertTrue(try repository.purchase(bunny, for: child))

        let snapshot = try repository.snapshot(for: child)
        XCTAssertEqual(snapshot.gems, 0, "gems are spent")
        XCTAssertTrue(snapshot.owned.contains(bunny.id))
        XCTAssertEqual(snapshot.companionID, bunny.id, "the first friend comes along automatically")
        XCTAssertEqual(snapshot.companion?.emoji, bunny.emoji)

        // Buying it twice is a no-op, not a double charge.
        try repository.awardGems(bunny.price, to: child)
        XCTAssertFalse(try repository.purchase(bunny, for: child))
        XCTAssertEqual(try repository.snapshot(for: child).gems, bunny.price)
    }

    func testPlacingPiecesFillsTheMuralAndPaysOnce() throws {
        let (context, child) = try makeContext()
        let repository = SwiftDataPuzzleRepository(context: context)
        let mural = MuralCatalog.mural(for: .forest)

        // No pieces, no placement — and nothing is lost trying.
        XCTAssertEqual(try repository.placeMuralPiece(in: .forest, for: child), .notPlaced)

        // Earn pieces by playing levels.
        let engine = PuzzleProgressionEngine()
        for level in 1...WorldMural.tileCount {
            _ = try repository.record(
                engine.makeResult(world: .forest, level: level, difficulty: 2,
                                  attempts: attempts(count: 1)),
                nextDifficulty: 2, for: child
            )
        }
        XCTAssertEqual(try repository.snapshot(for: child).pieces, WorldMural.tileCount)

        var lastPlacement = MuralPlacement.notPlaced
        for expected in 1...WorldMural.tileCount {
            lastPlacement = try repository.placeMuralPiece(in: .forest, for: child)
            XCTAssertTrue(lastPlacement.placed)
            XCTAssertEqual(lastPlacement.tilesPlaced, expected)
        }
        XCTAssertTrue(lastPlacement.completedNow, "the ninth piece finishes the picture")
        XCTAssertEqual(lastPlacement.bonusGems, mural.completionBonus)

        let snapshot = try repository.snapshot(for: child)
        XCTAssertEqual(snapshot.muralPlaced(.forest), WorldMural.tileCount)
        XCTAssertEqual(snapshot.pieces, 0, "pieces are spent placing them")
        XCTAssertFalse(snapshot.muralsInProgress.contains(.forest))

        // A finished mural takes no more pieces and pays no second bonus.
        try repository.awardGems(0, to: child)
        _ = try repository.record(
            engine.makeResult(world: .forest, level: 10, difficulty: 2, attempts: attempts(count: 1)),
            nextDifficulty: 2, for: child
        )
        let after = try repository.placeMuralPiece(in: .forest, for: child)
        XCTAssertFalse(after.placed)
        XCTAssertEqual(try repository.snapshot(for: child).pieces, 1, "the spare piece is kept")
    }

    func testCompanionMustBeOwned() throws {
        let (context, child) = try makeContext()
        let repository = SwiftDataPuzzleRepository(context: context)
        try repository.setCompanion("pet.unicorn", for: child)
        XCTAssertEqual(try repository.snapshot(for: child).companionID, "",
                       "you can't walk a unicorn you don't own")
    }
}

// MARK: - Maze rules

final class MazeRulesTests: XCTestCase {

    /// A hand-built 3×3 board:  🏁 ⬜ 🔥
    ///                          ⬜ 🔥 ⬜
    ///                          🔑 ⬜ 🏆
    private func board() -> PuzzleGrid {
        let roles: [PuzzleTileRole] = [
            .start, .plain, .hazard,
            .plain, .hazard, .plain,
            .key, .plain, .goal
        ]
        return PuzzleGrid(rows: 3, columns: 3, tiles: roles.map { PuzzleTile(role: $0) })
    }

    private func id(_ grid: PuzzleGrid, _ row: Int, _ column: Int) -> UUID {
        grid.tile(row: row, column: column)!.id
    }

    func testFirstStepMustBeTheStart() {
        let grid = board()
        XCTAssertTrue(MazeRules.canStep(to: id(grid, 0, 0), path: [], in: grid))
        XCTAssertFalse(MazeRules.canStep(to: id(grid, 0, 1), path: [], in: grid),
                       "you can't drop into the middle of a maze")
    }

    func testStepsMustNeighbourAndAvoidHazards() {
        let grid = board()
        let start = [id(grid, 0, 0)]
        XCTAssertTrue(MazeRules.canStep(to: id(grid, 1, 0), path: start, in: grid))
        XCTAssertTrue(MazeRules.canStep(to: id(grid, 0, 1), path: start, in: grid))
        XCTAssertFalse(MazeRules.canStep(to: id(grid, 2, 2), path: start, in: grid),
                       "no teleporting across the board")
        XCTAssertFalse(MazeRules.canStep(to: id(grid, 1, 1), path: [id(grid, 0, 1)], in: grid),
                       "fire is never walkable")
    }

    func testARouteNeverCrossesItself() {
        let grid = board()
        let path = [id(grid, 0, 0), id(grid, 1, 0)]
        XCTAssertFalse(MazeRules.canStep(to: id(grid, 0, 0), path: path, in: grid))
    }

    func testCompletionNeedsTheKeyThenTheGoal() {
        let grid = board()
        let withoutKey = [id(grid, 0, 0), id(grid, 0, 1), id(grid, 0, 2)]
        XCTAssertFalse(MazeRules.isComplete(path: withoutKey, in: grid), "that isn't even the goal")

        // Down the left side, over the key, along the bottom to the treasure.
        let full = [id(grid, 0, 0), id(grid, 1, 0), id(grid, 2, 0), id(grid, 2, 1), id(grid, 2, 2)]
        XCTAssertTrue(MazeRules.isComplete(path: full, in: grid))

        // The same finish without ever touching the key doesn't count.
        let skippedKey = [id(grid, 0, 0), id(grid, 1, 0), id(grid, 2, 0)]
        XCTAssertFalse(MazeRules.isComplete(path: skippedKey, in: grid))
    }

    /// Walking into a dead end is detectable, so the child can be told
    /// kindly to back up rather than sitting there stuck.
    func testDeadEndsAreDetected() {
        let grid = board()
        let open = [id(grid, 0, 0)]
        XCTAssertTrue(MazeRules.hasRouteRemaining(path: open, in: grid))

        // Up the top row: the fire at (0,2) walls it off from everything.
        let cornered = [id(grid, 0, 0), id(grid, 0, 1)]
        XCTAssertFalse(MazeRules.hasRouteRemaining(path: cornered, in: grid),
                       "the top-right corner is a dead end")
    }

    func testNeighbourCheckIsSymmetricAndRejectsStrangers() {
        let grid = board()
        XCTAssertTrue(MazeRules.areNeighbours(id(grid, 0, 0), id(grid, 0, 1), in: grid))
        XCTAssertTrue(MazeRules.areNeighbours(id(grid, 0, 1), id(grid, 0, 0), in: grid))
        XCTAssertFalse(MazeRules.areNeighbours(id(grid, 0, 0), id(grid, 1, 1), in: grid),
                       "diagonals don't count")
        XCTAssertFalse(MazeRules.areNeighbours(id(grid, 0, 0), UUID(), in: grid))
    }
}

// MARK: - Pipe rules

final class PipeRulesTests: XCTestCase {

    /// Three cells in a row: 🚰 ─ ─ 🪣, with the middle piece turned the
    /// wrong way to start.
    private func board(middle: PipeConnections) -> PuzzleGrid {
        PuzzleGrid(rows: 1, columns: 3, tiles: [
            PuzzleTile(role: .start, pipe: [.east]),
            PuzzleTile(pipe: middle),
            PuzzleTile(role: .goal, pipe: [.west])
        ])
    }

    func testAQuarterTurnMovesEveryArmRound() {
        XCTAssertEqual(PipeConnections.north.rotated(), .east)
        XCTAssertEqual(PipeConnections.east.rotated(), .south)
        XCTAssertEqual(PipeConnections.south.rotated(), .west)
        XCTAssertEqual(PipeConnections.west.rotated(), .north)

        let elbow: PipeConnections = [.north, .east]
        var turned = elbow
        for _ in 0..<4 { turned = turned.rotated() }
        XCTAssertEqual(turned, elbow, "four turns is a full circle")
    }

    func testOppositeSides() {
        XCTAssertEqual(PipeConnections.north.opposite, .south)
        XCTAssertEqual(PipeConnections.west.opposite, .east)
        XCTAssertEqual(PipeConnections([.north, .east]).opposite, [.south, .west])
    }

    /// The rule that makes the puzzle a puzzle: both sides have to open onto
    /// each other. One arm pointing at a closed neighbour is a leak.
    func testWaterOnlyCrossesWhenBothSidesOpen() {
        let joined = board(middle: [.east, .west])
        XCTAssertTrue(PipeRules.isConnected(joined))

        let turnedAway = board(middle: [.north, .south])
        XCTAssertFalse(PipeRules.isConnected(turnedAway), "the middle pipe faces the wrong way")
        XCTAssertEqual(PipeRules.flooded(turnedAway).count, 1, "only the tap is wet")
    }

    func testTurningTheMiddlePipeCompletesTheRun() {
        var grid = board(middle: [.north, .south])
        let middleID = grid.tiles[1].id
        XCTAssertFalse(PipeRules.isConnected(grid))

        grid = PipeRules.rotating(grid, tileID: middleID)
        XCTAssertTrue(PipeRules.isConnected(grid), "a single quarter turn should join it up")
        XCTAssertEqual(PipeRules.flooded(grid).count, 3, "every pipe is wet now")
    }

    func testFloodedReportsPartialProgress() {
        // Tap joins the middle, but the middle doesn't reach the bucket.
        let grid = PuzzleGrid(rows: 1, columns: 3, tiles: [
            PuzzleTile(role: .start, pipe: [.east]),
            PuzzleTile(pipe: [.west, .north]),
            PuzzleTile(role: .goal, pipe: [.west])
        ])
        XCTAssertEqual(PipeRules.flooded(grid).count, 2)
        XCTAssertFalse(PipeRules.isConnected(grid))
    }

    func testRotatingAnUnknownTileChangesNothing() {
        let grid = board(middle: [.east, .west])
        XCTAssertEqual(
            PipeRules.rotating(grid, tileID: UUID()).tiles.map(\.pipe),
            grid.tiles.map(\.pipe)
        )
    }

    func testPieceNames() {
        XCTAssertTrue(PipeConnections([.north, .south]).isStraight)
        XCTAssertFalse(PipeConnections([.north, .east]).isStraight)
        XCTAssertEqual(PipeConnections([.north, .east, .south, .west]).armCount, 4)
        XCTAssertFalse(PipeConnections([.north]).localizedName.isEmpty)
    }
}

// MARK: - Block geometry

final class PuzzlePatternTests: XCTestCase {

    /// An L: ■ ·
    ///        ■ ■
    private func lShape() -> PuzzlePattern {
        PuzzlePattern(rows: 2, columns: 2,
                      filled: [true, false,
                               true, true],
                      color: .blue)
    }

    func testFourTurnsComeBackToTheStart() {
        let shape = lShape()
        var turned = shape
        for _ in 0..<4 { turned = turned.rotated() }
        XCTAssertEqual(turned, shape, "four quarter turns is a full circle")
    }

    func testAQuarterTurnMovesTheCellsCorrectly() {
        // ■ ·      ■ ■
        // ■ ■  →   ■ ·
        XCTAssertEqual(lShape().rotated().filled, [true, true, true, false])
    }

    func testRotationOfANonSquareBlockSwapsRowsAndColumns() {
        let wide = PuzzlePattern(rows: 1, columns: 3, filled: [true, true, false], color: .red)
        let turned = wide.rotated()
        XCTAssertEqual(turned.rows, 3)
        XCTAssertEqual(turned.columns, 1)
        XCTAssertEqual(turned.filledCount, wide.filledCount, "turning never adds or drops squares")
    }

    func testIsRotationRecognisesEveryTurnAndRejectsStrangers() {
        let shape = lShape()
        for turn in shape.rotations {
            XCTAssertTrue(turn.isRotation(of: shape))
            XCTAssertTrue(shape.isRotation(of: turn), "being a turn goes both ways")
        }
        let different = PuzzlePattern(rows: 2, columns: 2,
                                      filled: [true, true, false, false], color: .blue)
        XCTAssertFalse(different.isRotation(of: shape))
    }

    /// The distinction the whole puzzle rests on: a mirror is not a turn.
    func testAMirrorIsNotARotation() {
        let shape = lShape()
        XCTAssertFalse(shape.mirrored().isRotation(of: shape))
        XCTAssertEqual(shape.mirrored().filledCount, shape.filledCount)
        XCTAssertEqual(shape.mirrored().mirrored(), shape)
    }

    func testSymmetryDetection() {
        XCTAssertTrue(lShape().hasDistinctRotations)

        // A full square looks the same whichever way you turn it.
        let square = PuzzlePattern(rows: 2, columns: 2,
                                   filled: [true, true, true, true], color: .green)
        XCTAssertFalse(square.hasDistinctRotations)

        // So does a diagonal pair, after half a turn.
        let diagonal = PuzzlePattern(rows: 2, columns: 2,
                                     filled: [true, false, false, true], color: .green)
        XCTAssertFalse(diagonal.hasDistinctRotations)
    }

    func testOutOfBoundsCellsReadAsEmpty() {
        let shape = lShape()
        XCTAssertFalse(shape.isFilled(row: -1, column: 0))
        XCTAssertFalse(shape.isFilled(row: 0, column: 5))
    }
}

// MARK: - Murals

final class MuralCatalogTests: XCTestCase {

    func testEveryWorldHasANineTileMural() {
        for world in PuzzleWorld.allCases {
            let mural = MuralCatalog.mural(for: world)
            XCTAssertEqual(mural.world, world)
            XCTAssertEqual(mural.tiles.count, WorldMural.tileCount, world.rawValue)
            XCTAssertFalse(mural.title.isEmpty, world.rawValue)
            XCTAssertTrue(mural.tiles.allSatisfy { !$0.isEmpty }, world.rawValue)
            XCTAssertGreaterThan(mural.completionBonus, 0, world.rawValue)
        }
    }

    func testRevealUncoversInOrder() {
        let mural = MuralCatalog.mural(for: .forest)
        XCTAssertEqual(mural.revealed(0).compactMap { $0 }.count, 0)
        XCTAssertEqual(mural.revealed(4).compactMap { $0 }.count, 4)
        XCTAssertEqual(mural.revealed(4)[0], mural.tiles[0], "the first piece fills the first tile")
        XCTAssertNil(mural.revealed(4)[4])
        XCTAssertEqual(mural.revealed(WorldMural.tileCount).compactMap { $0 }, mural.tiles)
        XCTAssertTrue(mural.isComplete(WorldMural.tileCount))
        XCTAssertFalse(mural.isComplete(WorldMural.tileCount - 1))
    }

    func testLaterWorldsPayMoreForTheirPicture() {
        XCTAssertGreaterThan(
            MuralCatalog.mural(for: .ice).completionBonus,
            MuralCatalog.mural(for: .forest).completionBonus
        )
    }
}

// MARK: - Collectible catalog

final class CollectibleCatalogTests: XCTestCase {

    func testCatalogIsWellFormed() {
        let all = CollectibleCatalog.all
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "duplicate collectible id")
        XCTAssertTrue(all.allSatisfy { $0.price > 0 }, "everything must cost something")
        XCTAssertTrue(all.allSatisfy { !$0.name.isEmpty && !$0.emoji.isEmpty })
        for kind in CollectibleKind.allCases {
            XCTAssertFalse(CollectibleCatalog.items(of: kind).isEmpty, "\(kind.rawValue) is empty")
        }
    }

    /// A child with no crystals must still have something to want and reach.
    func testSomethingIsAffordableEarly() {
        let starters = CollectibleCatalog.all.filter { $0.requiresCrystal == nil }
        XCTAssertFalse(starters.isEmpty)
        XCTAssertLessThanOrEqual(starters.map(\.price).min() ?? .max, 30,
                                 "the cheapest treat should be within a level or two")

        let affordable = CollectibleCatalog.affordable(gems: 40, crystals: [], owned: [])
        XCTAssertFalse(affordable.isEmpty)
        XCTAssertEqual(affordable, affordable.sorted { $0.price < $1.price }, "cheapest first")
        XCTAssertTrue(affordable.allSatisfy { $0.requiresCrystal == nil })
    }

    func testCrystalGatedItemsOpenWithTheirCrystal() {
        let gated = try? XCTUnwrap(CollectibleCatalog.all.first { $0.requiresCrystal == .space })
        guard let gated else { return }
        XCTAssertFalse(gated.isAvailable(crystals: []))
        XCTAssertTrue(gated.isAvailable(crystals: [.space]))
    }

    func testOwnedItemsAreNotOfferedAgain() {
        let owned: Set<String> = ["sticker.star"]
        XCTAssertFalse(
            CollectibleCatalog.affordable(gems: 999, crystals: [], owned: owned)
                .contains { $0.id == "sticker.star" }
        )
    }
}

// MARK: - Daily activities

final class PuzzleDailyEngineTests: XCTestCase {

    private let engine = PuzzleDailyEngine()

    func testStreakLadderLoopsAndEndsInAChest() {
        XCTAssertEqual(PuzzleDailyEngine.ladder.count, 7)
        XCTAssertTrue(PuzzleDailyEngine.ladder.last?.isChest == true)
        XCTAssertEqual(engine.reward(forStreakDay: 1).day, 1)
        XCTAssertEqual(engine.reward(forStreakDay: 8).day, 1, "day 8 starts the ladder again")
        XCTAssertEqual(engine.reward(forStreakDay: 0).day, 1, "no streak still shows day one")

        let gems = PuzzleDailyEngine.ladder.map(\.gems)
        XCTAssertEqual(gems, gems.sorted(), "the ladder should always climb")
    }

    /// The chest is seeded by the day: relaunching can't reroll it.
    func testChestRewardIsStablePerDayAndAlwaysPays() {
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let first = engine.chestReward(day: day, streakDays: 3)
        XCTAssertEqual(first, engine.chestReward(day: day, streakDays: 3))
        XCTAssertGreaterThan(first, 0, "an empty chest would be a broken promise")

        let tomorrow = day.addingTimeInterval(86_400)
        let week = (0..<7).map { engine.chestReward(day: day.addingTimeInterval(Double($0) * 86_400), streakDays: 3) }
        XCTAssertGreaterThan(Set(week).count, 1, "the chest should vary across days")
        XCTAssertGreaterThan(engine.chestReward(day: tomorrow, streakDays: 14),
                             0)
    }

    func testLongerStreaksRaiseTheChestFloor() {
        let day = Date(timeIntervalSince1970: 1_800_086_400)
        XCTAssertGreaterThan(
            engine.chestReward(day: day, streakDays: 10),
            engine.chestReward(day: day, streakDays: 0),
            "turning up should matter more than luck"
        )
    }

    func testChestNeedsTodaysPuzzleFirst() {
        let weekday = Date(timeIntervalSince1970: 1_800_000_000)
        let notPlayed = engine.activities(
            streakDays: 2, hasUnlockedWorld: true, dailyPuzzleDone: false,
            chestOpened: false, weekendChallengeDone: false, date: weekday
        )
        XCTAssertFalse(notPlayed.chestAvailable)

        let played = engine.activities(
            streakDays: 2, hasUnlockedWorld: true, dailyPuzzleDone: true,
            chestOpened: false, weekendChallengeDone: false, date: weekday
        )
        XCTAssertTrue(played.chestAvailable)

        let alreadyOpened = engine.activities(
            streakDays: 2, hasUnlockedWorld: true, dailyPuzzleDone: true,
            chestOpened: true, weekendChallengeDone: false, date: weekday
        )
        XCTAssertFalse(alreadyOpened.chestAvailable, "one chest a day")
    }

    func testWeekendDetectionAndChallengeSize() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        // 2026-08-01 is a Saturday; 2026-08-03 is a Monday.
        let saturday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3))!
        XCTAssertTrue(engine.isWeekend(saturday, calendar: calendar))
        XCTAssertFalse(engine.isWeekend(monday, calendar: calendar))

        XCTAssertGreaterThanOrEqual(engine.weekendChallengeCount(difficulty: 1), 8)
        XCTAssertGreaterThan(
            engine.weekendChallengeCount(difficulty: 8),
            engine.weekendChallengeCount(difficulty: 1)
        )
        XCTAssertEqual(engine.weekendBonusMultiplier(), 2)
    }

    func testActivitiesReportTodaysAndTomorrowsReward() {
        let activities = engine.activities(
            streakDays: 3, hasUnlockedWorld: true, dailyPuzzleDone: false,
            chestOpened: false, weekendChallengeDone: false,
            date: Date(timeIntervalSince1970: 1_800_000_000)
        )
        XCTAssertEqual(activities.todaysReward.day, 3)
        XCTAssertEqual(activities.nextReward?.day, 4)
        XCTAssertTrue(activities.hasDailyPuzzle)
    }
}
