//
//  MissionDomain.swift
//  Focus Forest Adventure
//
//  Pure domain value types for adventures, missions, questions, rewards,
//  and movement breaks. All Sendable — safe across concurrency domains.
//

import Foundation
import SwiftUI

// MARK: - Adventures

enum AdventureKind: String, CaseIterable, Codable, Sendable, Hashable {
    case alphabet, numbers, shapes, colors, memory, listening, animals

    var localizedTitle: String {
        switch self {
        case .alphabet: String(localized: "ABC")
        case .numbers: String(localized: "Numbers")
        case .shapes: String(localized: "Shapes")
        case .colors: String(localized: "Colors")
        case .memory: String(localized: "Memory")
        case .listening: String(localized: "Listening")
        case .animals: String(localized: "Animals")
        }
    }

    var emoji: String {
        switch self {
        case .alphabet: "🔤"
        case .numbers: "🔢"
        case .shapes: "🔷"
        case .colors: "🎨"
        case .memory: "🧠"
        case .listening: "👂"
        case .animals: "🦁"
        }
    }

    var tint: Color {
        switch self {
        case .alphabet: ForestTheme.Colors.skyBlue
        case .numbers: ForestTheme.Colors.sunshine
        case .shapes: ForestTheme.Colors.lavender
        case .colors: ForestTheme.Colors.bubblegum
        case .memory: ForestTheme.Colors.mint
        case .listening: ForestTheme.Colors.peach
        case .animals: ForestTheme.Colors.leafGreen
        }
    }
}

// MARK: - Mission plan

/// A generated, ready-to-play mission: an ordered set of questions with timing rules.
struct MissionPlan: Hashable, Sendable {
    let id: UUID
    let adventure: AdventureKind
    let missionType: MissionType
    let difficulty: Int                    // 1...5
    let questions: [MissionQuestion]
    /// Hard cap — mission auto-ends gracefully at this duration (frustration guard).
    let maxDuration: TimeInterval
    /// Auto-end early after this many consecutive misses (child never "fails").
    let frustrationMissLimit: Int
    /// Word missions (age 5+): targets in question order, consumed on
    /// completion so words never repeat until the bank is exhausted.
    var targetWords: [String] = []

    static func == (lhs: MissionPlan, rhs: MissionPlan) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum MissionType: String, Codable, Sendable, CaseIterable {
    // Alphabet
    case findLetter, matchLetters, traceLetter, letterSound
    /// Age 5+: read a short word and find it among 4 word options.
    case findWord
    // Numbers
    case countObjects, findBiggerNumber, simpleAddition
    // Shapes
    case findShape
    // Memory
    case flipCards, rememberSequence
    // Listening
    case guessAnimalSound, repeatPattern
    // Colors
    case tapColor, mixColors
    // Animals
    case findAnimal, feedAnimal, helpAnimal
}

// MARK: - Questions

/// One interactive question inside a mission.
struct MissionQuestion: Hashable, Sendable, Identifiable {
    let id: UUID
    let prompt: String                     // spoken + displayed
    let content: QuestionContent
}

/// Typed payloads for each mini-game renderer.
enum QuestionContent: Hashable, Sendable {
    /// Tap the correct option among decoys (letters, numbers, shapes, animals, colors).
    case tapCorrect(options: [QuestionOption], correctID: UUID)
    /// Count the emoji objects, then tap the right number.
    case countObjects(objectEmoji: String, count: Int, choices: [Int])
    /// Flip cards to find the matching pair.
    case memoryPairs(pairs: [String])
    /// Watch/listen to a sequence, then repeat it by tapping.
    case sequence(items: [QuestionOption], playbackInterval: TimeInterval)
    /// Trace a letter along guide points (normalized 0...1 coordinates).
    case traceLetter(letter: String, guidePoints: [TracePoint])
    /// Listen to a sound, pick which animal made it.
    case soundGuess(soundName: String, options: [QuestionOption], correctID: UUID)
}

/// Normalized (0...1) coordinate for letter-trace guides.
/// CGPoint is not Hashable, so we use our own value type.
struct TracePoint: Hashable, Sendable {
    var x: Double
    var y: Double
}

struct QuestionOption: Hashable, Sendable, Identifiable {
    let id: UUID
    let display: String                    // emoji or glyph
    let label: String                      // spoken / accessibility label
    var gameColor: ForestTheme.GameColor?

    init(display: String, label: String, gameColor: ForestTheme.GameColor? = nil) {
        self.id = UUID()
        self.display = display
        self.label = label
        self.gameColor = gameColor
    }
}

// MARK: - Rewards

struct RewardBundle: Hashable, Sendable {
    var stars: Int = 0
    var seeds: Int = 0
    var flowers: Int = 0
    var magicDust: Int = 0
    var forestXP: Int = 0
    var newlyUnlocked: [ForestElement] = []
    var newAchievements: [AchievementID] = []
    var bunnyPhrase: String = BunnyPhrase.celebration.text
}

// MARK: - Movement breaks

struct MovementBreak: Hashable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let instruction: String
    let emoji: String
    let duration: TimeInterval

    static let all: [MovementBreak] = [
        MovementBreak(id: UUID(), title: String(localized: "Bunny Hops!"),
                      instruction: String(localized: "Jump up high 5 times!"),
                      emoji: "🐰", duration: 30),
        MovementBreak(id: UUID(), title: String(localized: "Spin Like a Leaf!"),
                      instruction: String(localized: "Spin around slowly, arms out wide!"),
                      emoji: "🍃", duration: 30),
        MovementBreak(id: UUID(), title: String(localized: "Boop!"),
                      instruction: String(localized: "Touch your nose, then your toes!"),
                      emoji: "👃", duration: 30),
        MovementBreak(id: UUID(), title: String(localized: "Grow Like a Tree!"),
                      instruction: String(localized: "Stretch your arms way up to the sky!"),
                      emoji: "🌳", duration: 30),
        MovementBreak(id: UUID(), title: String(localized: "Dance Party!"),
                      instruction: String(localized: "Dance with Bunny! Wiggle wiggle!"),
                      emoji: "💃", duration: 30)
    ]

    static func random() -> MovementBreak { all.randomElement() ?? all[0] }
}

// MARK: - Bunny voice lines (always positive)

enum BunnyPhrase {
    case welcome, missionStart, correct, gentleRetry, celebration, movementBreak, forestGrew

    var text: String {
        switch self {
        case .welcome:
            [String(localized: "Hello Explorer! I'm so happy to see you!"),
             String(localized: "Welcome back Mr Reyaansh!")].randomElement()!
        case .missionStart:
            [String(localized: "Let's go on an adventure!"),
             String(localized: "Ooh, this will be fun!")].randomElement()!
        case .correct:
            [String(localized: "Amazing!"), String(localized: "Fantastic!"),
             String(localized: "You did it!"), String(localized: "Wow, great job!"),
             String(localized: "You found it!")].randomElement()!
        case .gentleRetry:
            [String(localized: "Almost! Let's try again together!"),
             String(localized: "Good try! One more time!"),
             String(localized: "So close! You can do it!")].randomElement()!
        case .celebration:
            [String(localized: "You are a superstar!"),
             String(localized: "The forest loves you!"),
             String(localized: "Hooray! What an explorer!")].randomElement()!
        case .movementBreak:
            [String(localized: "Time to wiggle! Let's move!"),
             String(localized: "Let's dance together!")].randomElement()!
        case .forestGrew:
            [String(localized: "Look! Your forest is growing!"),
             String(localized: "Something magical appeared in your forest!")].randomElement()!
        }
    }
}
