//
//  TracingAndStreakTests.swift
//  FocusForestAdventureTests
//
//  Tracing accuracy scoring (glyph-outline coverage), daily streak
//  date logic, and daily usage accounting.
//

import XCTest
@testable import FocusForestAdventure

// MARK: - Tracing score

final class GlyphOutlineScoreTests: XCTestCase {

    // Production proportions (`TracingSessionView.canvas`): a glyph fitted
    // into a 360pt canvas is ~295pt tall, sampled every 10pt, and scored
    // with tolerance 36. The fixture keeps that ratio. The original fixture
    // was a 100-unit square, where a 36-unit tolerance is over a third of
    // the letter — and its "half" was `prefix(count/2)` of an interleaved
    // point list, i.e. the first half of *every* side. Every untraced
    // point of that shape lies within 25 units of a traced one, so with a
    // 36-unit brush the half really did cover the whole square (97).
    private static let side: CGFloat = 300
    private static let spacing: CGFloat = 10
    private static let tolerance: CGFloat = 36

    /// A square outline as target points.
    private func squareOutline() -> [CGPoint] {
        squarePerimeter(edges: 4)
    }

    /// The first `edges` sides of the square, walked in order — what a child
    /// who traces the letter from its start and stops partway leaves behind.
    private func squarePerimeter(edges: Int) -> [CGPoint] {
        let s = Self.side
        let corners = [CGPoint(x: 0, y: 0), CGPoint(x: s, y: 0),
                       CGPoint(x: s, y: s), CGPoint(x: 0, y: s), CGPoint(x: 0, y: 0)]
        var points: [CGPoint] = []
        for edge in 0..<edges {
            let a = corners[edge], b = corners[edge + 1]
            for t in stride(from: CGFloat(0), through: 1, by: Self.spacing / s) {
                points.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        return points
    }

    func testPerfectTraceScoresAtLeastPassScore() {
        let outline = squareOutline()
        // "Trace" exactly along the outline.
        let score = GlyphOutline.score(drawn: [outline], outline: outline, tolerance: Self.tolerance)
        XCTAssertGreaterThanOrEqual(score, TracingProgress.passScore,
                                    "An exact trace must pass (score was \(score))")
    }

    func testWobblyCompleteTracePasses() {
        // A child's hand shakes; a complete trace that stays inside the
        // tolerance band must pass. Guards the half-trace test below
        // against being satisfied by making the scorer strict for everyone.
        let outline = squareOutline()
        var generator = SystemRandomNumberGenerator()
        let wobbly = outline.map {
            CGPoint(x: $0.x + .random(in: -20...20, using: &generator),
                    y: $0.y + .random(in: -20...20, using: &generator))
        }
        let score = GlyphOutline.score(drawn: [wobbly], outline: outline, tolerance: Self.tolerance)
        XCTAssertGreaterThanOrEqual(score, TracingProgress.passScore,
                                    "A shaky but complete trace must pass (score was \(score))")
    }

    func testHalfTraceFailsThePassBar() {
        let outline = squareOutline()
        let half = squarePerimeter(edges: 2)
        let score = GlyphOutline.score(drawn: [half], outline: outline, tolerance: Self.tolerance)
        XCTAssertLessThan(score, TracingProgress.passScore,
                          "Tracing only half the letter must not pass (score was \(score))")
    }

    func testThreeQuarterTraceFailsThePassBar() {
        // The case the old top-end curve let through (93 for three sides).
        let outline = squareOutline()
        let mostOfIt = squarePerimeter(edges: 3)
        let score = GlyphOutline.score(drawn: [mostOfIt], outline: outline, tolerance: Self.tolerance)
        XCTAssertLessThan(score, TracingProgress.passScore,
                          "Leaving a whole side untraced must not pass (score was \(score))")
    }

    func testScribbleFarAwayScoresLow() {
        let outline = squareOutline()
        let scribble = (0..<80).map { _ in
            CGPoint(x: .random(in: 400...500), y: .random(in: 400...500))
        }
        let score = GlyphOutline.score(drawn: [scribble], outline: outline, tolerance: Self.tolerance)
        XCTAssertLessThan(score, 20)
    }

    func testEmptyInputsScoreZero() {
        XCTAssertEqual(GlyphOutline.score(drawn: [], outline: squareOutline(), tolerance: Self.tolerance), 0)
        XCTAssertEqual(GlyphOutline.score(drawn: [[CGPoint.zero]], outline: [], tolerance: Self.tolerance), 0)
    }

    func testWorkbookCovers49Letters() {
        let all = TracingWorkbook.sections.dropLast().flatMap(\.letters)
        XCTAssertEqual(Set(all).count, all.count, "No duplicate letters across sections 1–11")
        XCTAssertGreaterThanOrEqual(all.count, 45)
    }
}

// MARK: - Daily streak

final class DailyStreakTests: XCTestCase {

    private var calendar: Calendar { Calendar(identifier: .gregorian) }

    override func setUp() {
        UserDefaults.standard.removeObject(forKey: "streak.count")
        UserDefaults.standard.removeObject(forKey: "streak.lastDay")
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: Date(timeIntervalSince1970: 1_750_000_000))!
    }

    func testFirstActivityStartsStreakAtOne() {
        DailyStreak.recordActivity(on: day(0), calendar: calendar)
        XCTAssertEqual(DailyStreak.current(asOf: day(0), calendar: calendar), 1)
    }

    func testConsecutiveDaysExtendStreak() {
        DailyStreak.recordActivity(on: day(0), calendar: calendar)
        DailyStreak.recordActivity(on: day(1), calendar: calendar)
        DailyStreak.recordActivity(on: day(2), calendar: calendar)
        XCTAssertEqual(DailyStreak.current(asOf: day(2), calendar: calendar), 3)
    }

    func testSameDayCountsOnce() {
        DailyStreak.recordActivity(on: day(0), calendar: calendar)
        DailyStreak.recordActivity(on: day(0), calendar: calendar)
        XCTAssertEqual(DailyStreak.current(asOf: day(0), calendar: calendar), 1)
    }

    func testGapResetsStreak() {
        DailyStreak.recordActivity(on: day(0), calendar: calendar)
        DailyStreak.recordActivity(on: day(1), calendar: calendar)
        DailyStreak.recordActivity(on: day(4), calendar: calendar)   // skipped 2 days
        XCTAssertEqual(DailyStreak.current(asOf: day(4), calendar: calendar), 1)
    }

    func testStreakSurvivesOvernightUntilNextEvening() {
        DailyStreak.recordActivity(on: day(0), calendar: calendar)
        XCTAssertEqual(DailyStreak.current(asOf: day(1), calendar: calendar), 1,
                       "Yesterday's streak still shows today before playing")
        XCTAssertEqual(DailyStreak.current(asOf: day(2), calendar: calendar), 0,
                       "Two idle days break the chain")
    }
}
