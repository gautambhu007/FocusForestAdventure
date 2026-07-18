//
//  TracingAndClockViews.swift
//  Focus Forest Adventure
//
//  Two more prompt features:
//  - Devanagari letter tracing (finger/Pencil): follow the dots over a
//    ghost letter, all standalone (the mission trace game is coupled to
//    missions, so this is a self-contained sibling).
//  - Clock game: read the analog clock, pick the right time.
//

import SwiftUI

// MARK: - Devanagari tracing

struct HindiTracingView: View {
    let dependencies: AppDependencies

    /// Letters with rough normalized dot paths. The big ghost glyph shows
    /// the true shape; the dots gamify following its strokes (headline
    /// first, then the body — the standard teaching order).
    private static let letters: [(letter: String, dots: [TracePoint])] = [
        ("र", [.init(x: 0.30, y: 0.22), .init(x: 0.50, y: 0.22), .init(x: 0.70, y: 0.22),
               .init(x: 0.50, y: 0.40), .init(x: 0.50, y: 0.55), .init(x: 0.44, y: 0.68), .init(x: 0.34, y: 0.78)]),
        ("ट", [.init(x: 0.30, y: 0.22), .init(x: 0.50, y: 0.22), .init(x: 0.70, y: 0.22),
               .init(x: 0.68, y: 0.40), .init(x: 0.60, y: 0.60), .init(x: 0.45, y: 0.70), .init(x: 0.32, y: 0.60)]),
        ("न", [.init(x: 0.30, y: 0.22), .init(x: 0.50, y: 0.22), .init(x: 0.70, y: 0.22),
               .init(x: 0.65, y: 0.40), .init(x: 0.65, y: 0.60), .init(x: 0.65, y: 0.78),
               .init(x: 0.45, y: 0.55), .init(x: 0.32, y: 0.62)]),
        ("ल", [.init(x: 0.30, y: 0.22), .init(x: 0.50, y: 0.22), .init(x: 0.70, y: 0.22),
               .init(x: 0.60, y: 0.40), .init(x: 0.45, y: 0.50), .init(x: 0.60, y: 0.62),
               .init(x: 0.50, y: 0.78), .init(x: 0.35, y: 0.70)]),
        ("ग", [.init(x: 0.30, y: 0.22), .init(x: 0.50, y: 0.22), .init(x: 0.70, y: 0.22),
               .init(x: 0.40, y: 0.40), .init(x: 0.38, y: 0.60), .init(x: 0.50, y: 0.72),
               .init(x: 0.65, y: 0.60), .init(x: 0.65, y: 0.40)]),
        ("म", [.init(x: 0.30, y: 0.22), .init(x: 0.50, y: 0.22), .init(x: 0.70, y: 0.22),
               .init(x: 0.35, y: 0.42), .init(x: 0.35, y: 0.62), .init(x: 0.50, y: 0.72),
               .init(x: 0.65, y: 0.62), .init(x: 0.65, y: 0.42), .init(x: 0.50, y: 0.55)])
    ]

    @State private var letterIndex = 0
    @State private var visited: Set<Int> = []
    @State private var strokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var celebrating = false
    @State private var sparkle = 0

    private var current: (letter: String, dots: [TracePoint]) { Self.letters[letterIndex] }

    var body: some View {
        ZStack {
            ForestTheme.Gradients.morningSky.ignoresSafeArea()
            SparkleBurstView(trigger: sparkle)

            VStack(spacing: 14) {
                Text(String(localized: "Trace \(current.letter) — follow the dots!"))
                    .font(ForestTheme.Fonts.heading)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)

                tracePad

                HStack(spacing: 12) {
                    Button {
                        resetPad()
                    } label: {
                        Label(String(localized: "Start over"), systemImage: "arrow.counterclockwise")
                            .font(ForestTheme.Fonts.caption)
                            .foregroundStyle(ForestTheme.Colors.deepGreen)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .forestCard(cornerRadius: 15)
                    }
                    .buttonStyle(SquishyButtonStyle())

                    BigBouncyButton(
                        title: celebrating ? String(localized: "Next letter!") : String(localized: "Skip"),
                        icon: "arrow.right",
                        color: celebrating ? ForestTheme.Colors.leafGreen : ForestTheme.Colors.sunshine
                    ) {
                        nextLetter()
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical)
            .adaptiveContentWidth(600)
        }
        .navigationTitle(String(localized: "लिखना सीखें · Tracing"))
        .navigationBarTitleDisplayMode(.inline)
        .task { speakCurrent() }
        .onDisappear { dependencies.speechService.stop() }
    }

    private var tracePad: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(ForestTheme.Colors.cloudWhite)
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 5)

                Text(current.letter)
                    .font(.system(size: proxy.size.height * 0.62, weight: .heavy, design: .rounded))
                    .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.25))

                ForEach(current.dots.indices, id: \.self) { index in
                    Circle()
                        .fill(visited.contains(index)
                              ? ForestTheme.Colors.sunshine
                              : ForestTheme.Colors.lavender)
                        .frame(width: 26, height: 26)
                        .position(x: CGFloat(current.dots[index].x) * proxy.size.width,
                                  y: CGFloat(current.dots[index].y) * proxy.size.height)
                        .animation(.bouncy(duration: 0.3), value: visited)
                }

                drawnPath
                    .stroke(ForestTheme.Colors.bubblegum,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        currentStroke.append(value.location)
                        markVisited(near: value.location, in: proxy.size)
                    }
                    .onEnded { _ in
                        strokes.append(currentStroke)
                        currentStroke = []
                        checkDone()
                    }
            )
        }
        .frame(height: 340)
        .padding(.horizontal, 24)
        .accessibilityLabel(String(localized: "Trace the letter \(current.letter) by following the dots"))
    }

    private var drawnPath: Path {
        var path = Path()
        for stroke in strokes + [currentStroke] where stroke.count > 1 {
            path.move(to: stroke[0])
            for point in stroke.dropFirst() { path.addLine(to: point) }
        }
        return path
    }

    private func markVisited(near location: CGPoint, in size: CGSize) {
        for (index, dot) in current.dots.enumerated() where !visited.contains(index) {
            let dotPoint = CGPoint(x: dot.x * size.width, y: dot.y * size.height)
            if hypot(dotPoint.x - location.x, dotPoint.y - location.y) < 34 {
                visited.insert(index)
                dependencies.hapticsService.playGentleTap()
            }
        }
    }

    private func checkDone() {
        guard !celebrating, visited.count == current.dots.count else { return }
        celebrating = true
        sparkle += 1
        dependencies.hapticsService.playSuccess()
        dependencies.soundEngine.play(.starEarned)
        Task { await dependencies.speechService.speak("शाबाश!", language: "hi-IN") }
    }

    private func nextLetter() {
        letterIndex = (letterIndex + 1) % Self.letters.count
        resetPad()
        speakCurrent()
    }

    private func resetPad() {
        visited = []
        strokes = []
        currentStroke = []
        celebrating = false
    }

    private func speakCurrent() {
        Task { await dependencies.speechService.speak(current.letter, language: "hi-IN") }
    }
}

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
            ForestTheme.Gradients.meadow.ignoresSafeArea()

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
