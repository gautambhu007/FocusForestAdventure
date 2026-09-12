//
//  WordSearchView.swift
//  Focus Forest Adventure
//
//  Word Hunt: the forty-sheet word-search campaign. Two screens — the map
//  of sheets, and one sheet being played — with the page composition the
//  spec asks for: title on top, instruction under it, the grid as the
//  centrepiece in its own panel, WORDS TO FIND below with a picture per
//  word, and the mascot leaning on the panel's edge rather than sitting
//  inside it.
//
//  Art contract: every sheet names a mascot and a palette. Today the
//  mascot is an emoji and the scene is a painted forest place or a
//  gradient; `WordSearchArt` swaps
//  in catalog assets per sheet as they land, and nothing else moves.
//

import SwiftUI

// MARK: - Map of sheets

@Observable
@MainActor
final class WordSearchHubViewModel {
    let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    private(set) var progress = WordSearchSnapshot()

    var sheets: [WordSearchSheet] { WordSearchWordBank.sheets }
    var nextSheetNumber: Int { progress.nextSheetNumber }
    var completedCount: Int { progress.completedCount }
    var totalStars: Int { progress.totalStars }

    func stars(_ sheet: WordSearchSheet) -> Int { progress.stars(for: sheet.number) }
    func isUnlocked(_ sheet: WordSearchSheet) -> Bool { progress.isUnlocked(sheet.number) }

    /// Re-read on every appearance: the map is what the child comes back
    /// to after a sheet, and it must show the star they just won.
    func refresh() {
        do {
            let child = try dependencies.childRepository.activeChild()
            progress = try dependencies.wordSearchRepository.snapshot(for: child)
        } catch {
            assertionFailure("Word Hunt progress load failed: \(error)")
        }
    }

    func sheetTapped(_ sheet: WordSearchSheet) {
        guard isUnlocked(sheet) else {
            dependencies.hapticsService.playGentleTap()
            return
        }
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        dependencies.appState.navigationPath.append(.wordSearchSheet(sheet.number))
    }

    func playNextTapped() {
        guard let sheet = WordSearchWordBank.sheet(number: nextSheetNumber) else { return }
        sheetTapped(sheet)
    }
}

struct WordSearchHubView: View {
    @State var viewModel: WordSearchHubViewModel

    private let columns = [GridItem(.adaptive(minimum: 84, maximum: 110), spacing: 12)]

    var body: some View {
        ZStack {
            ForestSceneBackground(place: .glade, legibility: 0.5).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header

                    ForEach(WordSearchStage.allCases, id: \.self) { stage in
                        stageSection(stage)
                    }
                }
                .padding(.horizontal, ForestTheme.Metrics.screenPadding)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(String(localized: "🔍 Word Hunt"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refresh() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(String(localized: "Find the hidden words!"))
                .font(ForestTheme.Fonts.heading)
                .foregroundStyle(ForestTheme.Colors.deepGreen)

            Text(String(localized: "\(viewModel.completedCount) of \(WordSearchWordBank.count) pages found · \(viewModel.totalStars) ⭐"))
                .font(ForestTheme.Fonts.caption)
                .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.8))

            BigBouncyButton(title: String(localized: "Play"), icon: "play.fill") {
                viewModel.playNextTapped()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .forestCard()
        .padding(.top, 8)
    }

    private func stageSection(_ stage: WordSearchStage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(stageTitle(stage))
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                Spacer()
                Text(stage.localizedAges)
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.7))
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.sheets.filter { $0.stage == stage }) { sheet in
                    sheetTile(sheet)
                }
            }
        }
        .padding(14)
        .forestCard(cornerRadius: 22)
    }

    private func stageTitle(_ stage: WordSearchStage) -> String {
        switch stage {
        case .seedling: String(localized: "🌱 Seedling")
        case .sprout: String(localized: "🌿 Sprout")
        case .sapling: String(localized: "🌳 Sapling")
        case .tree: String(localized: "🌲 Big Tree")
        }
    }

    private func sheetTile(_ sheet: WordSearchSheet) -> some View {
        let unlocked = viewModel.isUnlocked(sheet)
        let stars = viewModel.stars(sheet)
        let isNext = sheet.number == viewModel.nextSheetNumber
        return Button {
            viewModel.sheetTapped(sheet)
        } label: {
            VStack(spacing: 4) {
                Text(unlocked ? sheet.emoji : "🔒")
                    .font(.system(size: 30))
                Text("\(sheet.number)")
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                Text(String(repeating: "⭐", count: stars))
                    .font(.caption2)
                    .frame(height: 12)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(unlocked ? sheet.palette.tint.opacity(0.35) : Color.gray.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isNext ? ForestTheme.Colors.sunshine : .clear, lineWidth: 3)
            )
            .opacity(unlocked ? 1 : 0.6)
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel(unlocked
            ? String(localized: "Page \(sheet.number), \(sheet.title), \(stars) stars")
            : String(localized: "Page \(sheet.number), locked"))
    }
}

// MARK: - One sheet

@Observable
@MainActor
final class WordSearchPlayViewModel {
    enum Phase { case playing, celebrating }

    let dependencies: AppDependencies
    let sheet: WordSearchSheet
    private let engine = WordSearchEngine()

    private(set) var puzzle: WordSearchPuzzle
    private(set) var phase: Phase = .playing
    private(set) var foundWords: [String] = []
    /// Cells lit by found words, keyed by the word so each keeps its colour.
    private(set) var foundCells: [String: [WordSearchCell]] = [:]
    /// The straight run under the finger right now.
    private(set) var selection: [WordSearchCell] = []
    private(set) var wrongFlash = false
    /// The word whose row is popping right now; clears itself after the pop.
    private(set) var lastFound: String?
    /// Bumps once per found word — the sparkle burst and the mascot's
    /// reaction both key off it.
    private(set) var sparkleTrigger = 0
    /// The lit first letter of a hinted word. It stays lit through other
    /// drags and clears only when its own word is found.
    private(set) var hintCell: WordSearchCell?
    private(set) var hintWord: String?
    private(set) var hintsUsed = 0
    private(set) var starsEarned = 0

    private var dragStart: WordSearchCell?

    /// `seed` is for tests; play draws a fresh one.
    init(sheetNumber: Int, dependencies: AppDependencies, seed: UInt64? = nil) {
        self.dependencies = dependencies
        let sheet = WordSearchWordBank.sheet(number: sheetNumber) ?? WordSearchWordBank.sheets[0]
        self.sheet = sheet
        self.puzzle = engine.makePuzzle(sheet: sheet, seed: seed ?? engine.nextSeed(for: sheet.number, after: nil))
    }

    var words: [WordSearchWord] { sheet.words }
    func isFound(_ word: String) -> Bool { foundWords.contains(word) }
    var remainingCount: Int { words.count - foundWords.count }

    /// What the character is doing, derived from play so the view never
    /// has to sequence it: celebrating beats everything, then the brief
    /// nudge after a wrong drag, then the hop for a found word, then the
    /// lean toward a lit hint, else resting.
    var mascotState: WordSearchMascotState {
        if phase == .celebrating { return .celebrate }
        if wrongFlash { return .encourage }
        if lastFound != nil { return .wordFound }
        if hintCell != nil { return .hint }
        return .idle
    }

    /// The word a lit cell belongs to. Where two found words cross, the
    /// one found first keeps the cell, so the colour never flickers.
    func foundWord(at cell: WordSearchCell) -> String? {
        foundWords.first { foundCells[$0]?.contains(cell) == true }
    }

    /// One colour per word so the found runs read as separate ribbons.
    func color(for word: String) -> Color {
        let index = words.firstIndex { $0.text == word } ?? 0
        return Self.ribbon[index % Self.ribbon.count]
    }

    private static let ribbon: [Color] = [
        ForestTheme.Colors.leafGreen, ForestTheme.Colors.skyBlue, ForestTheme.Colors.sunshine,
        ForestTheme.Colors.bubblegum, ForestTheme.Colors.lavender, ForestTheme.Colors.peach,
        ForestTheme.Colors.mint, Color(red: 0.55, green: 0.8, blue: 0.85),
        Color(red: 0.95, green: 0.7, blue: 0.5), Color(red: 0.7, green: 0.85, blue: 0.6),
    ]

    // MARK: Dragging

    func dragBegan(at cell: WordSearchCell) {
        guard phase == .playing, puzzle.letter(at: cell) != nil else { return }
        dragStart = cell
        selection = [cell]
    }

    /// Snap the run to the nearest of the eight directions so the child
    /// need not trace a perfect line.
    func dragMoved(to cell: WordSearchCell) {
        guard let start = dragStart, phase == .playing else { return }
        let dr = cell.row - start.row, dc = cell.column - start.column
        guard dr != 0 || dc != 0 else { selection = [start]; return }
        let length = max(abs(dr), abs(dc))
        let stepRow: Int, stepColumn: Int
        if abs(dr) >= 2 * abs(dc) { (stepRow, stepColumn) = (dr.signum(), 0) }
        else if abs(dc) >= 2 * abs(dr) { (stepRow, stepColumn) = (0, dc.signum()) }
        else { (stepRow, stepColumn) = (dr.signum(), dc.signum()) }
        var run: [WordSearchCell] = []
        for step in 0...length {
            let next = WordSearchCell(row: start.row + stepRow * step, column: start.column + stepColumn * step)
            guard puzzle.letter(at: next) != nil else { break }
            run.append(next)
        }
        selection = run
    }

    func dragEnded() {
        defer { dragStart = nil; selection = [] }
        guard phase == .playing, selection.count >= 2 else { return }
        if let word = puzzle.word(spelledBy: selection), !foundWords.contains(word) {
            wordFound(word, cells: selection)
        } else {
            // A wrong drag is not a mistake worth a sound — but a *near*
            // miss (a real run of letters) gets the gentle nudge.
            wrongFlash = true
            dependencies.hapticsService.playGentleTap()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                wrongFlash = false
            }
        }
    }

    private func wordFound(_ word: String, cells: [WordSearchCell]) {
        foundWords.append(word)
        foundCells[word] = cells
        lastFound = word
        sparkleTrigger += 1
        if hintWord == word {
            hintWord = nil
            hintCell = nil
        }
        dependencies.soundEngine.play(.correctChime)
        dependencies.hapticsService.playSuccess()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if lastFound == word { lastFound = nil }
        }
        if foundWords.count == words.count {
            finish()
        }
    }

    // MARK: Hints

    /// Light the first letter of one unfound word. Costs a star, floor one —
    /// the app never sends a child away with nothing.
    func hintTapped() {
        guard phase == .playing,
              let placement = puzzle.placements.first(where: { !foundWords.contains($0.word) })
        else { return }
        hintsUsed += 1
        hintWord = placement.word
        hintCell = placement.cells.first
        dependencies.soundEngine.play(.tapPop)
        dependencies.hapticsService.playGentleTap()
    }

    // MARK: Finish

    private func finish() {
        starsEarned = max(1, 3 - hintsUsed)
        do {
            let child = try dependencies.childRepository.activeChild()
            try dependencies.wordSearchRepository.recordFinish(
                sheetNumber: sheet.number, stars: starsEarned, hintsUsed: hintsUsed, for: child
            )
        } catch {
            assertionFailure("Word Hunt save failed: \(error)")
        }
        phase = .celebrating
        dependencies.soundEngine.play(.starEarned)
        dependencies.hapticsService.playSuccess()
    }

    var nextSheet: WordSearchSheet? { WordSearchWordBank.sheet(number: sheet.number + 1) }

    func nextTapped() {
        guard let next = nextSheet else { backToMap(); return }
        dependencies.soundEngine.play(.tapPop)
        var path = dependencies.appState.navigationPath
        path.removeLast()
        path.append(.wordSearchSheet(next.number))
        dependencies.appState.navigationPath = path
    }

    func playAgainTapped() {
        dependencies.soundEngine.play(.tapPop)
        puzzle = engine.makePuzzle(sheet: sheet, seed: engine.nextSeed(for: sheet.number, after: puzzle.seed))
        foundWords = []
        foundCells = [:]
        selection = []
        hintCell = nil
        hintWord = nil
        hintsUsed = 0
        lastFound = nil
        phase = .playing
    }

    func backToMap() {
        dependencies.appState.navigationPath.removeLast()
    }
}

struct WordSearchPlayView: View {
    @State var viewModel: WordSearchPlayViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// The widest the puzzle column grows on a big screen. Beyond this the
    /// cells stop being letters and start being tiles.
    private static let puzzleColumnWidth: CGFloat = 560
    private static let wordColumnWidth: CGFloat = 300

    var body: some View {
        GeometryReader { proxy in
            // §22: iPad landscape puts the puzzle left and the words right;
            // everything else stacks. Phones are portrait-only, so the
            // width check only ever fires on an iPad.
            let sideBySide = sizeClass == .regular && proxy.size.width > proxy.size.height
            ZStack {
                background.ignoresSafeArea()

                if sideBySide {
                    landscape(height: proxy.size.height)
                } else {
                    portrait
                }

                if viewModel.phase == .celebrating {
                    celebration
                }
            }
        }
        .navigationTitle(String(localized: "Page \(viewModel.sheet.number)"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.hintTapped()
                } label: {
                    Label(String(localized: "Hint"), systemImage: "lightbulb.fill")
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                }
                .disabled(viewModel.phase != .playing)
                .accessibilityHint(String(localized: "Shows the first letter of a word"))
            }
        }
    }

    private var background: some View {
        WordSearchSceneBackground(sheet: viewModel.sheet)
    }

    // MARK: Layouts

    private var portrait: some View {
        ScrollView {
            VStack(spacing: 14) {
                titleBlock
                puzzlePanel
                wordList(singleColumn: false)
            }
            .frame(maxWidth: Self.puzzleColumnWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, ForestTheme.Metrics.screenPadding)
            .padding(.bottom, 24)
        }
    }

    /// The puzzle column is sized to the height so the whole grid is on
    /// screen without scrolling: the title block, the panel's own padding
    /// and the margins take about 260pt of it.
    private func landscape(height: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 24) {
            ScrollView {
                VStack(spacing: 14) {
                    titleBlock
                    puzzlePanel
                }
                .frame(maxWidth: min(Self.puzzleColumnWidth, height - 260))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            }
            ScrollView {
                wordList(singleColumn: true)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .frame(width: Self.wordColumnWidth)
        }
        .padding(.horizontal, ForestTheme.Metrics.screenPadding)
    }

    // MARK: Title

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(String(localized: "LEVEL \(viewModel.sheet.number)"))
                .font(ForestTheme.Fonts.caption)
                .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.7))
            Text(viewModel.sheet.title.uppercased())
                .font(ForestTheme.Fonts.title)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .multilineTextAlignment(.center)
            Text(viewModel.sheet.stage.localizedInstruction)
                .font(ForestTheme.Fonts.caption)
                .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.8))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        // The sign board from the templates: a cream plaque so the title
        // reads on a dark scene (the deep woods swallowed it otherwise).
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ForestTheme.Colors.cloudWhite.opacity(0.82))
        )
        .padding(.top, 8)
    }

    // MARK: Grid

    /// The mascot leans on the panel's top-right corner, per the spec's
    /// "outside the panel, not inside it", and reacts to play through
    /// `mascotState`.
    /// Big grids get a slimmer panel so a 10×10 keeps ~31pt cells on a
    /// phone — under the spec's 48pt ideal, but the drag snaps to a line
    /// so the finger need not land on the cell.
    private var puzzlePanel: some View {
        WordSearchGridView(viewModel: viewModel)
            .padding(viewModel.puzzle.size >= 9 ? 6 : 12)
            .forestCard(cornerRadius: 22)
            .overlay(alignment: .topTrailing) {
                GeometryReader { panel in
                    WordSearchMascotHop(trigger: reduceMotion ? 0 : viewModel.sparkleTrigger,
                                        dropDistance: panel.size.height - 40) {
                        WordSearchMascotView(sheet: viewModel.sheet, state: viewModel.mascotState)
                    }
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                    .offset(x: 10, y: -40)
                    .floating(amplitude: 4, period: 3)
                }
            }
            .padding(.top, 16)
    }

    // MARK: Word list

    private func wordList(singleColumn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "WORDS TO FIND"))
                .font(ForestTheme.Fonts.body)
                .foregroundStyle(ForestTheme.Colors.deepGreen)

            // A word never breaks across lines — WHIS-TLE is not a word a
            // child can read — so long words get one column and the rest
            // shrink a little rather than wrap.
            let longWords = viewModel.words.contains { $0.text.count >= 8 }
            LazyVGrid(columns: singleColumn || longWords ? [GridItem(.flexible())]
                                                          : [GridItem(.adaptive(minimum: 150), spacing: 8)],
                      spacing: 8) {
                ForEach(viewModel.words) { word in
                    wordRow(word)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .forestCard(cornerRadius: 22)
    }

    private func wordRow(_ word: WordSearchWord) -> some View {
        let found = viewModel.isFound(word.text)
        return HStack(spacing: 8) {
            WordSearchWordPicture(word: word)
            Text(word.text)
                .font(ForestTheme.Fonts.body)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(found ? ForestTheme.Colors.deepGreen.opacity(0.55) : ForestTheme.Colors.deepGreen)
                .strikethrough(found, color: ForestTheme.Colors.deepGreen)
            Spacer(minLength: 0)
            if found {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ForestTheme.Colors.leafGreen)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(found ? viewModel.color(for: word.text).opacity(0.35) : ForestTheme.Colors.cloudWhite.opacity(0.6))
        )
        .scaleEffect(viewModel.lastFound == word.text && !reduceMotion ? 1.06 : 1)
        .animation(.bouncy(duration: 0.5), value: viewModel.lastFound)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(found ? String(localized: "\(word.text), found") : word.text)
    }

    // MARK: Celebration

    /// The confetti is a `UIViewRepresentable` whose ideal width is the
    /// animation's own, wider than a phone. Left unconstrained it grew the
    /// whole layer past the screen, the layer sat at the leading edge, and
    /// everything centred in it — the Next Level button included — moved
    /// right of where it was drawn. Hence the fixed width and the pin.
    private var celebration: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14) {
                LottieView(animation: .confettiBig, loopMode: .playOnce)
                    .frame(width: 240, height: 120)
                    .clipped()
                    .accessibilityHidden(true)
                Text(String(localized: "GREAT JOB!"))
                    .font(ForestTheme.Fonts.hero)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                Text(String(localized: "You found them all!"))
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                Text(String(repeating: "⭐", count: viewModel.starsEarned))
                    .font(.system(size: 40))
                    .accessibilityLabel(String(localized: "\(viewModel.starsEarned) stars"))
                WordSearchMascotView(sheet: viewModel.sheet, state: .celebrate, size: 64)

                if viewModel.nextSheet != nil {
                    BigBouncyButton(title: String(localized: "Next Level"), icon: "arrow.right") {
                        viewModel.nextTapped()
                    }
                } else {
                    BigBouncyButton(title: String(localized: "Back to map"), icon: "map") {
                        viewModel.backToMap()
                    }
                }
                Button(String(localized: "Play again")) { viewModel.playAgainTapped() }
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
            }
            .padding(28)
            .frame(maxWidth: 420)
            .forestCard()
            .padding(ForestTheme.Metrics.screenPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }
}

// MARK: - The grid

struct WordSearchGridView: View {
    let viewModel: WordSearchPlayViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: CGFloat { viewModel.puzzle.size >= 9 ? 3 : 4 }

    var body: some View {
        GeometryReader { proxy in
            let size = viewModel.puzzle.size
            let side = (proxy.size.width - spacing * CGFloat(size - 1)) / CGFloat(size)

            ZStack {
                VStack(spacing: spacing) {
                    ForEach(0..<size, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<size, id: \.self) { column in
                                cell(WordSearchCell(row: row, column: column), side: side)
                            }
                        }
                    }
                }

                // §15: the sparkle bursts from the middle of the run just
                // found. The view lives in the tree from the start — it
                // fires on a *change* of the trigger, so one inserted at
                // the first find would miss it.
                SparkleBurstView(trigger: viewModel.sparkleTrigger)
                    .position(sparkleOrigin(side: side, size: size))
                    // Its rays sit visible at rest; keep them hidden until
                    // the first find so the grid doesn't wear a star.
                    .opacity(viewModel.sparkleTrigger > 0 ? 1 : 0)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let cell = cellAt(value.location, side: side, size: size)
                        if viewModel.selection.isEmpty {
                            viewModel.dragBegan(at: cell)
                        } else {
                            viewModel.dragMoved(to: cell)
                        }
                    }
                    .onEnded { _ in viewModel.dragEnded() }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .gentleShake(trigger: viewModel.wrongFlash)
    }

    private func sparkleOrigin(side: CGFloat, size: Int) -> CGPoint {
        let pitch = side + spacing
        guard let word = viewModel.foundWords.last, let cells = viewModel.foundCells[word],
              let middle = cells.dropFirst(cells.count / 2).first
        else { return CGPoint(x: pitch * CGFloat(size) / 2, y: pitch * CGFloat(size) / 2) }
        return CGPoint(x: CGFloat(middle.column) * pitch + side / 2, y: CGFloat(middle.row) * pitch + side / 2)
    }

    private func cellAt(_ point: CGPoint, side: CGFloat, size: Int) -> WordSearchCell {
        let pitch = side + spacing
        let column = min(max(Int(point.x / pitch), 0), size - 1)
        let row = min(max(Int(point.y / pitch), 0), size - 1)
        return WordSearchCell(row: row, column: column)
    }

    private func cell(_ cell: WordSearchCell, side: CGFloat) -> some View {
        let letter = viewModel.puzzle.letter(at: cell).map(String.init) ?? ""
        let selected = viewModel.selection.contains(cell)
        let foundWord = viewModel.foundWord(at: cell)
        let isHint = viewModel.hintCell == cell
        let fill: Color = if selected { ForestTheme.Colors.skyBlue }
            else if let foundWord { viewModel.color(for: foundWord) }
            else if isHint { ForestTheme.Colors.sunshine }
            else { ForestTheme.Colors.cloudWhite }

        return Text(letter)
            .font(.system(size: max(14, side * 0.55), weight: .heavy, design: .rounded))
            .foregroundStyle(ForestTheme.Colors.deepGreen)
            .frame(width: side, height: side)
            .background(
                RoundedRectangle(cornerRadius: side * 0.22, style: .continuous)
                    .fill(fill)
                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            )
            .scaleEffect(selected && !reduceMotion ? 1.08 : 1)
            .animation(.bouncy(duration: 0.25), value: selected)
            .animation(.easeOut(duration: 0.3), value: foundWord)
            .accessibilityLabel(letter)
    }
}

// MARK: - Palette

extension WordSearchPalette {
    /// One tint per theme family until painted scenes arrive.
    var tint: Color {
        switch self {
        case .meadow, .harvest: ForestTheme.Colors.leafGreen
        case .farm, .construction: ForestTheme.Colors.sunshine
        case .ocean, .river, .arctic: ForestTheme.Colors.skyBlue
        case .prehistoric, .savanna, .autumn: ForestTheme.Colors.peach
        case .space, .cave, .robot: ForestTheme.Colors.lavender
        case .jungle, .enchanted, .mountain: ForestTheme.Colors.mint
        case .city, .railway: Color(red: 0.75, green: 0.8, blue: 0.9)
        case .beach, .tropical: Color(red: 1.0, green: 0.88, blue: 0.6)
        case .winter: Color(red: 0.85, green: 0.93, blue: 1.0)
        case .fantasy, .celebration, .rescue: ForestTheme.Colors.bubblegum
        }
    }
}
