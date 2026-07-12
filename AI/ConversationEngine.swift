//
//  ConversationEngine.swift
//  Focus Forest Adventure
//
//  Phase 2.2 Bunny AI Assistant: offline intent detection + safe response
//  generation. Both are pure Sendable values (no I/O, no network) so every
//  response path is unit-testable and works with no connectivity.
//
//  Safety policy (see ARCHITECTURE.md):
//  - Every response comes from a curated, age-appropriate catalog.
//  - There is no open-ended text generation — unknown input maps to a
//    friendly redirect, never an answer Bunny can't stand behind.
//  - Distress is met with comfort plus a nudge toward a trusted grown-up.
//  - Positive reinforcement only: no shaming, no "wrong", no pressure.
//

import Foundation

// MARK: - Intents

/// What the child is asking for. Deliberately coarse: with 4–6 year olds,
/// broad friendly buckets beat brittle fine-grained parsing.
enum BunnyIntent: String, CaseIterable, Sendable {
    case greeting          // "hi bunny!"
    case howAreYou         // "how are you?"
    case whatNext          // "what should I play?"
    case affirmation       // "yes!" / "let's play!"
    case forest            // "tell me about my forest"
    case story             // "tell me a story"
    case help              // "this is hard" / "help me"
    case feelings          // "I'm sad / scared / angry / tired"
    case affection         // "I love you bunny"
    case joke              // "tell me a joke"
    case goodbye           // "bye bunny"
    case unknown           // anything else → safe redirect
}

// MARK: - Intent detection

/// Keyword-based offline intent detection. No ML, no network — a small
/// vocabulary matched against the lowercased utterance. Order matters:
/// feelings are checked first so "I'm sad, tell me a joke" comforts first.
struct IntentDetector: Sendable {

    func detect(from utterance: String) -> BunnyIntent {
        let text = utterance.lowercased()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .unknown
        }

        // Distress always wins — comfort before anything else.
        if matches(text, ["sad", "scared", "afraid", "angry", "mad", "cry", "crying",
                          "tired", "lonely", "hurt", "upset"]) {
            return .feelings
        }
        if matches(text, ["help", "hard", "can't do", "cant do", "too difficult",
                          "don't know how", "dont know how", "stuck"]) {
            return .help
        }
        if matches(text, ["love you", "like you", "best friend", "hug"]) {
            return .affection
        }
        if matches(text, ["joke", "funny", "laugh", "silly"]) {
            return .joke
        }
        if matches(text, ["story", "once upon", "tale"]) {
            return .story
        }
        if matches(text, ["forest", "tree", "trees", "flower", "garden", "animals",
                          "my dragon", "butterfly"]) {
            return .forest
        }
        if matches(text, ["what should", "what can i", "which game", "what game",
                          "what do i do", "play next", "what next", "bored"]) {
            return .whatNext
        }
        if matches(text, ["yes", "yeah", "yep", "okay", "ok bunny", "sure",
                          "let's play", "lets play", "want to play", "let's go", "lets go"]) {
            return .affirmation
        }
        if matches(text, ["how are you", "how do you feel", "are you ok",
                          "are you okay", "are you happy"]) {
            return .howAreYou
        }
        if matches(text, ["bye", "goodbye", "good night", "goodnight", "see you"]) {
            return .goodbye
        }
        if matches(text, ["hi", "hello", "hey", "good morning", "hiya"]) {
            return .greeting
        }
        return .unknown
    }

    private func matches(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}

// MARK: - Response generation

/// Local signals Bunny may weave into an answer. All data is on-device.
struct ConversationContext: Sendable, Equatable {
    var childNickname: String = ""
    var forestLevel: Int = 1
    var recommendedAdventure: AdventureKind?

    var displayName: String {
        childNickname.isEmpty ? String(localized: "Explorer") : childNickname
    }
}

/// Picks Bunny's reply from curated catalogs. `responses(for:context:)` is
/// exposed (not just the random pick) so tests can verify every possible
/// reply is safe, short, and positive.
struct ConversationEngine: Sendable {

    func respond(to intent: BunnyIntent, context: ConversationContext) -> String {
        responses(for: intent, context: context).randomElement()
            ?? String(localized: "Bunny is listening!")
    }

    /// The full catalog for an intent — every string a child could ever hear.
    func responses(for intent: BunnyIntent, context: ConversationContext) -> [String] {
        let name = context.displayName
        switch intent {
        case .greeting:
            return [
                String(localized: "Hello \(name)! I'm so happy you're here!"),
                String(localized: "Hi hi hi! Bunny missed you, \(name)!"),
                String(localized: "\(name)! My favorite explorer is back!")
            ]
        case .howAreYou:
            return [
                String(localized: "I'm hoppy and happy! Especially now that you're here!"),
                String(localized: "Wonderful! The forest smells like flowers today!"),
                String(localized: "I feel great! Talking with you is my favorite thing!")
            ]
        case .whatNext:
            if let adventure = context.recommendedAdventure {
                return [
                    String(localized: "Ooh, I think a \(adventure.localizedTitle) adventure would be super fun right now!"),
                    String(localized: "Let's try \(adventure.localizedTitle)! I have a good feeling about it!"),
                    String(localized: "Hmm... \(adventure.localizedTitle)! Want to play it together?")
                ]
            }
            return [
                String(localized: "Any adventure you pick will be great! Which one looks fun?"),
                String(localized: "Let's tap the big Adventure button and see what we find!")
            ]
        case .affirmation:
            if let adventure = context.recommendedAdventure {
                return [
                    String(localized: "Yay! Tap the big Adventure button and let's play \(adventure.localizedTitle) together!"),
                    String(localized: "Hooray! \(adventure.localizedTitle) adventure, here we come! Tap Adventure to start!")
                ]
            }
            return [
                String(localized: "Yay! Tap the big Adventure button and pick something fun!"),
                String(localized: "Hooray! Let's go on an adventure — tap the Adventure button!")
            ]
        case .forest:
            return [
                String(localized: "Your forest is level \(context.forestLevel)! Every mission makes it grow!"),
                String(localized: "The trees whisper about you, \(name)! They love when you visit!"),
                String(localized: "Our forest is getting so big! Want to go see it?")
            ]
        case .story:
            return [
                String(localized: "I tell my best stories after adventures! Finish a mission and I'll tell you a brand new one!"),
                String(localized: "Ooh, story time! Your old stories are in Story History — or earn a new one with a mission!")
            ]
        case .help:
            return [
                String(localized: "It's okay, \(name)! Tricky things get easier when we try together!"),
                String(localized: "You're doing great! One tiny step at a time — Bunny believes in you!"),
                String(localized: "Every explorer practices! Want to try a gentler adventure first?")
            ]
        case .feelings:
            return [
                String(localized: "Oh, \(name), come here for a bunny hug! Big feelings are okay."),
                String(localized: "I'm right here with you. Telling a grown-up you trust can help a lot, too."),
                String(localized: "Bunny hug! Take a big slow breath with me... in... and out. You are so loved.")
            ]
        case .affection:
            return [
                String(localized: "I love you too, \(name)! Biggest bunny hug ever!"),
                String(localized: "You're my favorite explorer in the whole forest!")
            ]
        case .joke:
            return [
                String(localized: "Why don't trees use phones? They love making tree-mendous calls with their leaves!"),
                String(localized: "What do you call a rabbit with fleas? Bugs Bunny! Hee hee!"),
                String(localized: "Why did the flower ride a bike? Because its petals were tired! Hee hee!")
            ]
        case .goodbye:
            return [
                String(localized: "Bye bye, \(name)! The forest and I will be right here waiting!"),
                String(localized: "See you soon! Sweet forest dreams!")
            ]
        case .unknown:
            return [
                String(localized: "Hmm, that's a big question! I'm best at forest things — ask me about your forest or what to play!"),
                String(localized: "Bunny's ears wiggled but didn't quite catch that! Want to hear a joke instead?"),
                String(localized: "Ooh, I'm not sure! Let's ask a grown-up together later. Want to pick an adventure meanwhile?")
            ]
        }
    }
}
