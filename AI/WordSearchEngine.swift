//
//  WordSearchEngine.swift
//  Focus Forest Adventure
//
//  Lays a sheet's words into a letter grid under its stage's rules, then
//  fills the gaps. Seeded and pure: the same (sheet, seed) always makes the
//  same grid, so nothing is stored and a replay can be a fresh seed.
//
//  Two things the generator refuses to ship, and re-rolls instead:
//  - a target word appearing twice (once placed, once by accident in the
//    filler) — the child would find the wrong one and be told "no";
//  - filler that spells a word from the small blocklist below.
//

import Foundation

/// One placed word: where it starts and which way it runs.
struct WordSearchPlacement: Hashable, Sendable {
    let word: String
    let row: Int
    let column: Int
    let direction: WordSearchDirection

    /// Every cell the word occupies, first letter first.
    var cells: [WordSearchCell] {
        (0..<word.count).map { step in
            WordSearchCell(row: row + direction.delta.row * step,
                           column: column + direction.delta.column * step)
        }
    }
}

struct WordSearchCell: Hashable, Sendable {
    let row: Int
    let column: Int
}

/// A finished, playable grid.
struct WordSearchPuzzle: Hashable, Sendable {
    let sheet: WordSearchSheet
    let size: Int
    /// Row-major, `size * size` uppercase letters.
    let letters: [Character]
    let placements: [WordSearchPlacement]
    let seed: UInt64

    func letter(at cell: WordSearchCell) -> Character? {
        guard cell.row >= 0, cell.row < size, cell.column >= 0, cell.column < size else { return nil }
        return letters[cell.row * size + cell.column]
    }

    /// The word a straight run of cells spells, if it is one of the sheet's
    /// words — read forwards or backwards, because a child drags from
    /// whichever end they saw first.
    func word(spelledBy cells: [WordSearchCell]) -> String? {
        let forward = String(cells.compactMap(letter(at:)))
        guard forward.count == cells.count else { return nil }
        let backward = String(forward.reversed())
        let targets = Set(sheet.words.map(\.text))
        if targets.contains(forward) { return forward }
        if targets.contains(backward) { return backward }
        return nil
    }

    /// How many letters are shared between two or more words.
    var intersectionCount: Int {
        var seen = Set<WordSearchCell>()
        var shared = 0
        for placement in placements {
            for cell in placement.cells {
                if !seen.insert(cell).inserted { shared += 1 }
            }
        }
        return shared
    }

    var backwardsWordCount: Int {
        placements.filter { $0.direction.isBackwards }.count
    }
}

struct WordSearchEngine: Sendable {

    /// Fillers must not spell these. Small on purpose: it guards against
    /// the handful a parent would object to, not against every word.
    static let blockedFiller: [String] = [
        "ASS", "BUM", "DIE", "DUMB", "FAT", "GUN", "HELL", "KILL", "POO", "SEX", "UGLY",
    ]

    /// Letter frequencies for filler, so the grid looks like English and a
    /// child's eye isn't drawn to a run of Qs.
    private static let fillerAlphabet: [Character] = Array(
        "AAAAAAAABBCCCDDDDEEEEEEEEEEEEFFGGGHHHIIIIIIIJKLLLLMMNNNNNNOOOOOOOPPQRRRRRRSSSSSSTTTTTTUUUVWWXYYZ"
    )

    /// Target letters may fill at most this share of the grid. Above it a
    /// diagonal has nowhere to go — three sheets at 86% never laid one in
    /// sixty seeds — and the page reads as stacked words, not a search.
    static let maximumDensity = 0.7

    /// Build a sheet's puzzle. Always succeeds: on a run of bad luck it
    /// steps the seed and, failing that, the grid size, and the test sweeps
    /// every sheet over many seeds to show that never leaves the stage's
    /// allowed sizes.
    func makePuzzle(sheet: WordSearchSheet, seed: UInt64) -> WordSearchPuzzle {
        let stage = sheet.stage
        let longest = sheet.words.map(\.text.count).max() ?? 3
        let letters = sheet.words.reduce(0) { $0 + $1.text.count }
        let fitting = stage.gridSizes.filter { $0 >= longest }
        precondition(!fitting.isEmpty, "sheet \(sheet.number) has a word longer than its stage allows")
        let roomy = fitting.firstIndex { Double(letters) <= Self.maximumDensity * Double($0 * $0) } ?? fitting.count - 1
        let sizes = Array(fitting[roomy...])

        for size in sizes {
            for retry in 0..<40 {
                var rng = SeededGenerator(seed: seed &+ UInt64(retry) &* 0x9E37_79B9_7F4A_7C15)
                if let puzzle = attempt(sheet: sheet, size: size, seed: seed, using: &rng) {
                    return puzzle
                }
            }
        }
        // Unreachable in practice — the sweep test proves every sheet
        // places within its first size — but a grid is owed regardless.
        var rng = SeededGenerator(seed: seed)
        return fallback(sheet: sheet, size: sizes.last!, seed: seed, using: &rng)
    }

    /// A fresh seed for a sheet that is not the last one played.
    func nextSeed(for sheetNumber: Int, after previous: UInt64?) -> UInt64 {
        var rng = SystemRandomNumberGenerator()
        var seed = UInt64.random(in: 1...UInt64.max, using: &rng)
        while seed == previous { seed = UInt64.random(in: 1...UInt64.max, using: &rng) }
        return seed ^ UInt64(sheetNumber)
    }

    // MARK: Placement

    private func attempt<R: RandomNumberGenerator>(
        sheet: WordSearchSheet, size: Int, seed: UInt64, using rng: inout R
    ) -> WordSearchPuzzle? {
        let stage = sheet.stage
        var grid = [Character?](repeating: nil, count: size * size)
        var placements: [WordSearchPlacement] = []
        var intersections = 0
        var backwards = 0

        // Longest first: the hardest to fit goes into the emptiest board.
        let words = sheet.words.map(\.text).sorted { $0.count > $1.count }

        // Direction is drawn first, then a slot within it. Drawing over
        // all slots at once starves the diagonals: a six-letter word in a
        // six-wide grid has twelve row-and-column slots and one diagonal,
        // and three sheets never showed a diagonal in sixty seeds.
        for word in words {
            var candidatesByDirection: [[WordSearchPlacement]] = []
            for direction in stage.directions {
                if direction.isBackwards, backwards >= stage.maximumBackwardsWords { continue }
                var candidates: [WordSearchPlacement] = []
                for row in 0..<size {
                    for column in 0..<size {
                        let placement = WordSearchPlacement(word: word, row: row, column: column, direction: direction)
                        guard let overlap = fits(placement, in: grid, size: size) else { continue }
                        if intersections + overlap > stage.maximumIntersections { continue }
                        candidates.append(placement)
                    }
                }
                if !candidates.isEmpty { candidatesByDirection.append(candidates) }
            }
            guard let chosen = candidatesByDirection.randomElement(using: &rng)?.randomElement(using: &rng) else { return nil }
            let overlap = fits(chosen, in: grid, size: size) ?? 0
            for (index, letter) in zip(chosen.cells, chosen.word) {
                grid[index.row * size + index.column] = letter
            }
            placements.append(chosen)
            intersections += overlap
            if chosen.direction.isBackwards { backwards += 1 }
        }

        // Fill, then check nothing accidental appeared. A few re-fills are
        // cheap; giving up returns nil so the caller re-rolls placement.
        let targets = sheet.words.map(\.text)
        for _ in 0..<20 {
            var letters = grid
            for index in letters.indices where letters[index] == nil {
                letters[index] = Self.fillerAlphabet.randomElement(using: &rng)
            }
            let filled = letters.map { $0! }
            if isClean(filled, size: size, targets: targets, expected: placements.count) {
                return WordSearchPuzzle(sheet: sheet, size: size, letters: filled,
                                        placements: placements, seed: seed)
            }
        }
        return nil
    }

    /// Shared-letter count if the word fits, nil if it doesn't.
    private func fits(_ placement: WordSearchPlacement, in grid: [Character?], size: Int) -> Int? {
        var overlap = 0
        for (cell, letter) in zip(placement.cells, placement.word) {
            guard cell.row >= 0, cell.row < size, cell.column >= 0, cell.column < size else { return nil }
            if let existing = grid[cell.row * size + cell.column] {
                guard existing == letter else { return nil }
                overlap += 1
            }
        }
        return overlap
    }

    /// Every target appears exactly once across all eight directions, and
    /// no blocked word appears except inside a target's own letters (the
    /// ASS in GRASS, the HELL in SHELL) — requiring zero there made four
    /// sheets unplaceable and dropped every seed into the rows-only
    /// fallback. The allowance is per word, not per placed grid: letters
    /// from *different* words lining up into DIE down a column is exactly
    /// what a parent would object to, and a placement that does it is
    /// rejected here so the caller re-rolls it.
    private func isClean(_ letters: [Character], size: Int, targets: [String], expected: Int) -> Bool {
        let lines = allLines(letters, size: size)
        var total = 0
        for target in targets {
            let reversed = String(target.reversed())
            let hits = lines.reduce(0) { $0 + occurrences(of: target, in: $1) + occurrences(of: reversed, in: $1) }
            // A palindrome would count twice; none of the bank's words are.
            if hits != 1 { return false }
            total += hits
        }
        guard total == expected else { return false }
        for blocked in Self.blockedFiller {
            let reversed = String(blocked.reversed())
            let inGrid = lines.reduce(0) { $0 + occurrences(of: blocked, in: $1) + occurrences(of: reversed, in: $1) }
            let insideTargets = targets.reduce(0) { $0 + occurrences(of: blocked, in: $1) + occurrences(of: reversed, in: $1) }
            if inGrid != insideTargets { return false }
        }
        return true
    }

    private func occurrences(of needle: String, in line: String) -> Int {
        guard needle.count <= line.count else { return 0 }
        var count = 0
        var search = line.startIndex
        while let range = line.range(of: needle, range: search..<line.endIndex) {
            count += 1
            search = line.index(after: range.lowerBound)
        }
        return count
    }

    /// Rows, columns and both diagonal families as strings.
    private func allLines(_ letters: [Character], size: Int) -> [String] {
        var lines: [String] = []
        for row in 0..<size {
            lines.append(String((0..<size).map { letters[row * size + $0] }))
        }
        for column in 0..<size {
            lines.append(String((0..<size).map { letters[$0 * size + column] }))
        }
        for start in -(size - 1)...(size - 1) {
            var down: [Character] = [], up: [Character] = []
            for row in 0..<size {
                let column = row + start
                if column >= 0, column < size {
                    down.append(letters[row * size + column])
                    up.append(letters[(size - 1 - row) * size + column])
                }
            }
            if down.count > 1 { lines.append(String(down)); lines.append(String(up)) }
        }
        return lines
    }

    /// Rows only, no filler cleverness — reached only if forty seeded
    /// attempts at every allowed size failed, which the sweep says never
    /// happens.
    private func fallback<R: RandomNumberGenerator>(
        sheet: WordSearchSheet, size: Int, seed: UInt64, using rng: inout R
    ) -> WordSearchPuzzle {
        var grid = [Character?](repeating: nil, count: size * size)
        var placements: [WordSearchPlacement] = []
        for (row, word) in sheet.words.map(\.text).prefix(size).enumerated() {
            let placement = WordSearchPlacement(word: word, row: row, column: 0, direction: .right)
            for (cell, letter) in zip(placement.cells, word) {
                grid[cell.row * size + cell.column] = letter
            }
            placements.append(placement)
        }
        let letters = grid.map { $0 ?? Self.fillerAlphabet.randomElement(using: &rng)! }
        return WordSearchPuzzle(sheet: sheet, size: size, letters: letters, placements: placements, seed: seed)
    }
}

// MARK: - Progress

/// Stars per sheet. UserDefaults, like the other mini-games: the campaign
/// is forty numbers, not a profile.
@MainActor
enum WordSearchProgress {
    private static var defaults: UserDefaults { .standard }
    private static func key(_ number: Int) -> String { "wordsearch.stars.\(number)" }

    static func stars(for number: Int) -> Int {
        defaults.integer(forKey: key(number))
    }

    /// Stars only ever go up — a rough replay never takes one away.
    static func record(stars: Int, for number: Int) {
        defaults.set(max(stars, self.stars(for: number)), forKey: key(number))
    }

    /// The first sheet with no stars yet; every earlier one is done.
    static var nextSheetNumber: Int {
        (1...WordSearchWordBank.count).first { stars(for: $0) == 0 } ?? WordSearchWordBank.count
    }

    /// A sheet opens once the one before it is finished. Sheet 1 is always open.
    static func isUnlocked(_ number: Int) -> Bool {
        number <= 1 || stars(for: number - 1) > 0
    }

    static var completedCount: Int {
        (1...WordSearchWordBank.count).filter { stars(for: $0) > 0 }.count
    }

    static var totalStars: Int {
        (1...WordSearchWordBank.count).reduce(0) { $0 + stars(for: $1) }
    }

    static func reset() {
        for number in 1...WordSearchWordBank.count { defaults.removeObject(forKey: key(number)) }
    }
}
