//
//  PuzzleGeneratorEngine.swift
//  Focus Forest Adventure
//
//  Builds Puzzle Adventure World boards from a PuzzleSpec. Pure and Sendable:
//  every generator takes an `inout RandomNumberGenerator`, so a seed
//  reproduces a board exactly (daily challenge, snapshot tests, bug reports).
//
//  Two invariants hold for every kind, covered by property-style tests:
//  (1) exactly one answer is consistent with the stated rule, and
//  (2) no two answer choices are visually identical.
//
//  Theming lives in the vocabulary, not in the recipes: a world's puzzles are
//  drawn with its own cast (acorns, rockets, fossils), except where the rule
//  is *about* color — then the board falls back to tintable shapes, because
//  "the red one" has to mean something.
//

import Foundation

struct PuzzleGeneratorEngine: Sendable {

    // MARK: Vocabulary

    /// Colors a world draws from. Early worlds stay on the four a
    /// four-year-old can already name.
    private func palette(for world: PuzzleWorld) -> [ForestTheme.GameColor] {
        switch world {
        case .forest:   [.red, .blue, .green, .yellow]
        case .pirate:   [.red, .blue, .yellow, .brown]
        case .space:    [.blue, .purple, .yellow, .white]
        case .castle:   [.purple, .pink, .blue, .yellow]
        case .dinosaur: [.green, .orange, .brown, .yellow]
        case .ocean:    [.blue, .green, .orange, .pink]
        case .ice:      [.blue, .white, .purple, .green]
        case .volcano:  [.red, .orange, .yellow, .purple, .green, .blue]
        case .rainbow:  [.red, .orange, .yellow, .green, .blue, .purple, .pink]
        }
    }

    private func symbols(for difficulty: Int) -> [PuzzleSymbol] {
        difficulty <= 2 ? PuzzleSymbol.starter : PuzzleSymbol.allCases
    }

    /// True when this puzzle can be drawn with the world's own pictures.
    private func usesPictures(_ spec: PuzzleSpec) -> Bool {
        !spec.kind.needsTintableShapes && !spec.world.story.motifs.isEmpty
    }

    // MARK: Entry points

    /// Generate one puzzle. `seed` makes the board reproducible.
    func generate(spec: PuzzleSpec, title: String? = nil, seed: UInt64) -> Puzzle {
        var rng = SeededGenerator(seed: seed)
        return generate(spec: spec, title: title, using: &rng)
    }

    func generate<R: RandomNumberGenerator>(
        spec: PuzzleSpec,
        title: String? = nil,
        using rng: inout R
    ) -> Puzzle {
        let puzzle: Puzzle
        switch spec.kind {
        case .completePattern:  puzzle = completePattern(spec: spec, rng: &rng)
        case .missingColor:     puzzle = missingColor(spec: spec, rng: &rng)
        case .matchTheShape:    puzzle = matchTheShape(spec: spec, rng: &rng)
        case .continueSequence: puzzle = continueSequence(spec: spec, rng: &rng)
        case .sameOrDifferent:  puzzle = sameOrDifferent(spec: spec, rng: &rng)
        case .oddOneOut:        puzzle = oddOneOut(spec: spec, rng: &rng)
        case .mirrorPuzzle:     puzzle = mirrorPuzzle(spec: spec, rng: &rng)
        case .shapeCount:       puzzle = shapeCount(spec: spec, rng: &rng)
        case .missingTile:      puzzle = missingTile(spec: spec, rng: &rng)
        case .rotateShape:      puzzle = rotateShape(spec: spec, rng: &rng)
        case .buildSymmetry:    puzzle = buildSymmetry(spec: spec, rng: &rng)
        case .colorLogic:       puzzle = colorLogic(spec: spec, rng: &rng)
        case .patternMatrix:    puzzle = patternMatrix(spec: spec, rng: &rng)
        case .numberShape:      puzzle = numberShape(spec: spec, rng: &rng)
        case .ravenMatrix:      puzzle = ravenMatrix(spec: spec, rng: &rng)
        case .growingSequence:  puzzle = growingSequence(spec: spec, rng: &rng)
        case .visualSudoku:     puzzle = visualSudoku(spec: spec, rng: &rng)
        case .ruleDiscovery:    puzzle = ruleDiscovery(spec: spec, rng: &rng)
        }
        guard let title else { return puzzle }
        return puzzle.retitled(title)
    }

    // MARK: Runs

    /// One story level. The chapter decides what the level is *about*; the
    /// rung decides how hard it is. Levels open with a puzzle a rung easier
    /// than the target so every level starts with a win.
    func generateRun<R: RandomNumberGenerator>(
        world: PuzzleWorld,
        level: Int,
        difficulty: Int,
        age: Int,
        count: Int = 5,
        using rng: inout R
    ) -> PuzzleRun {
        let rung = difficulty.clamped(to: 1...8)
        let story = world.story
        let isBoss = world.isBossLevel(level)
        let chapter = story.chapter(forLevel: level)

        // A boss replays the whole world; a chapter leads with its own kind
        // and mixes in neighbours for variety.
        let pool: [PuzzleKind] = isBoss
            ? eligibleKinds(world: world, difficulty: rung, age: age)
            : chapterPool(story: story, level: level, difficulty: rung, age: age)

        let total = max(1, isBoss ? max(count + 3, 8) : count)
        var puzzles: [Puzzle] = []
        var lastKind: PuzzleKind?

        for index in 0..<total {
            let stepped = (rung - 1 + (index * 2) / total).clamped(to: 1...8)
            let choices = pool.count > 1 ? pool.filter { $0 != lastKind } : pool
            let kind = (index == 0 && !isBoss ? chapter?.kind : nil)
                ?? choices.randomElement(using: &rng)
                ?? .completePattern
            lastKind = kind
            let spec = PuzzleSpec(
                world: world,
                kind: kind,
                difficulty: isBoss ? min(stepped + 1, 8) : stepped,
                isBoss: isBoss
            )
            let title = titleFor(kind: kind, story: story, fallback: chapter?.title)
            puzzles.append(generate(spec: spec, title: title, using: &rng))
        }

        return PuzzleRun(
            id: UUID(),
            world: world,
            level: level,
            difficulty: rung,
            puzzles: puzzles,
            isBoss: isBoss,
            chapter: chapter
        )
    }

    /// The daily challenge: same puzzle for everyone on a given day, drawn
    /// from a world the child has already opened.
    func generateDailyPuzzle(world: PuzzleWorld, difficulty: Int, day: Date, calendar: Calendar = .current) -> Puzzle {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        let seed = UInt64((components.year ?? 2000) * 10_000 + (components.month ?? 1) * 100 + (components.day ?? 1))
        var rng = SeededGenerator(seed: seed &* 2_654_435_761)
        let story = world.story
        let chapter = story.chapters.randomElement(using: &rng) ?? story.chapters.first
        let kind = chapter?.kind ?? .completePattern
        let spec = PuzzleSpec(world: world, kind: kind, difficulty: difficulty)
        return generate(spec: spec, title: chapter?.title, using: &rng)
    }

    /// The chapter's own kind, plus the kinds either side of it — enough
    /// variety that a level isn't five of the same puzzle.
    private func chapterPool(story: WorldStory, level: Int, difficulty: Int, age: Int) -> [PuzzleKind] {
        let chapters = story.chapters
        guard !chapters.isEmpty else { return [.completePattern] }
        let index = (level - 1).clamped(to: 0...(chapters.count - 1))
        let window = [index - 1, index, index + 1]
            .filter { $0 >= 0 && $0 < chapters.count }
            .map { chapters[$0].kind }
        let unique = Array(Set(window))
        return unique.isEmpty ? [chapters[index].kind] : unique
    }

    private func titleFor(kind: PuzzleKind, story: WorldStory, fallback: String?) -> String {
        story.chapters.first { $0.kind == kind }?.title ?? fallback ?? story.world.shortTitle
    }

    /// Kinds a world offers, filtered by age and rung, widening rather than
    /// ever returning nothing.
    func eligibleKinds(world: PuzzleWorld, difficulty: Int, age: Int) -> [PuzzleKind] {
        let worldKinds = Array(Set(world.kinds))
        let byRung = worldKinds.filter { $0.skill.level <= difficulty + 1 }
        if !byRung.isEmpty { return byRung }
        return worldKinds.isEmpty ? [.completePattern] : worldKinds
    }

    // MARK: - Level 1–2 kinds

    /// 🍃 🍂 🍃 🍂 ❓ 🍂 — a repeating unit with a hole punched in it.
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

    /// A color strip with one cell missing. Always shapes — the rule is color.
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

    /// Show one thing, find its twin.
    private func matchTheShape<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let pool = distinctGlyphs(count: 4, spec: spec, rng: &rng)
        let answer = pool[0]
        let tiles = [PuzzleTile(glyph: answer), PuzzleTile.blank(isTarget: true)]
        return assemble(
            spec: spec,
            grid: PuzzleGrid(rows: 1, columns: 2, tiles: tiles),
            answer: answer,
            decoyPool: Array(pool.dropFirst()),
            rng: &rng
        )
    }

    /// 🐢 🦜 🐢 🦜 ❓ — gap at the end.
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

    /// Two things side by side — same, or different?
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
            title: spec.kind.rawValue,
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
        // With tintable shapes, rung 3+ makes the odd one differ by color
        // only — a harder discrimination. Pictures can't do that (their
        // color isn't ours to change), so they differ by picture.
        let odd: PuzzleGlyph
        if spec.difficulty >= 3, pair[0].motif.isTintable {
            odd = PuzzleGlyph(motif: pair[0].motif, color: pair[1].color)
        } else {
            odd = pair[1]
        }
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
            title: spec.kind.rawValue,
            grid: PuzzleGrid(rows: count / columns, columns: columns, tiles: tiles),
            answerMode: .tapTile,
            options: [],
            correctID: tiles[oddIndex].id,
            timeLimit: spec.timeLimit,
            reward: spec.reward
        )
    }

    /// A B A / B A ❓ — the second row inverts the first.
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

    /// "How many acorns?" — counting inside visual noise.
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
            title: spec.kind.rawValue,
            grid: PuzzleGrid(rows: side, columns: side, tiles: tiles),
            answerMode: .options,
            options: options,
            correctID: correct.id,
            timeLimit: spec.timeLimit,
            reward: spec.reward
        )
    }

    // MARK: - Level 3–4 kinds

    /// 3×3 Latin square — each row is a shift of the one above.
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

    /// Legend: circle = red, square = blue. The answer needs the right shape
    /// *and* the color the rule assigns it.
    private func colorLogic<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let shapes = symbols(for: spec.difficulty).shuffled(using: &rng)
        let colors = palette(for: spec.world).shuffled(using: &rng)
        let ruleCount = 2
        let ruled = (0..<ruleCount).map { PuzzleGlyph(symbol: shapes[$0], color: colors[$0]) }
        // The legend's left side is the uncolored shape, drawn in ink.
        let legend = ruled.map { glyph in
            PuzzleLegendEntry(inputs: [PuzzleGlyph(motif: glyph.motif, color: .black)], result: glyph)
        }

        let length = 4
        var tiles = (0..<length).map { PuzzleTile(glyph: ruled[$0 % ruleCount]) }
        let answer = ruled[(length - 1) % ruleCount]
        tiles[length - 1] = .blank(isTarget: true)

        // Distractors break exactly one half of the rule each.
        let wrongColor = PuzzleGlyph(symbol: answer.symbolOrDefault, color: colors[ruleCount % colors.count])
        let swapped = ruled.first { $0.motif != answer.motif }
            ?? PuzzleGlyph(symbol: shapes[1], color: colors[1])
        let wrongShape = PuzzleGlyph(motif: swapped.motif, color: answer.color)

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

    /// A checkerboard of two glyphs with one cell missing.
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

    /// 1 🦴 / 2 🥚 / 3 🦴 / 4 ❓ — number parity picks the picture.
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

    /// Two rules at once: the row picks the shape, the column picks the
    /// color. Distractors satisfy one rule but never both.
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

    /// Each row extends the one above by exactly one.
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

    /// A 4×4 Latin square of colors — the blank has exactly one legal filling.
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

    /// Two worked examples define a secret rule — "keep the first shape, take
    /// the second color" — then the child applies it.
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
            PuzzleGlyph(motif: left.motif, color: right.color)
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
            combine(queryRight, queryLeft),   // rule reversed
            queryLeft,                        // copied the left
            queryRight                        // copied the right
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
    /// backfilled from the same vocabulary the board was drawn from, so a
    /// forest puzzle never sprouts a spaceship.
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
        if chosen.count < spec.options {
            for candidate in vocabulary(spec: spec, rotation: answer.rotation, rng: &rng)
            where chosen.count < spec.options {
                if !chosen.contains(candidate) { chosen.append(candidate) }
            }
        }

        let options = chosen.map { PuzzleOption(glyph: $0) }.shuffled(using: &rng)
        let correctID = options.first { $0.glyph == answer }?.id ?? options[0].id
        return Puzzle(
            id: UUID(),
            world: spec.world,
            kind: spec.kind,
            difficulty: spec.difficulty,
            title: spec.kind.rawValue,
            grid: grid,
            answerMode: .options,
            options: options,
            correctID: correctID,
            timeLimit: spec.timeLimit,
            reward: spec.reward
        )
    }

    /// Every glyph this puzzle may legally draw, in shuffled order.
    private func vocabulary<R: RandomNumberGenerator>(
        spec: PuzzleSpec,
        rotation: Double,
        rng: inout R
    ) -> [PuzzleGlyph] {
        if usesPictures(spec) {
            return spec.world.story.motifs
                .shuffled(using: &rng)
                .map { PuzzleGlyph(motif: $0, color: .black, rotation: rotation) }
        }
        var glyphs: [PuzzleGlyph] = []
        for symbol in symbols(for: spec.difficulty).shuffled(using: &rng) {
            for color in palette(for: spec.world).shuffled(using: &rng) {
                glyphs.append(PuzzleGlyph(symbol: symbol, color: color, rotation: rotation))
            }
        }
        return glyphs
    }

    /// `count` glyphs that are pairwise distinct. Picture worlds vary the
    /// picture; shape worlds vary *both* shape and color, so a color-blind
    /// child always has a second signal.
    private func distinctGlyphs<R: RandomNumberGenerator>(
        count: Int,
        spec: PuzzleSpec,
        rng: inout R
    ) -> [PuzzleGlyph] {
        if usesPictures(spec) {
            let motifs = padded(spec.world.story.motifs.shuffled(using: &rng),
                                with: PuzzleWorld.forest.story.motifs, toAtLeast: count)
            return (0..<count).map { PuzzleGlyph(motif: motifs[$0], color: .black) }
        }
        let shapes = padded(symbols(for: spec.difficulty).shuffled(using: &rng),
                            with: PuzzleSymbol.allCases, toAtLeast: count)
        let colors = padded(palette(for: spec.world).shuffled(using: &rng),
                            with: ForestTheme.GameColor.allCases, toAtLeast: count)
        return (0..<count).map { PuzzleGlyph(symbol: shapes[$0], color: colors[$0]) }
    }

    /// `values`, extended from `fallback` until it holds `toAtLeast`
    /// *distinct* entries. Padding must never introduce duplicates — a
    /// repeated color would break the Latin squares.
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
    /// Only for kinds whose rule determines *every* cell, so an extra hole
    /// adds load without adding ambiguity.
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

// MARK: - Small conveniences

private extension PuzzleGlyph {
    /// The underlying shape, for the color-rule generators that only ever
    /// build shape glyphs.
    var symbolOrDefault: PuzzleSymbol {
        if case .shape(let symbol) = motif { return symbol }
        return .circle
    }
}

extension Puzzle {
    /// Story title applied after generation — the recipes don't know which
    /// chapter they were summoned for.
    func retitled(_ newTitle: String) -> Puzzle {
        Puzzle(
            id: id,
            world: world,
            kind: kind,
            difficulty: difficulty,
            title: newTitle,
            grid: grid,
            answerMode: answerMode,
            options: options,
            correctID: correctID,
            timeLimit: timeLimit,
            reward: reward,
            legend: legend
        )
    }
}
