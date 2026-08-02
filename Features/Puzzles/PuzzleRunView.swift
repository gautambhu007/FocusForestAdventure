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
        Task { await dependencies.speechService.speak(puzzle.prompt) }
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
        if id == puzzle.correctID {
            await handleCorrect(revealing: glyph)
        } else {
            await handleMiss(id: id)
        }
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

    private func correctGlyph() -> PuzzleGlyph? {
        puzzle.options.first { $0.id == puzzle.correctID }?.glyph
            ?? puzzle.grid.tiles.first { $0.id == puzzle.correctID }?.glyph
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
            startedAt = Date()
            isAdvancing = false
            await dependencies.speechService.speak(puzzle.prompt)
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

                PuzzleGridView(
                    grid: puzzle.grid,
                    onTapTile: puzzle.answerMode == .tapTile
                        ? { tile in Task { await viewModel.answerTapped(id: tile.id, glyph: tile.glyph) } }
                        : nil,
                    shakingID: viewModel.shakingID,
                    solvedGlyph: viewModel.solvedGlyph
                )
                .padding(.horizontal, 4)

                if puzzle.answerMode == .options {
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
