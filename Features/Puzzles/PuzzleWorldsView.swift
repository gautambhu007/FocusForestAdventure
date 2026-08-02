//
//  PuzzleWorldsView.swift
//  Focus Forest Adventure
//
//  The Brainland map: nine worlds, the crystals won so far, and today's
//  challenge. Locked worlds stay visible with the reason they're locked —
//  a lock a child can read is a goal; a hidden world is nothing.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class PuzzleWorldsViewModel {

    private let dependencies: AppDependencies
    private(set) var snapshot = PuzzleProgressSnapshot()
    private(set) var isStarting = false
    /// Told once, on the child's first visit.
    private(set) var showsPrologue = false
    private(set) var today = DailyActivities(
        streakDays: 0, hasDailyPuzzle: false, dailyPuzzleDone: false,
        chestAvailable: false, chestOpened: false, isWeekend: false,
        weekendChallengeDone: false,
        todaysReward: PuzzleDailyEngine.ladder[0], nextReward: nil
    )
    /// Gems from the last chest, shown briefly.
    private(set) var chestPrize: Int?

    private static let prologueSeenKey = "puzzle.prologueSeen"

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var age: Int { dependencies.appState.settings.childAge }
    var gems: Int { snapshot.gems }
    var pieces: Int { snapshot.pieces }
    var totalStars: Int { snapshot.totalStars }
    var badges: [PuzzleBadge] { PuzzleBadge.allCases.filter { snapshot.badges.contains($0) } }
    var crystals: [MagicCrystal] { snapshot.earnedCrystals }
    var prologue: String { BrainlandStory.prologue }

    /// The seven story crystals, in order, with whether each is home yet.
    var crystalShelf: [(crystal: MagicCrystal, earned: Bool)] {
        BrainlandStory.keyCrystals.map { ($0, snapshot.hasCrystal($0.world)) }
    }

    func onAppear() async {
        refresh()
        if !UserDefaults.standard.bool(forKey: Self.prologueSeenKey) {
            showsPrologue = true
            await dependencies.speechService.speak(BrainlandStory.prologue)
        } else {
            await dependencies.speechService.speak(String(localized: "Where shall we explore today?"))
        }
    }

    func prologueDismissed() {
        showsPrologue = false
        UserDefaults.standard.set(true, forKey: Self.prologueSeenKey)
        dependencies.hapticsService.playGentleTap()
    }

    /// Re-read on every appearance so returning from a level shows the new
    /// chapter, gems, and crystals.
    func refresh() {
        do {
            let child = try dependencies.childRepository.activeChild()
            snapshot = try dependencies.puzzleRepository.snapshot(for: child)
        } catch {
            assertionFailure("Puzzle snapshot failed: \(error)")
            snapshot = PuzzleProgressSnapshot()
        }
        refreshToday()
    }

    private func refreshToday() {
        today = dependencies.puzzleDailyEngine.activities(
            streakDays: DailyStreak.current(),
            hasUnlockedWorld: !dependencies.puzzleProgressionEngine
                .unlockedWorlds(age: age, snapshot: snapshot).isEmpty,
            dailyPuzzleDone: DailyPuzzleLog.isDone(DailyPuzzleLog.dailyPuzzle),
            chestOpened: DailyPuzzleLog.isDone(DailyPuzzleLog.chest),
            weekendChallengeDone: DailyPuzzleLog.isDone(DailyPuzzleLog.weekend),
            date: .now
        )
    }

    var companionEmoji: String? { snapshot.companion?.emoji }

    // MARK: Daily activities

    func dailyPuzzleTapped() async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        do {
            let child = try dependencies.childRepository.activeChild()
            guard let run = try dependencies.startPuzzleRunUseCase.dailyRun(child: child, age: age) else { return }
            DailyPuzzleLog.markDone(DailyPuzzleLog.dailyPuzzle)
            dependencies.appState.navigationPath.append(.puzzleRun(run))
        } catch {
            assertionFailure("Daily puzzle failed: \(error)")
        }
    }

    func weekendChallengeTapped() async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        do {
            let child = try dependencies.childRepository.activeChild()
            guard let run = try dependencies.startPuzzleRunUseCase.weekendRun(child: child, age: age) else { return }
            DailyPuzzleLog.markDone(DailyPuzzleLog.weekend)
            dependencies.appState.navigationPath.append(.puzzleRun(run))
        } catch {
            assertionFailure("Weekend challenge failed: \(error)")
        }
    }

    /// The chest is opened, not won — it always contains something.
    func chestTapped() async {
        guard today.chestAvailable else { return }
        do {
            let child = try dependencies.childRepository.activeChild()
            let prize = dependencies.puzzleDailyEngine.chestReward(
                day: .now, streakDays: today.streakDays
            )
            try dependencies.puzzleRepository.awardGems(prize, to: child)
            DailyPuzzleLog.markDone(DailyPuzzleLog.chest)
            dependencies.hapticsService.playSuccess()
            dependencies.soundEngine.play(.chestOpen)
            refresh()
            chestPrize = prize
            await dependencies.speechService.speak(
                String(localized: "The chest had \(prize) gems inside!")
            )
            try? await Task.sleep(for: .seconds(1.8))
            chestPrize = nil
        } catch {
            assertionFailure("Chest failed: \(error)")
        }
    }

    func collectionTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        dependencies.appState.navigationPath.append(.puzzleCollection)
    }

    func isUnlocked(_ world: PuzzleWorld) -> Bool {
        dependencies.puzzleProgressionEngine.isUnlocked(world, age: age, snapshot: snapshot)
    }

    func lockReason(_ world: PuzzleWorld) -> String? {
        dependencies.puzzleProgressionEngine.lockReason(world, age: age, snapshot: snapshot)
    }

    func nextLevel(_ world: PuzzleWorld) -> Int {
        dependencies.puzzleProgressionEngine.nextLevel(in: world, snapshot: snapshot)
    }

    func isBossNext(_ world: PuzzleWorld) -> Bool {
        world.isBossLevel(nextLevel(world))
    }

    /// "Hidden Acorns" — what the next tap actually plays.
    func nextChapterTitle(_ world: PuzzleWorld) -> String {
        let level = nextLevel(world)
        if world.isBossLevel(level) { return world.story.bossTitle }
        return world.story.chapter(forLevel: level)?.title ?? world.localizedFocus
    }

    func progress(_ world: PuzzleWorld) -> Double {
        Double(snapshot.completed(world)) / Double(max(world.levelCount, 1))
    }

    func hasCrystal(_ world: PuzzleWorld) -> Bool { snapshot.hasCrystal(world) }

    func startTapped(_ world: PuzzleWorld) async {
        guard !isStarting, isUnlocked(world) else { return }
        isStarting = true
        defer { isStarting = false }
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)

        do {
            let child = try dependencies.childRepository.activeChild()
            let run = try dependencies.startPuzzleRunUseCase.execute(
                world: world,
                child: child,
                age: age,
                preference: dependencies.appState.settings.preferredDifficulty
            )
            dependencies.appState.navigationPath.append(.puzzleRun(run))
        } catch {
            assertionFailure("Puzzle run start failed: \(error)")
        }
    }
}

struct PuzzleWorldsView: View {
    @State var viewModel: PuzzleWorldsViewModel

    private let columns = [GridItem(.adaptive(minimum: 170, maximum: 260), spacing: 14)]

    var body: some View {
        ZStack {
            ForestSceneBackground(place: .magicGrove, legibility: 0.2)

            ScrollView {
                VStack(spacing: 16) {
                    Text(String(localized: "🧩 Brainland"))
                        .font(ForestTheme.Fonts.title)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .padding(.top, 12)
                        .accessibilityAddTraits(.isHeader)

                    crystalShelf
                    wallet
                    todayCard

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(PuzzleWorld.allCases, id: \.self) { world in
                            worldCard(world)
                        }
                    }

                    if !viewModel.badges.isEmpty {
                        badgeShelf
                    }
                }
                .padding(ForestTheme.Metrics.screenPadding)
                .adaptiveContentWidth(900)
            }

            if viewModel.showsPrologue {
                prologueOverlay
            }
            if let prize = viewModel.chestPrize {
                chestCelebration(prize)
            }
        }
        .navigationTitle(String(localized: "Puzzle Adventure"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.onAppear() }
        .onAppear { viewModel.refresh() }
    }

    // MARK: Story

    private var prologueOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("🌈🧙")
                    .font(.system(size: 64))
                    .floating(amplitude: 6, period: 2.4)
                Text(String(localized: "Brainland needs you!"))
                    .font(ForestTheme.Fonts.heading)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                Text(viewModel.prologue)
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.9))
                    .multilineTextAlignment(.center)
                BigBouncyButton(
                    title: String(localized: "I'll help!"),
                    icon: "sparkles",
                    color: ForestTheme.Colors.sunshine
                ) {
                    withAnimation(.smooth(duration: 0.4)) { viewModel.prologueDismissed() }
                }
            }
            .padding(24)
            .forestCard(cornerRadius: 28)
            .padding(28)
            .adaptiveContentWidth(520)
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }

    /// The seven crystals, dark until won — the campaign at a glance.
    private var crystalShelf: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.crystalShelf, id: \.crystal.id) { entry in
                Text(entry.crystal.emoji)
                    .font(.system(size: 26))
                    .opacity(entry.earned ? 1 : 0.25)
                    .saturation(entry.earned ? 1 : 0)
                    .accessibilityLabel(
                        entry.earned
                            ? String(localized: "\(entry.crystal.localizedName), won")
                            : String(localized: "\(entry.crystal.localizedName), not yet")
                    )
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .forestCard(cornerRadius: 20)
    }

    /// Today: the daily puzzle, the chest it opens, the streak, and (at the
    /// weekend) the long challenge. Nothing here expires with a timer — a
    /// missed day costs the streak bonus, never anything already earned.
    private var todayCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label(String(localized: "Today"), systemImage: "sun.max.fill")
                    .font(ForestTheme.Fonts.heading)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                Spacer()
                if viewModel.today.streakDays > 0 {
                    Text(String(localized: "🔥 \(viewModel.today.streakDays) day streak"))
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.8))
                }
            }

            streakLadder

            HStack(spacing: 10) {
                if viewModel.today.hasDailyPuzzle {
                    todayButton(
                        emoji: "🌞",
                        title: viewModel.today.dailyPuzzleDone
                            ? String(localized: "Played")
                            : String(localized: "Daily Puzzle"),
                        done: viewModel.today.dailyPuzzleDone
                    ) {
                        Task { await viewModel.dailyPuzzleTapped() }
                    }
                }

                todayButton(
                    emoji: "🎁",
                    title: viewModel.today.chestOpened
                        ? String(localized: "Opened")
                        : String(localized: "Mystery Chest"),
                    done: viewModel.today.chestOpened,
                    dimmed: !viewModel.today.chestAvailable && !viewModel.today.chestOpened
                ) {
                    Task { await viewModel.chestTapped() }
                }

                todayButton(emoji: "🎒", title: String(localized: "Collection"), done: false) {
                    viewModel.collectionTapped()
                }
            }

            if viewModel.today.isWeekend {
                Button {
                    Task { await viewModel.weekendChallengeTapped() }
                } label: {
                    Label(
                        viewModel.today.weekendChallengeDone
                            ? String(localized: "Weekend Challenge done — great work!")
                            : String(localized: "⭐️ Weekend Challenge — double gems!"),
                        systemImage: "star.circle.fill"
                    )
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ForestTheme.Colors.sunshine.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(SquishyButtonStyle())
                .disabled(viewModel.today.weekendChallengeDone)
            }

            if !viewModel.today.chestAvailable && !viewModel.today.chestOpened {
                Text(String(localized: "Finish today's puzzle to open the chest!"))
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.7))
            }
        }
        .padding(16)
        .forestCard(cornerRadius: 22)
    }

    private var streakLadder: some View {
        HStack(spacing: 6) {
            ForEach(PuzzleDailyEngine.ladder, id: \.day) { reward in
                let reached = reward.day <= ((viewModel.today.streakDays - 1) % 7) + 1
                    && viewModel.today.streakDays > 0
                VStack(spacing: 2) {
                    Text(reward.emoji)
                        .font(.system(size: 18))
                        .opacity(reached ? 1 : 0.3)
                    Text("\(reward.gems)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(reached ? 0.9 : 0.4))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(localized: "Streak day \(viewModel.today.streakDays). Today's reward: \(viewModel.today.todaysReward.gems) gems.")
        )
    }

    private func todayButton(
        emoji: String,
        title: String,
        done: Bool,
        dimmed: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emoji).font(.system(size: 26))
                Text(title)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(ForestTheme.Colors.cloudWhite.opacity(done ? 0.5 : 0.9))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(dimmed ? 0.5 : 1)
        }
        .buttonStyle(SquishyButtonStyle())
        .disabled(done || dimmed)
        .accessibilityLabel(title)
    }

    private func chestCelebration(_ prize: Int) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("🎁")
                    .font(.system(size: 84))
                    .floating(amplitude: 8, period: 1.8)
                Text(String(localized: "💎 \(prize) gems!"))
                    .font(ForestTheme.Fonts.heading)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
            }
            .padding(28)
            .forestCard(cornerRadius: 26)
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    private var wallet: some View {
        HStack(spacing: 18) {
            Label("\(viewModel.gems)", systemImage: "diamond.fill")
                .foregroundStyle(ForestTheme.Colors.skyBlue)
            Label("\(viewModel.pieces)", systemImage: "puzzlepiece.fill")
                .foregroundStyle(ForestTheme.Colors.leafGreen)
            Label("\(viewModel.totalStars)", systemImage: "star.fill")
                .foregroundStyle(ForestTheme.Colors.sunshine)
        }
        .font(ForestTheme.Fonts.body)
        .padding(.horizontal, 20).padding(.vertical, 10)
        .forestCard(cornerRadius: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(localized: "\(viewModel.gems) gems, \(viewModel.pieces) puzzle pieces, \(viewModel.totalStars) stars")
        )
    }

    // MARK: Worlds

    @ViewBuilder
    private func worldCard(_ world: PuzzleWorld) -> some View {
        let unlocked = viewModel.isUnlocked(world)
        Button {
            Task { await viewModel.startTapped(world) }
        } label: {
            VStack(spacing: 6) {
                Text(world.emoji)
                    .font(.system(size: 44))
                    .opacity(unlocked ? 1 : 0.45)
                Text(world.localizedTitle)
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .multilineTextAlignment(.center)

                if unlocked {
                    Text(viewModel.nextChapterTitle(world))
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    if viewModel.isBossNext(world) && !viewModel.hasCrystal(world) {
                        Label(String(localized: "Boss!"), systemImage: "flame.fill")
                            .font(ForestTheme.Fonts.caption)
                            .foregroundStyle(ForestTheme.Colors.peach)
                    }
                    ForestProgressBar(
                        progress: viewModel.progress(world),
                        label: String(localized: "Chapter \(viewModel.nextLevel(world)) of \(world.levelCount)")
                    )
                    .padding(.horizontal, 4)
                } else {
                    Label(String(localized: "Locked"), systemImage: "lock.fill")
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.7))
                    if let reason = viewModel.lockReason(world) {
                        Text(reason)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.65))
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 200)
            .padding(.vertical, 12)
            .forestCard(cornerRadius: 22)
            .overlay(alignment: .topTrailing) {
                if viewModel.hasCrystal(world) {
                    Text(world.crystal.emoji)
                        .font(.system(size: 22))
                        .padding(8)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(SquishyButtonStyle())
        .disabled(!unlocked || viewModel.isStarting)
        .accessibilityLabel(accessibilityLabel(world, unlocked: unlocked))
    }

    private func accessibilityLabel(_ world: PuzzleWorld, unlocked: Bool) -> String {
        guard unlocked else {
            return String(localized: "\(world.localizedTitle), locked. \(viewModel.lockReason(world) ?? "")")
        }
        let crystal = viewModel.hasCrystal(world)
            ? String(localized: " Crystal won.")
            : ""
        return String(
            localized: "\(world.localizedTitle). Next: \(viewModel.nextChapterTitle(world)), chapter \(viewModel.nextLevel(world)) of \(world.levelCount).\(crystal)"
        )
    }

    private var badgeShelf: some View {
        VStack(spacing: 10) {
            Text(String(localized: "Your badges"))
                .font(ForestTheme.Fonts.heading)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
            FlowLayout(spacing: 10) {
                ForEach(viewModel.badges, id: \.self) { badge in
                    HStack(spacing: 6) {
                        Text(badge.emoji)
                        Text(badge.localizedTitle)
                            .font(ForestTheme.Fonts.caption)
                            .foregroundStyle(ForestTheme.Colors.deepGreen)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(ForestTheme.Colors.cloudWhite.opacity(0.9))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(.top, 8)
    }
}
