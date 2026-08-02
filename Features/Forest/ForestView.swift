//
//  ForestView.swift
//  Focus Forest Adventure
//
//  The child's evolving forest — an explorable, hand-drawn world you can
//  always look at, and a real 3D Magic Forest you can step INTO once
//  you've earned something.
//
//  The gate is the point: answering questions earns treasures, each
//  treasure is one four-minute visit, and when the time is up the child
//  goes back to the adventures. Looking at the forest is always free;
//  walking in it is what you work for.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class ForestViewModel {

    private let dependencies: AppDependencies

    private(set) var forest: ForestState?
    private(set) var levelName = ""
    private(set) var progressToNext: Double = 0
    /// Unspent visits to the Magic Forest.
    private(set) var passes = 0
    private(set) var earnedTreasures: [ForestTreasure] = []
    /// What the child is working toward next.
    private(set) var nextTreasure: ForestTreasure?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func onAppear() async {
        do {
            let child = try dependencies.childRepository.activeChild()
            let forest = try dependencies.forestRepository.forest(for: child)
            self.forest = forest
            self.levelName = dependencies.forestGrowthEngine.localizedLevelName(forest.level)
            self.progressToNext = dependencies.forestGrowthEngine.progressToNextLevel(xp: forest.experience)
            refreshTreasures(forest)

            await dependencies.speechService.speak(
                canEnterMagicForest
                    ? String(localized: "Welcome to your \(levelName)! You can go inside — double tap!")
                    : String(localized: "Welcome to your \(levelName)!")
            )
        } catch {
            assertionFailure("Forest load failed: \(error)")
        }
    }

    private func refreshTreasures(_ forest: ForestState) {
        passes = forest.forestPasses
        earnedTreasures = forest.earnedTreasures
        nextTreasure = TreasureCatalog.next(after: forest.earnedTreasureIDs)
    }

    // MARK: Magic Forest gate

    var canEnterMagicForest: Bool { MagicForestRules.canEnter(passes: passes) }

    /// Spend one earned visit. Returns false when there is nothing to
    /// spend, in which case the caller should stay outside.
    @discardableResult
    func enterMagicForest() -> Bool {
        guard let forest, forest.forestPasses > 0 else { return false }
        forest.forestPasses -= 1
        try? dependencies.forestRepository.save()
        refreshTreasures(forest)
        dependencies.hapticsService.playSuccess()
        return true
    }

    /// The child tried to go in with nothing earned.
    func magicForestBlocked() {
        dependencies.hapticsService.playGentleTap()
        Task {
            await dependencies.speechService.speak(
                String(localized: "Let's earn something first! Answer some questions and the Magic Forest will open.")
            )
        }
    }

    /// The four minutes ran out, or the child left early.
    func magicForestVisitEnded(ranOutOfTime: Bool) {
        guard ranOutOfTime else { return }
        Task {
            await dependencies.speechService.speak(
                String(localized: "That's four minutes of magic! Let's earn another visit.")
            )
        }
    }

    func goEarnMore() {
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        dependencies.appState.navigationPath.append(.adventureSelect)
    }

    // MARK: Forest mini-games

    func arForestTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.appState.navigationPath.append(.arForest)
    }

    func starCatchTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.appState.navigationPath.append(.starCatch)
    }

    func leafCatchTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.appState.navigationPath.append(.leafCatch)
    }

    func bubblePopTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.appState.navigationPath.append(.bubblePop)
    }

    /// Voice for the 3D forest's learn cards and bunny hints.
    func speakLine(_ text: String) {
        Task { await dependencies.speechService.speak(text) }
    }

    var unlocked: [ForestElement] { forest?.unlockedElements ?? [] }
}

struct ForestView: View {
    @State var viewModel: ForestViewModel
    @State private var isImmersed = false
    @State private var showLockedNudge = false

    var body: some View {
        ZStack {
            ImmersiveForestScene(
                unlocked: viewModel.unlocked,
                isImmersed: $isImmersed,
                canImmerse: viewModel.canEnterMagicForest,
                onBlocked: {
                    viewModel.magicForestBlocked()
                    showLockedNudge = true
                }
            )

            if !isImmersed {
                VStack(spacing: 12) {
                    header
                    Spacer()
                    magicForestCard
                    magicButtons
                }
                .padding(ForestTheme.Metrics.screenPadding)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isImmersed)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showLockedNudge)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // The real 3D world: walk with the joystick, look around, step
        // inside buildings — for four minutes.
        .fullScreenCover(isPresented: $isImmersed) {
            Forest3DExperience(
                unlocked: viewModel.unlocked,
                treasures: viewModel.earnedTreasures,
                speak: { viewModel.speakLine($0) },
                onExit: { ranOutOfTime in
                    isImmersed = false
                    viewModel.magicForestVisitEnded(ranOutOfTime: ranOutOfTime)
                }
            )
        }
        .task { await viewModel.onAppear() }
    }

    // MARK: The gate

    /// The single most important card on this screen: either "you've
    /// earned a visit, go in" or "here's what to do to open it".
    @ViewBuilder
    private var magicForestCard: some View {
        if viewModel.canEnterMagicForest {
            Button {
                if viewModel.enterMagicForest() { isImmersed = true }
            } label: {
                VStack(spacing: 6) {
                    Text("🌟")
                        .font(.system(size: 40))
                        .floating(amplitude: 5, period: 1.8)
                    Text(String(localized: "Enter the Magic Forest"))
                        .font(ForestTheme.Fonts.heading)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                    Text(visitsRemainingText)
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "4 minutes of exploring"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .forestCard()
            }
            .buttonStyle(SquishyButtonStyle())
            .accessibilityHint(String(localized: "Uses one earned visit. Lasts four minutes."))
        } else {
            VStack(spacing: 8) {
                Text("🔒🌳")
                    .font(.system(size: 36))
                Text(String(localized: "Earn something to open the forest"))
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .multilineTextAlignment(.center)
                if let next = viewModel.nextTreasure {
                    HStack(spacing: 8) {
                        Text(next.emoji).font(.title2)
                        Text(String(localized: "Next: \(next.name)"))
                            .font(ForestTheme.Fonts.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Button {
                    viewModel.goEarnMore()
                } label: {
                    Label(String(localized: "Answer questions"), systemImage: "map.fill")
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .frame(minHeight: 52)
                        .background(Capsule().fill(ForestTheme.Colors.sunshine.gradient))
                }
                .buttonStyle(SquishyButtonStyle())
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .forestCard()
            .overlay(alignment: .top) {
                if showLockedNudge {
                    Text(String(localized: "Not yet — let's earn a visit first!"))
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(ForestTheme.Colors.deepGreen))
                        .offset(y: -18)
                        .transition(.scale.combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(3))
                            showLockedNudge = false
                        }
                }
            }
        }
    }

    private var visitsRemainingText: String {
        viewModel.passes == 1
            ? String(localized: "1 visit ready")
            : String(localized: "\(viewModel.passes) visits ready")
    }

    /// Forest games & AR entry points.
    private var magicButtons: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            magicButton(String(localized: "See in AR"), symbol: "arkit") {
                viewModel.arForestTapped()
            }
            magicButton(String(localized: "Star Catch"), symbol: "star.fill") {
                viewModel.starCatchTapped()
            }
            magicButton(String(localized: "Leaf Catch"), symbol: "leaf.fill") {
                viewModel.leafCatchTapped()
            }
            magicButton(String(localized: "Bubble Pop"), symbol: "circle.dotted") {
                viewModel.bubblePopTapped()
            }
        }
    }

    private func magicButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(ForestTheme.Fonts.caption)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .forestCard(cornerRadius: 18)
        }
        .buttonStyle(SquishyButtonStyle())
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(viewModel.levelName)
                .font(ForestTheme.Fonts.title)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .accessibilityAddTraits(.isHeader)
            ForestProgressBar(
                progress: viewModel.progressToNext,
                label: String(localized: "Growing…")
            )
            .padding(.horizontal, 30)
            if !viewModel.earnedTreasures.isEmpty {
                Text(String(localized: "\(viewModel.earnedTreasures.count) treasures earned"))
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .forestCard()
    }
}
