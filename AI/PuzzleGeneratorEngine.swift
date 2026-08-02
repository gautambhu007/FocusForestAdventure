//
//  PuzzleGeneratorEngine.swift
//  Focus Forest Adventure
//
//  Builds Puzzle Quest boards from a PuzzleSpec. Pure and Sendable: every
//  generator takes an `inout RandomNumberGenerator`, so a seed reproduces a
//  board exactly (daily challenges, snapshot tests, bug reports).
//
//  Two invariants hold for every kind, and are covered by property-style
//  tests: (1) exactly one answer is consistent with the stated rule, and
//  (2) no two answer choices are visually identical.
//

import Foundation

struct PuzzleGeneratorEngine: Sendable {

    // MARK: Palettes

    /// Colors a world draws from. Early worlds stay on the four colors a
    /// four-year-old can already name.
    private func palette(for world: PuzzleWorld) -> [ForestTheme.GameColor] {
        switch world {
        case .forest:  [.red, .blue, .green, .yellow]
        case .jungle:  [.green, .orange, .brown, .yellow]
        case .castle:  [.purple, .pink, .blue, .yellow]
        case .space:   [.blue, .purple, .yellow, .white]
        case .lab:     [.red, .blue, .green, .yellow, .purple, .orange]
        case .dragon:  [.red, .orange, .purple, .green, .blue, .pink]
        }
    }

    private func symbols(for difficulty: Int) -> [PuzzleSymbol] {
        difficulty <= 2 ? PuzzleSymbol.starter : PuzzleSymbol.allCases
    }

    // MARK: Entry points

    /// Generate one puzzle. `seed` makes the board reproducible.
    func generate(spec: PuzzleSpec, seed: UInt64) -> Puzzle {
        var rng = SeededGenerator(seed: seed)
        return generate(spec: spec, using: &rng)
    }

    func generate<R: RandomNumberGenerator>(spec: PuzzleSpec, using rng: inout R) -> Puzzle {
        switch spec.kind {
        case .completePattern:  return completePattern(spec: spec, rng: &rng)
        case .missingColor:     return missingColor(spec: spec, rng: &rng)
        case .matchTheShape:    return matchTheShape(spec: spec, rng: &rng)
        case .continueSequence: return continueSequence(spec: spec, rng: &rng)
        case .sameOrDifferent:  return sameOrDifferent(spec: spec, rng: &rng)
        case .oddOneOut:        return oddOneOut(spec: spec, rng: &rng)
        case .mirrorPuzzle:     return mirrorPuzzle(spec: spec, rng: &rng)
        case .shapeCount:       return shapeCount(spec: spec, rng: &rng)
        case .missingTile:      return missingTile(spec: spec, rng: &rng)
        case .rotateShape:      return rotateShape(spec: spec, rng: &rng)
        case .buildSymmetry:    return buildSymmetry(spec: spec, rng: &rng)
        case .colorLogic:       return colorLogic(spec: spec, rng: &rng)
        case .patternMatrix:    return patternMatrix(spec: spec, rng: &rng)
        case .numberShape:      return numberShape(spec: spec, rng: &rng)
        case .ravenMatrix:      return ravenMatrix(spec: spec, rng: &rng)
        case .growingSequence:  return growingSequence(spec: spec, rng: &rng)
        case .visualSudoku:     return visualSudoku(spec: spec, rng: &rng)
        case .ruleDiscovery:    return ruleDiscovery(spec: spec, rng: &rng)
        }
    }

    /// A level's worth of puzzles: `count` kinds appropriate to the world,
    /// the child's age, and the ladder rung — easiest first.
    func generateRun<R: RandomNumberGenerator>(
        world: PuzzleWorld,
        level: Int,
        difficulty: Int,
        age: Int,
        count: Int = 5,
        using rng: inout R
    ) -> PuzzleRun {
        let rung = difficulty.clamped(to: 1...8)
        let eligible = eligibleKinds(world: world, difficulty: rung, age: age)
        var puzzles: [Puzzle] = []
        var lastKind: PuzzleKind?
        for index in 0..<max(1, count) {
            // Ramp within the run: the first puzzle sits a rung below the
            // last, so every level opens with an easy win.
            let stepped = (rung - 1 + (index * 2) / max(1, count)).clamped(to: 1...8)
            let pool = eligible.count > 1 ? eligible.filter { $0 != lastKind } : eligible
            let kind = pool.randomElement(using: &rng) ?? .completePattern
            lastKind = kind
            let spec = PuzzleSpec(world: world, kind: kind, difficulty: stepped)
            puzzles.append(generate(spec: spec, using: &rng))
        }
        return PuzzleRun(id: UUID(), world: world, level: level, difficulty: rung, puzzles: puzzles)
    }

    /// Kinds the world offers, filtered by age and rung, widening the filter
    /// rather than ever returning nothing.
    func eligibleKinds(world: PuzzleWorld, difficulty: Int, age: Int) -> [PuzzleKind] {
        let worldKinds = world.kinds
        let byAge = worldKinds.filter { $0.minAge <= max(age, 4) }
        let byRung = byAge.filter { $0.skill.level <= difficulty + 1 }
        if !byRung.isEmpty { return byRung }
        if !byAge.isEmpty { return byAge }
        return worldKinds.isEmpty ? [.completePattern] : worldKinds
    }

    // MARK: - Level 1–2 kinds

    /// 🔺 🔵 🔺 🔵 ❓ 🔵 — a repeating unit with a hole punched in it.
    private func completePattern<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let period = spec.difficulty <= 2 ? 2 : (spec.difficulty <= 4 ? 3 : Int.random(in: 2...3, using: &rng))
        let unit = distinctGlyphs(count: period, spec: spec, rng: &rng)
        let length = min(max(period * 2 + 1, 5), spec.maxSide * 2)
        let glyphs = (0..<length).map { unit[$0 % period] }
        // Never blank the first or last cell — the child needs the rule on
        // both sides of the gap.
        let targetIndex = Int.random(in: 1...(length - 2), using: &rng)
        let answer = glyphs[targetIndex]

        var tiles = glyphs.map { PuzzleTile(glyph: $0) }
        tiles[targetIndex] = .blank(isTarget: true)

        return assemble(
            spec: spec,
            grid: PuzzleGrid(rows: 1, columns: length, tiles: tiles),
            answer: answer,
            decoyPool: unit,
            rng: &rng
        )
    }

    /// A vertical color strip with one cell missing.
    private func missingColor<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let colors = palette(for: spec.world).shuffled(using: &rng)
        let period = 2
        let symbol = symbols(for: spec.difficulty).randomElement(using: &rng) ?? .square
        let length = 5
        let unit = (0..<period).map { PuzzleGlyph(symbol: symbol, color: colors[$0 % colors.count]) }
        var tiles = (0..<length).map { PuzzleTile(glyph: unit[$0 % period]) }
        let targetIndex = Int.random(in: 1...(length - 2), using: &rng)
        let answer = unit[targetIndex % period]
        tiles[targetIndex] = .blank(isTarget: true)

        let decoys = colors.dropFirst(period).prefix(3).map { PuzzleGlyph(symbol: symbol, color: $0) }
        return assemble(
            spec: spec,
            grid: PuzzleGrid(rows: length, columns: 1, tiles: tiles),
            answer: answer,
            decoyPool: unit + decoys,
            rng: &rng
        )
    }

    /// Show one shape, find its twin. At rung 2+ every option shares a color
    /// so only the shape can tell them apart.
    private func matchTheShape<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let shapes = symbols(for: spec.difficulty).shuffled(using: &rng)
        let colors = palette(for: spec.world).shuffled(using: &rng)
        let sharedColor = colors[0]
        let answer = PuzzleGlyph(symbol: shapes[0], color: sharedColor)
        let decoys = shapes.dropFirst().prefix(3).map { symbol -> PuzzleGlyph in
            let color = spec.difficulty >= 2 ? sharedColor : (colors.randomElement(using: &rng) ?? sharedColor)
            return PuzzleGlyph(symbol: symbol, color: color)
        }
        let tiles = [PuzzleTile(glyph: answer), PuzzleTile.blank(isTarget: true)]
        return assemble(
            spec: spec,
            grid: PuzzleGrid(rows: 1, columns: 2, tiles: tiles),
            answer: answer,
            decoyPool: Array(decoys),
            rng: &rng
        )
    }

    /// 🐶 🐱 🐶 🐱 ❓ — same machinery as `completePattern`, gap at the end.
    private func continueSequence<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let period = spec.difficulty <= 3 ? 2 : 3
        let unit = distinctGlyphs(count: period, spec: spec, rng: &rng)
        let length = min(period * 2 + 1, spec.maxSide * 2)
        var tiles = (0..<length).map { PuzzleTile(glyph: unit[$0 % period]) }
        let answer = unit[(length - 1) % period]
        tiles[length - 1] = .blank(isTarget: true)
        return assemble(
            spec: spec,
            grid: PuzzleGrid(rows: 1, columns: length, tiles: tiles),
            answer: answer,
            decoyPool: unit,
            rng: &rng
        )
    }

    /// 🍎🍎 vs 🍎🍏 — a yes/no question, the gentlest rung on the ladder.
    private func sameOrDifferent<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let pair = distinctGlyphs(count: 2, spec: spec, rng: &rng)
        let areSame = Bool.random(using: &rng)
        let right = areSame ? pair[0] : pair[1]
        let tiles = [PuzzleTile(glyph: pair[0]), PuzzleTile(glyph: right)]
        let sameOption = PuzzleOption(text: String(localized: "Same"))
        let differentOption = PuzzleOption(text: String(localized: "Different"))
        return Puzzle(
            id: UUID(),
            world: spec.world,
            kind: spec.kind,
            difficulty: spec.difficulty,
            grid: PuzzleGrid(rows: 1, columns: 2, tiles: tiles),
            answerMode: .options,
            options: [sameOption, differentOption],
            correctID: areSame ? sameOption.id : differentOption.id,
            timeLimit: spec.timeLimit,
            reward: spec.reward
        )
    }

    // MARK: - Level 2–3 kinds

    /// Three alike, one not — answered by tapping the board itself.
    private func oddOneOut<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let pair = distinctGlyphs(count: 2, spec: spec, rng: &rng)
        // Rung 3+: the odd one differs only by color, which is a harder
        // discrimination than a different shape.
        let odd = spec.difficulty >= 3
            ? PuzzleGlyph(symbol: pair[0].symbol, color: pair[1].color)
            : pair[1]
        let count = spec.difficulty <= 2 ? 4 : 6
        let oddIndex = Int.random(in: 0..<count, using: &rng)
        var tiles = (0..<count).map { index in
            PuzzleTile(glyph: index == oddIndex ? odd : pair[0])
        }
        tiles[oddIndex].isTarget = true
        let columns = count == 4 ? 4 : 3
        return Puzzle(
            id: UUID(),
            world: spec.world,
            kind: spec.kind,
            difficulty: spec.difficulty,
            grid: PuzzleGrid(rows: count / columns, columns: columns, tiles: tiles),
            answerMode: .tapTile,
            options: [],
            correctID: tiles[oddIndex].id,
            timeLimit: spec.timeLimit,
            reward: spec.reward
        )
    }

    /// ▲ ▼ ▲ / ▼ ▲ ❓ — the second row inverts the first.
    private func mirrorPuzzle<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let pair = distinctGlyphs(count: 2, spec: spec, rng: &rng)
        let columns = min(max(3, spec.maxSide - 1), 5)
        var tiles: [PuzzleTile] = []
        for row in 0..<2 {
            for column in 0..<columns {
                let useFirst = ((row + column) % 2 == 0)
                tiles.append(PuzzleTile(glyph: useFirst ? pair[0] : pair[1]))
            }
        }
        let targetIndex = columns + (columns - 1)          // last cell, row 2
        let answer = tiles[targetIndex].glyph ?? pair[0]
        tiles[targetIndex] = .blank(isTarget: true)
        return assemble(
            spec: spec,
            grid: PuzzleGrid(rows: 2, columns: columns, tiles: tiles),
            answer: answer,
            decoyPool: pair,
            rng: &rng
        )
    }

    /// "How many triangles?" — counting inside visual noise.
    private func shapeCount<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let side = min(max(3, spec.maxSide - 2), 4)
        let pair = distinctGlyphs(count: 2, spec: spec, rng: &rng)
        let cellCount = side * side
        let targetCount = Int.random(in: 2...(cellCount - 2), using: &rng)
        var glyphs = (0..<cellCount).map { $0 < targetCount ? pair[0] : pair[1] }
        glyphs.shuffle(using: &rng)
        let tiles = glyphs.map { PuzzleTile(glyph: $0) }

        var counts = Set([targetCount])
        var candidates = [targetCount - 1, targetCount + 1, targetCount - 2, targetCount + 2, targetCount + 3]
        candidates.removeAll { $0 < 1 || $0 > cellCount }
        for candidate in candidates where counts.count < spec.options {
            counts.insert(candidate)
        }
        let options = counts.sorted().map { PuzzleOption(text: "\($0)") }
        let correct = options.first { $0.text == "\(targetCount)" } ?? options[0]

        return Puzzle(
            id: UUID(),
            world: spec.world,
            kind: spec.kind,
            difficulty: spec.difficulty,
            grid: PuzzleGrid(rows: side, columns: side, tiles: tiles),
            answerMode: .options,
            options: options,
            correctID: correct.id,
            timeLimit: spec.timeLimit,
            reward: spec.reward
        )
    }

    // MARK: - Level 3–4 kinds

    /// 3×3 Latin square of three glyphs — each row is a shift of the one above.
    private func missingTile<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let unit = distinctGlyphs(count: 3, spec: spec, rng: &rng)
        var tiles: [PuzzleTile] = []
        for row in 0..<3 {
            for column in 0..<3 {
                tiles.append(PuzzleTile(glyph: unit[(row + column) % 3]))
            }
        }
        let targetIndex = Int.random(in: 0..<9, using: &rng)
        let answer = tiles[targetIndex].glyph ?? unit[0]
        tiles[targetIndex] = .blank(isTarget: true)
        return assemble(
            spec: spec,
            grid: PuzzleGrid(rows: 3, columns: 3, tiles: tiles),
            answer: answer,
            decoyPool: unit,
            rng: &rng
        )
    }

    /// ▶ ▼ ◀ ❓ — one shape, turning a quarter each step.
    private func rotateShape<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let symbol: PuzzleSymbol = .arrow
        let color = palette(for: spec.world).randomElement(using: &rng) ?? .blue
        let clockwise = Bool.random(using: &rng)
        let step: Double = clockwise ? 90 : -90
        let start = Double(Int.random(in: 0...3, using: &rng)) * 90
        let length = 4
        var tiles: [PuzzleTile] = []
        for index in 0..<length {
            let rotation = normalizedAngle(start + step * Double(index))
            tiles.append(PuzzleTile(glyph: PuzzleGlyph(symbol: symbol, color: color, rotation: rotation)))
        }
        let answer = tiles[length - 1].glyph ?? PuzzleGlyph(symbol: symbol, color: color)
        tiles[length - 1] = .blank(isTarget: true)

        let decoys = (1...3).map { offset in
            PuzzleGlyph(symbol: symbol, color: color, rotation: normalizedAngle(answer.rotation + Double(offset) * 90))
        }
        return assemble(
            spec: spec,
            grid: PuzzleGrid(rows: 1, columns: length, tiles: tiles),
            answer: answer,
            decoyPool: decoys,
            rng: &rng
        )
    }

    /// A board symmetric about its vertical middle, with one half-cell blank.
    private func buildSymmetry<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let columns = 3
        let rows = min(max(2, spec.maxSide - 2), 3)
        let pair = distinctGlyphs(count: 2, spec: spec, rng: &rng)
        var grid: [[PuzzleGlyph]] = []
        for _ in 0..<rows {
            let left = Bool.random(using: &rng) ? pair[0] : pair[1]
            let middle = Bool.random(using: &rng) ? pair[0] : pair[1]
            grid.append([left, middle, left])          // mirrored about column 1
        }
        var tiles = grid.flatMap { $0.map { PuzzleTile(glyph: $0) } }
        // Blank a mirrored (outer) cell so its partner determines the answer.
        let targetRow = Int.random(in: 0..<rows, using: &rng)
        let targetIndex = targetRow * columns + 2
        let answer = grid[targetRow][2]
        tiles[targetIndex] = .blank(isTarget: true)
        return assemble(
            spec: spec,
            grid: PuzzleGrid(rows: rows, columns: columns, tiles: tiles),
            answer: answer,
            decoyPool: pair,
            rng: &rng
        )
    }

    /// Legend: circle = red, square = blue. The row cycles the shapes; the
    /// answer needs the right shape *and* the color the rule assigns it.
    private func colorLogic<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let shapes = symbols(for: spec.difficulty).shuffled(using: &rng)
        let colors = palette(for: spec.world).shuffled(using: &rng)
        let ruleCount = 2
        let ruled = (0..<ruleCount).map { PuzzleGlyph(symbol: shapes[$0], color: colors[$0]) }
        // The legend's left side is the *uncolored* shape (drawn in ink), so
        // the rule reads "this shape becomes this color".
        let legend = ruled.map { glyph in
            PuzzleLegendEntry(inputs: [PuzzleGlyph(symbol: glyph.symbol, color: .black)], result: glyph)
        }

        let length = 4
        var tiles = (0..<length).map { PuzzleTile(glyph: ruled[$0 % ruleCount]) }
        let answer = ruled[(length - 1) % ruleCount]
        tiles[length - 1] = .blank(isTarget: true)

        // Distractors break exactly one half of the rule each.
        let wrongColor = PuzzleGlyph(symbol: answer.symbol, color: colors[(ruleCount) % colors.count])
        let swapped = ruled.first { $0.symbol != answer.symbol }
            ?? PuzzleGlyph(symbol: shapes[1], color: colors[1])
        let wrongShape = PuzzleGlyph(symbol: swapped.symbol, color: answer.color)

        var puzzle = assemble(
            spec: spec,
            grid: PuzzleGrid(rows: 1, columns: length, tiles: tiles),
            answer: answer,
            decoyPool: [wrongColor, wrongShape, swapped],
            rng: &rng
        )
        puzzle.legend = legend
        return puzzle
    }

    // MARK: - Level 4–5 kinds

    /// ▲▼▲ / ▼▲▼ / ▲?▲ — a checkerboard of two glyphs.
    private func patternMatrix<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let pair = distinctGlyphs(count: 2, spec: spec, rng: &rng)
        let side = 3
        var tiles: [PuzzleTile] = []
        for row in 0..<side {
            for column in 0..<side {
                tiles.append(PuzzleTile(glyph: (row + column) % 2 == 0 ? pair[0] : pair[1]))
            }
        }
        let targetIndex = Int.random(in: 0..<(side * side), using: &rng)
        let answer = tiles[targetIndex].glyph ?? pair[0]
        tiles[targetIndex] = .blank(isTarget: true)
        applyExtraBlanks(&tiles, spec: spec, rng: &rng)
        return assemble(
            spec: spec,
            grid: PuzzleGrid(rows: side, columns: side, tiles: tiles),
            answer: answer,
            decoyPool: pair,
            rng: &rng
        )
    }

    /// 1 🔺 / 2 🔵 / 3 🔺 / 4 ❓ — number parity picks the shape.
    private func numberShape<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let pair = distinctGlyphs(count: 2, spec: spec, rng: &rng)
        let rows = 4
        var tiles: [PuzzleTile] = []
        for row in 0..<rows {
            tiles.append(PuzzleTile(text: "\(row + 1)"))
            tiles.append(PuzzleTile(glyph: row % 2 == 0 ? pair[0] : pair[1]))
        }
        let targetIndex = tiles.count - 1
        let answer = tiles[targetIndex].glyph ?? pair[0]
        tiles[targetIndex] = .blank(isTarget: true)
        return assemble(
            spec: spec,
            grid: PuzzleGrid(rows: rows, columns: 2, tiles: tiles),
            answer: answer,
            decoyPool: pair,
            rng: &rng
        )
    }

    // MARK: - Level 5+ kinds

    /// Two independent rules at once: the row picks the shape, the column
    /// picks the color. Distractors satisfy one rule but not both.
    private func ravenMatrix<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let shapes = symbols(for: spec.difficulty).shuffled(using: &rng)
        let colors = palette(for: spec.world).shuffled(using: &rng)
        let side = 3
        func glyph(row: Int, column: Int) -> PuzzleGlyph {
            PuzzleGlyph(symbol: shapes[row % shapes.count], color: colors[column % colors.count])
        }
        var tiles: [PuzzleTile] = []
        for row in 0..<side {
            for column in 0..<side {
                tiles.append(PuzzleTile(glyph: glyph(row: row, column: column)))
            }
        }
        // Blank a cell with both its row and its column still readable.
        let targetRow = Int.random(in: 0..<side, using: &rng)
        let targetColumn = Int.random(in: 0..<side, using: &rng)
        let targetIndex = targetRow * side + targetColumn
        let answer = glyph(row: targetRow, column: targetColumn)
        tiles[targetIndex] = .blank(isTarget: true)

        let otherRow = (targetRow + 1) % side
        let otherColumn = (targetColumn + 1) % side
        let decoys = [
            glyph(row: otherRow, column: targetColumn),     // right color, wrong shape
            glyph(row: targetRow, column: otherColumn),     // right shape, wrong color
            glyph(row: otherRow, column: otherColumn)       // neither
        ]
        return assemble(
            spec: spec,
            grid: PuzzleGrid(rows: side, columns: side, tiles: tiles),
            answer: answer,
            decoyPool: decoys,
            rng: &rng
        )
    }

    /// 🔺 / 🔺🔵 / 🔺🔵🟩 / ? — each row extends the one above by one.
    private func growingSequence<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let rows = 4
        let unit = distinctGlyphs(count: rows, spec: spec, rng: &rng)
        var tiles: [PuzzleTile] = []
        for row in 0..<rows {
            for column in 0..<rows {
                if column <= row {
                    let isTarget = (row == rows - 1 && column == row)
                    tiles.append(isTarget ? .blank(isTarget: true) : PuzzleTile(glyph: unit[column]))
                } else {
                    tiles.append(.blank())
                }
            }
        }
        return assemble(
            spec: spec,
            grid: PuzzleGrid(rows: rows, columns: rows, tiles: tiles),
            answer: unit[rows - 1],
            decoyPool: unit,
            rng: &rng
        )
    }

    /// A 4×4 Latin square of colors — no color twice in any row or column,
    /// so the blank has exactly one legal filling.
    private func visualSudoku<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let side = 4
        let colors = padded(palette(for: spec.world).shuffled(using: &rng),
                            with: ForestTheme.GameColor.allCases, toAtLeast: side)
        let chosen = Array(colors.prefix(side))
        let symbol = symbols(for: spec.difficulty).randomElement(using: &rng) ?? .circle
        var tiles: [PuzzleTile] = []
        for row in 0..<side {
            for column in 0..<side {
                let color = chosen[(row + column) % side]
                tiles.append(PuzzleTile(glyph: PuzzleGlyph(symbol: symbol, color: color)))
            }
        }
        let targetIndex = Int.random(in: 0..<(side * side), using: &rng)
        let answer = tiles[targetIndex].glyph ?? PuzzleGlyph(symbol: symbol, color: chosen[0])
        tiles[targetIndex] = .blank(isTarget: true)

        let decoys = chosen.filter { $0 != answer.color }.map { PuzzleGlyph(symbol: symbol, color: $0) }
        return assemble(
            spec: spec,
            grid: PuzzleGrid(rows: side, columns: side, tiles: tiles),
            answer: answer,
            decoyPool: decoys,
            rng: &rng
        )
    }

    /// Two worked examples define a secret rule — "the answer keeps the
    /// first shape and takes the second color" — then the child applies it.
    private func ruleDiscovery<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let shapes = symbols(for: spec.difficulty).shuffled(using: &rng)
        let colors = palette(for: spec.world).shuffled(using: &rng)

        func pair(_ index: Int) -> (PuzzleGlyph, PuzzleGlyph) {
            let left = PuzzleGlyph(symbol: shapes[index % shapes.count], color: colors[index % colors.count])
            let right = PuzzleGlyph(
                symbol: shapes[(index + 1) % shapes.count],
                color: colors[(index + 1) % colors.count]
            )
            return (left, right)
        }
        func combine(_ left: PuzzleGlyph, _ right: PuzzleGlyph) -> PuzzleGlyph {
            PuzzleGlyph(symbol: left.symbol, color: right.color)
        }

        let examples = (0..<2).map { index -> PuzzleLegendEntry in
            let (left, right) = pair(index)
            return PuzzleLegendEntry(inputs: [left, right], result: combine(left, right))
        }
        let (queryLeft, queryRight) = pair(2)
        let answer = combine(queryLeft, queryRight)
        let tiles = [
            PuzzleTile(glyph: queryLeft),
            PuzzleTile(glyph: queryRight),
            PuzzleTile.blank(isTarget: true)
        ]
        let decoys = [
            combine(queryRight, queryLeft),                                       // rule reversed
            queryLeft,                                                            // copied the left
            queryRight                                                            // copied the right
        ]
        var puzzle = assemble(
            spec: spec,
            grid: PuzzleGrid(rows: 1, columns: 3, tiles: tiles),
            answer: answer,
            decoyPool: decoys,
            rng: &rng
        )
        puzzle.legend = examples
        return puzzle
    }

    // MARK: - Shared helpers

    /// Build the option row: the answer plus distinct decoys, shuffled.
    /// Decoys that duplicate the answer (or each other) are dropped and
    /// backfilled, so no two chips ever look identical.
    private func assemble<R: RandomNumberGenerator>(
        spec: PuzzleSpec,
        grid: PuzzleGrid,
        answer: PuzzleGlyph,
        decoyPool: [PuzzleGlyph],
        rng: inout R
    ) -> Puzzle {
        var chosen: [PuzzleGlyph] = [answer]
        for glyph in decoyPool.shuffled(using: &rng) where chosen.count < spec.options {
            if !chosen.contains(glyph) { chosen.append(glyph) }
        }
        // Backfill from the full vocabulary if the recipe ran short.
        if chosen.count < spec.options {
            for symbol in symbols(for: spec.difficulty).shuffled(using: &rng) {
                for color in palette(for: spec.world).shuffled(using: &rng) where chosen.count < spec.options {
                    let candidate = PuzzleGlyph(symbol: symbol, color: color, rotation: answer.rotation)
                    if !chosen.contains(candidate) { chosen.append(candidate) }
                }
                if chosen.count >= spec.options { break }
            }
        }

        let options = chosen.map { PuzzleOption(glyph: $0) }.shuffled(using: &rng)
        let correctID = options.first { $0.glyph == answer }?.id ?? options[0].id
        return Puzzle(
            id: UUID(),
            world: spec.world,
            kind: spec.kind,
            difficulty: spec.difficulty,
            grid: grid,
            answerMode: .options,
            options: options,
            correctID: correctID,
            timeLimit: spec.timeLimit,
            reward: spec.reward
        )
    }

    /// `count` glyphs that are pairwise distinct in *both* shape and color —
    /// two signals apart, so a color-blind child can still tell them apart.
    private func distinctGlyphs<R: RandomNumberGenerator>(
        count: Int,
        spec: PuzzleSpec,
        rng: inout R
    ) -> [PuzzleGlyph] {
        let shapes = padded(symbols(for: spec.difficulty).shuffled(using: &rng),
                            with: PuzzleSymbol.allCases, toAtLeast: count)
        let colors = padded(palette(for: spec.world).shuffled(using: &rng),
                            with: ForestTheme.GameColor.allCases, toAtLeast: count)
        return (0..<count).map { PuzzleGlyph(symbol: shapes[$0], color: colors[$0]) }
    }

    /// `values`, extended with anything from `fallback` it doesn't already
    /// contain, until it has `toAtLeast` *distinct* entries. Padding must not
    /// introduce duplicates — a repeated color would break the Latin squares.
    private func padded<T: Hashable>(_ values: [T], with fallback: [T], toAtLeast count: Int) -> [T] {
        var seen = Set(values)
        var result = values
        guard result.count < count else { return result }
        for candidate in fallback where !seen.contains(candidate) {
            result.append(candidate)
            seen.insert(candidate)
            if result.count >= count { break }
        }
        return result
    }

    /// Extra decorative blanks for the higher rungs (`spec.missingTiles`).
    /// Only applied to kinds whose rule determines *every* cell, so an extra
    /// hole adds load without adding ambiguity.
    private func applyExtraBlanks<R: RandomNumberGenerator>(
        _ tiles: inout [PuzzleTile],
        spec: PuzzleSpec,
        rng: inout R
    ) {
        let extra = max(0, spec.missingTiles - 1)
        guard extra > 0 else { return }
        let fillable = tiles.indices.filter { !tiles[$0].isTarget && tiles[$0].glyph != nil }
        for index in fillable.shuffled(using: &rng).prefix(extra) {
            tiles[index] = .blank()
        }
    }

    private func normalizedAngle(_ degrees: Double) -> Double {
        let wrapped = degrees.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }
}
