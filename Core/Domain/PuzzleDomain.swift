//
//  PuzzleDomain.swift
//  Focus Forest Adventure
//
//  Pure domain value types for Puzzle Quest — the visual-reasoning game
//  (patterns, symmetry, rotation, matrices) for ages 4–8. All Sendable.
//
//  The difficulty ladder is *cognitive*, not "more shapes": each rung asks
//  for a new kind of thinking (match → complete → mirror → rotate → multi-rule
//  → memory+logic → hidden pattern → mixed IQ), and the grid grows with it.
//

import Foundation
import SwiftUI

// MARK: - Worlds

/// Themed progressions. A world is unlocked by age *and* by finishing enough
/// levels of the previous one — never by spending anything.
enum PuzzleWorld: String, CaseIterable, Codable, Sendable, Hashable {
    case forest, jungle, castle, space, lab, dragon

    var localizedTitle: String {
        switch self {
        case .forest: String(localized: "Forest")
        case .jungle: String(localized: "Jungle")
        case .castle: String(localized: "Castle")
        case .space: String(localized: "Space")
        case .lab: String(localized: "Lab")
        case .dragon: String(localized: "Dragon")
        }
    }

    /// What the world trains, in words a parent reads on the dashboard.
    var localizedTheme: String {
        switch self {
        case .forest: String(localized: "Colors")
        case .jungle: String(localized: "Shapes")
        case .castle: String(localized: "Patterns")
        case .space: String(localized: "Logic")
        case .lab: String(localized: "Brain Games")
        case .dragon: String(localized: "Expert")
        }
    }

    var emoji: String {
        switch self {
        case .forest: "🌳"
        case .jungle: "🐼"
        case .castle: "🏰"
        case .space: "🚀"
        case .lab: "🧩"
        case .dragon: "🐉"
        }
    }

    /// Youngest age this world is offered at (Settings → Learning → age).
    var minAge: Int {
        switch self {
        case .forest, .jungle: 4
        case .castle: 5
        case .space: 6
        case .lab: 7
        case .dragon: 8
        }
    }

    var levelCount: Int {
        switch self {
        case .forest, .jungle: 30
        case .castle: 40
        case .space: 50
        case .lab: 60
        case .dragon: 80
        }
    }

    /// Levels of the *previous* world needed before this one opens.
    /// Deliberately well under `levelCount` — a child who is ready by age
    /// shouldn't be gated behind completionism.
    var levelsRequiredInPrevious: Int {
        previous == nil ? 0 : 10
    }

    var previous: PuzzleWorld? {
        let all = PuzzleWorld.allCases
        guard let index = all.firstIndex(of: self), index > 0 else { return nil }
        return all[index - 1]
    }

    var tint: Color {
        switch self {
        case .forest: ForestTheme.Colors.leafGreen
        case .jungle: ForestTheme.Colors.mint
        case .castle: ForestTheme.Colors.lavender
        case .space: ForestTheme.Colors.skyBlue
        case .lab: ForestTheme.Colors.bubblegum
        case .dragon: ForestTheme.Colors.peach
        }
    }

    var place: ForestPlace {
        switch self {
        case .forest: .glade
        case .jungle: .deepWoods
        case .castle: .blossom
        case .space: .night
        case .lab: .magicGrove
        case .dragon: .dusk
        }
    }

    /// Puzzle kinds this world draws from, in roughly increasing order.
    var kinds: [PuzzleKind] {
        PuzzleKind.allCases.filter { $0.worlds.contains(self) }
    }
}

// MARK: - Cognitive ladder

/// The eight rungs. `level` doubles as the difficulty number stored on
/// progress records, so it must stay stable across releases.
enum PuzzleSkill: String, CaseIterable, Codable, Sendable, Hashable {
    case matchColors        // 1 — 2×2
    case completePattern    // 2 — 3×3
    case mirrorSymmetry     // 3 — 4×4
    case rotation           // 4 — 5×5
    case multiRule          // 5 — 6×6
    case memoryLogic        // 6 — 7×7
    case hiddenPattern      // 7 — 8×8
    case mixedIQ            // 8 — 9×9

    var level: Int { (PuzzleSkill.allCases.firstIndex(of: self) ?? 0) + 1 }

    static func forLevel(_ level: Int) -> PuzzleSkill {
        let index = (level - 1).clamped(to: 0...(allCases.count - 1))
        return allCases[index]
    }

    /// Upper bound on the grid this rung may use. Generators stay *at or
    /// below* it — a 3-in-a-row pattern is still 1×5 at level 5.
    var maxGridSide: Int { level + 1 }

    var localizedName: String {
        switch self {
        case .matchColors: String(localized: "Matching colors")
        case .completePattern: String(localized: "Completing patterns")
        case .mirrorSymmetry: String(localized: "Mirror symmetry")
        case .rotation: String(localized: "Rotation")
        case .multiRule: String(localized: "Multi-rule reasoning")
        case .memoryLogic: String(localized: "Memory and logic")
        case .hiddenPattern: String(localized: "Hidden patterns")
        case .mixedIQ: String(localized: "Mixed reasoning")
        }
    }
}

// MARK: - Puzzle kinds

/// One generator recipe. Every kind renders through the same
/// grid + options screen, so adding a kind never needs a new view.
enum PuzzleKind: String, CaseIterable, Codable, Sendable, Hashable {
    // Level 1–2 · ages 4–5
    case completePattern      // 🔺🔵🔺🔵❓🔵
    case missingColor         // fill the blank in a color strip
    case matchTheShape        // which option matches the shown shape
    case continueSequence     // 🐶🐱🐶🐱❓
    case sameOrDifferent      // two groups → Same / Different
    // Level 2–3 · ages 5–6
    case oddOneOut            // three alike, one different
    case mirrorPuzzle         // row flips the row above
    case shapeCount           // how many triangles in the grid
    // Level 3–4 · ages 6–7
    case missingTile          // 3×3 matrix, one tile missing
    case rotateShape          // ▶ ▼ ◀ ❓
    case buildSymmetry        // complete the symmetric block
    case colorLogic           // legend maps shape → color, apply it
    // Level 4–5 · ages 7–8
    case patternMatrix        // alternating matrix, missing cell
    case numberShape          // number ↔ shape correspondence
    // Level 5+ · ages 8+
    case ravenMatrix          // checkerboard-style matrix completion
    case growingSequence      // 🔺 / 🔺🔵 / 🔺🔵🟩 / ?
    case visualSudoku         // no repeated color in a row or column
    case ruleDiscovery        // ▲○ = ★, ○▲ = ? — infer the mapping

    var skill: PuzzleSkill {
        switch self {
        case .missingColor, .matchTheShape, .sameOrDifferent: .matchColors
        case .completePattern, .continueSequence, .oddOneOut: .completePattern
        case .mirrorPuzzle, .buildSymmetry: .mirrorSymmetry
        case .rotateShape: .rotation
        case .colorLogic, .missingTile, .shapeCount: .multiRule
        case .numberShape, .patternMatrix: .memoryLogic
        case .ravenMatrix, .growingSequence: .hiddenPattern
        case .visualSudoku, .ruleDiscovery: .mixedIQ
        }
    }

    var minAge: Int {
        switch self {
        case .completePattern, .missingColor, .matchTheShape,
             .continueSequence, .sameOrDifferent: 4
        case .oddOneOut, .mirrorPuzzle, .shapeCount: 5
        case .missingTile, .rotateShape, .buildSymmetry, .colorLogic: 6
        case .patternMatrix, .numberShape: 7
        case .ravenMatrix, .growingSequence, .visualSudoku, .ruleDiscovery: 8
        }
    }

    var worlds: [PuzzleWorld] {
        switch self {
        case .missingColor, .matchTheShape, .sameOrDifferent: [.forest, .jungle]
        case .completePattern, .continueSequence: [.forest, .jungle, .castle]
        case .oddOneOut: [.jungle, .castle]
        case .mirrorPuzzle, .buildSymmetry: [.castle, .space]
        case .shapeCount: [.castle, .space]
        case .missingTile, .colorLogic: [.space, .lab]
        case .rotateShape: [.space, .lab]
        case .patternMatrix, .numberShape: [.lab, .dragon]
        case .ravenMatrix, .growingSequence, .visualSudoku, .ruleDiscovery: [.dragon]
        }
    }

    /// Shown above the board and spoken by Bunny.
    var localizedPrompt: String {
        switch self {
        case .completePattern: String(localized: "What comes in the empty space?")
        case .missingColor: String(localized: "Which color is missing?")
        case .matchTheShape: String(localized: "Find the shape that matches!")
        case .continueSequence: String(localized: "What comes next?")
        case .sameOrDifferent: String(localized: "Are they the same or different?")
        case .oddOneOut: String(localized: "Which one is different?")
        case .mirrorPuzzle: String(localized: "Finish the mirror!")
        case .shapeCount: String(localized: "How many are there?")
        case .missingTile: String(localized: "Which tile is missing?")
        case .rotateShape: String(localized: "Which way does it turn next?")
        case .buildSymmetry: String(localized: "Make both sides match!")
        case .colorLogic: String(localized: "Follow the color rule!")
        case .patternMatrix: String(localized: "Fill in the missing one!")
        case .numberShape: String(localized: "What comes next?")
        case .ravenMatrix: String(localized: "Which tile finishes the pattern?")
        case .growingSequence: String(localized: "What comes next in the row?")
        case .visualSudoku: String(localized: "No color twice in a row or column!")
        case .ruleDiscovery: String(localized: "Figure out the secret rule!")
        }
    }

    /// One free nudge. Never gives the answer away outright.
    var localizedHint: String {
        switch self {
        case .completePattern, .continueSequence:
            String(localized: "Say the row out loud — it repeats!")
        case .missingColor:
            String(localized: "Look at the colors above and below.")
        case .matchTheShape:
            String(localized: "Look at the corners of the shape.")
        case .sameOrDifferent:
            String(localized: "Look at them one at a time.")
        case .oddOneOut:
            String(localized: "Three are friends. One is not!")
        case .mirrorPuzzle, .buildSymmetry:
            String(localized: "Imagine a mirror down the middle.")
        case .shapeCount:
            String(localized: "Point and count with your finger.")
        case .missingTile, .patternMatrix, .ravenMatrix:
            String(localized: "Read across the rows, then down the columns.")
        case .rotateShape:
            String(localized: "It keeps turning the same way each time.")
        case .colorLogic:
            String(localized: "Check the rule at the top.")
        case .numberShape:
            String(localized: "Match each number to its shape.")
        case .growingSequence:
            String(localized: "Each row adds one more!")
        case .visualSudoku:
            String(localized: "A color can only appear once in each line.")
        case .ruleDiscovery:
            String(localized: "What happens when they swap places?")
        }
    }
}

// MARK: - Glyphs

/// The drawable vocabulary. Symbol + color are independent so a puzzle can
/// vary one while holding the other fixed — that separation is what makes
/// "odd one out" and "color logic" learnable rather than guessable.
enum PuzzleSymbol: String, CaseIterable, Codable, Sendable, Hashable {
    case triangle, circle, square, star, diamond, heart, hexagon, arrow, moon, leaf

    var systemImage: String {
        switch self {
        case .triangle: "triangle.fill"
        case .circle: "circle.fill"
        case .square: "square.fill"
        case .star: "star.fill"
        case .diamond: "diamond.fill"
        case .heart: "heart.fill"
        case .hexagon: "hexagon.fill"
        case .arrow: "arrowtriangle.up.fill"
        case .moon: "moon.fill"
        case .leaf: "leaf.fill"
        }
    }

    var localizedName: String {
        switch self {
        case .triangle: String(localized: "triangle")
        case .circle: String(localized: "circle")
        case .square: String(localized: "square")
        case .star: String(localized: "star")
        case .diamond: String(localized: "diamond")
        case .heart: String(localized: "heart")
        case .hexagon: String(localized: "hexagon")
        case .arrow: String(localized: "arrow")
        case .moon: String(localized: "moon")
        case .leaf: String(localized: "leaf")
        }
    }

    /// Shapes simple enough for a four-year-old to name.
    static let starter: [PuzzleSymbol] = [.triangle, .circle, .square, .star]
}

/// A single drawn thing: shape, color, and (for rotation puzzles) heading.
struct PuzzleGlyph: Hashable, Sendable {
    var symbol: PuzzleSymbol
    var color: ForestTheme.GameColor
    /// Clockwise degrees. Only rotation puzzles use anything but 0.
    var rotation: Double = 0

    var accessibilityLabel: String {
        let base = "\(color.localizedName) \(symbol.localizedName)"
        guard rotation != 0 else { return base }
        return "\(base), \(Int(rotation)) degrees"
    }
}

// MARK: - Board

/// One cell. `glyph == nil` is the gap the child fills; every other cell is
/// a given. A grid may hold more than one gap (`missingTiles`), but only the
/// first is answered — the rest stay blank as visual noise for older rungs.
struct PuzzleTile: Hashable, Sendable, Identifiable {
    let id: UUID
    var glyph: PuzzleGlyph?
    /// Number/label cells (the "1 🔺 / 2 🔵" ladder). Mutually exclusive
    /// with `glyph`.
    var text: String?
    /// The gap the answer fills. Exactly one tile per puzzle has this.
    var isTarget: Bool

    init(id: UUID = UUID(), glyph: PuzzleGlyph? = nil, text: String? = nil, isTarget: Bool = false) {
        self.id = id
        self.glyph = glyph
        self.text = text
        self.isTarget = isTarget
    }

    static func blank(isTarget: Bool = false) -> PuzzleTile {
        PuzzleTile(isTarget: isTarget)
    }

    var isEmpty: Bool { glyph == nil && text == nil }

    var accessibilityLabel: String {
        if let glyph { return glyph.accessibilityLabel }
        if let text { return text }
        return isTarget ? String(localized: "empty space to fill") : String(localized: "empty")
    }
}

struct PuzzleGrid: Hashable, Sendable {
    var rows: Int
    var columns: Int
    /// Row-major, `rows * columns` entries.
    var tiles: [PuzzleTile]

    func tile(row: Int, column: Int) -> PuzzleTile? {
        guard row >= 0, row < rows, column >= 0, column < columns else { return nil }
        return tiles[row * columns + column]
    }

    var targetIndex: Int? { tiles.firstIndex(where: \.isTarget) }
}

/// A tappable answer. Either a glyph (most puzzles) or a word/number
/// (counting, same-or-different) — never both.
struct PuzzleOption: Hashable, Sendable, Identifiable {
    let id: UUID
    var glyph: PuzzleGlyph?
    var text: String?

    init(id: UUID = UUID(), glyph: PuzzleGlyph? = nil, text: String? = nil) {
        self.id = id
        self.glyph = glyph
        self.text = text
    }

    var accessibilityLabel: String {
        glyph?.accessibilityLabel ?? text ?? ""
    }
}

/// A worked example shown above the board: "🔺 ⭕ = ⭐".
/// Colour-logic uses one input; rule-discovery uses two.
struct PuzzleLegendEntry: Hashable, Sendable, Identifiable {
    let id: UUID
    var inputs: [PuzzleGlyph]
    var result: PuzzleGlyph

    init(id: UUID = UUID(), inputs: [PuzzleGlyph], result: PuzzleGlyph) {
        self.id = id
        self.inputs = inputs
        self.result = result
    }

    var accessibilityLabel: String {
        let left = inputs.map(\.accessibilityLabel).joined(separator: ", ")
        return String(localized: "\(left) makes \(result.accessibilityLabel)")
    }
}

// MARK: - Puzzle

/// Where the child taps to answer.
enum PuzzleAnswerMode: String, Codable, Sendable, Hashable {
    /// Tap one of the option chips under the board (most kinds).
    case options
    /// Tap a tile *on* the board — "which one is different?".
    case tapTile
}

struct Puzzle: Hashable, Sendable, Identifiable {
    let id: UUID
    let world: PuzzleWorld
    let kind: PuzzleKind
    /// Ladder rung 1…8 (see `PuzzleSkill`).
    let difficulty: Int
    let grid: PuzzleGrid
    let answerMode: PuzzleAnswerMode
    /// Empty in `.tapTile` mode.
    let options: [PuzzleOption]
    /// Option id, or tile id in `.tapTile` mode — correctness is one
    /// comparison either way.
    let correctID: UUID
    /// Soft cap — the timer never ends the puzzle, it only stops awarding the
    /// speed star (children must never lose progress to a clock).
    let timeLimit: TimeInterval
    /// Coins for a first-try solve.
    let reward: Int
    var legend: [PuzzleLegendEntry] = []

    var prompt: String { kind.localizedPrompt }
    var hint: String { kind.localizedHint }
    var skill: PuzzleSkill { kind.skill }

    static func == (lhs: Puzzle, rhs: Puzzle) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Spec (the JSON contract)

/// Declarative description of a puzzle to generate. Kept `Codable` so packs
/// of hand-tuned puzzles can ship as JSON alongside the generator without a
/// second code path — the generator is the only thing that builds a `Puzzle`.
struct PuzzleSpec: Codable, Hashable, Sendable {
    /// "3x3" — an upper bound; a generator may use a smaller board.
    var gridSize: String
    /// `PuzzleWorld` raw value.
    var theme: String
    /// Ladder rung 1…8.
    var difficulty: Int
    /// `PuzzleKind` raw value.
    var rule: String
    var missingTiles: Int
    var options: Int
    var timeLimit: TimeInterval
    var reward: Int

    init(world: PuzzleWorld, kind: PuzzleKind, difficulty: Int) {
        let rung = difficulty.clamped(to: 1...8)
        let side = PuzzleSkill.forLevel(rung).maxGridSide
        self.gridSize = "\(side)x\(side)"
        self.theme = world.rawValue
        self.difficulty = rung
        self.rule = kind.rawValue
        self.missingTiles = rung >= 5 ? 2 : 1
        self.options = rung <= 2 ? 3 : 4
        self.timeLimit = TimeInterval(30 + rung * 5)
        self.reward = 10 + rung * 5
    }

    var world: PuzzleWorld { PuzzleWorld(rawValue: theme) ?? .forest }
    var kind: PuzzleKind { PuzzleKind(rawValue: rule) ?? .completePattern }

    /// Parsed `gridSize`, falling back to the ladder's bound.
    var maxSide: Int {
        let parts = gridSize.lowercased().split(separator: "x")
        guard let first = parts.first, let value = Int(first) else {
            return PuzzleSkill.forLevel(difficulty).maxGridSide
        }
        return value.clamped(to: 2...9)
    }
}

// MARK: - Results

/// What the child did on one puzzle. Pure input to scoring/progress.
struct PuzzleAttempt: Hashable, Sendable {
    var kind: PuzzleKind
    var skill: PuzzleSkill
    var solved: Bool
    /// Wrong taps before the right one. Never surfaced as "mistakes".
    var missedTaps: Int
    var duration: TimeInterval
    var usedHint: Bool
    var timeLimit: TimeInterval
}

/// One run through a world: a handful of puzzles, then a celebration.
struct PuzzleRun: Hashable, Sendable, Identifiable {
    let id: UUID
    let world: PuzzleWorld
    let level: Int
    let difficulty: Int
    let puzzles: [Puzzle]

    static func == (lhs: PuzzleRun, rhs: PuzzleRun) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
