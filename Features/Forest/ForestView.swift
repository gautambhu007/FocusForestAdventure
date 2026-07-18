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

    func leafCatchTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.appState.navigationPath.append(.leafCatch)
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

            Button {
                viewModel.leafCatchTapped()
            } label: {
                Label(String(localized: "Leaf Catch"), systemImage: "leaf.fill")
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
                if element == .dragon {
                    // The magic forest's crown jewel actually FLIES.
                    FlyingDragonView(size: proxy.size)
                } else {
                    Text(element.emoji)
                        .font(.system(size: elementSize(element)))
                        .position(position(for: index, element: element, in: proxy.size))
                        .floating(amplitude: element == .butterflies ? 12 : 4,
                                  period: 2 + Double(index % 3))
                        .accessibilityLabel(element.localizedName)
                }
            }
        }
    }

    // MARK: Flying dragon

    /// A living dragon for the magic forest: soars back and forth across the
    /// sky on a smooth curved path, flips to face its flight direction, banks
    /// into turns, "beats its wings" with a scale pulse, leaves a sparkle
    /// trail, and puffs a little fire every few seconds. Pure SwiftUI —
    /// no animation assets. Respects Reduce Motion (calm float instead).
    private struct FlyingDragonView: View {
        let size: CGSize
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            if reduceMotion {
                Text("🐉")
                    .font(.system(size: 64))
                    .position(x: size.width * 0.7, y: size.height * 0.3)
                    .floating(amplitude: 4, period: 3)
                    .accessibilityLabel(String(localized: "Friendly Dragon"))
            } else {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let position = flightPosition(at: t)
                    let velocity = flightVelocity(at: t)
                    let facingRight = velocity.dx >= 0
                    // Nose follows the path like a snake's head: pitch up and
                    // down along the weave, clamped so it never looks wild.
                    let pitch = (atan2(velocity.dy, abs(velocity.dx)) * 180 / .pi)
                        .clamped(to: -32...32)
                    let wingBeat = 1 + 0.05 * sin(2 * .pi * t / 0.6)
                    let firePhase = t.truncatingRemainder(dividingBy: 7)

                    ZStack {
                        // Sparkle body: six close echoes trace the serpentine
                        // path behind the head — reads as a snaking tail.
                        ForEach(0..<6, id: \.self) { echo in
                            let lag = Double(echo + 1) * 0.22
                            Text("✨")
                                .font(.system(size: 24 - CGFloat(echo) * 3))
                                .opacity(0.60 - Double(echo) * 0.09)
                                .position(flightPosition(at: t - lag))
                        }

                        // Fire puff: a brief breath every ~7 seconds.
                        if firePhase < 0.9 {
                            Text("🔥")
                                .font(.system(size: 28))
                                .opacity(1.0 - firePhase / 0.9)
                                .scaleEffect(0.7 + firePhase)
                                .position(x: position.x + (facingRight ? 52 : -52),
                                          y: position.y + 6)
                        }

                        // The dragon itself (emoji faces left; flip to fly right).
                        Text("🐉")
                            .font(.system(size: 64))
                            .scaleEffect(x: facingRight ? -wingBeat : wingBeat, y: wingBeat)
                            .rotationEffect(.degrees(facingRight ? pitch : -pitch))
                            .position(position)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(String(localized: "Friendly Dragon flying around your forest"))
            }
        }

        /// Serpentine path confined to the CENTRAL 80% of the page:
        /// x sweeps 10%…90% of the width (14s per crossing) while y weaves
        /// through 18%…82% of the height with ~3 S-curves per crossing —
        /// the classic snake slither, drawn large across the middle.
        private func flightPosition(at t: TimeInterval) -> CGPoint {
            let x = (0.5 + 0.40 * sin(2 * .pi * t / 14)) * size.width
            let y = (0.5 + 0.32 * sin(2 * .pi * t / 5.0)) * size.height
            return CGPoint(x: x, y: y)
        }

        /// Analytic derivative of the path — drives head orientation.
        private func flightVelocity(at t: TimeInterval) -> CGVector {
            let dx = 0.40 * size.width * (2 * .pi / 14) * cos(2 * .pi * t / 14)
            let dy = 0.32 * size.height * (2 * .pi / 5.0) * cos(2 * .pi * t / 5.0)
            return CGVector(dx: dx, dy: dy)
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
