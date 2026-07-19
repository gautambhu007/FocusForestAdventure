//
//  DotConnectView.swift
//  Focus Forest Adventure
//
//  Smart Dot Connect — the IQ puzzle: connect same-color dots with lines
//  that never cross. Difficulties Beginner→Genius, a seeded Daily
//  Challenge, Relax mode (no timer), hints, undo, three-star scoring,
//  calm synthesized music, glow/flash/confetti feedback.
//

import SwiftUI
import Observation

// MARK: - Cosmetic unlocks (earned with total puzzle stars)

enum DotBoardTheme: String, CaseIterable, Identifiable {
    case classic, meadow, dusk, night

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .classic: String(localized: "Classic")
        case .meadow: String(localized: "Meadow")
        case .dusk: String(localized: "Dusk")
        case .night: String(localized: "Night Sky")
        }
    }

    var emoji: String {
        switch self {
        case .classic: "☁️"
        case .meadow: "🌿"
        case .dusk: "🌆"
        case .night: "🌌"
        }
    }

    /// Total Smart Dots stars required.
    var requiredStars: Int {
        switch self {
        case .classic: 0
        case .meadow: 3
        case .dusk: 6
        case .night: 12
        }
    }
}

enum DotStyle: String, CaseIterable, Identifiable {
    case circle, star, heart, hexagon

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .circle: "circle.fill"
        case .star: "star.fill"
        case .heart: "heart.fill"
        case .hexagon: "hexagon.fill"
        }
    }

    var requiredStars: Int {
        switch self {
        case .circle: 0
        case .star: 5
        case .heart: 9
        case .hexagon: 15
        }
    }
}

// MARK: - View model

@Observable
@MainActor
final class DotConnectViewModel {

    static let palette: [Color] = [
        Color(red: 0.95, green: 0.45, blue: 0.42), Color(red: 0.35, green: 0.6, blue: 0.95),
        Color(red: 0.4, green: 0.75, blue: 0.45), Color(red: 0.98, green: 0.75, blue: 0.3),
        Color(red: 0.7, green: 0.5, blue: 0.9), Color(red: 0.98, green: 0.55, blue: 0.75),
        Color(red: 0.35, green: 0.75, blue: 0.75), Color(red: 0.85, green: 0.55, blue: 0.35),
        Color(red: 0.55, green: 0.6, blue: 0.3), Color(red: 0.45, green: 0.5, blue: 0.85),
        Color(red: 0.9, green: 0.4, blue: 0.6), Color(red: 0.3, green: 0.65, blue: 0.55),
        Color(red: 0.75, green: 0.45, blue: 0.45), Color(red: 0.5, green: 0.7, blue: 0.9),
        Color(red: 0.8, green: 0.65, blue: 0.35), Color(red: 0.6, green: 0.45, blue: 0.7)
    ]

    let dependencies: AppDependencies
    private let engine = DotConnectEngine()

    private(set) var puzzle: DotPuzzle?
    private(set) var difficulty: DotDifficulty = .beginner
    private(set) var isDaily = false
    var relaxMode = false

    /// Accepted connections as sorted dot-id pairs.
    private(set) var connections: [[Int]] = []
    private(set) var dragFromDot: Int?
    var dragPoint: CGPoint?
    private(set) var errorFlash = false
    private(set) var hintPair: [Int]?
    private(set) var hintsUsed = 0
    private(set) var elapsedSeconds = 0
    private(set) var solvedStars: Int?     // nil while playing

    private var timerTask: Task<Void, Never>?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        let defaults = UserDefaults.standard
        self.theme = DotBoardTheme(rawValue: defaults.string(forKey: "dots.theme") ?? "") ?? .classic
        self.dotStyle = DotStyle(rawValue: defaults.string(forKey: "dots.style") ?? "") ?? .circle
    }

    // MARK: Game lifecycle

    func start(_ difficulty: DotDifficulty) {
        self.difficulty = difficulty
        isDaily = false
        var rng = SystemRandomNumberGenerator()
        load(engine.generate(difficulty: difficulty, using: &rng))
    }

    func startDaily() {
        difficulty = .medium
        isDaily = true
        load(engine.dailyPuzzle())
    }

    func newPuzzle() {
        isDaily ? startDaily() : start(difficulty)
    }

    private func load(_ newPuzzle: DotPuzzle) {
        puzzle = newPuzzle
        connections = []
        hintPair = nil
        hintsUsed = 0
        elapsedSeconds = 0
        solvedStars = nil
        dragFromDot = nil
        dragPoint = nil
        dependencies.soundEngine.play(.cardFlip)
        if dependencies.appState.settings.isMusicEnabled {
            dependencies.breakMusicEngine.start()
        }
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.solvedStars == nil else { return }
                self.elapsedSeconds += 1
            }
        }
    }

    func close() {
        timerTask?.cancel()
        dependencies.breakMusicEngine.stop()
        puzzle = nil
    }

    // MARK: Connection state helpers

    func isConnected(_ dotID: Int) -> Bool {
        connections.contains { $0.contains(dotID) }
    }

    func color(of dot: DotPuzzle.Dot) -> Color {
        Self.palette[dot.colorIndex % Self.palette.count]
    }

    // MARK: Drag gameplay

    func dragBegan(at point: CGPoint) {
        guard solvedStars == nil, let puzzle else { return }
        if let dot = puzzle.dots.first(where: {
            !isConnected($0.id) && DotConnectEngine.distance($0.point, point) < 0.07
        }) {
            dragFromDot = dot.id
            dragPoint = point
            dependencies.hapticsService.playGentleTap()
        }
    }

    func dragMoved(to point: CGPoint) {
        guard dragFromDot != nil else { return }
        dragPoint = point
    }

    func dragEnded(at point: CGPoint) {
        defer { dragFromDot = nil; dragPoint = nil }
        guard solvedStars == nil, let puzzle, let fromID = dragFromDot else { return }
        let from = puzzle.dots[fromID]
        guard let target = puzzle.dots.first(where: {
            $0.id != fromID && !isConnected($0.id)
                && $0.colorIndex == from.colorIndex
                && DotConnectEngine.distance($0.point, point) < 0.09
        }) else { return }

        // Crossing check against every accepted line.
        let crosses = connections.contains { seg in
            DotConnectEngine.segmentsCross(
                puzzle.dots[seg[0]].point, puzzle.dots[seg[1]].point,
                from.point, target.point
            )
        }
        if crosses {
            flashError()
            return
        }

        connections.append([fromID, target.id].sorted())
        hintPair = nil
        dependencies.hapticsService.playSuccess()
        dependencies.soundEngine.play(.correctChime)
        checkSolved()
    }

    private func flashError() {
        errorFlash = true
        dependencies.hapticsService.playSoftWobble()
        dependencies.soundEngine.play(.gentleTryAgain)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.45))
            self?.errorFlash = false
        }
    }

    private func checkSolved() {
        guard let puzzle, connections.count == puzzle.pairCount else { return }
        // A complete non-crossing same-color matching IS the unique solution.
        let stars: Int
        if hintsUsed == 0 && elapsedSeconds <= difficulty.targetSeconds && !relaxMode {
            stars = 3
        } else if hintsUsed == 0 {
            stars = 2
        } else {
            stars = 1
        }
        solvedStars = stars
        timerTask?.cancel()
        dependencies.breakMusicEngine.stop()
        dependencies.hapticsService.playSuccess()
        dependencies.soundEngine.play(.starEarned)
        SyncedScoreStore.set(stars, forKey: "dots.\(isDaily ? "daily" : difficulty.rawValue)")
        DailyStreak.recordActivity()
        Task { await dependencies.speechService.speak(String(localized: "Amazing puzzle solving!")) }
    }

    // MARK: Tools

    func undo() {
        guard solvedStars == nil, !connections.isEmpty else { return }
        connections.removeLast()
        dependencies.hapticsService.playGentleTap()
    }

    func reset() {
        guard solvedStars == nil else { return }
        connections = []
        hintPair = nil
        dependencies.hapticsService.playGentleTap()
    }

    func hint() {
        guard solvedStars == nil, let puzzle else { return }
        // First unconnected pair from the true solution.
        guard let pair = puzzle.solution.first(where: { !connections.contains($0) }) else { return }
        hintPair = pair
        hintsUsed += 1
        dependencies.soundEngine.play(.tapPop)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            if self?.hintPair == pair { self?.hintPair = nil }
        }
    }

    static func bestStars(for key: String) -> Int {
        SyncedScoreStore.int(forKey: "dots.\(key)")
    }

    /// Ring boards (all dots ~0.40 from center) get chords bowed inward.
    var isRingBoard: Bool {
        guard let puzzle else { return false }
        return puzzle.dots.allSatisfy { dot in
            abs(DotConnectEngine.distance(dot.point, CGPoint(x: 0.5, y: 0.5)) - 0.40) < 0.02
        }
    }

    // MARK: Cosmetics

    /// Total stars across all difficulties + daily — the unlock currency.
    static func totalDotStars() -> Int {
        (DotDifficulty.allCases.map(\.rawValue) + ["daily"])
            .reduce(0) { $0 + bestStars(for: $1) }
    }

    var theme: DotBoardTheme = .classic {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "dots.theme") }
    }

    var dotStyle: DotStyle = .circle {
        didSet { UserDefaults.standard.set(dotStyle.rawValue, forKey: "dots.style") }
    }

    func isUnlocked(_ theme: DotBoardTheme) -> Bool {
        Self.totalDotStars() >= theme.requiredStars
    }

    func isUnlocked(_ style: DotStyle) -> Bool {
        Self.totalDotStars() >= style.requiredStars
    }
}

// MARK: - Views

struct DotConnectView: View {
    @State var viewModel: DotConnectViewModel

    var body: some View {
        ZStack {
            themeBackground.ignoresSafeArea()

            if viewModel.puzzle != nil {
                gameScreen
            } else {
                menuScreen
            }
        }
        .navigationTitle(String(localized: "🧠 Smart Dots"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { viewModel.close() }
    }

    @ViewBuilder
    private var themeBackground: some View {
        switch viewModel.theme {
        case .classic: ForestTheme.Colors.cloudWhite
        case .meadow: ForestTheme.Gradients.meadow
        case .dusk: ForestTheme.Gradients.sunset
        case .night: LinearGradient(colors: [Color(red: 0.08, green: 0.10, blue: 0.22),
                                             Color(red: 0.16, green: 0.14, blue: 0.32)],
                                    startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: Menu

    private var menuScreen: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(String(localized: "Connect matching colors — lines must never cross!"))
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                Toggle(isOn: $viewModel.relaxMode) {
                    Label(String(localized: "Relax mode (no timer)"), systemImage: "leaf")
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .forestCard(cornerRadius: 16)

                ForEach(DotDifficulty.allCases) { difficulty in
                    menuCard(
                        title: "\(difficulty.stars) \(difficulty.localizedTitle)",
                        subtitle: String(localized: "\(difficulty.pairRange.lowerBound)–\(difficulty.pairRange.upperBound) pairs"),
                        best: DotConnectViewModel.bestStars(for: difficulty.rawValue)
                    ) {
                        viewModel.start(difficulty)
                    }
                }

                menuCard(
                    title: String(localized: "📅 Daily Challenge"),
                    subtitle: String(localized: "One special puzzle every day"),
                    best: DotConnectViewModel.bestStars(for: "daily")
                ) {
                    viewModel.startDaily()
                }

                unlocksSection
            }
            .padding(ForestTheme.Metrics.screenPadding)
            .adaptiveContentWidth(600)
        }
    }

    /// Themes + dot styles earned with total puzzle stars.
    private var unlocksSection: some View {
        VStack(spacing: 10) {
            Text(String(localized: "🎨 Unlocks · \(DotConnectViewModel.totalDotStars()) ⭐ earned"))
                .font(ForestTheme.Fonts.body)
                .foregroundStyle(ForestTheme.Colors.deepGreen)

            HStack(spacing: 10) {
                ForEach(DotBoardTheme.allCases) { theme in
                    let unlocked = viewModel.isUnlocked(theme)
                    Button {
                        if unlocked { viewModel.theme = theme }
                    } label: {
                        VStack(spacing: 2) {
                            Text(unlocked ? theme.emoji : "🔒").font(.title2)
                            Text(unlocked ? theme.localizedTitle : "\(theme.requiredStars)⭐")
                                .font(ForestTheme.Fonts.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .forestCard(cornerRadius: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(viewModel.theme == theme && unlocked
                                        ? ForestTheme.Colors.leafGreen : .clear, lineWidth: 3)
                        )
                        .opacity(unlocked ? 1 : 0.55)
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .accessibilityLabel(String(localized: "\(theme.localizedTitle) theme\(unlocked ? "" : ", locked, needs \(theme.requiredStars) stars")"))
                }
            }

            HStack(spacing: 10) {
                ForEach(DotStyle.allCases) { style in
                    let unlocked = viewModel.isUnlocked(style)
                    Button {
                        if unlocked { viewModel.dotStyle = style }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: unlocked ? style.symbol : "lock.fill")
                                .font(.title2)
                                .foregroundStyle(unlocked
                                                 ? DotConnectViewModel.palette[style.requiredStars % 16]
                                                 : .secondary)
                            Text(unlocked ? " " : "\(style.requiredStars)⭐")
                                .font(ForestTheme.Fonts.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .forestCard(cornerRadius: 14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(viewModel.dotStyle == style && unlocked
                                        ? ForestTheme.Colors.leafGreen : .clear, lineWidth: 3)
                        )
                        .opacity(unlocked ? 1 : 0.55)
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .accessibilityLabel(String(localized: "Dot style\(unlocked ? "" : ", locked, needs \(style.requiredStars) stars")"))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .forestCard(cornerRadius: 20)
    }

    private func menuCard(title: String, subtitle: String, best: Int,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(ForestTheme.Fonts.body)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                    Text(subtitle)
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if best > 0 {
                    Text(String(repeating: "⭐", count: best))
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .forestCard(cornerRadius: 20)
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel("\(title), \(subtitle)")
    }

    // MARK: Game

    private var gameScreen: some View {
        VStack(spacing: 10) {
            hud
            board
            tools
        }
        .padding(.vertical, 8)
        .adaptiveContentWidth(700)
    }

    private var hud: some View {
        HStack {
            Button {
                viewModel.close()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .padding(10)
                    .forestCard(cornerRadius: 14)
            }
            .buttonStyle(SquishyButtonStyle())
            .accessibilityLabel(String(localized: "Back to menu"))

            Spacer()
            Text(viewModel.isDaily
                 ? String(localized: "Daily Challenge")
                 : viewModel.difficulty.localizedTitle)
                .font(ForestTheme.Fonts.body)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
            Spacer()

            if !viewModel.relaxMode {
                Text("⏱ \(viewModel.elapsedSeconds)s")
                    .font(ForestTheme.Fonts.caption)
                    .monospacedDigit()
                    .foregroundStyle(viewModel.elapsedSeconds <= viewModel.difficulty.targetSeconds
                                     ? ForestTheme.Colors.deepGreen : .orange)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .forestCard(cornerRadius: 12)
            }
        }
        .padding(.horizontal, ForestTheme.Metrics.screenPadding)
    }

    private var board: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let canvasPoint: (CGPoint) -> CGPoint = { p in
                CGPoint(x: p.x * size.width, y: p.y * size.height)
            }
            let normalized: (CGPoint) -> CGPoint = { p in
                CGPoint(x: p.x / size.width, y: p.y / size.height)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(viewModel.errorFlash ? .red : ForestTheme.Colors.cardStroke.opacity(0.4),
                                    lineWidth: viewModel.errorFlash ? 5 : 1.5)
                    )
                    .animation(.easeOut(duration: 0.2), value: viewModel.errorFlash)

                if let puzzle = viewModel.puzzle {
                    // Accepted lines: elegant arcs. Ring boards bow chords
                    // toward the center (clears the rim dots); others get a
                    // gentle length-proportional perpendicular bow.
                    let boardCenter = CGPoint(x: size.width / 2, y: size.height / 2)
                    let ring = viewModel.isRingBoard
                    ForEach(viewModel.connections, id: \.self) { pair in
                        let a = canvasPoint(puzzle.dots[pair[0]].point)
                        let b = canvasPoint(puzzle.dots[pair[1]].point)
                        connectionCurve(from: a, to: b,
                                        towardCenter: ring ? boardCenter : nil)
                            .stroke(viewModel.color(of: puzzle.dots[pair[0]]).opacity(0.85),
                                    style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .shadow(color: viewModel.color(of: puzzle.dots[pair[0]]).opacity(0.6),
                                    radius: 6)
                    }

                    // Live drag line
                    if let fromID = viewModel.dragFromDot, let dragPoint = viewModel.dragPoint {
                        let from = canvasPoint(puzzle.dots[fromID].point)
                        Path { path in
                            path.move(to: from)
                            path.addLine(to: canvasPoint(dragPoint))
                        }
                        .stroke(viewModel.color(of: puzzle.dots[fromID]).opacity(0.5),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [2, 8]))
                    }

                    // Dots (in the unlocked style of choice)
                    ForEach(puzzle.dots) { dot in
                        let hinted = viewModel.hintPair?.contains(dot.id) == true
                        Image(systemName: viewModel.dotStyle.symbol)
                            .font(.system(size: 30))
                            .foregroundStyle(viewModel.color(of: dot))
                            .background(
                                Circle().fill(.white.opacity(viewModel.isConnected(dot.id) ? 0.9 : 0.55))
                                    .frame(width: 42, height: 42)
                            )
                            .scaleEffect(hinted ? 1.35 : 1.0)
                            .shadow(color: hinted ? ForestTheme.Colors.sunshine : .black.opacity(0.15),
                                    radius: hinted ? 12 : 3)
                            .position(canvasPoint(dot.point))
                            .animation(.bouncy(duration: 0.35), value: hinted)
                            .animation(.bouncy(duration: 0.35), value: viewModel.isConnected(dot.id))
                            .accessibilityLabel(String(localized: "Dot, color \(dot.colorIndex + 1)\(viewModel.isConnected(dot.id) ? ", connected" : "")"))
                    }

                    if viewModel.solvedStars != nil {
                        ConfettiView(particleCount: 60).allowsHitTesting(false)
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if viewModel.dragFromDot == nil {
                            viewModel.dragBegan(at: normalized(value.location))
                        } else {
                            viewModel.dragMoved(to: normalized(value.location))
                        }
                    }
                    .onEnded { value in
                        viewModel.dragEnded(at: normalized(value.location))
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, ForestTheme.Metrics.screenPadding)
    }

    /// Elegant arc between dots. When `towardCenter` is set (ring boards)
    /// the bow pulls inward — visually clearing the rim dots; otherwise a
    /// perpendicular bow proportional to length.
    private func connectionCurve(from a: CGPoint, to b: CGPoint,
                                 towardCenter center: CGPoint? = nil) -> Path {
        var path = Path()
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let dx = b.x - a.x, dy = b.y - a.y
        let length = max(1, hypot(dx, dy))
        let control: CGPoint
        if let center {
            // Bow toward the board center, stronger for longer chords.
            let bow = min(0.30 * length, 46)
            let toCenter = CGPoint(x: center.x - mid.x, y: center.y - mid.y)
            let centerDistance = max(1, hypot(toCenter.x, toCenter.y))
            control = CGPoint(x: mid.x + toCenter.x / centerDistance * bow * 2,
                              y: mid.y + toCenter.y / centerDistance * bow * 2)
        } else {
            let bow = min(0.10 * length, 18)
            control = CGPoint(x: mid.x - dy / length * bow * 2,
                              y: mid.y + dx / length * bow * 2)
        }
        path.move(to: a)
        path.addQuadCurve(to: b, control: control)
        return path
    }

    private var tools: some View {
        Group {
            if let stars = viewModel.solvedStars {
                VStack(spacing: 10) {
                    Text(String(repeating: "⭐", count: stars))
                        .font(.system(size: 44))
                    Text(stars == 3 ? String(localized: "Genius! Fast and flawless!")
                         : stars == 2 ? String(localized: "Brilliant — no hints!")
                         : String(localized: "Puzzle solved!"))
                        .font(ForestTheme.Fonts.heading)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                    HStack(spacing: 12) {
                        BigBouncyButton(title: String(localized: "Next puzzle!"),
                                        icon: "arrow.right",
                                        color: ForestTheme.Colors.leafGreen) {
                            viewModel.newPuzzle()
                        }
                    }
                }
            } else {
                HStack(spacing: 10) {
                    toolButton("arrow.uturn.backward", String(localized: "Undo")) { viewModel.undo() }
                    toolButton("trash", String(localized: "Reset")) { viewModel.reset() }
                    toolButton("lightbulb", String(localized: "Hint")) { viewModel.hint() }
                    toolButton("sparkles", String(localized: "New")) { viewModel.newPuzzle() }
                }
                .padding(.horizontal, ForestTheme.Metrics.screenPadding)
            }
        }
    }

    private func toolButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.title3)
                Text(label).font(ForestTheme.Fonts.caption)
            }
            .foregroundStyle(ForestTheme.Colors.deepGreen)
            .frame(maxWidth: .infinity, minHeight: 54)
            .forestCard(cornerRadius: 16)
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel(label)
    }
}
