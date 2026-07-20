//
//  ForestView.swift
//  Focus Forest Adventure
//
//  The child's evolving forest — now an explorable, hand-drawn world.
//  Drag to wander through the parallax layers; double-tap to step INSIDE
//  the forest (the world zooms around you and the buttons melt away);
//  double-tap again to hop back out. Unlocked elements grow the scene:
//  grass → flowers → trees → butterflies → foxes → river → rainbow →
//  treehouse → castle → dragon.
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
            await dependencies.speechService.speak(
                String(localized: "Welcome to your \(levelName)!")
            )
        } catch {
            assertionFailure("Forest load failed: \(error)")
        }
    }

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

    var unlocked: [ForestElement] { forest?.unlockedElements ?? [] }
    var nextUnlock: ForestElement? {
        ForestElement.allCases.first { !unlocked.contains($0) }
    }
}

struct ForestView: View {
    @State var viewModel: ForestViewModel
    @State private var isImmersed = false

    var body: some View {
        ZStack {
            ImmersiveForestScene(unlocked: viewModel.unlocked,
                                 isImmersed: $isImmersed)

            if !isImmersed {
                VStack {
                    header
                    Spacer()
                    explorerHint
                    magicButtons
                    nextUnlockCard
                }
                .padding(ForestTheme.Metrics.screenPadding)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isImmersed)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Double-tap zooms the 2D scene, then the REAL 3D world fades in:
        // walk with the joystick, look around, step inside buildings.
        .fullScreenCover(isPresented: $isImmersed) {
            Forest3DExperience(unlocked: viewModel.unlocked) {
                isImmersed = false
            }
        }
        .task { await viewModel.onAppear() }
    }

    /// Invitation to explore the world with fingers.
    private var explorerHint: some View {
        Text(String(localized: "Drag to explore — double-tap to walk in 3D!"))
            .font(ForestTheme.Fonts.caption)
            .foregroundStyle(ForestTheme.Colors.deepGreen)
            .padding(.horizontal, 14).padding(.vertical, 6)
            .forestCard(cornerRadius: 16)
            .padding(.bottom, 6)
            .allowsHitTesting(false)
    }

    /// Forest games & AR entry points (2×2 grid so all four fit).
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
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private func magicButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(ForestTheme.Fonts.caption)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .forestCard(cornerRadius: 16)
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
        }
        .padding(16)
        .forestCard()
    }

    @ViewBuilder
    private var nextUnlockCard: some View {
        if let next = viewModel.nextUnlock {
            HStack(spacing: 12) {
                Text(next.emoji)
                    .font(.system(size: 40))
                    .grayscale(0.9)
                    .opacity(0.7)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Coming soon…"))
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                    Text(next.localizedName)
                        .font(ForestTheme.Fonts.body)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .foregroundStyle(ForestTheme.Colors.sunshine)
            }
            .padding(16)
            .forestCard()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Next to grow: \(next.localizedName)"))
        }
    }
}
