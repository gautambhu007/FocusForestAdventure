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
    /// Walk a safe route from start to goal, collecting the key on the way.
    case maze
    /// Which block is the same one, turned around?
    case blockRotation
    /// Put every piece in its right place to build the picture.
    case assemble
    /// Turn the pipes until the water can flow from end to end.
    case pipeConnect

    var skill: PuzzleSkill {
        switch self {
        case .missingColor, .matchTheShape, .sameOrDifferent: .matchColors
        case .completePattern, .continueSequence, .oddOneOut: .completePattern
        // Assembly is part-to-whole spatial work, which is the same rung as
        // symmetry — and feeds the same parent-facing skills.
        case .mirrorPuzzle, .buildSymmetry, .assemble: .mirrorSymmetry
        case .rotateShape, .blockRotation: .rotation
        case .colorLogic, .missingTile, .shapeCount: .multiRule
        case .numberShape, .patternMatrix, .memoryGrid: .memoryLogic
        case .ravenMatrix, .growingSequence, .hiddenObject: .hiddenPattern
        case .visualSudoku, .ruleDiscovery, .maze: .mixedIQ
        // Turning pipes until a route joins up is rotation *and* planning.
        case .pipeConnect: .rotation
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
        case .hiddenObject: String(localized: "Find them all!")
        case .memoryGrid: String(localized: "What was hiding here?")
        case .maze: String(localized: "Find a safe way through!")
        case .blockRotation: String(localized: "Which one is the same, turned around?")
        case .assemble: String(localized: "Put every piece in its place!")
        case .pipeConnect: String(localized: "Turn the pipes to join them up!")
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
        case .hiddenObject:
            String(localized: "Look row by row, and don't rush.")
        case .memoryGrid:
            String(localized: "Picture the board in your head.")
        case .maze:
            String(localized: "Trace the way with your finger first.")
        case .blockRotation:
            String(localized: "Turn your head — or turn the picture in your mind!")
        case .assemble:
            String(localized: "Tap a piece, then tap where it goes.")
        case .pipeConnect:
            String(localized: "Start at the tap and follow the water along.")
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

/// What a cell *is*. Mazes use start/goal/hazard/key; assembly puzzles use
/// `.slot`. Every other kind uses `.plain`.
enum PuzzleTileRole: String, Codable, Sendable, Hashable {
    case plain, start, goal, hazard, key, slot

    /// Hazards can never be stepped on — the rest can.
    var isWalkable: Bool { self != .hazard }

    var localizedName: String {
        switch self {
        case .plain: String(localized: "path")
        case .start: String(localized: "start")
        case .goal: String(localized: "treasure")
        case .hazard: String(localized: "danger")
        case .key: String(localized: "key")
        case .slot: String(localized: "empty space")
        }
    }
}

/// Which sides of a cell a pipe opens onto.
struct PipeConnections: OptionSet, Hashable, Sendable {
    let rawValue: Int

    static let north = PipeConnections(rawValue: 1 << 0)
    static let east  = PipeConnections(rawValue: 1 << 1)
    static let south = PipeConnections(rawValue: 1 << 2)
    static let west  = PipeConnections(rawValue: 1 << 3)

    static let all: [PipeConnections] = [.north, .east, .south, .west]

    /// A quarter turn clockwise: north becomes east, and so on around.
    func rotated() -> PipeConnections {
        var turned: PipeConnections = []
        if contains(.north) { turned.insert(.east) }
        if contains(.east)  { turned.insert(.south) }
        if contains(.south) { turned.insert(.west) }
        if contains(.west)  { turned.insert(.north) }
        return turned
    }

    /// The side facing back at you from the neighbour on this side.
    var opposite: PipeConnections {
        var flipped: PipeConnections = []
        if contains(.north) { flipped.insert(.south) }
        if contains(.south) { flipped.insert(.north) }
        if contains(.east)  { flipped.insert(.west) }
        if contains(.west)  { flipped.insert(.east) }
        return flipped
    }

    var armCount: Int { PipeConnections.all.filter { contains($0) }.count }

    /// A straight pipe looks identical after a half turn, which matters when
    /// deciding whether a scramble actually changed anything.
    var isStraight: Bool {
        self == [.north, .south] || self == [.east, .west]
    }

    var localizedName: String {
        switch armCount {
        case 0: String(localized: "blank tile")
        case 1: String(localized: "pipe end")
        case 2: isStraight ? String(localized: "straight pipe") : String(localized: "corner pipe")
        case 3: String(localized: "T pipe")
        default: String(localized: "cross pipe")
        }
    }
}

/// A small block of filled and empty cells — the thing a block-rotation
/// puzzle asks the child to turn around in their head.
struct PuzzlePattern: Hashable, Sendable {
    var rows: Int
    var columns: Int
    /// Row-major, `rows * columns` entries.
    var filled: [Bool]
    var color: ForestTheme.GameColor

    func isFilled(row: Int, column: Int) -> Bool {
        guard row >= 0, row < rows, column >= 0, column < columns else { return false }
        return filled[row * columns + column]
    }

    /// A quarter turn clockwise. Note rows and columns swap.
    func rotated() -> PuzzlePattern {
        var turned = [Bool](repeating: false, count: filled.count)
        for row in 0..<rows {
            for column in 0..<columns {
                // (row, column) → (column, rows - 1 - row) in the new grid,
                // whose width is `rows`.
                let newRow = column
                let newColumn = rows - 1 - row
                turned[newRow * rows + newColumn] = isFilled(row: row, column: column)
            }
        }
        return PuzzlePattern(rows: columns, columns: rows, filled: turned, color: color)
    }

    /// All four orientations, starting with this one.
    var rotations: [PuzzlePattern] {
        var result = [self]
        var current = self
        for _ in 0..<3 {
            current = current.rotated()
            result.append(current)
        }
        return result
    }

    /// Flipped left-to-right. A mirror is *not* a rotation, which is exactly
    /// what makes it a good distractor.
    func mirrored() -> PuzzlePattern {
        var flipped = [Bool](repeating: false, count: filled.count)
        for row in 0..<rows {
            for column in 0..<columns {
                flipped[row * columns + (columns - 1 - column)] = isFilled(row: row, column: column)
            }
        }
        return PuzzlePattern(rows: rows, columns: columns, filled: flipped, color: color)
    }

    /// Is `other` this block, just turned? Compares the cells, ignoring color.
    func isRotation(of other: PuzzlePattern) -> Bool {
        other.rotations.contains { $0.rows == rows && $0.columns == columns && $0.filled == filled }
    }

    /// A block with no rotational symmetry — one whose four turns all look
    /// different. Symmetric blocks would give a puzzle several right answers.
    var hasDistinctRotations: Bool {
        let shapes = rotations.map { [$0.rows, $0.columns] + $0.filled.map { $0 ? 1 : 0 } }
        return Set(shapes).count == 4
    }

    var filledCount: Int { filled.filter { $0 }.count }

    var accessibilityLabel: String {
        String(localized: "a block of \(filledCount) squares")
    }
}

struct PuzzleTile: Hashable, Sendable, Identifiable {
    let id: UUID
    var glyph: PuzzleGlyph?
    /// Number/label cells (the "1 🔺 / 2 🔵" ladder).
    var text: String?
    /// The gap the answer fills. At most one tile per puzzle has this.
    var isTarget: Bool
    var role: PuzzleTileRole
    /// Pipe puzzles: which sides this tile currently opens onto.
    var pipe: PipeConnections?

    init(
        id: UUID = UUID(),
        glyph: PuzzleGlyph? = nil,
        text: String? = nil,
        isTarget: Bool = false,
        role: PuzzleTileRole = .plain,
        pipe: PipeConnections? = nil
    ) {
        self.id = id
        self.glyph = glyph
        self.text = text
        self.isTarget = isTarget
        self.role = role
        self.pipe = pipe
    }

    static func blank(isTarget: Bool = false) -> PuzzleTile {
        PuzzleTile(isTarget: isTarget)
    }

    var isEmpty: Bool { glyph == nil && text == nil }

    var accessibilityLabel: String {
        if role != .plain { return role.localizedName }
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
    /// Block-rotation puzzles answer with a little block, not a glyph.
    var pattern: PuzzlePattern?

    init(
        id: UUID = UUID(),
        glyph: PuzzleGlyph? = nil,
        text: String? = nil,
        pattern: PuzzlePattern? = nil
    ) {
        self.id = id
        self.glyph = glyph
        self.text = text
        self.pattern = pattern
    }

    var accessibilityLabel: String {
        glyph?.accessibilityLabel ?? text ?? pattern?.accessibilityLabel ?? ""
    }
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
    /// Tap one of the option chips under the board.
    case options
    /// Tap the one tile on the board that answers the question.
    case tapTile
    /// Tap *every* matching tile — the puzzle ends when they're all found.
    case tapMany
    /// Walk a route: each tap must neighbour the last one.
    case tapPath
    /// Pick a piece, then tap the space it belongs in.
    case assemble
    /// Tap tiles to turn them until something lines up.
    case rotateTiles
}

/// The rules of a pipe puzzle, kept pure so they're tested without a view.
/// Water flows between neighbours only when *both* sides open onto each
/// other — one open end facing a wall is a leak, not a join.
enum PipeRules {

    /// Turn one tile a quarter clockwise.
    static func rotating(_ grid: PuzzleGrid, tileID: UUID) -> PuzzleGrid {
        var updated = grid
        guard let index = updated.tiles.firstIndex(where: { $0.id == tileID }),
              let pipe = updated.tiles[index].pipe
        else { return grid }
        updated.tiles[index].pipe = pipe.rotated()
        return updated
    }

    /// Every cell the water reaches from the source, following joined pipes.
    static func flooded(_ grid: PuzzleGrid) -> Set<UUID> {
        guard let startIndex = grid.tiles.firstIndex(where: { $0.role == .start }) else { return [] }
        var reached: Set<UUID> = [grid.tiles[startIndex].id]
        var frontier = [startIndex]

        while let index = frontier.popLast() {
            guard let pipe = grid.tiles[index].pipe else { continue }
            let row = index / grid.columns
            let column = index % grid.columns

            for side in PipeConnections.all where pipe.contains(side) {
                let (nextRow, nextColumn) = step(from: (row, column), towards: side)
                guard nextRow >= 0, nextRow < grid.rows,
                      nextColumn >= 0, nextColumn < grid.columns
                else { continue }
                let neighbourIndex = nextRow * grid.columns + nextColumn
                let neighbour = grid.tiles[neighbourIndex]
                // The neighbour has to open back towards us.
                guard let neighbourPipe = neighbour.pipe,
                      neighbourPipe.contains(side.opposite),
                      !reached.contains(neighbour.id)
                else { continue }
                reached.insert(neighbour.id)
                frontier.append(neighbourIndex)
            }
        }
        return reached
    }

    /// Has the water made it all the way to the far end?
    static func isConnected(_ grid: PuzzleGrid) -> Bool {
        guard let goal = grid.tiles.first(where: { $0.role == .goal }) else { return false }
        return flooded(grid).contains(goal.id)
    }

    private static func step(
        from cell: (row: Int, column: Int),
        towards side: PipeConnections
    ) -> (Int, Int) {
        switch side {
        case .north: (cell.row - 1, cell.column)
        case .south: (cell.row + 1, cell.column)
        case .east:  (cell.row, cell.column + 1)
        case .west:  (cell.row, cell.column - 1)
        default:     (cell.row, cell.column)
        }
    }
}

/// The rules of a maze, kept out of the view so they can be tested without
/// one. A route is legal when every step neighbours the last, never lands on
/// a hazard, and never doubles back onto itself.
enum MazeRules {

    /// Row/column of a tile in a grid, or nil if it isn't there.
    static func position(of id: UUID, in grid: PuzzleGrid) -> (row: Int, column: Int)? {
        guard let index = grid.tiles.firstIndex(where: { $0.id == id }) else { return nil }
        return (index / grid.columns, index % grid.columns)
    }

    static func areNeighbours(_ first: UUID, _ second: UUID, in grid: PuzzleGrid) -> Bool {
        guard let a = position(of: first, in: grid), let b = position(of: second, in: grid) else {
            return false
        }
        return abs(a.row - b.row) + abs(a.column - b.column) == 1
    }

    /// Can this tile be the next step after `path`?
    static func canStep(to id: UUID, path: [UUID], in grid: PuzzleGrid) -> Bool {
        guard let tile = grid.tiles.first(where: { $0.id == id }), tile.role.isWalkable else {
            return false
        }
        guard !path.contains(id) else { return false }
        guard let last = path.last else { return tile.role == .start }
        return areNeighbours(last, id, in: grid)
    }

    /// A route is finished when it stands on the goal, having picked up the
    /// key first if there is one.
    static func isComplete(path: [UUID], in grid: PuzzleGrid) -> Bool {
        guard let last = path.last,
              grid.tiles.first(where: { $0.id == last })?.role == .goal
        else { return false }
        let keys = grid.tiles.filter { $0.role == .key }.map(\.id)
        return keys.allSatisfy { path.contains($0) }
    }

    /// Is there any legal route left from here? Used to tell a child kindly
    /// that they've boxed themselves in.
    static func hasRouteRemaining(path: [UUID], in grid: PuzzleGrid) -> Bool {
        guard let last = path.last else { return true }
        guard let start = position(of: last, in: grid) else { return false }

        var visited = Set(path)
        var frontier = [start]
        var reachable: Set<UUID> = []
        while let cell = frontier.popLast() {
            for (row, column) in [(cell.0 - 1, cell.1), (cell.0 + 1, cell.1),
                                  (cell.0, cell.1 - 1), (cell.0, cell.1 + 1)] {
                guard let tile = grid.tile(row: row, column: column),
                      tile.role.isWalkable,
                      !visited.contains(tile.id)
                else { continue }
                visited.insert(tile.id)
                reachable.insert(tile.id)
                frontier.append((row, column))
            }
        }
        let needed = grid.tiles.filter { $0.role == .goal || $0.role == .key }
            .map(\.id)
            .filter { !path.contains($0) }
        return needed.allSatisfy { reachable.contains($0) }
    }
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
    /// Every id that counts as correct: one option, one tile, or (in
    /// `.tapMany`) all the tiles that must be found.
    let correctIDs: Set<UUID>
    /// Soft cap — the clock only *adds* the speed star, it never ends a puzzle.
    let timeLimit: TimeInterval
    /// Magic gems for a first-try solve.
    let reward: Int
    var legend: [PuzzleLegendEntry] = []
    /// Memory puzzles show the board for this long, then cover it.
    var peekDuration: TimeInterval?

    init(
        id: UUID,
        world: PuzzleWorld,
        kind: PuzzleKind,
        difficulty: Int,
        title: String,
        grid: PuzzleGrid,
        answerMode: PuzzleAnswerMode,
        options: [PuzzleOption],
        correctIDs: Set<UUID>,
        timeLimit: TimeInterval,
        reward: Int,
        legend: [PuzzleLegendEntry] = [],
        peekDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.world = world
        self.kind = kind
        self.difficulty = difficulty
        self.title = title
        self.grid = grid
        self.answerMode = answerMode
        self.options = options
        self.correctIDs = correctIDs
        self.timeLimit = timeLimit
        self.reward = reward
        self.legend = legend
        self.peekDuration = peekDuration
    }

    /// Convenience for the single-answer kinds, which are most of them.
    init(
        id: UUID,
        world: PuzzleWorld,
        kind: PuzzleKind,
        difficulty: Int,
        title: String,
        grid: PuzzleGrid,
        answerMode: PuzzleAnswerMode,
        options: [PuzzleOption],
        correctID: UUID,
        timeLimit: TimeInterval,
        reward: Int,
        legend: [PuzzleLegendEntry] = [],
        peekDuration: TimeInterval? = nil
    ) {
        self.init(
            id: id, world: world, kind: kind, difficulty: difficulty, title: title,
            grid: grid, answerMode: answerMode, options: options,
            correctIDs: [correctID], timeLimit: timeLimit, reward: reward,
            legend: legend, peekDuration: peekDuration
        )
    }

    /// The single expected answer. Meaningless for `.tapMany`.
    var correctID: UUID { correctIDs.first ?? id }

    /// How many taps solve this puzzle.
    var targetCount: Int { correctIDs.count }

    var prompt: String {
        guard kind == .hiddenObject else { return kind.localizedPrompt }
        return String(localized: "Find all \(correctIDs.count)!")
    }
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

/// Why this run is being played. Only story runs advance the campaign —
/// the daily and weekend challenges pay gems and practise skills without
/// moving the map, so a child can't accidentally skip the story.
enum PuzzleRunMode: String, Codable, Sendable, Hashable {
    case chapter, boss, daily, weekend

    var advancesStory: Bool { self == .chapter || self == .boss }
}

/// One playthrough: a handful of puzzles, then a celebration.
struct PuzzleRun: Hashable, Sendable, Identifiable {
    let id: UUID
    let world: PuzzleWorld
    /// 0 for runs that don't advance the campaign.
    let level: Int
    let difficulty: Int
    let puzzles: [Puzzle]
    let mode: PuzzleRunMode
    /// The chapter being played, for the story card before the first puzzle.
    let chapter: StoryChapter?

    /// Boss runs are longer, harder, and pay a crystal.
    var isBoss: Bool { mode == .boss }

    static func == (lhs: PuzzleRun, rhs: PuzzleRun) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
