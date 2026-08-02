//
//  PuzzleRunView.swift
//  Focus Forest Adventure
//
//  Plays one chapter: a character sets the scene, then the puzzles, then the
//  celebration (and, after a boss, the world's crystal).
//
//  All three phases live in a single navigation destination — same reason as
//  MissionContainerView: swapping path entries mid-transition wedges
//  NavigationStack.
//
//  A wrong tap costs nothing but a shake, the hint is one tap away, and after
//  three misses the character fills the answer in and the story moves on. A
//  child can be stuck, but never stopped.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class PuzzleRunViewModel {

    enum Phase: Equatable { case story, playing, summary }

    private let dependencies: AppDependencies
    let run: PuzzleRun

    private(set) var phase: Phase = .story
    private(set) var index = 0
    private(set) var missedTaps = 0
    private(set) var usedHint = false
    private(set) var showingHint = false
    /// Set once the puzzle is answered — drives the "answer drops in" reveal.
    private(set) var solvedGlyph: PuzzleGlyph?
    private(set) var isAdvancing = false
    var shakingID: UUID?
    /// Hidden-object progress: tiles already found on this puzzle.
    private(set) var foundIDs: Set<UUID> = []
    /// Maze progress: the route walked so far.
    private(set) var path: [UUID] = []
    /// Assembly progress: slots already holding their piece, and the pieces
    /// that went into them.
    private(set) var filledSlotIDs: Set<UUID> = []
    private(set) var usedPieceIDs: Set<UUID> = []
    /// The piece the child has picked up.
    private(set) var selectedPieceID: UUID?
    /// Pipe puzzles: the board as it stands, since turning tiles changes it.
    private(set) var workingGrid: PuzzleGrid?
    private(set) var floodedIDs: Set<UUID> = []
    /// Memory puzzles: true once the peek has elapsed and the board is
    /// face down.
    private(set) var isBoardCovered = false
    private var peekTask: Task<Void, Never>?

    private(set) var completion: PuzzleRunCompletion?
    private var attempts: [PuzzleAttempt] = []
    private var startedAt = Date()

    /// Misses before the character quietly solves it and moves on.
    private let mercyMissLimit = 3

    init(run: PuzzleRun, dependencies: AppDependencies) {
        self.run = run
        self.dependencies = dependencies
    }

    // MARK: Story

    var story: WorldStory { run.world.story }
    var character: StoryCharacter? { story.character(forLevel: run.level) }

    var chapterTitle: String {
        run.isBoss ? story.bossTitle : (run.chapter?.title ?? run.world.localizedTitle)
    }

    var chapterBlurb: String {
        run.isBoss ? story.bossPremise : (run.chapter?.blurb ?? story.quest)
    }

    var puzzle: Puzzle { run.puzzles[min(index, run.puzzles.count - 1)] }

    /// The board to draw: the working copy for pipe puzzles (which the child
    /// is rearranging), the puzzle's own grid for everything else.
    var displayGrid: PuzzleGrid { workingGrid ?? puzzle.grid }
    var progress: Double { Double(index) / Double(max(run.puzzles.count, 1)) }
    var puzzleNumber: Int { index + 1 }
    var puzzleCount: Int { run.puzzles.count }

    func onAppear() async {
        guard phase == .story else { return }
        let line = character.map { "\($0.name). \($0.greeting)" } ?? chapterBlurb
        await dependencies.speechService.speak(line)
    }

    func beginTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        phase = .playing
        startedAt = Date()
        preparePipesIfNeeded()
        startPeekIfNeeded()
        Task { await dependencies.speechService.speak(puzzle.prompt) }
    }

    /// Memory puzzles show the board, then cover it. The clock for *this*
    /// puzzle only starts once the board goes down — looking isn't answering.
    private func startPeekIfNeeded() {
        peekTask?.cancel()
        isBoardCovered = false
        guard let peek = puzzle.peekDuration else { return }
        peekTask = Task { [weak self] in
            await self?.dependencies.speechService.speak(String(localized: "Look carefully…"))
            try? await Task.sleep(for: .seconds(peek))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.isBoardCovered = true
            self.startedAt = Date()
            self.dependencies.soundEngine.play(.cardFlip)
            await self.dependencies.speechService.speak(self.puzzle.prompt)
        }
    }

    func onDisappear() {
        peekTask?.cancel()
        peekTask = nil
    }

    /// The board is only tappable in the tap-the-board modes, and never
    /// during a peek.
    var isBoardTappable: Bool {
        guard !isAdvancing else { return false }
        switch puzzle.answerMode {
        case .tapTile, .tapMany, .tapPath: return puzzle.peekDuration == nil || isBoardCovered
        // Slots are tappable once a piece has been picked up.
        case .assemble: return selectedPieceID != nil
        case .rotateTiles: return true
        case .options: return false
        }
    }

    /// How far the water has got, so there's always visible progress.
    var pipeProgress: String? {
        guard puzzle.answerMode == .rotateTiles else { return nil }
        let pipes = displayGrid.tiles.filter { $0.pipe != nil }.count
        guard pipes > 0 else { return nil }
        return String(localized: "💧 \(floodedIDs.count) of \(pipes) pipes joined")
    }

    /// "Pick a piece" → "Now tap where it goes" — assembly needs a running
    /// instruction, like the maze does.
    var assembleInstruction: String? {
        guard puzzle.answerMode == .assemble else { return nil }
        if selectedPieceID != nil { return String(localized: "Now tap where it goes!") }
        let left = puzzle.correctIDs.count - filledSlotIDs.count
        return left == puzzle.correctIDs.count
            ? String(localized: "Pick a piece to start!")
            : String(localized: "\(left) more to place")
    }

    /// "Tap the start" → "Keep going!" — the maze needs a running instruction
    /// more than a static prompt.
    var mazeInstruction: String? {
        guard puzzle.answerMode == .tapPath else { return nil }
        if path.isEmpty { return String(localized: "Tap 🏁 to begin!") }
        let keysLeft = puzzle.grid.tiles.filter { $0.role == .key && !path.contains($0.id) }
        if !keysLeft.isEmpty { return String(localized: "Get the 🔑 first!") }
        return String(localized: "Now reach the 🏆!")
    }

    /// True when the child has walked into a dead end. Backing up is free.
    var isStuckInMaze: Bool {
        guard puzzle.answerMode == .tapPath, !path.isEmpty, !isAdvancing else { return false }
        return !MazeRules.hasRouteRemaining(path: path, in: puzzle.grid)
    }

    /// Undo one step — a maze must never need restarting from scratch.
    func stepBack() {
        guard !path.isEmpty, !isAdvancing else { return }
        path.removeLast()
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
    }

    /// "3 of 5 found" for the hidden-object hunt.
    var foundProgress: String? {
        guard puzzle.answerMode == .tapMany else { return nil }
        return String(localized: "\(foundIDs.count) of \(puzzle.targetCount) found")
    }

    // MARK: Playing

    func hintTapped() {
        guard !showingHint else { return }
        usedHint = true
        showingHint = true
        dependencies.hapticsService.playGentleTap()
        Task { await dependencies.speechService.speak(puzzle.hint) }
    }

    /// Single entry point for both answer modes — correctness is one id
    /// comparison either way.
    func answerTapped(id: UUID, glyph: PuzzleGlyph?) async {
        guard !isAdvancing, phase == .playing else { return }

        // Hunts and mazes take many taps before the puzzle is done; every
        // other kind is decided by one.
        if puzzle.answerMode == .tapMany {
            await handleHunt(id: id)
            return
        }
        if puzzle.answerMode == .tapPath {
            await handleStep(id: id)
            return
        }
        if puzzle.answerMode == .assemble {
            await handleSlot(id: id)
            return
        }
        if puzzle.answerMode == .rotateTiles {
            await handleTurn(id: id)
            return
        }
        if puzzle.correctIDs.contains(id) {
            await handleCorrect(revealing: glyph)
        } else {
            await handleMiss(id: id)
        }
    }

    private func handleHunt(id: UUID) async {
        guard puzzle.correctIDs.contains(id) else {
            await handleMiss(id: id)
            return
        }
        guard !foundIDs.contains(id) else { return }   // tapping a found one is free
        foundIDs.insert(id)
        dependencies.soundEngine.play(.tapPop)
        dependencies.hapticsService.playGentleTap()

        guard foundIDs.count >= puzzle.targetCount else { return }
        isAdvancing = true
        dependencies.soundEngine.play(.correctChime)
        dependencies.hapticsService.playSuccess()
        recordAttempt(solved: true)
        await dependencies.speechService.speak(character?.cheer ?? BunnyPhrase.correct.text)
        try? await Task.sleep(for: .seconds(0.9))
        await advance()
    }

    private func handleCorrect(revealing glyph: PuzzleGlyph?) async {
        isAdvancing = true
        solvedGlyph = glyph ?? correctGlyph()
        dependencies.soundEngine.play(.correctChime)
        dependencies.hapticsService.playSuccess()
        recordAttempt(solved: true)
        await dependencies.speechService.speak(character?.cheer ?? BunnyPhrase.correct.text)
        try? await Task.sleep(for: .seconds(0.9))
        await advance()
    }

    private func handleMiss(id: UUID) async {
        missedTaps += 1
        shakingID = id
        dependencies.soundEngine.play(.gentleTryAgain)
        dependencies.hapticsService.playGentleTap()

        if missedTaps >= mercyMissLimit {
            // Third miss: show the answer, praise the effort, move on.
            isAdvancing = true
            solvedGlyph = correctGlyph()
            // A hunt has no single answer to drop in — uncover what's left.
            if puzzle.answerMode == .tapMany { foundIDs = puzzle.correctIDs }
            recordAttempt(solved: false)
            await dependencies.speechService.speak(
                String(localized: "Here it is! Let's do the next one together.")
            )
            try? await Task.sleep(for: .seconds(1.2))
            await advance()
        } else {
            await dependencies.speechService.speak(BunnyPhrase.gentleRetry.text)
            try? await Task.sleep(for: .seconds(0.4))
            shakingID = nil
        }
    }

    /// One step of a maze. Stepping back onto the previous cell is an undo,
    /// not a mistake — a child exploring a route shouldn't be told off for it.
    private func handleStep(id: UUID) async {
        if path.count >= 2, path[path.count - 2] == id {
            stepBack()
            return
        }
        guard MazeRules.canStep(to: id, path: path, in: puzzle.grid) else {
            let tile = puzzle.grid.tiles.first { $0.id == id }
            if tile?.role == .hazard {
                // Walking into the fire is a real mistake.
                await handleMiss(id: id)
            } else {
                // Reaching for a square that isn't next door isn't a wrong
                // answer, it's a mis-tap — shake, but don't count it.
                shakingID = id
                dependencies.hapticsService.playGentleTap()
                try? await Task.sleep(for: .seconds(0.3))
                shakingID = nil
            }
            return
        }
        path.append(id)
        dependencies.soundEngine.play(.tapPop)
        dependencies.hapticsService.playGentleTap()

        guard MazeRules.isComplete(path: path, in: puzzle.grid) else { return }
        isAdvancing = true
        dependencies.soundEngine.play(.correctChime)
        dependencies.hapticsService.playSuccess()
        recordAttempt(solved: true)
        await dependencies.speechService.speak(character?.cheer ?? BunnyPhrase.correct.text)
        try? await Task.sleep(for: .seconds(0.9))
        await advance()
    }

    // MARK: Pipes

    /// Turning a pipe is never wrong — there's nothing to get wrong, only a
    /// board that isn't joined up yet. So no tap here counts as a miss.
    private func handleTurn(id: UUID) async {
        let grid = PipeRules.rotating(displayGrid, tileID: id)
        workingGrid = grid
        floodedIDs = PipeRules.flooded(grid)
        dependencies.soundEngine.play(.tapPop)
        dependencies.hapticsService.playGentleTap()

        guard PipeRules.isConnected(grid) else { return }
        isAdvancing = true
        dependencies.soundEngine.play(.correctChime)
        dependencies.hapticsService.playSuccess()
        recordAttempt(solved: true)
        await dependencies.speechService.speak(character?.cheer ?? BunnyPhrase.correct.text)
        try? await Task.sleep(for: .seconds(1.1))
        await advance()
    }

    /// Pipe puzzles need their working board (and the water) set up before
    /// the first tap.
    private func preparePipesIfNeeded() {
        guard puzzle.answerMode == .rotateTiles else {
            workingGrid = nil
            floodedIDs = []
            return
        }
        workingGrid = puzzle.grid
        floodedIDs = PipeRules.flooded(puzzle.grid)
    }

    // MARK: Assembly

    /// Picking a piece up is free — tapping a second piece just swaps which
    /// one is in hand, and tapping the one you're holding puts it back.
    func pieceTapped(_ option: PuzzleOption) {
        guard puzzle.answerMode == .assemble, !isAdvancing else { return }
        guard !usedPieceIDs.contains(option.id) else { return }
        selectedPieceID = selectedPieceID == option.id ? nil : option.id
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
    }

    func isPieceUsed(_ option: PuzzleOption) -> Bool { usedPieceIDs.contains(option.id) }
    func isPieceSelected(_ option: PuzzleOption) -> Bool { selectedPieceID == option.id }

    /// Dropping the held piece into a space. A piece that doesn't belong
    /// there bounces back into the bank rather than being taken away.
    private func handleSlot(id: UUID) async {
        guard let pieceID = selectedPieceID,
              let piece = puzzle.options.first(where: { $0.id == pieceID }),
              let slot = puzzle.grid.tiles.first(where: { $0.id == id }),
              slot.role == .slot,
              !filledSlotIDs.contains(id)
        else { return }

        guard slot.glyph == piece.glyph else {
            missedTaps += 1
            shakingID = id
            selectedPieceID = nil
            dependencies.soundEngine.play(.gentleTryAgain)
            dependencies.hapticsService.playGentleTap()
            await dependencies.speechService.speak(BunnyPhrase.gentleRetry.text)
            try? await Task.sleep(for: .seconds(0.4))
            shakingID = nil
            return
        }

        filledSlotIDs.insert(id)
        usedPieceIDs.insert(pieceID)
        selectedPieceID = nil
        dependencies.soundEngine.play(.tapPop)
        dependencies.hapticsService.playGentleTap()

        guard filledSlotIDs.count >= puzzle.correctIDs.count else { return }
        isAdvancing = true
        dependencies.soundEngine.play(.correctChime)
        dependencies.hapticsService.playSuccess()
        recordAttempt(solved: true)
        await dependencies.speechService.speak(character?.cheer ?? BunnyPhrase.correct.text)
        try? await Task.sleep(for: .seconds(0.9))
        await advance()
    }

    private func correctGlyph() -> PuzzleGlyph? {
        puzzle.options.first { puzzle.correctIDs.contains($0.id) }?.glyph
            ?? puzzle.grid.tiles.first { puzzle.correctIDs.contains($0.id) }?.glyph
    }

    private func recordAttempt(solved: Bool) {
        attempts.append(
            PuzzleAttempt(
                kind: puzzle.kind,
                skill: puzzle.skill,
                solved: solved,
                missedTaps: missedTaps,
                duration: Date().timeIntervalSince(startedAt),
                usedHint: usedHint,
                timeLimit: puzzle.timeLimit
            )
        )
    }

    private func advance() async {
        if index + 1 < run.puzzles.count {
            index += 1
            missedTaps = 0
            usedHint = false
            showingHint = false
            solvedGlyph = nil
            shakingID = nil
            foundIDs = []
            path = []
            filledSlotIDs = []
            usedPieceIDs = []
            selectedPieceID = nil
            startedAt = Date()
            isAdvancing = false
            preparePipesIfNeeded()
            startPeekIfNeeded()
            if puzzle.peekDuration == nil {
                await dependencies.speechService.speak(puzzle.prompt)
            }
        } else {
            await finish()
        }
    }

    private func finish() async {
        phase = .summary
        dependencies.soundEngine.play(run.isBoss ? .chestOpen : .starEarned)
        do {
            let child = try dependencies.childRepository.activeChild()
            completion = try dependencies.completePuzzleRunUseCase.execute(
                run: run,
                attempts: attempts,
                child: child,
                age: dependencies.appState.settings.childAge,
                preference: dependencies.appState.settings.preferredDifficulty
            )
        } catch {
            // Child-facing surfaces never show errors — the celebration still
            // plays, it just isn't backed by a saved result.
            assertionFailure("Puzzle run completion failed: \(error)")
        }
        await dependencies.speechService.speak(completion?.storyLine ?? BunnyPhrase.celebration.text)
    }

    /// One way out: back to the Brainland map, which now offers the next
    /// chapter. (Starting the next run from here would mean swapping the top
    /// path entry mid-transition — the NavigationStack wedge this app avoids.)
    func doneTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        if !dependencies.appState.navigationPath.isEmpty {
            dependencies.appState.navigationPath.removeLast()
        }
    }
}

// MARK: - View

struct PuzzleRunView: View {
    @State var viewModel: PuzzleRunViewModel

    var body: some View {
        ZStack {
            ForestSceneBackground(place: viewModel.run.world.place, legibility: 0.24)

            switch viewModel.phase {
            case .story: PuzzleStoryCard(viewModel: viewModel)
            case .playing: playing
            case .summary: PuzzleSummaryView(viewModel: viewModel)
            }
        }
        .navigationTitle(viewModel.chapterTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    private var playing: some View {
        let puzzle = viewModel.puzzle
        return ScrollView {
            VStack(spacing: 18) {
                header

                Text(puzzle.prompt)
                    .font(ForestTheme.Fonts.heading)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .accessibilityAddTraits(.isHeader)

                if !puzzle.legend.isEmpty {
                    PuzzleLegendView(entries: puzzle.legend)
                }

                if let found = viewModel.foundProgress {
                    Text(found)
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.8))
                        .monospacedDigit()
                } else if let progress = viewModel.pipeProgress {
                    Text(progress)
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.85))
                        .monospacedDigit()
                } else if let instruction = viewModel.assembleInstruction {
                    Text(instruction)
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.85))
                } else if let instruction = viewModel.mazeInstruction {
                    Text(instruction)
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.85))
                } else if puzzle.peekDuration != nil && !viewModel.isBoardCovered {
                    Label(String(localized: "Remember the board!"), systemImage: "eye.fill")
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.8))
                }

                PuzzleGridView(
                    grid: viewModel.displayGrid,
                    onTapTile: viewModel.isBoardTappable
                        ? { tile in Task { await viewModel.answerTapped(id: tile.id, glyph: tile.glyph) } }
                        : nil,
                    shakingID: viewModel.shakingID,
                    solvedGlyph: viewModel.solvedGlyph,
                    isCovered: viewModel.isBoardCovered,
                    foundIDs: viewModel.foundIDs,
                    path: viewModel.path,
                    filledSlotIDs: viewModel.filledSlotIDs,
                    floodedIDs: viewModel.floodedIDs
                )
                .padding(.horizontal, 4)

                if puzzle.answerMode == .tapPath && !viewModel.path.isEmpty {
                    mazeControls
                }

                if puzzle.answerMode == .assemble {
                    pieceBank(puzzle: puzzle)
                }

                // Memory puzzles hold their chips back until the board is
                // covered — otherwise the answer is just sitting there.
                if puzzle.answerMode == .options,
                   puzzle.peekDuration == nil || viewModel.isBoardCovered {
                    PuzzleOptionsView(
                        options: puzzle.options,
                        onTap: { option in
                            Task { await viewModel.answerTapped(id: option.id, glyph: option.glyph) }
                        },
                        shakingID: viewModel.shakingID,
                        isLocked: viewModel.isAdvancing
                    )
                }

                hintRow(puzzle: puzzle)
            }
            .padding(ForestTheme.Metrics.screenPadding)
            .adaptiveContentWidth(720)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(viewModel.character?.emoji ?? viewModel.run.world.emoji)
                .font(.system(size: 30))
            ForestProgressBar(progress: viewModel.progress, label: viewModel.puzzle.title)
            Text("\(viewModel.puzzleNumber)/\(viewModel.puzzleCount)")
                .font(ForestTheme.Fonts.caption)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(localized: "\(viewModel.puzzle.title), puzzle \(viewModel.puzzleNumber) of \(viewModel.puzzleCount)")
        )
    }

    /// The bank of pieces waiting to be placed. A used piece stays visible
    /// but greyed, so the child can see how far they've got.
    private func pieceBank(puzzle: Puzzle) -> some View {
        FlowLayout(spacing: 12) {
            ForEach(puzzle.options) { option in
                Button {
                    viewModel.pieceTapped(option)
                } label: {
                    Group {
                        if let glyph = option.glyph {
                            PuzzleGlyphView(glyph: glyph, size: 44)
                        }
                    }
                    .frame(width: 74, height: 74)
                    .background(
                        viewModel.isPieceSelected(option)
                            ? ForestTheme.Colors.sunshine.opacity(0.5)
                            : ForestTheme.Colors.cloudWhite
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                viewModel.isPieceSelected(option)
                                    ? ForestTheme.Colors.deepGreen.opacity(0.8)
                                    : .black.opacity(0.08),
                                lineWidth: viewModel.isPieceSelected(option) ? 3 : 1
                            )
                    )
                    .opacity(viewModel.isPieceUsed(option) ? 0.3 : 1)
                }
                .buttonStyle(SquishyButtonStyle())
                .disabled(viewModel.isPieceUsed(option))
                .accessibilityLabel(pieceLabel(option))
            }
        }
        .padding(.horizontal, 8)
    }

    private func pieceLabel(_ option: PuzzleOption) -> String {
        if viewModel.isPieceUsed(option) {
            return String(localized: "\(option.accessibilityLabel), already placed")
        }
        if viewModel.isPieceSelected(option) {
            return String(localized: "\(option.accessibilityLabel), in your hand")
        }
        return option.accessibilityLabel
    }

    /// Backing up is always available and never framed as a failure — a maze
    /// should never need starting over.
    private var mazeControls: some View {
        VStack(spacing: 8) {
            if viewModel.isStuckInMaze {
                Text(String(localized: "That way's blocked — step back and try another way!"))
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            Button {
                viewModel.stepBack()
            } label: {
                Label(String(localized: "Step Back"), systemImage: "arrow.uturn.backward")
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .forestCard(cornerRadius: 16)
            }
            .buttonStyle(SquishyButtonStyle())
        }
    }

    @ViewBuilder
    private func hintRow(puzzle: Puzzle) -> some View {
        VStack(spacing: 10) {
            if viewModel.showingHint {
                Text(puzzle.hint)
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .forestCard(cornerRadius: 18)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(.bouncy(duration: 0.4)) { viewModel.hintTapped() }
                } label: {
                    Label(String(localized: "Hint"), systemImage: "lightbulb.fill")
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .forestCard(cornerRadius: 18)
                }
                .buttonStyle(SquishyButtonStyle())
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Story card

struct PuzzleStoryCard: View {
    let viewModel: PuzzleRunViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(viewModel.character?.emoji ?? viewModel.run.world.emoji)
                    .font(.system(size: 76))
                    .floating(amplitude: 6, period: 2.4)

                if viewModel.run.isBoss {
                    Label(String(localized: "Boss Puzzle"), systemImage: "flame.fill")
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.peach)
                }

                Text(viewModel.chapterTitle)
                    .font(ForestTheme.Fonts.title)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                if let character = viewModel.character {
                    SpeechBubble(text: character.greeting)
                        .padding(.horizontal, 8)
                    Text(character.name)
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.75))
                }

                Text(viewModel.chapterBlurb)
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                BigBouncyButton(
                    title: String(localized: "Let's Go!"),
                    icon: "sparkles",
                    color: ForestTheme.Colors.sunshine
                ) {
                    viewModel.beginTapped()
                }
                .padding(.top, 8)
            }
            .padding(ForestTheme.Metrics.screenPadding)
            .adaptiveContentWidth(560)
        }
    }
}

// MARK: - Summary

struct PuzzleSummaryView: View {
    let viewModel: PuzzleRunViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(viewModel.completion?.crystal?.emoji ?? "🎉")
                    .font(.system(size: 76))
                    .floating(amplitude: 6, period: 2.2)

                Text(headline)
                    .font(ForestTheme.Fonts.title)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                if let completion = viewModel.completion {
                    stars(completion.result.stars)

                    Text(completion.storyLine)
                        .font(ForestTheme.Fonts.body)
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    HStack(spacing: 18) {
                        Label("\(completion.result.gems)", systemImage: "diamond.fill")
                            .foregroundStyle(ForestTheme.Colors.skyBlue)
                        Label("\(completion.result.pieces)", systemImage: "puzzlepiece.fill")
                            .foregroundStyle(ForestTheme.Colors.leafGreen)
                    }
                    .font(ForestTheme.Fonts.body)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        String(localized: "\(completion.result.gems) gems and \(completion.result.pieces) puzzle pieces earned")
                    )

                    if let crystal = completion.crystal {
                        card {
                            Text(String(localized: "\(crystal.emoji) You won the \(crystal.localizedName)!"))
                        }
                    }

                    if !completion.newBadges.isEmpty {
                        badges(completion.newBadges)
                    }

                    if let unlocked = completion.unlockedWorld {
                        card {
                            Text(String(localized: "\(unlocked.emoji) \(unlocked.localizedTitle) is open!"))
                        }
                    }

                    if completion.finishedCampaign {
                        card {
                            Text(BrainlandStory.epilogue)
                        }
                    }
                }

                BigBouncyButton(
                    title: String(localized: "Back to the Map"),
                    icon: "map.fill",
                    color: ForestTheme.Colors.sunshine
                ) {
                    viewModel.doneTapped()
                }
                .padding(.bottom, 24)
            }
            .padding(ForestTheme.Metrics.screenPadding)
            .adaptiveContentWidth(560)
        }
    }

    private var headline: String {
        if viewModel.completion?.crystal != nil {
            return String(localized: "Crystal Won!")
        }
        return String(localized: "Chapter Complete!")
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(ForestTheme.Fonts.body)
            .foregroundStyle(ForestTheme.Colors.deepGreen)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .forestCard(cornerRadius: 18)
    }

    private func stars(_ count: Int) -> some View {
        HStack(spacing: 10) {
            ForEach(1...3, id: \.self) { position in
                Image(systemName: position <= count ? "star.fill" : "star")
                    .font(.system(size: 44))
                    .foregroundStyle(ForestTheme.Colors.sunshine)
                    .scaleEffect(position <= count ? 1 : 0.8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(count) of 3 stars"))
    }

    private func badges(_ badges: [PuzzleBadge]) -> some View {
        VStack(spacing: 8) {
            Text(String(localized: "New badge!"))
                .font(ForestTheme.Fonts.caption)
                .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.8))
            ForEach(badges, id: \.self) { badge in
                card {
                    HStack(spacing: 10) {
                        Text(badge.emoji).font(.system(size: 30))
                        Text(badge.localizedTitle)
                    }
                }
            }
        }
    }
}
