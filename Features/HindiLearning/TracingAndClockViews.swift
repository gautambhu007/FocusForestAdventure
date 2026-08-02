//
//  TracingAndClockViews.swift
//  Focus Forest Adventure
//
//  Clock game: read the analog clock, pick the right time.
//  (Devanagari tracing lives in HindiTracingWorkbook.swift — the
//  section-based workbook with glyph-path scoring.)
//

import SwiftUI

// MARK: - Clock game

struct ClockGameView: View {
    let dependencies: AppDependencies

    private static let rounds = 5

    @State private var hour = 3
    @State private var halfPast = false
    @State private var choices: [String] = []
    @State private var round = 0
    @State private var score = 0
    @State private var isDone = false
    @State private var shaking: String?

    private var answer: String { halfPast ? "\(hour):30" : "\(hour):00" }

    var body: some View {
        ZStack {
            ForestSceneBackground(place: .glade, legibility: 0.24)

            VStack(spacing: 18) {
                if isDone {
                    ConfettiView(particleCount: 50).ignoresSafeArea().allowsHitTesting(false)
                    Text(String(localized: "Great clock reading! \(score) of \(Self.rounds) stars!"))
                        .font(ForestTheme.Fonts.title)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    BigBouncyButton(title: String(localized: "Play again!"),
                                    icon: "clock.fill",
                                    color: ForestTheme.Colors.sunshine) {
                        round = 0; score = 0; isDone = false
                        nextRound()
                    }
                } else {
                    HStack(spacing: 6) {
                        ForEach(0..<Self.rounds, id: \.self) { star in
                            Image(systemName: star < score ? "star.fill" : "star")
                                .foregroundStyle(ForestTheme.Colors.sunshine)
                        }
                    }

                    Text(String(localized: "What time is it?"))
                        .font(ForestTheme.Fonts.heading)
                        .foregroundStyle(.white)

                    clockFace
                        .frame(width: 230, height: 230)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                        ForEach(choices, id: \.self) { choice in
                            Button {
                                tapped(choice)
                            } label: {
                                Text(choice)
                                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                                    .frame(maxWidth: .infinity, minHeight: 74)
                                    .forestCard(cornerRadius: 18)
                            }
                            .buttonStyle(SquishyButtonStyle())
                            .gentleShake(trigger: shaking == choice)
                            .accessibilityLabel(choice)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .adaptiveContentWidth(600)
        }
        .navigationTitle(String(localized: "घड़ी का खेल · Clock Game"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { nextRound() }
        .onDisappear { dependencies.speechService.stop() }
    }

    /// Analog clock drawn in SwiftUI: face, 12 hour ticks, two hands.
    private var clockFace: some View {
        ZStack {
            Circle().fill(ForestTheme.Colors.cloudWhite)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
            Circle().stroke(ForestTheme.Colors.deepGreen, lineWidth: 6)

            ForEach(1...12, id: \.self) { tick in
                Text("\(tick)")
                    .font(ForestTheme.Fonts.caption.weight(.bold))
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .rotationEffect(.degrees(-Double(tick) * 30))   // keep glyph upright
                    .offset(y: -92)
                    .rotationEffect(.degrees(Double(tick) * 30))    // place around the dial
            }

            // Hour hand (accounts for the half-past offset)
            Capsule()
                .fill(ForestTheme.Colors.deepGreen)
                .frame(width: 9, height: 62)
                .offset(y: -26)
                .rotationEffect(.degrees(Double(hour % 12) * 30 + (halfPast ? 15 : 0)))

            // Minute hand
            Capsule()
                .fill(ForestTheme.Colors.leafGreen)
                .frame(width: 7, height: 88)
                .offset(y: -40)
                .rotationEffect(.degrees(halfPast ? 180 : 0))

            Circle().fill(ForestTheme.Colors.sunshine).frame(width: 16, height: 16)
        }
        .accessibilityLabel(String(localized: "A clock showing a mystery time"))
    }

    private func nextRound() {
        guard round < Self.rounds else {
            LearningProgress.recordScore(score, for: "clock")
            dependencies.hapticsService.playSuccess()
            isDone = true
            return
        }
        round += 1
        hour = Int.random(in: 1...12)
        halfPast = Bool.random()
        var set: Set<String> = [answer]
        while set.count < 4 {
            let h = Int.random(in: 1...12)
            set.insert(Bool.random() ? "\(h):30" : "\(h):00")
        }
        choices = Array(set).shuffled()
        Task { await dependencies.speechService.speak(String(localized: "Look at the clock! What time is it?")) }
    }

    private func tapped(_ choice: String) {
        if choice == answer {
            score += 1
            dependencies.hapticsService.playSuccess()
            dependencies.soundEngine.play(.starEarned)
            nextRound()
        } else {
            shaking = choice
            dependencies.hapticsService.playSoftWobble()
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                shaking = nil
            }
        }
    }
}
