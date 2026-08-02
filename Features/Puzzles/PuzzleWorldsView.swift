//
//  PuzzleWorldsView.swift
//  Focus Forest Adventure
//
//  Puzzle Quest's front door: six themed worlds, each showing the level the
//  child is up to. Locked worlds stay visible with a "how to open it" line —
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

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var age: Int { dependencies.appState.settings.childAge }
    var coins: Int { snapshot.coins }
    var totalStars: Int { snapshot.totalStars }
    var badges: [PuzzleBadge] { PuzzleBadge.allCases.filter { snapshot.badges.contains($0) } }

    func onAppear() async {
        refresh()
        await dependencies.speechService.speak(String(localized: "Let's solve some puzzles!"))
    }

    /// Re-read on every appearance so returning from a level shows the new
    /// level number and coin count.
    func refresh() {
        do {
            let child = try dependencies.childRepository.activeChild()
            snapshot = try dependencies.puzzleRepository.snapshot(for: child)
        } catch {
            assertionFailure("Puzzle snapshot failed: \(error)")
            snapshot = PuzzleProgressSnapshot()
        }
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

    func progress(_ world: PuzzleWorld) -> Double {
        Double(snapshot.completed(world)) / Double(max(world.levelCount, 1))
    }

    func skillName(_ world: PuzzleWorld) -> String {
        PuzzleSkill.forLevel(snapshot.rung(world)).localizedName
    }

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
                    Text(String(localized: "🧩 Puzzle Quest"))
                        .font(ForestTheme.Fonts.title)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .padding(.top, 12)
                        .accessibilityAddTraits(.isHeader)

                    wallet

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
        }
        .navigationTitle(String(localized: "Puzzle Quest"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.onAppear() }
        .onAppear { viewModel.refresh() }
    }

    private var wallet: some View {
        HStack(spacing: 18) {
            Label("\(viewModel.coins)", systemImage: "circle.hexagongrid.fill")
                .foregroundStyle(ForestTheme.Colors.sunshine)
            Label("\(viewModel.totalStars)", systemImage: "star.fill")
                .foregroundStyle(ForestTheme.Colors.sunshine)
        }
        .font(ForestTheme.Fonts.body)
        .padding(.horizontal, 20).padding(.vertical, 10)
        .forestCard(cornerRadius: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(localized: "\(viewModel.coins) coins, \(viewModel.totalStars) stars")
        )
    }

    @ViewBuilder
    private func worldCard(_ world: PuzzleWorld) -> some View {
        let unlocked = viewModel.isUnlocked(world)
        Button {
            Task { await viewModel.startTapped(world) }
        } label: {
            VStack(spacing: 8) {
                Text(world.emoji)
                    .font(.system(size: 46))
                    .opacity(unlocked ? 1 : 0.45)
                Text(world.localizedTitle)
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                Text(world.localizedTheme)
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.75))

                if unlocked {
                    Text(String(localized: "Level \(viewModel.nextLevel(world)) of \(world.levelCount)"))
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.7))
                        .monospacedDigit()
                    ForestProgressBar(progress: viewModel.progress(world), label: viewModel.skillName(world))
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
            .frame(maxWidth: .infinity, minHeight: 190)
            .padding(.vertical, 12)
            .forestCard(cornerRadius: 22)
            .overlay(alignment: .topTrailing) {
                if unlocked {
                    Circle()
                        .fill(world.tint)
                        .frame(width: 14, height: 14)
                        .padding(10)
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
        return String(
            localized: "\(world.localizedTitle), \(world.localizedTheme), level \(viewModel.nextLevel(world)) of \(world.levelCount)"
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
