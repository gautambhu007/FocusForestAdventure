//
//  Phase23to28Tests.swift
//  FocusForestAdventureTests
//
//  Tests for Phases 2.3–2.8: dashboard insights, report exports, AR scene
//  state, gesture classification, engagement pacing, daily recommendations.
//

import XCTest
import simd
@testable import FocusForestAdventure

// MARK: - 2.3 Dashboard insights

final class DashboardInsightsTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ offset: Int, from today: Date) -> Date {
        calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: today))!
    }

    func testStreakCountsConsecutiveDays() {
        let today = Date()
        let focus: [Date: TimeInterval] = [
            day(0, from: today): 300,
            day(1, from: today): 200,
            day(2, from: today): 100
        ]
        let insights = DashboardInsights.compute(dailyFocus: focus, calendar: calendar, today: today)
        XCTAssertEqual(insights.currentStreakDays, 3)
    }

    func testMissingTodayDoesNotBreakStreak() {
        let today = Date()
        let focus: [Date: TimeInterval] = [
            day(1, from: today): 300,
            day(2, from: today): 200
        ]
        let insights = DashboardInsights.compute(dailyFocus: focus, calendar: calendar, today: today)
        XCTAssertEqual(insights.currentStreakDays, 2,
                       "Not having played YET today shouldn't zero the streak")
    }

    func testGapBreaksStreak() {
        let today = Date()
        let focus: [Date: TimeInterval] = [
            day(0, from: today): 300,
            day(2, from: today): 200   // gap at day 1
        ]
        let insights = DashboardInsights.compute(dailyFocus: focus, calendar: calendar, today: today)
        XCTAssertEqual(insights.currentStreakDays, 1)
    }

    func testWeeklyTrendComparesWindows() {
        let today = Date()
        var focus: [Date: TimeInterval] = [:]
        for back in 0...6 { focus[day(back, from: today)] = 600 }    // 70 min
        for back in 7...13 { focus[day(back, from: today)] = 300 }   // 35 min
        let insights = DashboardInsights.compute(dailyFocus: focus, calendar: calendar, today: today)
        XCTAssertEqual(insights.thisWeekMinutes, 70)
        XCTAssertEqual(insights.previousWeekMinutes, 35)
        XCTAssertEqual(insights.weeklyTrendPercent, 100)
    }

    func testNoBaselineMeansNoTrend() {
        let today = Date()
        let focus: [Date: TimeInterval] = [day(0, from: today): 600]
        let insights = DashboardInsights.compute(dailyFocus: focus, calendar: calendar, today: today)
        XCTAssertNil(insights.weeklyTrendPercent)
    }
}

// MARK: - 2.4 Reports

final class ReportTests: XCTestCase {

    private func makeSummary() -> PerformanceSummary {
        var summary = PerformanceSummary()
        summary.totalMissions = 8
        summary.totalFocusSeconds = 1200
        summary.averageAttentionScore = 0.72
        summary.perSubject[.numbers] = .init(
            missions: 5, accuracy: 0.8, averageResponseTime: 4.25, currentDifficulty: 2
        )
        summary.perSubject[.colors] = .init(
            missions: 3, accuracy: 0.66, averageResponseTime: 5.5, currentDifficulty: 1
        )
        return summary
    }

    func testReportBuilderAggregates() {
        let report = ReportBuilder().makeReport(
            childName: "Mira", rangeDays: 7, summary: makeSummary(),
            achievements: [.firstMission], recommendations: ["Keep it playful."]
        )
        XCTAssertEqual(report.totalMissions, 8)
        XCTAssertEqual(report.focusMinutes, 20)
        XCTAssertEqual(report.attentionPercent, 72)
        XCTAssertEqual(report.subjects.count, 2)
        XCTAssertEqual(report.subjects.first?.missions, 5, "Rows sorted by missions desc")
    }

    func testCSVHasStableColumnsAndRows() {
        let report = ReportBuilder().makeReport(
            childName: "Mira", rangeDays: 7, summary: makeSummary(),
            achievements: [], recommendations: []
        )
        let csv = ReportCSVEncoder.encode(report)
        XCTAssertTrue(csv.contains("subject,missions,accuracy_percent,avg_response_seconds,difficulty"),
                      "Column names are a stable external contract")
        XCTAssertTrue(csv.contains("child,Mira"))
        XCTAssertTrue(csv.contains("total_missions,8"))
        XCTAssertEqual(csv.components(separatedBy: "\n").count,
                       7 + 1 + report.subjects.count,
                       "6 metadata lines + blank + header + one line per subject")
    }

    func testCSVEscapesSpecialCharacters() {
        XCTAssertEqual(ReportCSVEncoder.escape("plain"), "plain")
        XCTAssertEqual(ReportCSVEncoder.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(ReportCSVEncoder.escape("say \"hi\""), "\"say \"\"hi\"\"\"")
    }
}

// MARK: - 2.5 AR scene state (ARKit-free)

final class ARForestSceneStateTests: XCTestCase {

    func testPlantingTracksCounts() {
        var state = ARForestSceneState()
        state.plant(.tree, transform: matrix_identity_float4x4)
        state.plant(.flower, transform: matrix_identity_float4x4)
        state.plant(.tree, transform: matrix_identity_float4x4)
        XCTAssertEqual(state.treeCount, 2)
        XCTAssertEqual(state.flowerCount, 1)
    }

    func testWateringCapsAtThree() {
        var state = ARForestSceneState()
        state.plant(.tree, transform: matrix_identity_float4x4)
        XCTAssertEqual(state.water(at: 0), 1)
        XCTAssertEqual(state.water(at: 0), 2)
        XCTAssertEqual(state.water(at: 0), 3)
        XCTAssertEqual(state.water(at: 0), 3, "Growth caps at stage 3")
        XCTAssertNil(state.water(at: 9), "Invalid index is safely nil")
    }

    func testStateRoundTripsThroughJSON() throws {
        var state = ARForestSceneState()
        state.plant(.tree, transform: matrix_identity_float4x4)
        state.starsCollected = 4
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ARForestSceneState.self, from: data)
        XCTAssertEqual(decoded, state)
    }

    func testTransformFlatteningRoundTrips() {
        let transform = matrix_identity_float4x4
        let restored = simd_float4x4(flattened: transform.flattened)
        XCTAssertEqual(restored, transform)
        XCTAssertNil(simd_float4x4(flattened: [1, 2, 3]), "Wrong length is rejected")
    }
}

// MARK: - 2.6 Gestures

final class GestureEngineTests: XCTestCase {

    let engine = GestureEngine()

    private func hand(
        wrist: CGPoint = CGPoint(x: 0.5, y: 0.8),
        thumb: CGPoint?, index: CGPoint?, middle: CGPoint?, ring: CGPoint?, little: CGPoint?
    ) -> HandLandmarks {
        HandLandmarks(wrist: wrist, thumbTip: thumb, indexTip: index,
                      middleTip: middle, ringTip: ring, littleTip: little)
    }

    func testPinchDetected() {
        let landmarks = hand(
            thumb: CGPoint(x: 0.50, y: 0.50), index: CGPoint(x: 0.52, y: 0.51),
            middle: CGPoint(x: 0.5, y: 0.4), ring: CGPoint(x: 0.55, y: 0.42), little: CGPoint(x: 0.6, y: 0.45)
        )
        XCTAssertEqual(engine.classify(landmarks), .pinch)
    }

    func testOpenPalmDetected() {
        let landmarks = hand(
            thumb: CGPoint(x: 0.2, y: 0.5), index: CGPoint(x: 0.4, y: 0.4),
            middle: CGPoint(x: 0.5, y: 0.38), ring: CGPoint(x: 0.6, y: 0.4), little: CGPoint(x: 0.7, y: 0.5)
        )
        XCTAssertEqual(engine.classify(landmarks), .openPalm)
    }

    func testGrabDetected() {
        let landmarks = hand(
            thumb: CGPoint(x: 0.38, y: 0.78), index: CGPoint(x: 0.5, y: 0.7),
            middle: CGPoint(x: 0.52, y: 0.71), ring: CGPoint(x: 0.54, y: 0.72), little: CGPoint(x: 0.56, y: 0.73)
        )
        XCTAssertEqual(engine.classify(landmarks), .grab)
    }

    func testPointDetected() {
        let landmarks = hand(
            thumb: CGPoint(x: 0.45, y: 0.72), index: CGPoint(x: 0.5, y: 0.4),
            middle: CGPoint(x: 0.52, y: 0.71), ring: CGPoint(x: 0.54, y: 0.72), little: CGPoint(x: 0.56, y: 0.73)
        )
        XCTAssertEqual(engine.classify(landmarks), .point)
    }

    func testMissingWristMeansNoGesture() {
        var landmarks = hand(thumb: .zero, index: .zero, middle: .zero, ring: .zero, little: .zero)
        landmarks.wrist = nil
        XCTAssertEqual(engine.classify(landmarks), .none)
    }

    func testTooFewLandmarksMeansNoGesture() {
        let landmarks = hand(thumb: CGPoint(x: 0.2, y: 0.2), index: nil, middle: nil, ring: nil, little: nil)
        XCTAssertEqual(engine.classify(landmarks), .none, "No guessing from sparse data")
    }

    func testWaveDetectorNeedsRepeatedSwings() {
        var detector = WaveDetector()
        XCTAssertFalse(detector.add(wristX: 0.3, at: 0.0))
        XCTAssertFalse(detector.add(wristX: 0.5, at: 0.2))   // right
        XCTAssertFalse(detector.add(wristX: 0.3, at: 0.4))   // left (1 change)
        XCTAssertFalse(detector.add(wristX: 0.5, at: 0.6))   // right (2)
        XCTAssertTrue(detector.add(wristX: 0.3, at: 0.8), "3 direction changes inside window = wave")
    }

    func testOldSwingsExpire() {
        var detector = WaveDetector()
        _ = detector.add(wristX: 0.3, at: 0.0)
        _ = detector.add(wristX: 0.5, at: 0.2)
        _ = detector.add(wristX: 0.3, at: 0.4)
        _ = detector.add(wristX: 0.5, at: 0.6)
        XCTAssertFalse(detector.add(wristX: 0.3, at: 5.0),
                       "Direction changes older than the window don't count")
    }
}

// MARK: - 2.7 Engagement

final class EngagementEngineTests: XCTestCase {

    let engine = EngagementEngine()

    func testFastAccurateAnswersScoreHigh() {
        let score = engine.score(responseTimes: [2.5, 3, 2.8, 3.1],
                                 consecutiveMisses: 0, secondsSinceInteraction: 1)
        XCTAssertGreaterThan(score, 0.7)
        XCTAssertEqual(engine.advice(for: score), .keepGoing)
    }

    func testSlowingAnswersAndMissesDropScore() {
        let score = engine.score(responseTimes: [4, 6, 8, 10, 12],
                                 consecutiveMisses: 2, secondsSinceInteraction: 10)
        XCTAssertLessThan(score, 0.45)
        XCTAssertNotEqual(engine.advice(for: score), EngagementEngine.PacingAdvice.keepGoing)
    }

    func testCompleteDisengagementAdvisesWindDown() {
        let score = engine.score(responseTimes: [9, 10, 11, 12, 14],
                                 consecutiveMisses: 3, secondsSinceInteraction: 25)
        XCTAssertEqual(engine.advice(for: score), .windDown)
    }

    func testNoDataIsNotPunished() {
        let score = engine.score(responseTimes: [], consecutiveMisses: 0, secondsSinceInteraction: 0)
        XCTAssertEqual(engine.advice(for: score), .keepGoing,
                       "A mission that just started must not trigger interventions")
    }

    func testScoreStaysInUnitRange() {
        for times in [[TimeInterval]](arrayLiteral: [], [0.1], [30, 40, 50], [1, 1, 1, 1, 1]) {
            for misses in [0, 1, 5, 20] {
                let score = engine.score(responseTimes: times, consecutiveMisses: misses,
                                         secondsSinceInteraction: 100)
                XCTAssertGreaterThanOrEqual(score, 0)
                XCTAssertLessThanOrEqual(score, 1)
            }
        }
    }
}

// MARK: - 2.8 Daily recommendations

final class DailyRecommendationsTests: XCTestCase {

    let engine = LearningRecommendationEngine(difficultyEngine: AdaptiveDifficultyEngine())

    func testColdStartDegradesGracefully() {
        let daily = engine.makeDailyRecommendations(summary: PerformanceSummary())
        XCTAssertEqual(daily.storyTheme, .discovery)
        XCTAssertGreaterThanOrEqual(daily.difficulty, 1)
        XCTAssertFalse(daily.schedule.isEmpty)
        XCTAssertFalse(daily.parentExplanations.isEmpty)
        XCTAssertNil(daily.favoriteActivity, "No favorite without history")
        XCTAssertTrue(daily.parentExplanations.contains { $0.contains(String(localized: "getting to know")) })
    }

    func testStrugglingProfileGetsCourageTheme() {
        var summary = PerformanceSummary()
        summary.totalMissions = 6
        summary.averageAttentionScore = 0.6
        summary.perSubject[.numbers] = .init(missions: 4, accuracy: 0.3, averageResponseTime: 7, currentDifficulty: 2)
        summary.perSubject[.colors] = .init(missions: 2, accuracy: 0.7, averageResponseTime: 5, currentDifficulty: 1)

        let daily = engine.makeDailyRecommendations(summary: summary)
        XCTAssertEqual(daily.storyTheme, .courage)
    }

    func testMasteryProfileGetsCelebrationAndMagicDust() {
        var summary = PerformanceSummary()
        summary.totalMissions = 10
        summary.averageAttentionScore = 0.8
        summary.perSubject[.shapes] = .init(missions: 6, accuracy: 0.95, averageResponseTime: 3, currentDifficulty: 3)
        summary.perSubject[.memory] = .init(missions: 4, accuracy: 0.8, averageResponseTime: 4, currentDifficulty: 2)

        let daily = engine.makeDailyRecommendations(summary: summary)
        XCTAssertEqual(daily.storyTheme, .celebration)
        XCTAssertEqual(daily.rewardEmphasis, .magicDust)
        XCTAssertEqual(daily.favoriteActivity, .shapes, "Most played = favorite")
    }

    func testLowAttentionGetsCalmBreakAndStars()  {
        var summary = PerformanceSummary()
        summary.totalMissions = 5
        summary.averageAttentionScore = 0.3
        summary.perSubject[.alphabet] = .init(missions: 5, accuracy: 0.6, averageResponseTime: 6, currentDifficulty: 1)

        let daily = engine.makeDailyRecommendations(summary: summary)
        XCTAssertEqual(daily.rewardEmphasis, .stars)
        XCTAssertLessThanOrEqual(daily.schedule.count, 2, "Low attention = fewer scheduled sessions")
    }

    func testExplanationsAreNonEmptyAndPlainLanguage() {
        var summary = PerformanceSummary()
        summary.totalMissions = 5
        summary.perSubject[.numbers] = .init(missions: 5, accuracy: 0.7, averageResponseTime: 5, currentDifficulty: 2)

        let daily = engine.makeDailyRecommendations(summary: summary)
        XCTAssertGreaterThanOrEqual(daily.parentExplanations.count, 2)
        for note in daily.parentExplanations {
            XCTAssertGreaterThan(note.count, 20, "Explanations should be real sentences")
        }
    }
}
