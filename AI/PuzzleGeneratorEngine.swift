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
        case .hiddenObject:     puzzle = hiddenObject(spec: spec, rng: &rng)
        case .memoryGrid:       puzzle = memoryGrid(spec: spec, rng: &rng)
        case .maze:             puzzle = maze(spec: spec, rng: &rng)
        case .blockRotation:    puzzle = blockRotation(spec: spec, rng: &rng)
        case .assemble:         puzzle = assembly(spec: spec, rng: &rng)
        case .pipeConnect:      puzzle = pipeConnect(spec: spec, rng: &rng)
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
            mode: isBoss ? .boss : .chapter,
            chapter: chapter
        )
    }

    /// The daily challenge as a playable run: one seeded puzzle, no story
    /// progress, same board for everyone all day.
    func generateDailyRun(world: PuzzleWorld, difficulty: Int, day: Date, calendar: Calendar = .current) -> PuzzleRun {
        PuzzleRun(
            id: UUID(),
            world: world,
            level: 0,
            difficulty: difficulty.clamped(to: 1...8),
            puzzles: [generateDailyPuzzle(world: world, difficulty: difficulty, day: day, calendar: calendar)],
            mode: .daily,
            chapter: nil
        )
    }

    /// The weekend challenge: a longer mixed run across a world's chapters.
    func generateWeekendRun<R: RandomNumberGenerator>(
        world: PuzzleWorld,
        difficulty: Int,
        age: Int,
        count: Int,
        using rng: inout R
    ) -> PuzzleRun {
        let rung = difficulty.clamped(to: 1...8)
        let pool = eligibleKinds(world: world, difficulty: rung, age: age)
        let story = world.story
        var puzzles: [Puzzle] = []
        var lastKind: PuzzleKind?
        for index in 0..<max(1, count) {
            let stepped = (rung - 1 + (index * 2) / max(1, count)).clamped(to: 1...8)
            let choices = pool.count > 1 ? pool.filter { $0 != lastKind } : pool
            let kind = choices.randomElement(using: &rng) ?? .completePattern
            lastKind = kind
            let spec = PuzzleSpec(world: world, kind: kind, difficulty: stepped)
            puzzles.append(generate(spec: spec, title: titleFor(kind: kind, story: story, fallback: nil), using: &rng))
        }
        return PuzzleRun(
            id: UUID(),
            world: world,
            level: 0,
            difficulty: rung,
            puzzles: puzzles,
            mode: .weekend,
            chapter: nil
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

    // MARK: - Search & memory kinds

    /// "Find 5 acorns" — the whole board is the answer, tapped one by one.
    /// Every found tile stays found; a wrong tap only shakes.
    private func hiddenObject<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let side = min(max(3, spec.maxSide - 1), 5)
        let cellCount = side * side
        // Three to five targets: enough to feel like a hunt, few enough that
        // a four-year-old can hold the count in their head.
        let targetCount = (2 + spec.difficulty / 2).clamped(to: 3...5)
        let vocabulary = distinctGlyphs(count: 4, spec: spec, rng: &rng)
        let target = vocabulary[0]
        let clutter = Array(vocabulary.dropFirst())

        var glyphs: [PuzzleGlyph] = (0..<cellCount).map { index in
            index < targetCount ? target : (clutter.randomElement(using: &rng) ?? target)
        }
        glyphs.shuffle(using: &rng)

        var tiles: [PuzzleTile] = []
        var correctIDs: Set<UUID> = []
        for glyph in glyphs {
            let isTarget = (glyph == target)
            let tile = PuzzleTile(glyph: glyph, isTarget: isTarget)
            if isTarget { correctIDs.insert(tile.id) }
            tiles.append(tile)
        }

        return Puzzle(
            id: UUID(),
            world: spec.world,
            kind: spec.kind,
            difficulty: spec.difficulty,
            title: spec.kind.rawValue,
            grid: PuzzleGrid(rows: side, columns: side, tiles: tiles),
            answerMode: .tapMany,
            options: [],
            correctIDs: correctIDs,
            timeLimit: spec.timeLimit,
            reward: spec.reward
        )
    }

    /// Look, remember, then answer: the board is shown for a few seconds and
    /// covered, and the child says what was in the marked cell. The peek is
    /// generous — this trains memory, not panic.
    private func memoryGrid<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let side = min(max(2, spec.maxSide - 3), 4)
        let cellCount = side * side
        let vocabulary = distinctGlyphs(count: min(4, max(2, side)), spec: spec, rng: &rng)
        var glyphs = (0..<cellCount).map { index in
            vocabulary[index % vocabulary.count]
        }
        glyphs.shuffle(using: &rng)

        var tiles = glyphs.map { PuzzleTile(glyph: $0) }
        let targetIndex = Int.random(in: 0..<cellCount, using: &rng)
        let answer = glyphs[targetIndex]
        // The target keeps its glyph — the view hides it once the peek ends,
        // so the board can be drawn from a single source of truth.
        tiles[targetIndex].isTarget = true

        // Longer peeks at the easier rungs.
        let peek = TimeInterval(6 - min(spec.difficulty, 4))

        var puzzle = assemble(
            spec: spec,
            grid: PuzzleGrid(rows: side, columns: side, tiles: tiles),
            answer: answer,
            decoyPool: vocabulary,
            rng: &rng
        )
        puzzle.peekDuration = max(2, peek)
        return puzzle
    }

    // MARK: - Maze

    /// A route from start to treasure, around the dangers, picking up the key
    /// on the way at the higher rungs.
    ///
    /// The safe route is carved *first* and hazards are only ever placed off
    /// it, so a board can never be unsolvable — no retry loop, no chance of
    /// shipping a maze with no way through.
    private func maze<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let side = min(max(3, spec.maxSide - 1), 5)
        let route = carveRoute(side: side, rng: &rng)
        let routeCells = Set(route.map { $0.row * side + $0.column })

        // Hazards fill some of what the route doesn't use. The density climbs
        // with the rung but always leaves the carved route clear.
        let density = min(0.2 + Double(spec.difficulty) * 0.05, 0.5)
        var roles = [PuzzleTileRole](repeating: .plain, count: side * side)
        for index in 0..<(side * side) where !routeCells.contains(index) {
            if Double.random(in: 0..<1, using: &rng) < density {
                roles[index] = .hazard
            }
        }
        roles[0] = .start
        roles[side * side - 1] = .goal

        // From rung 4, the treasure needs a key first — one more thing to
        // plan around, and straight out of the story.
        if spec.difficulty >= 4, route.count > 2 {
            let keyStep = route[Int.random(in: 1..<(route.count - 1), using: &rng)]
            roles[keyStep.row * side + keyStep.column] = .key
        }

        let hazardGlyph = hazardMotif(for: spec.world)
        let tiles = roles.map { role -> PuzzleTile in
            PuzzleTile(glyph: role == .hazard ? hazardGlyph : nil, role: role)
        }
        let grid = PuzzleGrid(rows: side, columns: side, tiles: tiles)
        let goalID = tiles.last?.id ?? UUID()

        return Puzzle(
            id: UUID(),
            world: spec.world,
            kind: spec.kind,
            difficulty: spec.difficulty,
            title: spec.kind.rawValue,
            grid: grid,
            answerMode: .tapPath,
            options: [],
            correctIDs: [goalID],
            timeLimit: spec.timeLimit + 20,     // routes deserve thinking time
            reward: spec.reward
        )
    }

    /// A wandering but never self-crossing route from the top-left corner to
    /// the bottom-right one, moving only right and down.
    private func carveRoute<R: RandomNumberGenerator>(
        side: Int,
        rng: inout R
    ) -> [(row: Int, column: Int)] {
        var route: [(row: Int, column: Int)] = [(0, 0)]
        var row = 0
        var column = 0
        while row < side - 1 || column < side - 1 {
            let canGoDown = row < side - 1
            let canGoRight = column < side - 1
            let goDown: Bool
            if canGoDown && canGoRight {
                goDown = Bool.random(using: &rng)
            } else {
                goDown = canGoDown
            }
            if goDown { row += 1 } else { column += 1 }
            route.append((row, column))
        }
        return route
    }

    /// What "danger" looks like in this world — water, fire, or ice.
    private func hazardMotif(for world: PuzzleWorld) -> PuzzleGlyph {
        let motif: PuzzleMotif
        switch world {
        case .forest:   motif = .picture("💧", name: String(localized: "water"))
        case .pirate:   motif = .picture("🌊", name: String(localized: "waves"))
        case .space:    motif = .picture("☄️", name: String(localized: "meteor"))
        case .castle:   motif = .picture("🔥", name: String(localized: "fire"))
        case .dinosaur: motif = .picture("🌋", name: String(localized: "lava"))
        case .ocean:    motif = .picture("🦈", name: String(localized: "shark"))
        case .ice:      motif = .picture("🕳", name: String(localized: "hole"))
        case .volcano:  motif = .picture("🔥", name: String(localized: "fire"))
        case .rainbow:  motif = .picture("🌑", name: String(localized: "shadow"))
        }
        return PuzzleGlyph(motif: motif, color: .black)
    }

    // MARK: - Block rotation

    /// Show a block; find the same block turned around.
    ///
    /// Two things make this fair: the block is chosen to have four *different*
    /// orientations (a symmetric block would have several right answers), and
    /// every distractor is checked against all four turns of the original, so
    /// a decoy can never accidentally be correct.
    private func blockRotation<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let side = spec.difficulty <= 3 ? 2 : 3
        let color = palette(for: spec.world).randomElement(using: &rng) ?? .blue
        let original = asymmetricPattern(side: side, difficulty: spec.difficulty, color: color, rng: &rng)

        // The answer is the block, turned a quarter, half, or three quarters.
        let turns = Int.random(in: 1...3, using: &rng)
        var answer = original
        for _ in 0..<turns { answer = answer.rotated() }

        // Distractors: the mirror image (never a rotation of the original for
        // an asymmetric block), and blocks with a cell moved.
        var decoys: [PuzzlePattern] = []
        let mirror = original.mirrored()
        if !mirror.isRotation(of: original) { decoys.append(mirror) }
        for _ in 0..<12 where decoys.count < spec.options - 1 {
            let candidate = nudged(original, rng: &rng)
            guard !candidate.isRotation(of: original),
                  !decoys.contains(where: { $0.filled == candidate.filled && $0.rows == candidate.rows })
            else { continue }
            decoys.append(candidate)
        }
        // Last resort: fresh blocks with a different number of squares, which
        // can't be a rotation of anything.
        while decoys.count < spec.options - 1 {
            var candidate = asymmetricPattern(side: side, difficulty: spec.difficulty, color: color, rng: &rng)
            if candidate.isRotation(of: original) { candidate = nudged(candidate, rng: &rng) }
            if !candidate.isRotation(of: original) { decoys.append(candidate) }
        }

        // The board shows the original block, drawn as filled tiles.
        let blockGlyph = PuzzleGlyph(symbol: .square, color: color)
        let tiles = (0..<(side * side)).map { index -> PuzzleTile in
            let row = index / side
            let column = index % side
            return PuzzleTile(glyph: original.isFilled(row: row, column: column) ? blockGlyph : nil)
        }

        var options = ([answer] + decoys.prefix(spec.options - 1))
            .map { PuzzleOption(pattern: $0) }
        options.shuffle(using: &rng)
        let correctID = options.first { $0.pattern == answer }?.id ?? options[0].id

        return Puzzle(
            id: UUID(),
            world: spec.world,
            kind: spec.kind,
            difficulty: spec.difficulty,
            title: spec.kind.rawValue,
            grid: PuzzleGrid(rows: side, columns: side, tiles: tiles),
            answerMode: .options,
            options: options,
            correctIDs: [correctID],
            timeLimit: spec.timeLimit + 10,
            reward: spec.reward
        )
    }

    /// A block whose four turns all look different, so exactly one option can
    /// be the answer. Falls back to a known-asymmetric L after a few tries.
    private func asymmetricPattern<R: RandomNumberGenerator>(
        side: Int,
        difficulty: Int,
        color: ForestTheme.GameColor,
        rng: inout R
    ) -> PuzzlePattern {
        let cellCount = side * side
        let fillCount = max(2, min(cellCount - 1, side + difficulty / 3))
        for _ in 0..<20 {
            var cells = [Bool](repeating: false, count: cellCount)
            for index in (0..<cellCount).shuffled(using: &rng).prefix(fillCount) {
                cells[index] = true
            }
            let candidate = PuzzlePattern(rows: side, columns: side, filled: cells, color: color)
            if candidate.hasDistinctRotations { return candidate }
        }
        // An L is asymmetric at any size.
        var cells = [Bool](repeating: false, count: cellCount)
        cells[0] = true
        cells[side] = true
        cells[side + 1] = true
        return PuzzlePattern(rows: side, columns: side, filled: cells, color: color)
    }

    /// The same block with one square moved somewhere else.
    private func nudged<R: RandomNumberGenerator>(
        _ pattern: PuzzlePattern,
        rng: inout R
    ) -> PuzzlePattern {
        var cells = pattern.filled
        let filledIndices = cells.indices.filter { cells[$0] }
        let emptyIndices = cells.indices.filter { !cells[$0] }
        guard let from = filledIndices.randomElement(using: &rng),
              let to = emptyIndices.randomElement(using: &rng)
        else { return pattern }
        cells[from] = false
        cells[to] = true
        return PuzzlePattern(rows: pattern.rows, columns: pattern.columns,
                             filled: cells, color: pattern.color)
    }

    // MARK: - Assembly

    /// Build the picture: a row of empty spaces, a bank of pieces, and a
    /// piece to put in each. The silhouette shows what belongs where, so this
    /// is part-to-whole matching rather than guesswork.
    private func assembly<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let slotCount = (2 + spec.difficulty / 2).clamped(to: 3...5)
        // One spare piece from rung 4 up: now the bank has to be read, not
        // just emptied.
        let spares = spec.difficulty >= 4 ? 1 : 0
        let pieces = distinctGlyphs(count: slotCount + spares, spec: spec, rng: &rng)

        let wanted = Array(pieces.prefix(slotCount)).shuffled(using: &rng)
        let tiles = wanted.map { PuzzleTile(glyph: $0, role: .slot) }
        let options = pieces.shuffled(using: &rng).map { PuzzleOption(glyph: $0) }

        // Every slot is an answer; the run view checks a tapped piece against
        // the slot it's dropped into.
        return Puzzle(
            id: UUID(),
            world: spec.world,
            kind: spec.kind,
            difficulty: spec.difficulty,
            title: spec.kind.rawValue,
            grid: PuzzleGrid(rows: 1, columns: slotCount, tiles: tiles),
            answerMode: .assemble,
            options: options,
            correctIDs: Set(tiles.map(\.id)),
            timeLimit: spec.timeLimit + 15,
            reward: spec.reward
        )
    }

    // MARK: - Pipes

    /// Turn the pipes until the water runs from the tap to the far end.
    ///
    /// Built the same way round as the maze: the working pipeline is laid
    /// down *first*, then every tile is turned a random amount. Solvability
    /// is therefore guaranteed — turning each tile back is always a solution.
    /// The only thing checked afterwards is that the scramble didn't leave
    /// the puzzle already solved.
    private func pipeConnect<R: RandomNumberGenerator>(spec: PuzzleSpec, rng: inout R) -> Puzzle {
        let side = min(max(3, spec.maxSide - 2), 4)
        let route = carveRoute(side: side, rng: &rng)

        // Lay the pipeline: each route cell opens towards its neighbours on
        // the route, so the ends are single spouts and the rest join up.
        var connections = [PipeConnections](repeating: [], count: side * side)
        for (position, cell) in route.enumerated() {
            let index = cell.row * side + cell.column
            if position > 0 {
                connections[index].insert(direction(from: cell, to: route[position - 1]))
            }
            if position < route.count - 1 {
                connections[index].insert(direction(from: cell, to: route[position + 1]))
            }
        }

        // Off-route cells get loose pipe so the board doesn't advertise the
        // answer by being empty everywhere else.
        let clutter: [PipeConnections] = [[.north, .south], [.north, .east], [.east, .south]]
        let routeCells = Set(route.map { $0.row * side + $0.column })
        for index in 0..<(side * side) where !routeCells.contains(index) {
            connections[index] = clutter.randomElement(using: &rng) ?? [.north, .south]
        }

        func build(_ connections: [PipeConnections]) -> PuzzleGrid {
            let tiles = connections.enumerated().map { index, pipe -> PuzzleTile in
                let role: PuzzleTileRole = index == 0
                    ? .start
                    : (index == side * side - 1 ? .goal : .plain)
                return PuzzleTile(role: role, pipe: pipe)
            }
            return PuzzleGrid(rows: side, columns: side, tiles: tiles)
        }

        // Scramble. Straight pipes look the same after a half turn, so a
        // "turned" tile isn't always a changed tile — hence the check that
        // the board didn't come out already solved.
        var scrambled = connections
        for attempt in 0..<8 {
            scrambled = connections.map { pipe in
                var turned = pipe
                let turns = attempt == 0
                    ? Int.random(in: 1...3, using: &rng)   // never leave a tile untouched
                    : Int.random(in: 0...3, using: &rng)
                for _ in 0..<turns { turned = turned.rotated() }
                return turned
            }
            if !PipeRules.isConnected(build(scrambled)) { break }
        }

        let grid = build(scrambled)
        let goalID = grid.tiles.last?.id ?? UUID()

        return Puzzle(
            id: UUID(),
            world: spec.world,
            kind: spec.kind,
            difficulty: spec.difficulty,
            title: spec.kind.rawValue,
            grid: grid,
            answerMode: .rotateTiles,
            options: [],
            correctIDs: [goalID],
            timeLimit: spec.timeLimit + 25,     // fiddling deserves time
            reward: spec.reward
        )
    }

    /// Which side of `cell` faces `other`. They must be neighbours.
    private func direction(
        from cell: (row: Int, column: Int),
        to other: (row: Int, column: Int)
    ) -> PipeConnections {
        if other.row < cell.row { return .north }
        if other.row > cell.row { return .south }
        if other.column > cell.column { return .east }
        return .west
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
            correctIDs: correctIDs,
            timeLimit: timeLimit,
            reward: reward,
            legend: legend,
            peekDuration: peekDuration
        )
    }
}
