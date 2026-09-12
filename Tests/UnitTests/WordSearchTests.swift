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

import SwiftData
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

/// The campaign rules on a value with no store behind it.
final class WordSearchSnapshotTests: XCTestCase {

    func testOnlyTheFirstSheetIsOpenAtTheStart() {
        let snapshot = WordSearchSnapshot()
        XCTAssertTrue(snapshot.isUnlocked(1))
        XCTAssertFalse(snapshot.isUnlocked(2))
        XCTAssertEqual(snapshot.nextSheetNumber, 1)
        XCTAssertEqual(snapshot.completedCount, 0)
        XCTAssertEqual(snapshot.wordsFound, 0)
    }

    func testFinishingASheetOpensTheNextAndCountsItsWords() {
        var snapshot = WordSearchSnapshot()
        snapshot.stars[1] = 2
        XCTAssertTrue(snapshot.isUnlocked(2))
        XCTAssertFalse(snapshot.isUnlocked(3))
        XCTAssertEqual(snapshot.nextSheetNumber, 2)
        XCTAssertEqual(snapshot.totalStars, 2)
        XCTAssertEqual(snapshot.wordsFound, WordSearchWordBank.sheets[0].words.count)
    }

    func testNextSheetIsTheFirstGapNotTheHighestFinished() {
        var snapshot = WordSearchSnapshot()
        snapshot.stars[1] = 3
        snapshot.stars[3] = 1
        XCTAssertEqual(snapshot.nextSheetNumber, 2)
        XCTAssertEqual(snapshot.completedCount, 2)
    }

    func testFinishedCampaignPointsAtTheLastSheet() {
        var snapshot = WordSearchSnapshot()
        for number in 1...WordSearchWordBank.count { snapshot.stars[number] = 1 }
        XCTAssertEqual(snapshot.nextSheetNumber, WordSearchWordBank.count)
        XCTAssertEqual(snapshot.completedCount, WordSearchWordBank.count)
        XCTAssertEqual(snapshot.wordsFound, WordSearchWordBank.allWords.count)
    }
}

@MainActor
final class WordSearchRepositoryTests: XCTestCase {

    private var container: ModelContainer!
    private var deps: AppDependencies!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: ModelContainerFactory.schema, configurations: [config])
        deps = AppDependencies(modelContainer: container)
    }

    override func tearDown() async throws {
        deps = nil
        container = nil
    }

    func testAFreshChildHasNothing() throws {
        let child = try deps.childRepository.activeChild()
        XCTAssertEqual(try deps.wordSearchRepository.snapshot(for: child), WordSearchSnapshot())
    }

    func testAFinishIsReadBackAndSurvivesAFreshContext() throws {
        let child = try deps.childRepository.activeChild()
        try deps.wordSearchRepository.recordFinish(sheetNumber: 1, stars: 2, hintsUsed: 1, for: child)

        let again = AppDependencies(modelContainer: container)
        let snapshot = try again.wordSearchRepository.snapshot(for: try again.childRepository.activeChild())
        XCTAssertEqual(snapshot.stars(for: 1), 2)
        XCTAssertEqual(snapshot.timesFinished, 1)
        XCTAssertNotNil(snapshot.lastFinishedAt)
        XCTAssertTrue(snapshot.isUnlocked(2))
    }

    func testStarsNeverGoDownButFinishesAndFewestHintsKeepCounting() throws {
        let child = try deps.childRepository.activeChild()
        try deps.wordSearchRepository.recordFinish(sheetNumber: 5, stars: 3, hintsUsed: 0, for: child)
        try deps.wordSearchRepository.recordFinish(sheetNumber: 5, stars: 1, hintsUsed: 4, for: child)
        let snapshot = try deps.wordSearchRepository.snapshot(for: child)
        XCTAssertEqual(snapshot.stars(for: 5), 3)
        XCTAssertEqual(snapshot.timesFinished, 2)
        let row = try XCTUnwrap(child.wordSearchRecords?.first { $0.sheetNumber == 5 })
        XCTAssertEqual(row.fewestHints, 0)
        XCTAssertEqual(child.wordSearchRecords?.count, 1, "one row per sheet")
    }

    func testRowsBelongToTheirChild() throws {
        let child = try deps.childRepository.activeChild()
        try deps.wordSearchRepository.recordFinish(sheetNumber: 2, stars: 3, hintsUsed: 0, for: child)
        let other = try deps.childRepository.createChild(name: "Other", avatarEmoji: "🦊")
        XCTAssertEqual(try deps.wordSearchRepository.snapshot(for: other), WordSearchSnapshot())
    }
}

/// The art contract: names an artist can produce to, and the fallbacks
/// every sheet plays on until they do.
final class WordSearchArtTests: XCTestCase {

    func testAssetNamesFollowTheContract() {
        XCTAssertEqual(WordSearchArt.mascotName(sheet: 7, state: .idle), "WS_CHAR_07_Idle")
        XCTAssertEqual(WordSearchArt.mascotName(sheet: 40, state: .celebrate), "WS_CHAR_40_Celebrate")
        XCTAssertEqual(WordSearchArt.sceneName(sheet: 1), "WS_ENV_01")
        XCTAssertEqual(WordSearchArt.wordName("bee"), "WS_WORD_BEE")
    }

    func testEveryNameTheCampaignCanAskForIsUniqueAndCatalogSafe() {
        var names: [String] = []
        for sheet in WordSearchWordBank.sheets {
            names.append(WordSearchArt.sceneName(sheet: sheet.number))
            for state in WordSearchMascotState.allCases {
                names.append(WordSearchArt.mascotName(sheet: sheet.number, state: state))
            }
            for word in sheet.words { names.append(WordSearchArt.wordName(word.text)) }
        }
        XCTAssertEqual(Set(names).count, names.count, "no two layers share an asset name")
        for name in names {
            XCTAssertTrue(name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }, "\(name) is not a safe asset name")
        }
        // 40 scenes + 40 × 8 poses + one picture per target word.
        XCTAssertEqual(names.count, 40 + 40 * 8 + WordSearchWordBank.allWords.count)
    }

    /// The first real art through the contract: Kenney's CC0 animals
    /// (docs/WordSearch/ThirdPartyArt.md). A character with only an idle
    /// pose must still answer for every state.
    func testBundledArtResolvesAndAnIdleOnlyCharacterCoversEveryState() {
        XCTAssertTrue(WordSearchArt.isBundled("WS_CHAR_06_Idle"))
        XCTAssertFalse(WordSearchArt.isBundled("WS_CHAR_06_Celebrate"), "only the idle pose shipped")
        for state in WordSearchMascotState.allCases {
            XCTAssertNotNil(WordSearchArt.mascot(sheet: 6, state: state), "\(state) falls back to Idle")
        }
        XCTAssertNotNil(WordSearchArt.wordPicture("SNAKE"))
        XCTAssertNil(WordSearchArt.wordPicture("VINE"), "still emoji")
    }

    func testAMissingAssetIsAFallbackNotAnError() {
        XCTAssertFalse(WordSearchArt.isBundled("WS_CHAR_99_Idle"))
        XCTAssertNil(WordSearchArt.mascot(sheet: 99, state: .celebrate))
        XCTAssertNil(WordSearchArt.wordPicture("NOT_A_WORD"))
    }

    func testEverySheetHasAPaintedSceneFromOneSourceOrTheOther() {
        let forest = WordSearchWordBank.sheets.filter { $0.palette.forestPlace != nil }
        let painted = WordSearchWordBank.sheets.filter { $0.palette.paintedScene != nil }
        // Documented in docs/WordSearch/ArtContract.md; keep the two in step.
        XCTAssertEqual(forest.count, 21, "sheets with a forest place: \(forest.map(\.number))")
        XCTAssertEqual(painted.count, 19, "sheets with a code-painted scene: \(painted.map(\.number))")
        XCTAssertTrue(forest.contains { $0.number == 7 }, "Enchanted Forest stands in the deep woods")
        XCTAssertEqual(WordSearchWordBank.sheets[2].palette.paintedScene, .ocean, "Ocean Friends is painted as an ocean")
        for sheet in WordSearchWordBank.sheets {
            XCTAssertTrue((sheet.palette.forestPlace != nil) != (sheet.palette.paintedScene != nil),
                          "sheet \(sheet.number) must have exactly one scene source")
        }
        XCTAssertEqual(Set(painted.compactMap(\.palette.paintedScene)).count, WordSearchSceneFamily.allCases.count,
                       "every painted family is used by some sheet")
    }
}

/// The play screen's logic, driven the way a finger drives it: begin,
/// move, end. Seeds are pinned so every run sees the same grid.
@MainActor
final class WordSearchPlayViewModelTests: XCTestCase {

    private var container: ModelContainer!
    private var deps: AppDependencies!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: ModelContainerFactory.schema, configurations: [config])
        deps = AppDependencies(modelContainer: container)
    }

    override func tearDown() async throws {
        deps = nil
        container = nil
    }

    private func savedStars(for sheet: Int) throws -> Int {
        try deps.wordSearchRepository.snapshot(for: try deps.childRepository.activeChild()).stars(for: sheet)
    }

    private func makeViewModel(sheet: Int = 1, seed: UInt64 = 11) -> WordSearchPlayViewModel {
        WordSearchPlayViewModel(sheetNumber: sheet, dependencies: deps, seed: seed)
    }

    private func drag(_ viewModel: WordSearchPlayViewModel, _ cells: [WordSearchCell]) {
        viewModel.dragBegan(at: cells[0])
        for cell in cells.dropFirst() { viewModel.dragMoved(to: cell) }
        viewModel.dragEnded()
    }

    func testDraggingAlongAPlacedWordFindsIt() {
        let viewModel = makeViewModel()
        let placement = viewModel.puzzle.placements[0]
        drag(viewModel, [placement.cells.first!, placement.cells.last!])
        XCTAssertEqual(viewModel.foundWords, [placement.word])
        XCTAssertEqual(viewModel.foundCells[placement.word], placement.cells)
        XCTAssertEqual(viewModel.sparkleTrigger, 1)
        XCTAssertTrue(viewModel.selection.isEmpty, "the run clears when the finger lifts")
    }

    func testDraggingBackwardsFindsTheSameWord() {
        let viewModel = makeViewModel()
        let placement = viewModel.puzzle.placements[0]
        drag(viewModel, [placement.cells.last!, placement.cells.first!])
        XCTAssertEqual(viewModel.foundWords, [placement.word])
    }

    func testDragSnapsToTheNearestLineSoAWobbleStillReadsTheWord() {
        let viewModel = makeViewModel()
        guard let placement = viewModel.puzzle.placements.first(where: { $0.direction == .right && $0.word.count >= 3 })
        else { return XCTFail("seed 11 sheet 1 has a rightward word") }
        let end = placement.cells.last!
        // The finger drifts one row off the line at the far end.
        let wobble = WordSearchCell(row: end.row + (end.row + 1 < viewModel.puzzle.size ? 1 : -1), column: end.column)
        viewModel.dragBegan(at: placement.cells[0])
        viewModel.dragMoved(to: wobble)
        XCTAssertEqual(viewModel.selection, placement.cells, "a shallow drift snaps to the row")
        viewModel.dragEnded()
        XCTAssertEqual(viewModel.foundWords, [placement.word])
    }

    func testARunThatIsNotAWordFindsNothingAndNudges() {
        let viewModel = makeViewModel()
        // The first row is a run of letters; only a target counts. Pick a
        // two-cell run that no target could be — every target is 3+ letters.
        drag(viewModel, [WordSearchCell(row: 0, column: 0), WordSearchCell(row: 0, column: 1)])
        XCTAssertTrue(viewModel.foundWords.isEmpty)
        XCTAssertTrue(viewModel.wrongFlash)
        XCTAssertEqual(viewModel.phase, .playing)
    }

    func testFindingAWordTwiceCountsOnce() {
        let viewModel = makeViewModel()
        let placement = viewModel.puzzle.placements[0]
        drag(viewModel, [placement.cells.first!, placement.cells.last!])
        drag(viewModel, [placement.cells.first!, placement.cells.last!])
        XCTAssertEqual(viewModel.foundWords.count, 1)
        XCTAssertEqual(viewModel.sparkleTrigger, 1)
    }

    func testFindingEveryWordFinishesWithThreeStarsAndRecordsProgress() throws {
        let viewModel = makeViewModel(sheet: 3)
        for placement in viewModel.puzzle.placements {
            drag(viewModel, [placement.cells.first!, placement.cells.last!])
        }
        XCTAssertEqual(viewModel.phase, .celebrating)
        XCTAssertEqual(viewModel.starsEarned, 3)
        XCTAssertEqual(try savedStars(for: 3), 3)
        let hub = WordSearchHubViewModel(dependencies: deps)
        hub.refresh()
        XCTAssertTrue(hub.isUnlocked(WordSearchWordBank.sheets[3]), "the map sees the new star")
    }

    func testEachHintCostsAStarDownToOne() {
        let viewModel = makeViewModel(sheet: 2)
        for _ in 0..<5 { viewModel.hintTapped() }
        XCTAssertEqual(viewModel.hintsUsed, 5)
        for placement in viewModel.puzzle.placements {
            drag(viewModel, [placement.cells.first!, placement.cells.last!])
        }
        XCTAssertEqual(viewModel.starsEarned, 1, "never zero")
    }

    func testHintLightsTheFirstLetterOfAnUnfoundWordAndOutlivesOtherDrags() {
        let viewModel = makeViewModel()
        let first = viewModel.puzzle.placements[0]
        drag(viewModel, [first.cells.first!, first.cells.last!])

        viewModel.hintTapped()
        guard let hintWord = viewModel.hintWord else { return XCTFail("a hint names its word") }
        XCTAssertNotEqual(hintWord, first.word, "hints point at unfound words")
        let hinted = viewModel.puzzle.placements.first { $0.word == hintWord }!
        XCTAssertEqual(viewModel.hintCell, hinted.cells.first)

        // A wrong drag leaves the hint alone.
        drag(viewModel, [WordSearchCell(row: 0, column: 0), WordSearchCell(row: 0, column: 1)])
        XCTAssertEqual(viewModel.hintCell, hinted.cells.first)

        // Finding the hinted word clears it.
        drag(viewModel, [hinted.cells.first!, hinted.cells.last!])
        XCTAssertNil(viewModel.hintCell)
        XCTAssertNil(viewModel.hintWord)
    }

    func testDragsAreIgnoredOnceCelebrating() {
        let viewModel = makeViewModel(sheet: 4)
        for placement in viewModel.puzzle.placements {
            drag(viewModel, [placement.cells.first!, placement.cells.last!])
        }
        XCTAssertEqual(viewModel.phase, .celebrating)
        let before = viewModel.sparkleTrigger
        viewModel.dragBegan(at: WordSearchCell(row: 0, column: 0))
        XCTAssertTrue(viewModel.selection.isEmpty)
        XCTAssertEqual(viewModel.sparkleTrigger, before)
    }

    func testPlayAgainDealsAFreshGridAndClearsEverything() throws {
        let viewModel = makeViewModel(sheet: 5)
        let firstSeed = viewModel.puzzle.seed
        viewModel.hintTapped()
        for placement in viewModel.puzzle.placements {
            drag(viewModel, [placement.cells.first!, placement.cells.last!])
        }
        viewModel.playAgainTapped()
        XCTAssertNotEqual(viewModel.puzzle.seed, firstSeed)
        XCTAssertEqual(viewModel.phase, .playing)
        XCTAssertTrue(viewModel.foundWords.isEmpty)
        XCTAssertTrue(viewModel.foundCells.isEmpty)
        XCTAssertNil(viewModel.hintCell)
        XCTAssertEqual(viewModel.hintsUsed, 0)
        XCTAssertEqual(try savedStars(for: 5), 2, "the first run's stars are kept")
    }

    func testTheMascotFollowsPlay() {
        let viewModel = makeViewModel(sheet: 2)
        XCTAssertEqual(viewModel.mascotState, .idle)

        viewModel.hintTapped()
        XCTAssertEqual(viewModel.mascotState, .hint, "leans toward the lit letter")

        let placement = viewModel.puzzle.placements.first { $0.word != viewModel.hintWord }!
        drag(viewModel, [placement.cells.first!, placement.cells.last!])
        XCTAssertEqual(viewModel.mascotState, .wordFound, "the hop outranks the still-lit hint")

        drag(viewModel, [WordSearchCell(row: 0, column: 0), WordSearchCell(row: 0, column: 1)])
        XCTAssertEqual(viewModel.mascotState, .encourage, "the nudge outranks the hop while it flashes")

        for other in viewModel.puzzle.placements where other.word != placement.word {
            drag(viewModel, [other.cells.first!, other.cells.last!])
        }
        XCTAssertEqual(viewModel.mascotState, .celebrate, "and celebrating outranks everything")
    }

    private final class SpeechSpy: SpeechServiceProtocol {
        var isEnabled = true
        var hasNaturalVoice = true
        var hasHindiVoice = true
        var spoken: [String] = []
        func speak(_ text: String) async { spoken.append(text) }
        func speak(_ text: String, language: String) async { spoken.append(text) }
        func stop() {}
        func refreshVoice() {}
    }

    func testAFoundWordIsReadOutThenCheered() async throws {
        let spy = SpeechSpy()
        let viewModel = WordSearchPlayViewModel(sheetNumber: 1, dependencies: deps, seed: 11, speech: spy)
        let placement = viewModel.puzzle.placements[0]
        drag(viewModel, [placement.cells.first!, placement.cells.last!])
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(spy.spoken.first, placement.word.lowercased(), "the word comes first")
        XCTAssertEqual(spy.spoken.count, 2, "then a cheer")
        XCTAssertTrue(WordSearchPlayViewModel.cheers.contains(spy.spoken[1]), "\(spy.spoken[1]) is not a cheer")

        // A wrong drag says nothing; a repeat find says nothing again.
        drag(viewModel, [WordSearchCell(row: 0, column: 0), WordSearchCell(row: 0, column: 1)])
        drag(viewModel, [placement.cells.first!, placement.cells.last!])
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(spy.spoken.count, 2)

        // The next word gets a different cheer.
        let second = viewModel.puzzle.placements[1]
        drag(viewModel, [second.cells.first!, second.cells.last!])
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(spy.spoken.count, 4)
        XCTAssertNotEqual(spy.spoken[1], spy.spoken[3])
    }

    func testACrossingCellKeepsTheColourOfTheWordFoundFirst() {
        // Sweep seeds for a grid with an intersection so the case is real.
        for seed in UInt64(1)...40 {
            let viewModel = makeViewModel(sheet: 25, seed: seed)
            let placements = viewModel.puzzle.placements
            guard let (a, b) = placements.enumerated().lazy.compactMap({ i, a -> (WordSearchPlacement, WordSearchPlacement)? in
                placements.dropFirst(i + 1).first { !Set($0.cells).isDisjoint(with: a.cells) }.map { (a, $0) }
            }).first else { continue }
            let shared = Set(a.cells).intersection(b.cells).first!
            drag(viewModel, [b.cells.first!, b.cells.last!])
            drag(viewModel, [a.cells.first!, a.cells.last!])
            XCTAssertEqual(viewModel.foundWord(at: shared), b.word)
            return
        }
        XCTFail("sheet 25 never intersected in 40 seeds — pick another sheet")
    }
}
