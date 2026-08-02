//
//  LeafCatchGameView.swift
//  Focus Forest Adventure
//
//  Second gesture mini-game — puts GRAB and OPEN PALM to work:
//  leaves drift down; make a fist (grab) near a leaf to catch it,
//  open your palm to release a gust that slows all leaves for a moment.
//  Tapping a leaf always works too (touch-first, camera optional).
//

import SwiftUI
import Observation

@Observable
@MainActor
final class LeafCatchViewModel {

    struct Leaf: Identifiable, Equatable {
        let id = UUID()
        var position: CGPoint    // normalized 0…1
        var symbol: String
        var speed: Double        // normalized fall per tick
    }

    let dependencies: AppDependencies
    var hands: any HandTrackingServiceProtocol { dependencies.handTrackingService }

    private(set) var leaves: [Leaf] = []
    private(set) var score = 0
    private(set) var secondsLeft = 30
    private(set) var isRunning = false
    private(set) var isHandModeActive = false
    /// Slow-motion gust from an open palm (seconds remaining).
    private(set) var gustActive = false

    private var loop: Task<Void, Never>?
    private var gustCooldown = 0

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func start() {
        guard !isRunning else { return }
        score = 0
        secondsLeft = 30
        leaves = []
        isRunning = true
        dependencies.soundEngine.play(.tapPop)

        loop = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.25))
                guard let self, self.isRunning else { return }
                tick += 1
                if tick.isMultiple(of: 4) {          // once per second
                    self.secondsLeft -= 1
                    if self.gustCooldown > 0 { self.gustCooldown -= 1 }
                    if self.secondsLeft <= 0 {
                        self.finish()
                        return
                    }
                }
                self.step()
            }
        }
    }

    private func step() {
        // Fall
        let factor = gustActive ? 0.25 : 1.0
        for index in leaves.indices {
            leaves[index].position.y += leaves[index].speed * factor
        }
        leaves.removeAll { $0.position.y > 1.05 }

        // Spawn
        if leaves.count < 5 {
            leaves.append(Leaf(
                position: CGPoint(x: .random(in: 0.12...0.88), y: -0.05),
                symbol: ["🍃", "🍁", "🍂"].randomElement()!,
                speed: .random(in: 0.014...0.029)
            ))
        }

        // Gestures
        guard isHandModeActive else { return }
        if hands.gesture == .grab, let pointer = hands.pointerPosition {
            if let index = leaves.firstIndex(where: {
                hypot($0.position.x - pointer.x, $0.position.y - pointer.y) < 0.13
            }) {
                collect(leaves[index])
            }
        } else if hands.gesture == .openPalm, gustCooldown == 0 {
            triggerGust()
        }
    }

    private func triggerGust() {
        gustCooldown = 6
        gustActive = true
        dependencies.hapticsService.playGentleTap()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.gustActive = false
        }
    }

    func collect(_ leaf: Leaf) {
        guard isRunning, let index = leaves.firstIndex(of: leaf) else { return }
        leaves.remove(at: index)
        score += 1
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.starEarned)
    }

    func enableHandMode() async {
        guard hands.isAvailable else { return }
        guard await hands.requestPermission() else { return }
        hands.startTracking()
        isHandModeActive = true
    }

    func finish() {
        isRunning = false
        loop?.cancel()
        loop = nil
        stopHands()
        dependencies.hapticsService.playSuccess()
        LearningProgress.recordScore(min(score / 3, 5), for: "leafcatch")
        Task { await dependencies.speechService.speak(
            String(localized: "Wow! You caught \(score) leaves!")
        )}
    }

    func exit() {
        isRunning = false
        loop?.cancel()
        loop = nil
        stopHands()
    }

    private func stopHands() {
        if isHandModeActive {
            hands.stopTracking()
            isHandModeActive = false
        }
    }
}

struct LeafCatchGameView: View {
    @State var viewModel: LeafCatchViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForestSceneBackground(place: .dusk, legibility: 0.1)

                ForEach(viewModel.leaves) { leaf in
                    Button {
                        viewModel.collect(leaf)
                    } label: {
                        Text(leaf.symbol)
                            .font(.system(size: 50))
                            .rotationEffect(.degrees(leaf.position.y * 180))
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .position(x: leaf.position.x * geometry.size.width,
                              y: leaf.position.y * geometry.size.height)
                    .accessibilityLabel(String(localized: "Leaf. Tap to catch"))
                }

                if viewModel.isHandModeActive, let pointer = viewModel.hands.pointerPosition {
                    Circle()
                        .fill(viewModel.hands.gesture == .grab
                              ? ForestTheme.Colors.sunshine.opacity(0.9)
                              : .white.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .position(x: pointer.x * geometry.size.width,
                                  y: pointer.y * geometry.size.height)
                        .allowsHitTesting(false)
                }

                VStack {
                    HStack {
                        Text("🍃 \(viewModel.score)")
                            .font(ForestTheme.Fonts.heading)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .forestCard(cornerRadius: 14)
                        Spacer()
                        if viewModel.gustActive {
                            Text(String(localized: "💨 Slow-mo!"))
                                .font(ForestTheme.Fonts.caption)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .forestCard(cornerRadius: 14)
                        }
                        Spacer()
                        Text("⏱ \(viewModel.secondsLeft)")
                            .font(ForestTheme.Fonts.heading)
                            .monospacedDigit()
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .forestCard(cornerRadius: 14)
                    }
                    Spacer()
                    if !viewModel.isRunning {
                        startOverlay
                        Spacer()
                    }
                }
                .padding()
            }
            .animation(.linear(duration: 0.25), value: viewModel.leaves)
        }
        .navigationTitle(String(localized: "Leaf Catch"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { viewModel.exit() }
    }

    private var startOverlay: some View {
        VStack(spacing: 14) {
            Text(viewModel.score > 0
                 ? String(localized: "You caught \(viewModel.score) leaves! 🎉")
                 : String(localized: "Catch the falling leaves!"))
                .font(ForestTheme.Fonts.title)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .multilineTextAlignment(.center)

            BigBouncyButton(
                title: viewModel.score > 0 ? String(localized: "Play again!") : String(localized: "Start!"),
                icon: "leaf.fill",
                color: ForestTheme.Colors.leafGreen
            ) {
                viewModel.start()
            }

            if viewModel.hands.isAvailable && !viewModel.isHandModeActive {
                Button {
                    Task { await viewModel.enableHandMode() }
                } label: {
                    Label(String(localized: "Grab with your fist, open palm for slow-mo! (uses camera)"),
                          systemImage: "hand.raised")
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
