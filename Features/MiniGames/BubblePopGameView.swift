//
//  BubblePopGameView.swift
//  Focus Forest Adventure
//
//  Third gesture mini-game — puts POINT to work: bubbles drift upward;
//  point your index finger and hold it over a bubble to pop it (a ring
//  fills while you dwell). Tapping always works without the camera.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class BubblePopViewModel {

    struct Bubble: Identifiable, Equatable {
        let id = UUID()
        var position: CGPoint     // normalized
        var size: CGFloat         // 44...74 pt
        var rise: Double
    }

    let dependencies: AppDependencies
    var hands: any HandTrackingServiceProtocol { dependencies.handTrackingService }

    private(set) var bubbles: [Bubble] = []
    private(set) var score = 0
    private(set) var secondsLeft = 30
    private(set) var isRunning = false
    private(set) var isHandModeActive = false
    /// Dwell state: which bubble the finger is over, and for how long (0…1).
    private(set) var dwellTarget: UUID?
    private(set) var dwellProgress: Double = 0

    private var loop: Task<Void, Never>?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func start() {
        guard !isRunning else { return }
        score = 0
        secondsLeft = 30
        bubbles = []
        isRunning = true
        dependencies.soundEngine.play(.tapPop)

        loop = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.2))
                guard let self, self.isRunning else { return }
                tick += 1
                if tick.isMultiple(of: 5) {
                    self.secondsLeft -= 1
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
        for index in bubbles.indices {
            bubbles[index].position.y -= bubbles[index].rise
        }
        bubbles.removeAll { $0.position.y < -0.06 }

        if bubbles.count < 4 {
            bubbles.append(Bubble(
                position: CGPoint(x: .random(in: 0.15...0.85), y: 1.05),
                size: .random(in: 44...74),
                rise: .random(in: 0.008...0.016)
            ))
        }

        // Point-and-dwell: index finger held over a bubble fills the ring.
        guard isHandModeActive else { return }
        if hands.gesture == .point || hands.gesture == .none,
           let pointer = hands.pointerPosition,
           let target = bubbles.first(where: {
               hypot($0.position.x - pointer.x, $0.position.y - pointer.y) < 0.11
           }) {
            if dwellTarget == target.id {
                dwellProgress += 0.2 / 0.7        // ~0.7s to pop
                if dwellProgress >= 1 {
                    pop(target)
                }
            } else {
                dwellTarget = target.id
                dwellProgress = 0.2
            }
        } else {
            dwellTarget = nil
            dwellProgress = 0
        }
    }

    func pop(_ bubble: Bubble) {
        guard isRunning, let index = bubbles.firstIndex(of: bubble) else { return }
        bubbles.remove(at: index)
        dwellTarget = nil
        dwellProgress = 0
        score += 1
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
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
        LearningProgress.recordScore(min(score / 3, 5), for: "bubblepop")
        Task { await dependencies.speechService.speak(
            String(localized: "Pop pop pop! \(score) bubbles!")
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

struct BubblePopGameView: View {
    @State var viewModel: BubblePopViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForestTheme.Gradients.magic.ignoresSafeArea()

                ForEach(viewModel.bubbles) { bubble in
                    Button {
                        viewModel.pop(bubble)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(ForestTheme.Colors.skyBlue.opacity(0.45))
                                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
                            Circle()
                                .fill(.white.opacity(0.5))
                                .frame(width: bubble.size * 0.22, height: bubble.size * 0.22)
                                .offset(x: -bubble.size * 0.18, y: -bubble.size * 0.18)
                            if viewModel.dwellTarget == bubble.id {
                                Circle()
                                    .trim(from: 0, to: viewModel.dwellProgress)
                                    .stroke(ForestTheme.Colors.sunshine,
                                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                            }
                        }
                        .frame(width: bubble.size, height: bubble.size)
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .position(x: bubble.position.x * geometry.size.width,
                              y: bubble.position.y * geometry.size.height)
                    .accessibilityLabel(String(localized: "Bubble. Tap to pop"))
                }

                if viewModel.isHandModeActive, let pointer = viewModel.hands.pointerPosition {
                    Image(systemName: "hand.point.up.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white.opacity(0.85))
                        .position(x: pointer.x * geometry.size.width,
                                  y: pointer.y * geometry.size.height)
                        .allowsHitTesting(false)
                }

                VStack {
                    HStack {
                        Text("🫧 \(viewModel.score)")
                            .font(ForestTheme.Fonts.heading)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .forestCard(cornerRadius: 14)
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
            .animation(.linear(duration: 0.2), value: viewModel.bubbles)
        }
        .navigationTitle(String(localized: "Bubble Pop"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { viewModel.exit() }
    }

    private var startOverlay: some View {
        VStack(spacing: 14) {
            Text(viewModel.score > 0
                 ? String(localized: "You popped \(viewModel.score) bubbles! 🎉")
                 : String(localized: "Pop the floating bubbles!"))
                .font(ForestTheme.Fonts.title)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .multilineTextAlignment(.center)

            BigBouncyButton(
                title: viewModel.score > 0 ? String(localized: "Play again!") : String(localized: "Start!"),
                icon: "circle.dotted",
                color: ForestTheme.Colors.skyBlue
            ) {
                viewModel.start()
            }

            if viewModel.hands.isAvailable && !viewModel.isHandModeActive {
                Button {
                    Task { await viewModel.enableHandMode() }
                } label: {
                    Label(String(localized: "Point and hold your finger over a bubble! (uses camera)"),
                          systemImage: "hand.point.up")
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
