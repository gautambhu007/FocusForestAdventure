//
//  ForestView.swift
//  Focus Forest Adventure
//
//  The child's evolving forest. Unlocked elements appear as animated layers;
//  the scene grows from empty meadow to magic forest.
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

    var unlocked: [ForestElement] { forest?.unlockedElements ?? [] }
    var nextUnlock: ForestElement? {
        ForestElement.allCases.first { !unlocked.contains($0) }
    }
}

struct ForestView: View {
    @State var viewModel: ForestViewModel

    var body: some View {
        ZStack {
            AnimatedForestBackground(density: densityForLevel)

            // Unlocked element layers
            forestElements

            VStack {
                header
                Spacer()
                magicButtons
                nextUnlockCard
            }
            .padding(ForestTheme.Metrics.screenPadding)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.onAppear() }
    }

    /// Phase 2.5/2.6 entry points.
    private var magicButtons: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.arForestTapped()
            } label: {
                Label(String(localized: "See in AR"), systemImage: "arkit")
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .forestCard(cornerRadius: 16)
            }
            .buttonStyle(SquishyButtonStyle())

            Button {
                viewModel.starCatchTapped()
            } label: {
                Label(String(localized: "Star Catch"), systemImage: "star.fill")
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .forestCard(cornerRadius: 16)
            }
            .buttonStyle(SquishyButtonStyle())
        }
        .padding(.bottom, 6)
    }

    private var densityForLevel: AnimatedForestBackground.Density {
        switch viewModel.forest?.level ?? 1 {
        case ..<3: .light
        case ..<6: .medium
        default: .lush
        }
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

    /// Renders each unlocked element as a playful animated layer.
    private var forestElements: some View {
        GeometryReader { proxy in
            ForEach(Array(viewModel.unlocked.enumerated()), id: \.element) { index, element in
                Text(element.emoji)
                    .font(.system(size: elementSize(element)))
                    .position(position(for: index, element: element, in: proxy.size))
                    .floating(amplitude: element == .butterflies ? 12 : 4,
                              period: 2 + Double(index % 3))
                    .accessibilityLabel(element.localizedName)
            }
        }
    }

    private func elementSize(_ element: ForestElement) -> CGFloat {
        switch element {
        case .castle, .treehouse: 80
        case .rainbow, .river: 72
        case .dragon: 64
        default: 48
        }
    }

    private func position(for index: Int, element: ForestElement, in size: CGSize) -> CGPoint {
        // Deterministic scattered layout: pretty without physics.
        let xs: [CGFloat] = [0.18, 0.78, 0.42, 0.65, 0.28, 0.85, 0.5, 0.15, 0.7, 0.38]
        let ys: [CGFloat] = [0.72, 0.65, 0.78, 0.5, 0.55, 0.75, 0.35, 0.45, 0.42, 0.62]
        let i = index % xs.count
        return CGPoint(x: xs[i] * size.width, y: ys[i] * size.height)
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
