//
//  AssistantTests.swift
//  FocusForestAdventureTests
//
//  Phase 2.2 tests: intent detection, safe fallback responses,
//  blocked/unknown intent behavior, and conversation history capping.
//

import XCTest
@testable import FocusForestAdventure

// MARK: - Intent detection

final class IntentDetectorTests: XCTestCase {

    let detector = IntentDetector()

    func testDetectsGreeting() {
        XCTAssertEqual(detector.detect(from: "Hi Bunny!"), .greeting)
        XCTAssertEqual(detector.detect(from: "hello"), .greeting)
    }

    func testDetectsWhatNext() {
        XCTAssertEqual(detector.detect(from: "What should I play?"), .whatNext)
        XCTAssertEqual(detector.detect(from: "I'm bored"), .whatNext)
    }

    func testDetectsForestQuestions() {
        XCTAssertEqual(detector.detect(from: "Tell me about my forest"), .forest)
        XCTAssertEqual(detector.detect(from: "how are my trees"), .forest)
    }

    func testDetectsAffirmation() {
        XCTAssertEqual(detector.detect(from: "Yes I want to play together"), .affirmation)
        XCTAssertEqual(detector.detect(from: "okay bunny let's go"), .affirmation)
    }

    func testDetectsJokeAndStory() {
        XCTAssertEqual(detector.detect(from: "tell me a joke"), .joke)
        XCTAssertEqual(detector.detect(from: "tell me a story"), .story)
    }

    func testDistressOutranksEverythingElse() {
        XCTAssertEqual(detector.detect(from: "I'm sad, tell me a joke"), .feelings,
                       "Comfort must come before entertainment")
        XCTAssertEqual(detector.detect(from: "I am scared of the forest"), .feelings,
                       "Distress beats topic keywords")
    }

    func testHelpRequestsAreDetected() {
        XCTAssertEqual(detector.detect(from: "this is too hard"), .help)
        XCTAssertEqual(detector.detect(from: "help me please"), .help)
    }

    func testUnknownAndEmptyFallBackSafely() {
        XCTAssertEqual(detector.detect(from: "what is the capital of France"), .unknown)
        XCTAssertEqual(detector.detect(from: ""), .unknown)
        XCTAssertEqual(detector.detect(from: "   "), .unknown)
    }
}

// MARK: - Response safety

final class ConversationEngineTests: XCTestCase {

    let engine = ConversationEngine()
    let context = ConversationContext(
        childNickname: "Mira", forestLevel: 3, recommendedAdventure: .numbers
    )

    /// Words that must never appear in anything Bunny says to a child.
    private let bannedWords = [
        "wrong", "bad", "stupid", "fail", "failure", "no!", "never",
        "shame", "naughty", "lazy", "hate"
    ]

    func testEveryIntentHasResponses() {
        for intent in BunnyIntent.allCases {
            XCTAssertFalse(engine.responses(for: intent, context: context).isEmpty,
                           "\(intent) must have at least one response")
        }
    }

    func testAllResponsesAreShortAndPositive() {
        for intent in BunnyIntent.allCases {
            for response in engine.responses(for: intent, context: context) {
                XCTAssertFalse(response.isEmpty)
                XCTAssertLessThan(response.count, 160,
                                  "\(intent): responses must stay short for young children")
                let lowered = response.lowercased()
                for banned in bannedWords {
                    XCTAssertFalse(lowered.contains(banned),
                                   "\(intent): '\(response)' contains banned word '\(banned)'")
                }
            }
        }
    }

    func testUnknownIntentRedirectsGently() {
        let responses = engine.responses(for: .unknown, context: context)
        XCTAssertFalse(responses.isEmpty)
        // The redirect must never pretend to answer — spot-check it steers
        // back to app topics or a grown-up.
        for response in responses {
            XCTAssertGreaterThan(response.count, 10)
        }
    }

    func testResponsesUseNickname() {
        let greeting = engine.responses(for: .greeting, context: context)
        XCTAssertTrue(greeting.allSatisfy { $0.contains("Mira") },
                      "Greetings should feel personal")
    }

    func testEmptyNicknameFallsBackToExplorer() {
        let anonymous = ConversationContext()
        let greeting = engine.responses(for: .greeting, context: anonymous)
        XCTAssertTrue(greeting.allSatisfy { $0.contains(String(localized: "Explorer")) })
    }

    func testWhatNextUsesRecommendationWhenAvailable() {
        let withPlan = engine.responses(for: .whatNext, context: context)
        XCTAssertTrue(withPlan.allSatisfy { $0.contains(AdventureKind.numbers.localizedTitle) },
                      "Recommendations should surface the suggested adventure")

        let withoutPlan = engine.responses(for: .whatNext, context: ConversationContext())
        XCTAssertFalse(withoutPlan.isEmpty, "Cold start still needs a friendly answer")
    }

    func testForestAnswerReflectsLevel() {
        let responses = engine.responses(for: .forest, context: context)
        XCTAssertTrue(responses.contains { $0.contains("3") },
                      "At least one forest answer should mention the level")
    }

    func testRandomPickAlwaysComesFromCatalog() {
        for intent in BunnyIntent.allCases {
            let catalog = engine.responses(for: intent, context: context)
            for _ in 0..<10 {
                XCTAssertTrue(catalog.contains(engine.respond(to: intent, context: context)),
                              "respond must never invent text outside the catalog")
            }
        }
    }
}

// MARK: - Conversation history

@MainActor
final class ConversationHistoryTests: XCTestCase {

    func testAppendsInOrder() {
        let history = ConversationHistory()
        history.append(ConversationTurn(speaker: .child, text: "hi"))
        history.append(ConversationTurn(speaker: .bunny, text: "hello!"))
        XCTAssertEqual(history.turns.map(\.text), ["hi", "hello!"])
    }

    func testCapsAtMaxTurns() {
        let history = ConversationHistory(maxTurns: 3)
        for index in 0..<10 {
            history.append(ConversationTurn(speaker: .child, text: "message \(index)"))
        }
        XCTAssertEqual(history.turns.count, 3)
        XCTAssertEqual(history.turns.last?.text, "message 9",
                       "Capping must drop the oldest turns, not the newest")
    }

    func testClearEmptiesHistory() {
        let history = ConversationHistory()
        history.append(ConversationTurn(speaker: .child, text: "hi"))
        history.clear()
        XCTAssertTrue(history.turns.isEmpty)
    }
}
