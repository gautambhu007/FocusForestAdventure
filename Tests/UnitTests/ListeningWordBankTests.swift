//
//  ListeningWordBankTests.swift
//  FocusForestAdventureTests
//
//  Listening Corner · Word Explorer: word bank quality and batch drawing.
//

import XCTest
@testable import FocusForestAdventure

final class ListeningWordBankTests: XCTestCase {

    func testBankHasAtLeastOneThousandUniqueWords() {
        XCTAssertGreaterThanOrEqual(ListeningWordBank.allWords.count, 1000)
        XCTAssertEqual(Set(ListeningWordBank.allWords).count, ListeningWordBank.allWords.count,
                       "Every word must be unique")
    }

    func testAllWordsAreTwoToFiveLowercaseLetters() {
        for word in ListeningWordBank.allWords {
            XCTAssertTrue((2...5).contains(word.count), "'\(word)' must be 2–5 letters")
            XCTAssertTrue(word.allSatisfy { $0.isLetter && $0.isLowercase },
                          "'\(word)' must be lowercase letters only")
        }
    }

    func testNoInappropriateWords() {
        let banned: Set<String> = ["gun", "war", "die", "kill", "hit", "rum", "gin",
                                   "ale", "axe", "bomb", "dead", "hell", "damn",
                                   "hate", "harm", "hurt", "jail"]
        XCTAssertTrue(banned.isDisjoint(with: ListeningWordBank.allWords),
                      "The bank must contain no violent or adult words")
    }

    func testRandomBatchExcludesShownWords() {
        let shown = Set(ListeningWordBank.allWords.prefix(200))
        let batch = ListeningWordBank.randomBatch(count: 40, excluding: shown)
        XCTAssertEqual(batch.count, 40)
        XCTAssertTrue(shown.isDisjoint(with: batch), "Shown words must not repeat in the next batch")
        XCTAssertEqual(Set(batch).count, batch.count, "No duplicates within one batch")
    }

    func testRandomBatchRefillsWhenBankNearlyExhausted() {
        let nearlyAll = Set(ListeningWordBank.allWords.dropLast(10))
        let batch = ListeningWordBank.randomBatch(count: 40, excluding: nearlyAll)
        XCTAssertEqual(batch.count, 40, "When too few unseen words remain, the batch refills")
    }

    func testEveryWordHasAPicture() {
        for word in ListeningWordBank.allWords {
            XCTAssertFalse(ListeningWordBank.emoji(for: word).isEmpty,
                           "'\(word)' must always yield a picture (mapped or fallback)")
        }
    }
}
