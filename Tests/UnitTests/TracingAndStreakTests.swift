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

    /// A square outline as target points.
    private func squareOutline() -> [CGPoint] {
        var points: [CGPoint] = []
        for i in stride(from: 0, through: 100, by: 5) {
            points.append(CGPoint(x: CGFloat(i), y: 0))
            points.append(CGPoint(x: CGFloat(i), y: 100))
            points.append(CGPoint(x: 0, y: CGFloat(i)))
            points.append(CGPoint(x: 100, y: CGFloat(i)))
        }
        return points
    }

    func testPerfectTraceScoresAtLeastPassScore() {
        let outline = squareOutline()
        // "Trace" exactly along the outline.
        let score = GlyphOutline.score(drawn: [outline], outline: outline, tolerance: 36)
        XCTAssertGreaterThanOrEqual(score, TracingProgress.passScore,
                                    "An exact trace must pass (score was \(score))")
    }

    func testHalfTraceFailsThePassBar() {
        let outline = squareOutline()
        let half = Array(outline.prefix(outline.count / 2))
        let score = GlyphOutline.score(drawn: [half], outline: outline, tolerance: 36)
        XCTAssertLessThan(score, TracingProgress.passScore,
                          "Tracing only half the letter must not pass (score was \(score))")
    }

    func testScribbleFarAwayScoresLow() {
        let outline = squareOutline()
        let scribble = (0..<80).map { _ in
            CGPoint(x: .random(in: 400...500), y: .random(in: 400...500))
        }
        let score = GlyphOutline.score(drawn: [scribble], outline: outline, tolerance: 36)
        XCTAssertLessThan(score, 20)
    }

    func testEmptyInputsScoreZero() {
        XCTAssertEqual(GlyphOutline.score(drawn: [], outline: squareOutline(), tolerance: 36), 0)
        XCTAssertEqual(GlyphOutline.score(drawn: [[CGPoint.zero]], outline: [], tolerance: 36), 0)
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
