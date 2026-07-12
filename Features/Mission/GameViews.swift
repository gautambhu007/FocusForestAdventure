//
//  GameViews.swift
//  Focus Forest Adventure
//
//  The mini-game renderers. Each takes typed question content + the shared
//  MissionViewModel and reports success/miss back through it.
//

import SwiftUI

// MARK: - Tap the correct option (letters, numbers, shapes, colors, animals)

struct TapCorrectGameView: View {
    let options: [QuestionOption]
    let correctID: UUID
    let viewModel: MissionViewModel

    @State private var shakingID: UUID?
    @Environment(AppState.self) private var appState

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 120), spacing: 16)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(options) { option in
                Button {
                    Task { await tapped(option) }
                } label: {
                    optionLabel(option)
                }
                .buttonStyle(SquishyButtonStyle())
                .gentleShake(trigger: shakingID == option.id)
                .accessibilityLabel(option.label)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func optionLabel(_ option: QuestionOption) -> some View {
        Group {
            if let gameColor = option.gameColor {
                // Color games: color + paired symbol (color-blind safe).
                VStack(spacing: 6) {
                    Image(systemName: gameColor.accessibilitySymbol)
                        .font(.system(size: 40))
                    if appState.settings.isColorBlindModeEnabled {
                        Text(gameColor.localizedName)
                            .font(ForestTheme.Fonts.caption)
                    }
                }
                .foregroundStyle(gameColor.contrastingForeground)
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(
                    ForestTheme.Colors.gameColor(
                        gameColor,
                        colorBlindMode: appState.settings.isColorBlindModeEnabled
                    )
                )
            } else {
                Text(option.display)
                    .font(ForestTheme.Fonts.giant)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)   // explicit: .primary turns white in dark mode
                    .lineLimit(1)               // words must never wrap mid-word
                    .minimumScaleFactor(0.2)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(ForestTheme.Colors.cloudWhite)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            // Subtle edge so light cards (white, yellow) stay visible
            // against the pale background.
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    private func tapped(_ option: QuestionOption) async {
        viewModel.gentleTapHaptic()
        if option.id == correctID {
            await viewModel.submitAnswer(correct: true)
        } else {
            shakingID = option.id
            try? await Task.sleep(for: .milliseconds(400))
            shakingID = nil
            await viewModel.submitAnswer(correct: false)
        }
    }
}

// MARK: - Counting game

struct CountingGameView: View {
    let objectEmoji: String
    let count: Int
    let choices: [Int]
    let viewModel: MissionViewModel

    @State private var revealed = 0

    var body: some View {
        VStack(spacing: 28) {
            // Objects pop in one by one so the child can count along.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                ForEach(0..<count, id: \.self) { index in
                    Text(objectEmoji)
                        .font(.system(size: 52))
                        .scaleEffect(index < revealed ? 1 : 0.01)
                        .animation(.bouncy(duration: 0.4).delay(Double(index) * 0.25), value: revealed)
                        .accessibilityHidden(true)
                }
            }
            .padding()
            .forestCard()
            .padding(.horizontal)
            .accessibilityLabel(String(localized: "\(count) \(objectEmoji) to count"))

            HStack(spacing: 16) {
                ForEach(choices, id: \.self) { number in
                    Button {
                        Task {
                            viewModel.gentleTapHaptic()
                            await viewModel.submitAnswer(correct: number == count)
                        }
                    } label: {
                        Text("\(number)")
                            .font(ForestTheme.Fonts.hero)
                            .foregroundStyle(ForestTheme.Colors.deepGreen)
                            .frame(width: 90, height: 90)
                            .background(ForestTheme.Colors.sunshine.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .accessibilityLabel("\(number)")
                }
            }
        }
        .onAppear { revealed = count }
    }
}

// MARK: - Memory pairs

struct MemoryGameView: View {
    let pairs: [String]
    let viewModel: MissionViewModel

    @State private var cards: [MemoryCard] = []
    @State private var flippedIndices: [Int] = []
    @State private var isBusy = false

    struct MemoryCard: Identifiable {
        let id = UUID()
        let symbol: String
        var isFaceUp = false
        var isMatched = false
        var isCelebrating = false   // match: pop + sparkle + glow
        var isWobbling = false      // mismatch: gentle shake
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 14)], spacing: 14) {
            ForEach(cards.indices, id: \.self) { index in
                MemoryCardView(card: cards[index]) {
                    Task { await flip(index) }
                }
            }
        }
        .padding(.horizontal)
        .onAppear {
            cards = (pairs + pairs).shuffled().map { MemoryCard(symbol: $0) }
        }
    }

    private func flip(_ index: Int) async {
        guard !isBusy, !cards[index].isFaceUp, !cards[index].isMatched else { return }
        viewModel.gentleTapHaptic()
        viewModel.playSound(named: SoundEffect.cardFlip.rawValue)
        withAnimation(.bouncy(duration: 0.4)) { cards[index].isFaceUp = true }
        flippedIndices.append(index)

        guard flippedIndices.count == 2 else { return }
        isBusy = true
        let (a, b) = (flippedIndices[0], flippedIndices[1])
        flippedIndices = []

        if cards[a].symbol == cards[b].symbol {
            await celebrateMatch(a, b)
        } else {
            await wobbleMismatch(a, b)
        }
        isBusy = false
    }

    /// Match: chime + success haptic, cards pop with a golden glow and
    /// sparkles, then settle into their matched (dimmed) state.
    private func celebrateMatch(_ a: Int, _ b: Int) async {
        cards[a].isMatched = true
        cards[b].isMatched = true
        viewModel.playSound(named: SoundEffect.correctChime.rawValue)
        viewModel.successHaptic()

        withAnimation(.bouncy(duration: 0.35)) {
            cards[a].isCelebrating = true
            cards[b].isCelebrating = true
        }
        try? await Task.sleep(for: .seconds(0.8))
        withAnimation(.bouncy(duration: 0.4)) {
            cards[a].isCelebrating = false
            cards[b].isCelebrating = false
        }

        if cards.allSatisfy(\.isMatched) {
            await viewModel.completeCurrentQuestion()
        }
    }

    /// Mismatch: soft wobble haptic + gentle side-to-side shake, a moment to
    /// memorize both cards, then they flip back. Never harsh — just "not yet!".
    private func wobbleMismatch(_ a: Int, _ b: Int) async {
        viewModel.wobbleHaptic()
        viewModel.playSound(named: SoundEffect.gentleTryAgain.rawValue)

        cards[a].isWobbling = true
        cards[b].isWobbling = true
        try? await Task.sleep(for: .milliseconds(450))
        cards[a].isWobbling = false
        cards[b].isWobbling = false

        try? await Task.sleep(for: .milliseconds(650))   // time to memorize
        withAnimation(.bouncy(duration: 0.4)) {
            cards[a].isFaceUp = false
            cards[b].isFaceUp = false
        }
    }
}

private struct MemoryCardView: View {
    let card: MemoryGameView.MemoryCard
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(card.isFaceUp || card.isMatched
                          ? AnyShapeStyle(ForestTheme.Colors.cloudWhite)
                          : AnyShapeStyle(ForestTheme.Gradients.meadow))
                if card.isFaceUp || card.isMatched {
                    Text(card.symbol)
                        .font(.system(size: 44))
                        .scaleEffect(card.isCelebrating ? 1.25 : 1)
                } else {
                    Image(systemName: "leaf.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                }

                // Sparkles burst over a fresh match.
                if card.isCelebrating {
                    Text("✨")
                        .font(.title)
                        .offset(x: 26, y: -34)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                    Text("⭐")
                        .font(.caption)
                        .offset(x: -28, y: 30)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
            }
            .frame(height: 100)
            .rotation3DEffect(.degrees(card.isFaceUp ? 0 : 180), axis: (x: 0, y: 1, z: 0))
            .scaleEffect(card.isCelebrating ? 1.15 : 1)
            .shadow(color: card.isCelebrating ? ForestTheme.Colors.sunshine.opacity(0.9) : .clear,
                    radius: card.isCelebrating ? 16 : 0)
            .opacity(card.isMatched && !card.isCelebrating ? 0.55 : 1)
            .gentleShake(trigger: card.isWobbling)
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel(card.isFaceUp || card.isMatched
                            ? card.symbol
                            : String(localized: "Hidden card"))
    }
}

// MARK: - Sequence / repeat the pattern

struct SequenceGameView: View {
    let items: [QuestionOption]
    let playbackInterval: TimeInterval
    let viewModel: MissionViewModel

    @State private var highlightedIndex: Int?
    @State private var isShowingSequence = true
    @State private var childProgress = 0

    private var uniqueOptions: [QuestionOption] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.display).inserted }
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(isShowingSequence
                 ? String(localized: "Watch closely… 👀")
                 : String(localized: "Your turn!"))
                .font(ForestTheme.Fonts.body)
                .foregroundStyle(ForestTheme.Colors.deepGreen)

            HStack(spacing: 14) {
                ForEach(items.indices, id: \.self) { index in
                    Text(items[index].display)
                        .font(.system(size: 46))
                        .scaleEffect(highlightedIndex == index ? 1.35 : 1)
                        .opacity(isShowingSequence || index < childProgress ? 1 : 0.25)
                        .animation(.bouncy(duration: 0.3), value: highlightedIndex)
                }
            }
            .padding()
            .forestCard()

            if !isShowingSequence {
                HStack(spacing: 16) {
                    ForEach(uniqueOptions) { option in
                        Button {
                            Task { await tapped(option) }
                        } label: {
                            Text(option.display)
                                .font(.system(size: 52))
                                .frame(width: 90, height: 90)
                                .background(ForestTheme.Colors.lavender.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(SquishyButtonStyle())
                        .accessibilityLabel(option.label)
                    }
                }
            }
        }
        .task { await playSequence() }
    }

    private func playSequence() async {
        try? await Task.sleep(for: .seconds(0.8))
        for index in items.indices {
            highlightedIndex = index
            viewModel.playSound(named: SoundEffect.tapPop.rawValue)
            try? await Task.sleep(for: .seconds(playbackInterval))
            highlightedIndex = nil
            try? await Task.sleep(for: .seconds(0.2))
        }
        withAnimation(.bouncy) { isShowingSequence = false }
    }

    private func tapped(_ option: QuestionOption) async {
        viewModel.gentleTapHaptic()
        if option.display == items[childProgress].display {
            childProgress += 1
            viewModel.playSound(named: SoundEffect.tapPop.rawValue)
            if childProgress == items.count {
                await viewModel.completeCurrentQuestion()
            }
        } else {
            childProgress = 0
            await viewModel.submitAnswer(correct: false)
            // Replay for a gentle second chance.
            isShowingSequence = true
            await playSequence()
        }
    }
}

// MARK: - Trace letter

struct TraceLetterGameView: View {
    let letter: String
    let guidePoints: [TracePoint]
    let viewModel: MissionViewModel

    @State private var visitedPoints: Set<Int> = []
    @State private var strokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(ForestTheme.Colors.cloudWhite)
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)

                    // Ghost letter (deepGreen adapts: soft green by day,
                    // soft mint by night — visible on the card either way)
                    Text(letter)
                        .font(.system(size: proxy.size.height * 0.7, weight: .heavy, design: .rounded))
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.28))

                    // Guide dots
                    ForEach(guidePoints.indices, id: \.self) { index in
                        Circle()
                            .fill(visitedPoints.contains(index)
                                  ? ForestTheme.Colors.sunshine
                                  : ForestTheme.Colors.lavender)
                            .frame(width: 26, height: 26)
                            .position(
                                x: CGFloat(guidePoints[index].x) * proxy.size.width,
                                y: CGFloat(guidePoints[index].y) * proxy.size.height
                            )
                            .animation(.bouncy(duration: 0.3), value: visitedPoints)
                    }

                    // Child's drawing
                    drawingPath
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
                            Task { await checkCompletion() }
                        }
                )
            }
            .frame(height: 320)
            .padding(.horizontal)
            .accessibilityLabel(String(localized: "Trace the letter \(letter) by following the dots"))
        }
    }

    private var drawingPath: Path {
        var path = Path()
        for stroke in strokes + [currentStroke] where !stroke.isEmpty {
            path.move(to: stroke[0])
            path.addLines(stroke)
        }
        return path
    }

    private func markVisited(near location: CGPoint, in size: CGSize) {
        for (index, point) in guidePoints.enumerated() {
            let target = CGPoint(x: CGFloat(point.x) * size.width, y: CGFloat(point.y) * size.height)
            if hypot(target.x - location.x, target.y - location.y) < 44 {
                if visitedPoints.insert(index).inserted {
                    viewModel.gentleTapHaptic()
                }
            }
        }
    }

    private func checkCompletion() async {
        if visitedPoints.count == guidePoints.count {
            await viewModel.completeCurrentQuestion()
        }
        // Not all dots yet? No penalty — the child just keeps tracing.
    }
}

// MARK: - Sound guess (listening)

struct SoundGuessGameView: View {
    let soundName: String
    let options: [QuestionOption]
    let correctID: UUID
    let viewModel: MissionViewModel

    var body: some View {
        VStack(spacing: 24) {
            Button {
                viewModel.playSound(named: soundName)
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 44))
                    Text(String(localized: "Play sound"))
                        .font(ForestTheme.Fonts.caption)
                }
                .foregroundStyle(.white)
                .frame(width: 140, height: 120)
                .background(ForestTheme.Colors.peach.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .buttonStyle(SquishyButtonStyle())
            .accessibilityLabel(String(localized: "Play the animal sound again"))

            TapCorrectGameView(options: options, correctID: correctID, viewModel: viewModel)
        }
        .task {
            // Let Bunny finish reading the prompt before the animal sound plays
            // (the spoken fallback would otherwise interrupt the question).
            try? await Task.sleep(for: .seconds(2.4))
            viewModel.playSound(named: soundName)
        }
    }
}
