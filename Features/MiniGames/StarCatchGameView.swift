//
//  StarCatchGameView.swift
//  Focus Forest Adventure
//
//  Phase 2.6 gesture mini-game: pinch floating stars to collect them.
//  Every interaction has a touch fallback — tapping a star always works,
//  with or without hand tracking.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class StarCatchViewModel {

    struct Star: Identifiable, Equatable {
        let id = UUID()
        var position: CGPoint   // normalized 0…1
        var scale: Double = 1.0
    }

    let dependencies: AppDependencies
    var hands: any HandTrackingServiceProtocol { dependencies.handTrackingService }

    private(set) var stars: [Star] = []
    private(set) var score = 0
    private(set) var secondsLeft = 30
    private(set) var isRunning = false
    private(set) var isHandModeActive = false
    /// Flashes true briefly when the child waves — Bunny waves back.
    private(set) var bunnyIsWavingBack = false

    private var loop: Task<Void, Never>?
    private var lastSeenWaveCount = 0

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    // MARK: Game lifecycle

    func start() {
        guard !isRunning else { return }
        score = 0
        secondsLeft = 30
        stars = []
        isRunning = true
        dependencies.soundEngine.play(.tapPop)

        loop = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.5))
                guard let self, self.isRunning else { return }
                tick += 1
                if tick.isMultiple(of: 2) {             // once per second
                    self.secondsLeft -= 1
                    if self.secondsLeft <= 0 {
                        self.finish()
                        return
                    }
                }
                if self.stars.count < 4 {
                    self.spawnStar()
                }
                self.checkPinch()
                self.checkWave()
            }
        }
    }

    func finish() {
        isRunning = false
        loop?.cancel()
        loop = nil
        stopHandMode()
        dependencies.hapticsService.playSuccess()
        Task { await dependencies.speechService.speak(
            String(localized: "Wow! You caught \(score) stars!")
        )}
    }

    func exit() {
        isRunning = false
        loop?.cancel()
        loop = nil
        stopHandMode()
    }

    // MARK: Hand tracking (optional layer)

    func enableHandMode() async {
        guard hands.isAvailable else { return }
        guard await hands.requestPermission() else { return }
        hands.startTracking()
        isHandModeActive = true
    }

    private func stopHandMode() {
        if isHandModeActive {
            hands.stopTracking()
            isHandModeActive = false
        }
    }

    /// Pinching within reach of a star collects it.
    private func checkPinch() {
        guard isHandModeActive, hands.gesture == .pinch,
              let pointer = hands.pointerPosition else { return }
        if let index = stars.firstIndex(where: { hypot($0.position.x - pointer.x, $0.position.y - pointer.y) < 0.12 }) {
            collect(stars[index])
        }
    }

    /// Waving at Bunny: Bunny waves back, cheers, and drops two bonus stars.
    private func checkWave() {
        guard isHandModeActive, hands.waveCount > lastSeenWaveCount else { return }
        lastSeenWaveCount = hands.waveCount
        bunnyIsWavingBack = true
        dependencies.hapticsService.playSuccess()
        spawnStar()
        spawnStar()
        Task { [weak self] in
            await self?.dependencies.speechService.speak(
                String(localized: "Hello to you too! Here come bonus stars!")
            )
            try? await Task.sleep(for: .seconds(2))
            self?.bunnyIsWavingBack = false
        }
    }

    // MARK: Stars

    func collect(_ star: Star) {
        guard isRunning, let index = stars.firstIndex(of: star) else { return }
        stars.remove(at: index)
        score += 1
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.starEarned)
    }

    private func spawnStar() {
        stars.append(Star(position: CGPoint(
            x: .random(in: 0.15...0.85),
            y: .random(in: 0.2...0.75)
        )))
    }
}

struct StarCatchGameView: View {
    @State var viewModel: StarCatchViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForestSceneBackground(place: .night, legibility: 0.1)
                MagicDustView().ignoresSafeArea()

                // Stars (tap fallback always works).
                ForEach(viewModel.stars) { star in
                    Button {
                        viewModel.collect(star)
                    } label: {
                        Text("⭐")
                            .font(.system(size: 54))
                            .floating(amplitude: 6, period: 1.6)
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .position(x: star.position.x * geometry.size.width,
                              y: star.position.y * geometry.size.height)
                    .accessibilityLabel(String(localized: "Star. Tap to collect"))
                    .transition(.scale.combined(with: .opacity))
                }

                // Hand cursor when tracking.
                if viewModel.isHandModeActive, let pointer = viewModel.hands.pointerPosition {
                    Circle()
                        .fill(viewModel.hands.gesture == .pinch
                              ? ForestTheme.Colors.sunshine.opacity(0.9)
                              : .white.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .position(x: pointer.x * geometry.size.width,
                                  y: pointer.y * geometry.size.height)
                        .allowsHitTesting(false)
                        .animation(.smooth(duration: 0.1), value: pointer)
                }

                VStack {
                    hud
                    if viewModel.bunnyIsWavingBack {
                        HStack(spacing: 8) {
                            LottieView(animation: .bunnyWave, loopMode: .loop)
                                .frame(width: 60, height: 60)
                            Text(String(localized: "Bunny waves back! 👋"))
                                .font(ForestTheme.Fonts.body)
                                .foregroundStyle(ForestTheme.Colors.deepGreen)
                        }
                        .padding(10)
                        .forestCard(cornerRadius: 16)
                        .transition(.scale.combined(with: .opacity))
                    }
                    Spacer()
                    if !viewModel.isRunning {
                        startOverlay
                        Spacer()
                    }
                }
                .padding()
                .animation(.bouncy(duration: 0.4), value: viewModel.bunnyIsWavingBack)
            }
            .animation(.bouncy(duration: 0.4), value: viewModel.stars)
        }
        .navigationTitle(String(localized: "Star Catch"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { viewModel.exit() }
    }

    private var hud: some View {
        HStack {
            Text("⭐ \(viewModel.score)")
                .font(ForestTheme.Fonts.heading)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .forestCard(cornerRadius: 14)
                .accessibilityLabel(String(localized: "Score: \(viewModel.score) stars"))
            Spacer()
            Text("⏱ \(viewModel.secondsLeft)")
                .font(ForestTheme.Fonts.heading)
                .monospacedDigit()
                .padding(.horizontal, 14).padding(.vertical, 8)
                .forestCard(cornerRadius: 14)
                .accessibilityLabel(String(localized: "\(viewModel.secondsLeft) seconds left"))
        }
    }

    private var startOverlay: some View {
        VStack(spacing: 14) {
            Text(viewModel.score > 0
                 ? String(localized: "You caught \(viewModel.score) stars! 🎉")
                 : String(localized: "Catch the falling stars!"))
                .font(ForestTheme.Fonts.title)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .multilineTextAlignment(.center)

            BigBouncyButton(
                title: viewModel.score > 0 ? String(localized: "Play again!") : String(localized: "Start!"),
                icon: "star.fill",
                color: ForestTheme.Colors.sunshine
            ) {
                viewModel.start()
            }

            if viewModel.hands.isAvailable && !viewModel.isHandModeActive {
                Button {
                    Task { await viewModel.enableHandMode() }
                } label: {
                    Label(String(localized: "Pinch to catch, wave to say hi! (uses camera)"),
                          systemImage: "hand.pinch")
                        .font(ForestTheme.Fonts.caption)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .forestCard(cornerRadius: 14)
                }
                .buttonStyle(SquishyButtonStyle())
            }
        }
        .padding(20)
        .forestCard()
    }
}
