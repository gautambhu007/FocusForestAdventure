//
//  AdditionEngineTests.swift
//  FocusForestAdventureTests
//
//  Age-6 addition sections: ranges, uniqueness, sum cap, difficulty
//  ordering, answer choices, and mission generation.
//

import XCTest
@testable import FocusForestAdventure

final class AdditionEngineTests: XCTestCase {

    let engine = AdditionEngine()

    func testEverySectionYields20UniqueQuestions() {
        for section in AdditionSection.allCases {
            let problems = engine.problems(for: section)
            XCTAssertEqual(problems.count, 20, "\(section) must have 20 questions")
            XCTAssertEqual(Set(problems).count, 20, "\(section) must not repeat questions")
        }
    }

    func testNoSumEverExceeds20AndNoNegatives() {
        for section in AdditionSection.allCases {
            for problem in engine.problems(for: section) {
                XCTAssertLessThanOrEqual(problem.sum, 20, "\(section): \(problem.display)")
                XCTAssertGreaterThanOrEqual(problem.a, 1)
                XCTAssertGreaterThanOrEqual(problem.b, 1)
            }
        }
    }

    func testEasySectionUsesOnly1Through9() {
        for problem in engine.problems(for: .easy) {
            XCTAssertTrue((1...9).contains(problem.a), problem.display)
            XCTAssertTrue((1...9).contains(problem.b), problem.display)
        }
    }

    func testMediumSectionUses5Through14() {
        for problem in engine.problems(for: .medium) {
            XCTAssertTrue((5...14).contains(problem.a), problem.display)
            XCTAssertTrue((5...14).contains(problem.b), problem.display)
        }
    }

    func testHardSectionUsesLargeAddends() {
        for problem in engine.problems(for: .hard) {
            XCTAssertGreaterThanOrEqual(max(problem.a, problem.b), 8,
                                        "\(problem.display): hard questions feature a number ≥ 8")
        }
    }

    func testGradedSectionsIncreaseInDifficulty() {
        for section in [AdditionSection.easy, .medium, .hard] {
            let sums = engine.problems(for: section).map(\.sum)
            XCTAssertEqual(sums, sums.sorted(),
                           "\(section): sums must rise gradually through the section")
        }
    }

    func testChoicesContainCorrectAnswerAmongFour() {
        for section in AdditionSection.allCases {
            for problem in engine.problems(for: section, count: 5) {
                let choices = engine.choices(for: problem)
                XCTAssertEqual(choices.count, 4)
                XCTAssertTrue(choices.contains(problem.sum))
                XCTAssertEqual(Set(choices).count, 4, "Choices must be distinct")
                XCTAssertTrue(choices.allSatisfy { (0...20).contains($0) })
            }
        }
    }

    func testAge6NumbersMissionUsesChosenSection() {
        let generator = MissionGeneratorEngine(difficultyEngine: AdaptiveDifficultyEngine())
        let plan = generator.generateMission(adventure: .numbers, difficulty: 2,
                                             age: 6, additionSection: .easy)
        XCTAssertEqual(plan.missionType, .simpleAddition)
        XCTAssertEqual(plan.questions.count, 20)
        for question in plan.questions {
            guard case .tapCorrect(let options, let correctID) = question.content else {
                return XCTFail("Addition questions must be tapCorrect")
            }
            XCTAssertEqual(options.count, 4)
            XCTAssertTrue(options.contains { $0.id == correctID })
        }
    }

    func testWithoutSectionNumbersBehavesAsBefore() {
        let generator = MissionGeneratorEngine(difficultyEngine: AdaptiveDifficultyEngine())
        let plan = generator.generateMission(adventure: .numbers, difficulty: 1, age: 6)
        XCTAssertNotEqual(plan.missionType, .simpleAddition,
                          "Low difficulty without a chosen section stays counting-style")
    }
}
