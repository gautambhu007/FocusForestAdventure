//
//  HindiTracingWorkbook.swift
//  Focus Forest Adventure
//
//  Section-based Hindi handwriting workbook (ages 4–7). Twelve sections of
//  grouped letters; inside a section, letters come one at a time in fixed
//  order — hear it, watch the path animate, trace it, get scored, advance.
//
//  Key engineering choice: letter outlines are extracted from the SYSTEM
//  FONT via Core Text glyph paths, so every letter (including conjuncts
//  क्ष/त्र/ज्ञ and अं/अः) gets a pixel-accurate outline and a real
//  coverage-based accuracy score — no hand-authored path data.
//
//  Scoring (< a few ms): sample the glyph outline into points; score =
//  70% coverage (outline points the child passed near) + 30% precision
//  (child's points that stayed near the outline). 60%+ passes.
//

import SwiftUI
import CoreText
import UIKit

// MARK: - Glyph path extraction

enum GlyphOutline {

    /// Combined CGPath for a string (handles conjunct clusters via CTLine).
    static func path(for text: String, fontSize: CGFloat) -> CGPath? {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return nil }

        let combined = CGMutablePath()
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            let attributes = CTRunGetAttributes(run) as! [NSAttributedString.Key: Any]
            let runFont = attributes[.font] as! UIFont
            for index in 0..<count {
                if let glyphPath = CTFontCreatePathForGlyph(runFont as CTFont, glyphs[index], nil) {
                    let transform = CGAffineTransform(translationX: positions[index].x,
                                                      y: positions[index].y)
                    combined.addPath(glyphPath, transform: transform)
                }
            }
        }
        return combined.isEmpty ? nil : combined
    }

    /// Path scaled + centered into `rect` (font space is y-up; flip it).
    static func fitted(_ path: CGPath, into rect: CGRect) -> CGPath {
        let box = path.boundingBoxOfPath
        guard box.width > 0, box.height > 0 else { return path }
        let scale = min(rect.width / box.width, rect.height / box.height) * 0.82
        var transform = CGAffineTransform.identity
            .translatedBy(x: rect.midX, y: rect.midY)
            .scaledBy(x: scale, y: -scale)   // flip y for UIKit space
            .translatedBy(x: -box.midX, y: -box.midY)
        return path.copy(using: &transform) ?? path
    }

    /// Flatten a path into evenly spaced sample points (curves subdivided).
    static func samples(of path: CGPath, spacing: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        var current = CGPoint.zero

        func line(to end: CGPoint) {
            let distance = hypot(end.x - current.x, end.y - current.y)
            let steps = max(1, Int(distance / spacing))
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                points.append(CGPoint(x: current.x + (end.x - current.x) * t,
                                      y: current.y + (end.y - current.y) * t))
            }
            current = end
        }

        path.applyWithBlock { element in
            let pts = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                current = pts[0]
                points.append(current)
            case .addLineToPoint:
                line(to: pts[0])
            case .addQuadCurveToPoint:
                let start = current, control = pts[0], end = pts[1]
                for step in 1...8 {
                    let t = CGFloat(step) / 8
                    let x = (1-t)*(1-t)*start.x + 2*(1-t)*t*control.x + t*t*end.x
                    let y = (1-t)*(1-t)*start.y + 2*(1-t)*t*control.y + t*t*end.y
                    line(to: CGPoint(x: x, y: y))
                }
            case .addCurveToPoint:
                let start = current, c1 = pts[0], c2 = pts[1], end = pts[2]
                for step in 1...10 {
                    let t = CGFloat(step) / 10
                    let mt = 1 - t
                    let x = mt*mt*mt*start.x + 3*mt*mt*t*c1.x + 3*mt*t*t*c2.x + t*t*t*end.x
                    let y = mt*mt*mt*start.y + 3*mt*mt*t*c1.y + 3*mt*t*t*c2.y + t*t*t*end.y
                    line(to: CGPoint(x: x, y: y))
                }
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        return points
    }

    /// Accuracy 0–100: coverage of the outline + precision of the strokes.
    /// Calibrated for a 99% completion bar: a careful, COMPLETE trace by a
    /// child should genuinely reach 99–100, while partial or off-shape
    /// traces cannot — so the curve is generous near the top but the
    /// coverage requirement stays strict.
    static func score(drawn: [[CGPoint]], outline: [CGPoint], tolerance: CGFloat) -> Int {
        let drawnPoints = drawn.flatMap { $0 }
        guard !drawnPoints.isEmpty, !outline.isEmpty else { return 0 }
        let tolerance2 = tolerance * tolerance

        func near(_ point: CGPoint, _ set: [CGPoint]) -> Bool {
            for other in set {
                let dx = point.x - other.x, dy = point.y - other.y
                if dx*dx + dy*dy < tolerance2 { return true }
            }
            return false
        }

        let covered = outline.filter { near($0, drawnPoints) }.count
        let precise = drawnPoints.filter { near($0, outline) }.count
        let coverage = Double(covered) / Double(outline.count)
        let precision = Double(precise) / Double(drawnPoints.count)
        let raw = coverage * 0.7 + precision * 0.3
        // Forgiving top-end curve: raw 0.95 → ~97, raw 0.98 → ~99.
        let curved = pow(raw, 0.55)
        return min(100, Int((curved * 100).rounded()))
    }
}

// MARK: - Sections & progress

struct TracingSection: Identifiable, Sendable {
    let id: Int
    let titleHindi: String
    let titleEnglish: String
    let letters: [String]
}

enum TracingWorkbook {
    static let sections: [TracingSection] = [
        TracingSection(id: 1, titleHindi: "स्वर – भाग 1", titleEnglish: "Vowels 1", letters: ["अ", "आ", "इ", "ई"]),
        TracingSection(id: 2, titleHindi: "स्वर – भाग 2", titleEnglish: "Vowels 2", letters: ["उ", "ऊ", "ऋ", "ए"]),
        TracingSection(id: 3, titleHindi: "स्वर – भाग 3", titleEnglish: "Vowels 3", letters: ["ऐ", "ओ", "औ", "अं", "अः"]),
        TracingSection(id: 4, titleHindi: "क वर्ग", titleEnglish: "Ka group", letters: ["क", "ख", "ग", "घ", "ङ"]),
        TracingSection(id: 5, titleHindi: "च वर्ग", titleEnglish: "Cha group", letters: ["च", "छ", "ज", "झ", "ञ"]),
        TracingSection(id: 6, titleHindi: "ट वर्ग", titleEnglish: "Ta group", letters: ["ट", "ठ", "ड", "ढ", "ण"]),
        TracingSection(id: 7, titleHindi: "त वर्ग", titleEnglish: "Ta group 2", letters: ["त", "थ", "द", "ध", "न"]),
        TracingSection(id: 8, titleHindi: "प वर्ग", titleEnglish: "Pa group", letters: ["प", "फ", "ब", "भ", "म"]),
        TracingSection(id: 9, titleHindi: "य वर्ग", titleEnglish: "Ya group", letters: ["य", "र", "ल", "व"]),
        TracingSection(id: 10, titleHindi: "श वर्ग", titleEnglish: "Sha group", letters: ["श", "ष", "स", "ह"]),
        TracingSection(id: 11, titleHindi: "संयुक्त अक्षर", titleEnglish: "Conjuncts", letters: ["क्ष", "त्र", "ज्ञ"]),
        TracingSection(id: 12, titleHindi: "दोहराव चुनौती", titleEnglish: "Revision Challenge",
                       letters: ["अ", "क", "म", "र", "स", "ज"].shuffled())
    ]

    static let allLetterCount = sections.dropLast().reduce(0) { $0 + $1.letters.count }
}

enum TracingProgress {
    /// Completion bar: a letter counts at 88%+ accuracy.
    /// (Single knob — tuned from 60 → 99 → 88 based on real-child testing.)
    static let passScore = 88

    // UserDefaults isn't Sendable, so it's accessed inline (never stored
    // statically) to satisfy Swift 6 strict concurrency.

    static func bestScore(_ letter: String) -> Int {
        SyncedScoreStore.int(forKey: "trace.best.\(letter)")
    }

    static func record(_ score: Int, letter: String) {
        DailyStreak.recordActivity()
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: "trace.attempts.\(letter)") + 1,
                     forKey: "trace.attempts.\(letter)")
        SyncedScoreStore.set(score, forKey: "trace.best.\(letter)")
    }

    static func isCompleted(_ letter: String) -> Bool { bestScore(letter) >= passScore }

    static func completedCount(in section: TracingSection) -> Int {
        section.letters.filter(isCompleted).count
    }

    static func isSectionComplete(_ section: TracingSection) -> Bool {
        completedCount(in: section) == section.letters.count
    }

    static func isSectionPerfect(_ section: TracingSection) -> Bool {
        // With a 99% completion bar, "perfect" means flawless 100s.
        section.letters.allSatisfy { bestScore($0) >= 100 }
    }

    /// First not-yet-completed section is the "current" one; later = locked.
    static func firstIncompleteIndex() -> Int {
        TracingWorkbook.sections.firstIndex { !isSectionComplete($0) } ?? TracingWorkbook.sections.count - 1
    }

    /// Overall course progress 0…1.
    static func overallProgress() -> Double {
        let all = TracingWorkbook.sections.flatMap(\.letters)
        let done = all.filter(isCompleted).count
        return all.isEmpty ? 0 : Double(done) / Double(all.count)
    }
}

// MARK: - Section list screen

struct HindiTracingWorkbookView: View {
    let dependencies: AppDependencies

    @State private var activeSection: TracingSection?
    @State private var refresh = 0   // bumps after a section closes

    var body: some View {
        ZStack {
            ForestTheme.Gradients.morningSky.ignoresSafeArea()

            if let section = activeSection {
                TracingSessionView(section: section, dependencies: dependencies) {
                    activeSection = nil
                    refresh += 1
                }
            } else {
                sectionList
            }
        }
        .navigationTitle(String(localized: "✍️ हिंदी लिखना सीखें"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { dependencies.speechService.stop() }
    }

    private var sectionList: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Overall course progress
                let progress = TracingProgress.overallProgress()
                VStack(spacing: 6) {
                    Text(String(localized: "Progress: \(Int(progress * 100))%"))
                        .font(ForestTheme.Fonts.body)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                    Gauge(value: progress) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                        .tint(ForestTheme.Colors.leafGreen)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .forestCard(cornerRadius: 18)

                let currentIndex = TracingProgress.firstIncompleteIndex()
                ForEach(Array(TracingWorkbook.sections.enumerated()), id: \.element.id) { index, section in
                    sectionCard(section, index: index, currentIndex: currentIndex)
                }
            }
            .padding(ForestTheme.Metrics.screenPadding)
            .adaptiveContentWidth(650)
        }
        .id(refresh)
    }

    private func sectionCard(_ section: TracingSection, index: Int, currentIndex: Int) -> some View {
        let complete = TracingProgress.isSectionComplete(section)
        let perfect = TracingProgress.isSectionPerfect(section)
        let locked = index > currentIndex
        let done = TracingProgress.completedCount(in: section)

        return Button {
            guard !locked else {
                dependencies.hapticsService.playSoftWobble()
                return
            }
            dependencies.hapticsService.playGentleTap()
            activeSection = section
        } label: {
            HStack(spacing: 14) {
                Text(perfect ? "⭐" : complete ? "✅" : locked ? "🔒" : "▶️")
                    .font(.system(size: 34))

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Section \(section.id) · \(section.titleHindi)"))
                        .font(ForestTheme.Fonts.body)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                    Text(section.letters.joined(separator: "  "))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(locked ? 0.35 : 0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(String(localized: "\(done) / \(section.letters.count) completed"))
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .forestCard(cornerRadius: 22)
            .opacity(locked ? 0.6 : 1)
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel(String(localized: "Section \(section.id), \(section.titleEnglish), \(done) of \(section.letters.count) completed\(locked ? ", locked" : "")"))
    }
}

// MARK: - Tracing session (one section, letters in order)

struct TracingSessionView: View {
    let section: TracingSection
    let dependencies: AppDependencies
    let onClose: () -> Void

    private static let successPhrases = ["बहुत बढ़िया!", "शानदार!", "वाह!", "कमाल कर दिया!",
                                         "तुम बहुत अच्छा लिख रहे हो!", "सुपर!",
                                         "मुझे तुम पर गर्व है!", "इसी तरह करते रहो!"]
    private static let retryPhrases = ["कोई बात नहीं।", "एक बार और कोशिश करो।",
                                       "तुम कर सकते हो।", "चलो फिर से बनाते हैं।"]

    @State private var letterIndex = 0
    @State private var strokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var lastScore: Int?
    @State private var passed = false
    @State private var sectionDone = false
    @State private var sparkle = 0
    @State private var replayStart: Date?

    private var letter: String { section.letters[letterIndex] }

    var body: some View {
        VStack(spacing: 10) {
            header

            if sectionDone {
                celebration
            } else {
                canvas
                feedbackRow
                controls
            }
        }
        .padding(.vertical, 8)
        .adaptiveContentWidth(650)
        .task { introduceLetter() }
    }

    private var header: some View {
        HStack {
            Button {
                dependencies.speechService.stop()
                onClose()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .padding(10)
                    .forestCard(cornerRadius: 14)
            }
            .buttonStyle(SquishyButtonStyle())
            .accessibilityLabel(String(localized: "Back to sections"))

            Spacer()

            VStack(spacing: 2) {
                Text(section.titleHindi)
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                Text(String(localized: "Letter \(letterIndex + 1) of \(section.letters.count)"))
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(letter)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .frame(width: 48, height: 48)
                .forestCard(cornerRadius: 14)
        }
        .padding(.horizontal, ForestTheme.Metrics.screenPadding)
    }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)
            let glyph = GlyphOutline.path(for: letter, fontSize: 200)
                .map { GlyphOutline.fitted($0, into: rect) }
            let outline = glyph.map { GlyphOutline.samples(of: $0, spacing: 10) } ?? []

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(ForestTheme.Colors.cloudWhite)
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 5)

                // Light outline of the true letter shape
                if let glyph {
                    Path(glyph)
                        .stroke(ForestTheme.Colors.deepGreen.opacity(0.22),
                                style: StrokeStyle(lineWidth: 3))
                    Path(glyph)
                        .fill(ForestTheme.Colors.deepGreen.opacity(0.06))
                }

                // Starting dot (first outline point)
                if let start = outline.first {
                    Circle()
                        .fill(ForestTheme.Colors.leafGreen)
                        .frame(width: 22, height: 22)
                        .position(start)
                        .accessibilityHidden(true)
                }

                // Replay animation: a dot travels the outline
                if let replayStart {
                    TimelineView(.animation) { timeline in
                        let t = timeline.date.timeIntervalSince(replayStart) / 3.0
                        if t < 1, !outline.isEmpty {
                            let index = min(Int(t * Double(outline.count)), outline.count - 1)
                            Circle()
                                .fill(ForestTheme.Colors.sunshine)
                                .frame(width: 18, height: 18)
                                .position(outline[index])
                        }
                    }
                    .allowsHitTesting(false)
                }

                // Child's strokes
                drawnPath
                    .stroke(ForestTheme.Colors.bubblegum,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))

                SparkleBurstView(trigger: sparkle)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !passed else { return }
                        currentStroke.append(value.location)
                    }
                    .onEnded { _ in
                        guard !passed else { return }
                        strokes.append(currentStroke)
                        currentStroke = []
                        evaluate(outline: outline)
                    }
            )
        }
        .frame(height: 360)
        .padding(.horizontal, ForestTheme.Metrics.screenPadding)
        .accessibilityLabel(String(localized: "Trace the letter \(letter) with your finger"))
    }

    private var drawnPath: Path {
        var path = Path()
        for stroke in strokes + [currentStroke] where stroke.count > 1 {
            path.move(to: stroke[0])
            for point in stroke.dropFirst() { path.addLine(to: point) }
        }
        return path
    }

    private var feedbackRow: some View {
        HStack(spacing: 8) {
            if let lastScore {
                if passed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ForestTheme.Colors.leafGreen)
                    Text(String(localized: "\(lastScore)% — शाबाश!"))
                } else if lastScore >= 78 {
                    Text(String(localized: "\(lastScore)% — so close! Trace every part of the letter!"))
                } else {
                    Text(String(localized: "\(lastScore)% — try once more!"))
                }
            } else {
                Text(String(localized: "Start at the green dot and trace the letter!"))
            }
        }
        .font(ForestTheme.Fonts.body)
        .foregroundStyle(ForestTheme.Colors.deepGreen)
        .frame(minHeight: 30)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            controlButton("arrow.uturn.backward", String(localized: "Undo")) {
                _ = strokes.popLast()
            }
            controlButton("trash", String(localized: "Clear")) {
                strokes = []
                lastScore = nil
            }
            controlButton("play.circle", String(localized: "Watch")) {
                replayStart = .now
            }
            controlButton("speaker.wave.2", String(localized: "Hear")) {
                speakLetter()
            }
        }
        .padding(.horizontal, ForestTheme.Metrics.screenPadding)
    }

    private func controlButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
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

    private var celebration: some View {
        VStack(spacing: 16) {
            ConfettiView(particleCount: 70).ignoresSafeArea().allowsHitTesting(false)
            Text("🎉")
                .font(.system(size: 90))
                .floating(amplitude: 8, period: 1.4)
            Text(String(localized: "Section Completed!"))
                .font(ForestTheme.Fonts.title)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
            Text(String(localized: "Great job! You earned a gold star ⭐"))
                .font(ForestTheme.Fonts.body)
                .foregroundStyle(.secondary)
            BigBouncyButton(
                title: String(localized: "Back to sections"),
                icon: "square.grid.2x2.fill",
                color: ForestTheme.Colors.sunshine
            ) {
                onClose()
            }
        }
        .padding(24)
    }

    // MARK: Flow

    private func introduceLetter() {
        strokes = []
        currentStroke = []
        lastScore = nil
        passed = false
        replayStart = .now   // auto-play the tracing animation
        speakLetter()
    }

    private func speakLetter() {
        Task { await dependencies.speechService.speak(letter, language: "hi-IN") }
    }

    private func evaluate(outline: [CGPoint]) {
        guard !outline.isEmpty, !strokes.isEmpty else { return }
        // Tolerance widened alongside the 99% bar: forgiving of wobble,
        // strict about completeness.
        let score = GlyphOutline.score(drawn: strokes, outline: outline, tolerance: 36)
        lastScore = score
        TracingProgress.record(score, letter: letter)

        if score >= TracingProgress.passScore {
            passed = true
            sparkle += 1
            dependencies.hapticsService.playSuccess()
            dependencies.soundEngine.play(.starEarned)
            Task {
                await dependencies.speechService.speak(
                    Self.successPhrases.randomElement()!, language: "hi-IN"
                )
                try? await Task.sleep(for: .seconds(1.6))
                advance()
            }
        } else if strokes.count >= 2 {
            // Gentle nudge only after real effort — never on the first stroke.
            Task {
                await dependencies.speechService.speak(
                    Self.retryPhrases.randomElement()!, language: "hi-IN"
                )
            }
        }
    }

    private func advance() {
        if letterIndex + 1 < section.letters.count {
            letterIndex += 1
            introduceLetter()
        } else {
            sectionDone = true
            dependencies.soundEngine.play(.correctChime)
            dependencies.hapticsService.playSuccess()
            Task { await dependencies.speechService.speak("शाबाश! सेक्शन पूरा हो गया!", language: "hi-IN") }
        }
    }
}
