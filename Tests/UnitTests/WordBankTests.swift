//
//  WordBankTests.swift
//  FocusForestAdventureTests
//
//  Age-based content: word bank quality, non-repeating draws, and the
//  age-5 word mission generation.
//

import XCTest
@testable import FocusForestAdventure

final class WordBankTests: XCTestCase {

    func testBankHasAtLeast300UniqueWords() {
        XCTAssertGreaterThanOrEqual(WordBank.allWords.count, 300)
        XCTAssertEqual(Set(WordBank.allWords).count, WordBank.allWords.count,
                       "Every word must be unique")
    }

    func testAllWordsAreThreeToFourLowercaseLetters() {
        for word in WordBank.allWords {
            XCTAssertTrue((3...4).contains(word.count), "'\(word)' must be 3–4 letters")
            XCTAssertTrue(word.allSatisfy { $0.isLetter && $0.isLowercase },
                          "'\(word)' must be lowercase letters only")
        }
    }

    func testNoInappropriateWords() {
        let banned: Set<String> = ["gun", "war", "die", "kill", "hit", "rum", "gin",
                                   "ale", "axe", "bomb", "dead", "hell", "damn"]
        XCTAssertTrue(banned.isDisjoint(with: WordBank.allWords),
                      "The bank must contain no violent or adult words")
    }

    func testDrawExcludesUsedWords() {
        let used = Set(WordBank.allWords.prefix(100))
        let drawn = WordBank.drawTargets(count: 20, excluding: used)
        XCTAssertEqual(drawn.count, 20)
        XCTAssertTrue(used.isDisjoint(with: drawn), "Used words must never be re-drawn")
        XCTAssertEqual(Set(drawn).count, drawn.count, "No duplicates within one draw")
    }

    func testDrawResetsWhenBankExhausted() {
        let nearlyAll = Set(WordBank.allWords.dropLast(5))
        let drawn = WordBank.drawTargets(count: 20, excluding: nearlyAll)
        XCTAssertEqual(drawn.count, 20,
                       "When fewer unseen words remain than needed, the lap resets")
    }

    func testEveryWordHasAPicture() {
        XCTAssertEqual(WordBank.emoji(for: "cat"), "🐱")
        for word in WordBank.allWords {
            XCTAssertFalse(WordBank.emoji(for: word).isEmpty,
                           "'\(word)' must always yield a picture (mapped or fallback)")
        }
    }

    func testDistractorsExcludeTarget() {
        let distractors = WordBank.distractors(for: "cat", count: 3)
        XCTAssertEqual(distractors.count, 3)
        XCTAssertFalse(distractors.contains("cat"))
        XCTAssertEqual(Set(distractors).count, 3, "Distractors within a question are unique")
    }
}

// MARK: - Age-based mission generation

final class AgeBasedMissionTests: XCTestCase {

    let generator = MissionGeneratorEngine(difficultyEngine: AdaptiveDifficultyEngine())

    func testAge4AlphabetStaysLetterBased() {
        let plan = generator.generateMission(adventure: .alphabet, difficulty: 1, age: 4)
        XCTAssertNotEqual(plan.missionType, .findWord)
        XCTAssertTrue(plan.targetWords.isEmpty)
    }

    func testAge5AlphabetBecomesWordReading() {
        let plan = generator.generateMission(adventure: .alphabet, difficulty: 1, age: 5)
        XCTAssertEqual(plan.missionType, .findWord)
        XCTAssertEqual(plan.targetWords.count, plan.questions.count)
        XCTAssertEqual(Set(plan.targetWords).count, plan.targetWords.count,
                       "No target word repeats within a mission")
    }

    func testWordQuestionsHaveExactlyFourOptions() {
        let plan = generator.generateMission(adventure: .alphabet, difficulty: 3, age: 5)
        for question in plan.questions {
            guard case .tapCorrect(let options, let correctID) = question.content else {
                return XCTFail("Word questions must be tapCorrect")
            }
            XCTAssertEqual(options.count, 4, "Word questions always offer 4 choices")
            XCTAssertTrue(options.contains { $0.id == correctID })
            XCTAssertEqual(Set(options.map(\.display)).count, 4, "Options must be distinct")
            for option in options {
                XCTAssertTrue((3...4).contains(option.display.count),
                              "Options are 3–4 letter words")
            }
        }
    }

    func testUsedWordsAreNeverReDrawn() {
        let used = Set(WordBank.allWords.prefix(200))
        let plan = generator.generateMission(adventure: .alphabet, difficulty: 1,
                                             age: 5, usedWords: used)
        XCTAssertTrue(used.isDisjoint(with: plan.targetWords),
                      "Previously seen words must not appear as targets")
    }

    func testAge5DoesNotChangeOtherAdventures() {
        let plan = generator.generateMission(adventure: .numbers, difficulty: 1, age: 5)
        XCTAssertNotEqual(plan.missionType, .findWord)
        XCTAssertTrue(plan.targetWords.isEmpty)
    }
}
