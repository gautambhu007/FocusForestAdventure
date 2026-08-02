//
//  PuzzleDomain.swift
//  Focus Forest Adventure
//
//  Pure domain value types for Puzzle Adventure World — the story campaign
//  where a Young Explorer restores the kingdom of Brainland one puzzle at a
//  time. All Sendable.
//
//  Two axes, deliberately independent:
//  • WORLDS are the story (Forest → Pirate → Space → … → Rainbow). They give
//    a child a *reason* to solve the next puzzle: characters to help, a boss
//    to beat, a crystal to win back.
//  • SKILL RUNGS are the difficulty (match → complete → mirror → rotate →
//    multi-rule → memory+logic → hidden pattern → mixed IQ). The ladder is
//    cognitive, not "more shapes", and it moves with the child, not with
//    the story.
//
//  A world therefore never hard-codes how hard it is; it decides what the
//  puzzles are *about*. See BrainlandStory for the chapter list.
//

import Foundation
import SwiftUI

// MARK: - Worlds

enum PuzzleWorld: String, CaseIterable, Codable, Sendable, Hashable {
    case forest      // 🌳 Forest of Patterns
    case pirate      // 🏴‍☠️ Pirate Island
    case space       // 🚀 Space Academy
    case castle      // 🏰 Magic Castle
    case dinosaur    // 🦕 Dinosaur Valley
    case ocean       // 🌊 Ocean Kingdom
    case ice         // ❄️ Ice Mountain
    case volcano     // 🌋 Volcano Lab
    case rainbow     // 🌈 Rainbow Kingdom (the final trial)

    var localizedTitle: String {
        switch self {
        case .forest: String(localized: "Forest of Patterns")
        case .pirate: String(localized: "Pirate Island")
        case .space: String(localized: "Space Academy")
        case .castle: String(localized: "Magic Castle")
        case .dinosaur: String(localized: "Dinosaur Valley")
        case .ocean: String(localized: "Ocean Kingdom")
        case .ice: String(localized: "Ice Mountain")
        case .volcano: String(localized: "Volcano Lab")
        case .rainbow: String(localized: "Rainbow Kingdom")
        }
    }

    /// Short name for tight spaces (map tiles, dashboards).
    var shortTitle: String {
        switch self {
        case .forest: String(localized: "Forest")
        case .pirate: String(localized: "Pirates")
        case .space: String(localized: "Space")
        case .castle: String(localized: "Castle")
        case .dinosaur: String(localized: "Dinos")
        case .ocean: String(localized: "Ocean")
        case .ice: String(localized: "Ice")
        case .volcano: String(localized: "Volcano")
        case .rainbow: String(localized: "Rainbow")
        }
    }

    var emoji: String {
        switch self {
        case .forest: "🌳"
        case .pirate: "🏴‍☠️"
        case .space: "🚀"
        case .castle: "🏰"
        case .dinosaur: "🦕"
        case .ocean: "🌊"
        case .ice: "❄️"
        case .volcano: "🌋"
        case .rainbow: "🌈"
        }
    }

    /// What this world mostly trains — the line a parent reads.
    var localizedFocus: String {
        switch self {
        case .forest: String(localized: "Colors, shapes, and patterns")
        case .pirate: String(localized: "Direction, planning, and sequences")
        case .space: String(localized: "Spatial reasoning and rotation")
        case .castle: String(localized: "Logic and deduction")
        case .dinosaur: String(localized: "Memory and classification")
        case .ocean: String(localized: "Sorting and visual scanning")
        case .ice: String(localized: "Multi-step reasoning")
        case .volcano: String(localized: "Mixed skills at once")
        case .rainbow: String(localized: "Everything, together")
        }
    }

    var minAge: Int {
        switch self {
        case .forest: 4
        case .pirate: 5
        case .space, .castle: 6
        case .dinosaur, .ocean: 7
        case .ice, .volcano, .rainbow: 8
        }
    }

    /// Story levels, then one boss. Ten chapters is a campaign a child can
    /// actually finish — a 30-level grind would put the crystal out of reach,
    /// and the crystal is the whole point.
    var levelCount: Int { BrainlandStory.story(for: self).chapters.count + 1 }

    /// The final level of a world is its boss.
    var bossLevel: Int { levelCount }

    func isBossLevel(_ level: Int) -> Bool { level >= bossLevel }

    /// Worlds must be *earned*: the crystal from the previous world opens
    /// the next. Age only decides where a child may start, never how the
    /// story unfolds.
    var previous: PuzzleWorld? {
        let all = PuzzleWorld.allCases
        guard let index = all.firstIndex(of: self), index > 0 else { return nil }
        return all[index - 1]
    }

    /// The Rainbow Kingdom needs every crystal, not just the last one.
    var requiresAllCrystals: Bool { self == .rainbow }

    var tint: Color {
        switch self {
        case .forest: ForestTheme.Colors.leafGreen
        case .pirate: ForestTheme.Colors.sunshine
        case .space: ForestTheme.Colors.skyBlue
        case .castle: ForestTheme.Colors.lavender
        case .dinosaur: ForestTheme.Colors.peach
        case .ocean: ForestTheme.Colors.mint
        case .ice: ForestTheme.Colors.skyBlue
        case .volcano: ForestTheme.Colors.bubblegum
        case .rainbow: ForestTheme.Colors.sunshine
        }
    }

    var place: ForestPlace {
        switch self {
        case .forest: .glade
        case .pirate: .riverbank
        case .space: .night
        case .castle: .blossom
        case .dinosaur: .deepWoods
        case .ocean: .riverbank
        case .ice: .dusk
        case .volcano: .dusk
        case .rainbow: .magicGrove
        }
    }

    var story: WorldStory { BrainlandStory.story(for: self) }
    var crystal: MagicCrystal { story.crystal }
    var kinds: [PuzzleKind] { story.chapters.map(\.kind) }
}

/// The prize for beating a world's boss. Seven crystals power the Rainbow
/// Castle; the eighth (Volcano) is the bonus lab's trophy.
struct MagicCrystal: Hashable, Sendable, Identifiable {
    let world: PuzzleWorld
    let emoji: String
    let localizedName: String

    var id: PuzzleWorld { world }
}

// MARK: - Cognitive ladder

/// The eight difficulty rungs. `level` is persisted, so the order is fixed.
enum PuzzleSkill: String, CaseIterable, Codable, Sendable, Hashable {
    case matchColors        // 1
    case completePattern    // 2
    case mirrorSymmetry     // 3
    case rotation           // 4
    case multiRule          // 5
    case memoryLogic        // 6
    case hiddenPattern      // 7
    case mixedIQ            // 8

    var level: Int { (PuzzleSkill.allCases.firstIndex(of: self) ?? 0) + 1 }

    static func forLevel(_ level: Int) -> PuzzleSkill {
        let index = (level - 1).clamped(to: 0...(allCases.count - 1))
        return allCases[index]
    }

    /// Upper bound on the grid this rung may use — generators stay at or
    /// below it.
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

    /// Which parent-facing cognitive skills this rung feeds. The dashboard
    /// reports in these terms, not in engine terms.
    var cognitiveSkills: [CognitiveSkill] {
        switch self {
        case .matchColors: [.patternRecognition, .concentration]
        case .completePattern: [.patternRecognition, .logicalThinking]
        case .mirrorSymmetry: [.spatialReasoning, .visualMemory]
        case .rotation: [.spatialReasoning, .problemSolving]
        case .multiRule: [.logicalThinking, .problemSolving]
        case .memoryLogic: [.visualMemory, .logicalThinking]
        case .hiddenPattern: [.patternRecognition, .concentration]
        case .mixedIQ: [.problemSolving, .logicalThinking]
        }
    }
}

/// The seven skills the parent dashboard reports on.
enum CognitiveSkill: String, CaseIterable, Codable, Sendable, Hashable {
    case patternRecognition, visualMemory, spatialReasoning
    case logicalThinking, concentration, problemSolving, processingSpeed

    var localizedName: String {
        switch self {
        case .patternRecognition: String(localized: "Pattern Recognition")
        case .visualMemory: String(localized: "Visual Memory")
        case .spatialReasoning: String(localized: "Spatial Reasoning")
        case .logicalThinking: String(localized: "Logical Thinking")
        case .concentration: String(localized: "Concentration")
        case .problemSolving: String(localized: "Problem Solving")
        case .processingSpeed: String(localized: "Processing Speed")
        }
    }
}

// MARK: - Puzzle kinds

/// One generator recipe. Chapters give these story names ("Leaf Pattern");
/// the kind itself only describes the *rule*.
enum PuzzleKind: String, CaseIterable, Codable, Sendable, Hashable {
    case completePattern, missingColor, matchTheShape, continueSequence, sameOrDifferent
    case oddOneOut, mirrorPuzzle, shapeCount
    case missingTile, rotateShape, buildSymmetry, colorLogic
    case patternMatrix, numberShape
    case ravenMatrix, growingSequence, visualSudoku, ruleDiscovery
    /// Find every hidden thing on the board — tap them all.
    case hiddenObject
    /// The board is shown, then covered. What was in the marked cell?
    case memoryGrid

    var skill: PuzzleSkill {
        switch self {
        case .missingColor, .matchTheShape, .sameOrDifferent: .matchColors
        case .completePattern, .continueSequence, .oddOneOut: .completePattern
        case .mirrorPuzzle, .buildSymmetry: .mirrorSymmetry
        case .rotateShape: .rotation
        case .colorLogic, .missingTile, .shapeCount: .multiRule
        case .numberShape, .patternMatrix, .memoryGrid: .memoryLogic
        case .ravenMatrix, .growingSequence, .hiddenObject: .hiddenPattern
        case .visualSudoku, .ruleDiscovery: .mixedIQ
        }
    }

    /// Kinds whose *rule is about color* must use tintable shapes — a themed
    /// emoji can't be "the red one".
    var needsTintableShapes: Bool {
        switch self {
        // Rule-discovery recombines one glyph's shape with another's color,
        // so it needs tintable shapes too.
        case .missingColor, .colorLogic, .visualSudoku, .ravenMatrix, .rotateShape, .ruleDiscovery: true
        default: false
        }
    }

    var localizedPrompt: String {
        switch self {
        case .completePattern: String(localized: "What comes in the empty space?")
        case .missingColor: String(localized: "Which color is missing?")
        case .matchTheShape: String(localized: "Find the one that matches!")
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
        case .visualSudoku: String(localized: "No repeats in a row or column!")
        case .ruleDiscovery: String(localized: "Figure out the secret rule!")
        }
    }

    var localizedHint: String {
        switch self {
        case .completePattern, .continueSequence:
            String(localized: "Say the row out loud — it repeats!")
        case .missingColor:
            String(localized: "Look at the colors above and below.")
        case .matchTheShape:
            String(localized: "Look carefully at the edges.")
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
            String(localized: "Match each number to its picture.")
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

/// Tintable geometric shapes — used whenever the *rule* is about color.
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

    static let starter: [PuzzleSymbol] = [.triangle, .circle, .square, .star]
}

/// What a tile actually draws. Story worlds use their own cast of objects
/// (acorns, rockets, fossils); color-rule puzzles fall back to shapes.
enum PuzzleMotif: Hashable, Sendable {
    case shape(PuzzleSymbol)
    /// Themed picture. `name` is the spoken/VoiceOver word.
    case picture(String, name: String)

    var localizedName: String {
        switch self {
        case .shape(let symbol): symbol.localizedName
        case .picture(_, let name): name
        }
    }

    /// Pictures carry their own colors, so tinting them would be a lie —
    /// generators must vary the *picture*, never its color.
    var isTintable: Bool {
        if case .shape = self { return true }
        return false
    }
}

struct PuzzleGlyph: Hashable, Sendable {
    var motif: PuzzleMotif
    var color: ForestTheme.GameColor
    /// Clockwise degrees. Only rotation puzzles use anything but 0.
    var rotation: Double = 0

    init(motif: PuzzleMotif, color: ForestTheme.GameColor = .black, rotation: Double = 0) {
        self.motif = motif
        self.color = color
        self.rotation = rotation
    }

    init(symbol: PuzzleSymbol, color: ForestTheme.GameColor, rotation: Double = 0) {
        self.init(motif: .shape(symbol), color: color, rotation: rotation)
    }

    var accessibilityLabel: String {
        var base = motif.localizedName
        if motif.isTintable { base = "\(color.localizedName) \(base)" }
        guard rotation != 0 else { return base }
        return "\(base), \(Int(rotation)) degrees"
    }
}

// MARK: - Board

struct PuzzleTile: Hashable, Sendable, Identifiable {
    let id: UUID
    var glyph: PuzzleGlyph?
    /// Number/label cells (the "1 🔺 / 2 🔵" ladder).
    var text: String?
    /// The gap the answer fills. At most one tile per puzzle has this.
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

struct PuzzleOption: Hashable, Sendable, Identifiable {
    let id: UUID
    var glyph: PuzzleGlyph?
    var text: String?

    init(id: UUID = UUID(), glyph: PuzzleGlyph? = nil, text: String? = nil) {
        self.id = id
        self.glyph = glyph
        self.text = text
    }

    var accessibilityLabel: String { glyph?.accessibilityLabel ?? text ?? "" }
}

/// A worked example shown above the board: "🔺 ⭕ = ⭐".
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

enum PuzzleAnswerMode: String, Codable, Sendable, Hashable {
    case options
    case tapTile
}

struct Puzzle: Hashable, Sendable, Identifiable {
    let id: UUID
    let world: PuzzleWorld
    let kind: PuzzleKind
    /// Ladder rung 1…8.
    let difficulty: Int
    /// Story name for this puzzle ("Hidden Acorns"), from the chapter.
    let title: String
    let grid: PuzzleGrid
    let answerMode: PuzzleAnswerMode
    let options: [PuzzleOption]
    /// Option id, or tile id in `.tapTile` mode.
    let correctID: UUID
    /// Soft cap — the clock only *adds* the speed star, it never ends a puzzle.
    let timeLimit: TimeInterval
    /// Magic gems for a first-try solve.
    let reward: Int
    var legend: [PuzzleLegendEntry] = []

    var prompt: String { kind.localizedPrompt }
    var hint: String { kind.localizedHint }
    var skill: PuzzleSkill { kind.skill }

    static func == (lhs: Puzzle, rhs: Puzzle) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Spec (the JSON contract)

/// Declarative description of a puzzle to generate. `Codable` so hand-tuned
/// puzzle packs can ship as JSON without a second code path — the generator
/// stays the only thing that builds a `Puzzle`.
struct PuzzleSpec: Codable, Hashable, Sendable {
    var gridSize: String
    var theme: String
    var difficulty: Int
    var rule: String
    var missingTiles: Int
    var options: Int
    var timeLimit: TimeInterval
    var reward: Int
    /// Boss puzzles are worth more and allow a little longer.
    var isBoss: Bool

    init(world: PuzzleWorld, kind: PuzzleKind, difficulty: Int, isBoss: Bool = false) {
        let rung = difficulty.clamped(to: 1...8)
        let side = PuzzleSkill.forLevel(rung).maxGridSide
        self.gridSize = "\(side)x\(side)"
        self.theme = world.rawValue
        self.difficulty = rung
        self.rule = kind.rawValue
        self.missingTiles = rung >= 5 ? 2 : 1
        self.options = rung <= 2 ? 3 : 4
        self.timeLimit = TimeInterval(30 + rung * 5) + (isBoss ? 15 : 0)
        self.reward = (10 + rung * 5) * (isBoss ? 2 : 1)
        self.isBoss = isBoss
    }

    var world: PuzzleWorld { PuzzleWorld(rawValue: theme) ?? .forest }
    var kind: PuzzleKind { PuzzleKind(rawValue: rule) ?? .completePattern }

    var maxSide: Int {
        let parts = gridSize.lowercased().split(separator: "x")
        guard let first = parts.first, let value = Int(first) else {
            return PuzzleSkill.forLevel(difficulty).maxGridSide
        }
        return value.clamped(to: 2...9)
    }
}

// MARK: - Results

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

/// One playthrough of a level: a handful of puzzles, then a celebration.
struct PuzzleRun: Hashable, Sendable, Identifiable {
    let id: UUID
    let world: PuzzleWorld
    let level: Int
    let difficulty: Int
    let puzzles: [Puzzle]
    /// Boss runs are longer, harder, and pay a crystal.
    let isBoss: Bool
    /// The chapter being played, for the story card before the first puzzle.
    let chapter: StoryChapter?

    static func == (lhs: PuzzleRun, rhs: PuzzleRun) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
