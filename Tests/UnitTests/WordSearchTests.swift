//
//  WordSearchTests.swift
//  FocusForestAdventureTests
//
//  Word Hunt: the campaign's word table obeys the zero-repetition rule and
//  its stage tables; the generator honours every stage rule for every
//  sheet over many seeds; the progress store never takes a star away.
//
//  The uniqueness test is the reason the word table can be trusted. It is
//  stricter than the spec: not just no duplicates, but no shared stems and
//  no word hiding inside another, because a drag across SUN inside
//  SUNSHINE would light up half a word.
//

import XCTest
@testable import FocusForestAdventure

final class WordSearchWordBankTests: XCTestCase {

    func testExactlyFortySheetsNumberedInOrder() {
        XCTAssertEqual(WordSearchWordBank.sheets.count, 40)
        XCTAssertEqual(WordSearchWordBank.sheets.map(\.number), Array(1...40))
        XCTAssertEqual(Set(WordSearchWordBank.sheets.map(\.title)).count, 40, "no theme repeats")
    }

    func testNoTargetWordRepeatsAcrossTheCampaign() {
        let collisions = WordSearchWordBank.collisions()
        XCTAssertTrue(collisions.isEmpty,
                      "words collide: \(collisions.map { "\($0.0)/\($0.1)" }.joined(separator: ", "))")
        XCTAssertEqual(Set(WordSearchWordBank.allWords).count, WordSearchWordBank.allWords.count)
    }

    func testStemCollapsesPluralsAndObviousEndings() {
        XCTAssertEqual(WordSearchWordBank.stem("BUTTERFLIES"), "BUTTERFLY")
        XCTAssertEqual(WordSearchWordBank.stem("CATS"), "CAT")
        XCTAssertEqual(WordSearchWordBank.stem("BOXES"), "BOX")
        XCTAssertEqual(WordSearchWordBank.stem("JUMPED"), "JUMP")
        XCTAssertEqual(WordSearchWordBank.stem("BUS"), "BUS", "a three-letter word is not a plural")
    }

    func testEverySheetObeysItsStageTable() {
        for sheet in WordSearchWordBank.sheets {
            let stage = sheet.stage
            XCTAssertTrue(stage.wordCount.contains(sheet.words.count),
                          "sheet \(sheet.number) has \(sheet.words.count) words, stage allows \(stage.wordCount)")
            for word in sheet.words {
                XCTAssertTrue(stage.wordLength.contains(word.text.count),
                              "sheet \(sheet.number) '\(word.text)' is \(word.text.count) letters, stage allows \(stage.wordLength)")
                XCTAssertTrue(word.text.allSatisfy { $0.isLetter && $0.isUppercase },
                              "'\(word.text)' must be uppercase letters only")
                XCTAssertFalse(word.emoji.isEmpty, "'\(word.text)' needs a picture")
            }
            XCTAssertLessThanOrEqual(sheet.words.map(\.text.count).max() ?? 0, stage.gridSizes.max() ?? 0,
                                     "sheet \(sheet.number) has a word longer than its biggest grid")
        }
    }

    func testStagesSplitTheCampaignIntoTens() {
        XCTAssertEqual(WordSearchWordBank.sheets.filter { $0.stage == .seedling }.map(\.number), Array(1...10))
        XCTAssertEqual(WordSearchWordBank.sheets.filter { $0.stage == .sprout }.map(\.number), Array(11...20))
        XCTAssertEqual(WordSearchWordBank.sheets.filter { $0.stage == .sapling }.map(\.number), Array(21...30))
        XCTAssertEqual(WordSearchWordBank.sheets.filter { $0.stage == .tree }.map(\.number), Array(31...40))
    }

    func testNoPalindromesBecauseTheCleanCheckCountsBothDirections() {
        for word in WordSearchWordBank.allWords {
            XCTAssertNotEqual(word, String(word.reversed()), "\(word) reads the same backwards")
        }
    }
}

final class WordSearchEngineTests: XCTestCase {
    private let engine = WordSearchEngine()

    /// The property that matters: every sheet, many seeds, every rule.
    /// The direction check doubles as the guard against the rows-only
    /// fallback, which is meant to be unreachable: across the seeds every
    /// direction the stage allows must show up at least once, and the
    /// fallback only ever lays words to the right. Four sheets whose
    /// targets contain a blocked word once hit the fallback on every seed
    /// and no assertion noticed.
    func testEverySheetGeneratesWithinItsStageRulesAcrossSeeds() {
        for sheet in WordSearchWordBank.sheets {
            let stage = sheet.stage
            var directionsSeen = Set<WordSearchDirection>()
            for seed in UInt64(1)...60 {
                let puzzle = engine.makePuzzle(sheet: sheet, seed: seed)
                let label = "sheet \(sheet.number) seed \(seed)"
                directionsSeen.formUnion(puzzle.placements.map(\.direction))

                XCTAssertTrue(stage.gridSizes.contains(puzzle.size), "\(label): size \(puzzle.size)")
                XCTAssertLessThanOrEqual(Double(sheet.words.reduce(0) { $0 + $1.text.count }),
                                         0.7 * Double(puzzle.size * puzzle.size),
                                         "\(label): more than 70% target letters — no room to search")
                XCTAssertEqual(puzzle.letters.count, puzzle.size * puzzle.size, label)
                XCTAssertEqual(puzzle.placements.count, sheet.words.count, "\(label): every word placed")
                XCTAssertEqual(Set(puzzle.placements.map(\.word)), Set(sheet.words.map(\.text)), label)

                for placement in puzzle.placements {
                    XCTAssertTrue(stage.directions.contains(placement.direction),
                                  "\(label): \(placement.word) runs \(placement.direction)")
                    XCTAssertEqual(puzzle.word(spelledBy: placement.cells), placement.word,
                                   "\(label): \(placement.word) is readable where it was placed")
                }
                XCTAssertLessThanOrEqual(puzzle.intersectionCount, stage.maximumIntersections, label)
                XCTAssertLessThanOrEqual(puzzle.backwardsWordCount, stage.maximumBackwardsWords, label)
            }
            XCTAssertEqual(directionsSeen, Set(stage.directions),
                           "sheet \(sheet.number): over 60 seeds only \(directionsSeen) were used")
        }
    }

    func testSameSeedSameGridAndDifferentSeedsDiffer() {
        let sheet = WordSearchWordBank.sheets[20]
        XCTAssertEqual(engine.makePuzzle(sheet: sheet, seed: 7), engine.makePuzzle(sheet: sheet, seed: 7))
        let grids = Set((1...20).map { engine.makePuzzle(sheet: sheet, seed: UInt64($0)).letters })
        XCTAssertGreaterThan(grids.count, 15, "seeds should give distinct arrangements")
    }

    func testNoTargetAppearsTwiceInAnyDirection() {
        for sheet in WordSearchWordBank.sheets {
            for seed in UInt64(1)...30 {
                let puzzle = engine.makePuzzle(sheet: sheet, seed: seed)
                for word in sheet.words.map(\.text) {
                    XCTAssertEqual(runs(spelling: word, in: puzzle), 1,
                                   "sheet \(sheet.number) seed \(seed): \(word) appears more than once")
                }
            }
        }
    }

    /// Filler adds no blocked word. A blocked word inside a target (the
    /// HELL in SHELL) is expected exactly as often as that target appears,
    /// so the count must equal what the targets contribute, not zero.
    func testBlockedFillerNeverAppears() {
        var sawTargetContribution = false
        for sheet in WordSearchWordBank.sheets {
            for seed in UInt64(1)...30 {
                let puzzle = engine.makePuzzle(sheet: sheet, seed: seed)
                for blocked in WordSearchEngine.blockedFiller {
                    let fromTargets = sheet.words.reduce(0) { $0 + occurrences(of: blocked, in: $1.text) }
                    if fromTargets > 0 { sawTargetContribution = true }
                    XCTAssertEqual(runs(spelling: blocked, in: puzzle), fromTargets,
                                   "sheet \(sheet.number) seed \(seed) spells \(blocked)")
                }
            }
        }
        XCTAssertTrue(sawTargetContribution, "the bank has targets containing a blocked word; if none remain, simplify this test")
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        var count = 0
        var search = text.startIndex
        while let range = text.range(of: needle, range: search..<text.endIndex) {
            count += 1
            search = text.index(after: range.lowerBound)
        }
        return count
    }

    func testAWordReadsBackwardsToo() {
        let puzzle = engine.makePuzzle(sheet: WordSearchWordBank.sheets[0], seed: 3)
        let placement = puzzle.placements[0]
        XCTAssertEqual(puzzle.word(spelledBy: placement.cells.reversed()), placement.word)
        XCTAssertNil(puzzle.word(spelledBy: Array(placement.cells.dropLast())), "a partial run is not the word")
    }

    /// Independent count of a word's straight-line occurrences, so the
    /// engine's own checker is not the only witness. Scanning every start
    /// cell in all eight directions finds a word laid backwards too — read
    /// from its far end it spells forwards — so each occurrence is counted
    /// exactly once and nothing is divided.
    private func runs(spelling word: String, in puzzle: WordSearchPuzzle) -> Int {
        var count = 0
        let letters = Array(word)
        for row in 0..<puzzle.size {
            for column in 0..<puzzle.size {
                for direction in WordSearchDirection.allCases {
                    let cells = (0..<letters.count).map {
                        WordSearchCell(row: row + direction.delta.row * $0, column: column + direction.delta.column * $0)
                    }
                    let spelled = cells.compactMap(puzzle.letter(at:))
                    if spelled.count == letters.count, spelled == letters { count += 1 }
                }
            }
        }
        return count
    }
}

@MainActor
final class WordSearchProgressTests: XCTestCase {

    override func setUp() async throws {
        WordSearchProgress.reset()
    }

    override func tearDown() async throws {
        WordSearchProgress.reset()
    }

    func testOnlyTheFirstSheetIsOpenAtTheStart() {
        XCTAssertTrue(WordSearchProgress.isUnlocked(1))
        XCTAssertFalse(WordSearchProgress.isUnlocked(2))
        XCTAssertEqual(WordSearchProgress.nextSheetNumber, 1)
        XCTAssertEqual(WordSearchProgress.completedCount, 0)
    }

    func testFinishingASheetOpensTheNext() {
        WordSearchProgress.record(stars: 2, for: 1)
        XCTAssertTrue(WordSearchProgress.isUnlocked(2))
        XCTAssertFalse(WordSearchProgress.isUnlocked(3))
        XCTAssertEqual(WordSearchProgress.nextSheetNumber, 2)
        XCTAssertEqual(WordSearchProgress.totalStars, 2)
    }

    func testStarsNeverGoDown() {
        WordSearchProgress.record(stars: 3, for: 5)
        WordSearchProgress.record(stars: 1, for: 5)
        XCTAssertEqual(WordSearchProgress.stars(for: 5), 3)
    }

    func testFinishedCampaignPointsAtTheLastSheet() {
        for number in 1...WordSearchWordBank.count { WordSearchProgress.record(stars: 1, for: number) }
        XCTAssertEqual(WordSearchProgress.nextSheetNumber, WordSearchWordBank.count)
        XCTAssertEqual(WordSearchProgress.completedCount, WordSearchWordBank.count)
    }
}
