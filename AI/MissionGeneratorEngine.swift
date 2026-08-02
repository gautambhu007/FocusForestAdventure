//
//  MissionGeneratorEngine.swift
//  Focus Forest Adventure
//
//  Procedurally generates missions tuned to a difficulty level (1–5).
//  Difficulty scales option count, distractor similarity, sequence length,
//  and number ranges — never all at once, so growth feels gradual.
//

import Foundation

struct MissionGeneratorEngine: Sendable {

    /// Questions per mission. The frustration guard (time cap + consecutive-miss
    /// limit) still ends a mission gracefully if the child tires before finishing,
    /// so a longer set never means a longer sit — it means more to do for the
    /// children who are in the flow and want to keep going.
    static let questionsPerMission = 30

    /// Time allowance per question used to size the mission's duration cap.
    static let secondsPerQuestion: TimeInterval = 20

    let difficultyEngine: AdaptiveDifficultyEngine
    var random: @Sendable () -> Double = { Double.random(in: 0...1) }

    init(difficultyEngine: AdaptiveDifficultyEngine) {
        self.difficultyEngine = difficultyEngine
    }

    /// Generate a full mission for an adventure at a difficulty (1...5).
    /// `age` switches content style (5+ turns ABC into word reading);
    /// `usedWords` keeps word targets from ever repeating;
    /// `additionSection` (age 6 Numbers) picks one of the four graded
    /// addition sub-sections; `forcedType` (Listening Corner tiles) picks a
    /// specific mission type instead of the adventure's semi-random default.
    func generateMission(
        adventure: AdventureKind,
        difficulty: Int,
        duration: TimeInterval = 240,
        age: Int = 4,
        usedWords: Set<String> = [],
        additionSection: AdditionSection? = nil,
        forcedType: MissionType? = nil
    ) -> MissionPlan {
        let level = difficulty.clamped(to: 1...5)
        let questionCount = Self.questionsPerMission

        // Age 5+: the ABC adventure becomes word reading.
        // Age 6 Numbers with a chosen section: graded addition practice.
        let type: MissionType
        if let forcedType {
            type = forcedType
        } else if adventure == .alphabet && age >= 5 {
            type = .findWord
        } else if adventure == .numbers, additionSection != nil {
            type = .simpleAddition
        } else {
            type = missionType(for: adventure, difficulty: level)
        }

        var targetWords: [String] = []
        let questions: [MissionQuestion]
        if type == .findWord {
            targetWords = WordBank.drawTargets(count: questionCount, excluding: usedWords)
            questions = targetWords.map { wordQuestion(target: $0) }
        } else if let section = additionSection, type == .simpleAddition {
            let engine = AdditionEngine()
            questions = engine.problems(for: section, count: questionCount)
                .map { additionChoiceQuestion($0, engine: engine) }
        } else {
            questions = (0..<questionCount).map { _ in
                makeQuestion(adventure: adventure, type: type, difficulty: level)
            }
        }

        return MissionPlan(
            id: UUID(),
            adventure: adventure,
            missionType: type,
            difficulty: level,
            questions: questions,
            // Never let the attention-based duration cut a full mission short:
            // allow at least ~secondsPerQuestion per question.
            maxDuration: max(duration, TimeInterval(questionCount) * Self.secondsPerQuestion),
            frustrationMissLimit: 3,
            targetWords: targetWords
        )
    }

    // MARK: Mission type selection

    func missionType(for adventure: AdventureKind, difficulty: Int) -> MissionType {
        switch adventure {
        case .alphabet:
            difficulty <= 2 ? [.findLetter, .letterSound].randomElement()!
                            : [.findLetter, .matchLetters, .traceLetter, .letterSound].randomElement()!
        case .numbers:
            difficulty <= 2 ? .countObjects
                            : difficulty <= 4 ? [.countObjects, .findBiggerNumber].randomElement()!
                            : [.findBiggerNumber, .simpleAddition].randomElement()!
        case .shapes: .findShape
        case .memory:
            difficulty <= 3 ? .flipCards : [.flipCards, .rememberSequence].randomElement()!
        case .listening:
            difficulty <= 3 ? .guessAnimalSound : [.guessAnimalSound, .repeatPattern].randomElement()!
        case .colors:
            difficulty <= 3 ? .tapColor : [.tapColor, .mixColors].randomElement()!
        case .animals: [.findAnimal, .feedAnimal, .helpAnimal].randomElement()!
        }
    }

    // MARK: Question factories

    func makeQuestion(adventure: AdventureKind, type: MissionType, difficulty: Int) -> MissionQuestion {
        switch type {
        case .findWord:
            // Normally built in bulk by generateMission (non-repeating);
            // this path is a safe fallback for direct calls.
            return wordQuestion(target: WordBank.drawTargets(count: 1, excluding: []).first ?? "cat")
        case .findLetter, .matchLetters, .letterSound:
            return letterQuestion(difficulty: difficulty, spokenSound: type == .letterSound)
        case .traceLetter:
            return traceQuestion(difficulty: difficulty)
        case .countObjects:
            return countingQuestion(difficulty: difficulty)
        case .findBiggerNumber:
            return biggerNumberQuestion(difficulty: difficulty)
        case .simpleAddition:
            return additionQuestion(difficulty: difficulty)
        case .findShape:
            return shapeQuestion(difficulty: difficulty)
        case .flipCards:
            return memoryQuestion(difficulty: difficulty)
        case .rememberSequence, .repeatPattern:
            return sequenceQuestion(difficulty: difficulty)
        case .guessAnimalSound:
            return animalSoundQuestion(difficulty: difficulty)
        case .tapColor, .mixColors:
            return colorQuestion(difficulty: difficulty)
        case .findAnimal, .feedAnimal, .helpAnimal:
            return animalQuestion(type: type, difficulty: difficulty)
        }
    }

    private func optionCount(_ difficulty: Int) -> Int { min(2 + difficulty, 6) }

    private func letterQuestion(difficulty: Int, spokenSound: Bool) -> MissionQuestion {
        // Early levels use visually distinct letters; from level 3 the rest
        // of the alphabet joins in, and level 4+ adds the look-alikes.
        let easyPool = "ABCDEFHKLMOSTU".map(String.init)
        let fullPool = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init)
        let pool0 = difficulty >= 3 ? fullPool : easyPool
        let trickyPairs = [["B", "D"], ["M", "W"], ["P", "Q"], ["E", "F"], ["O", "Q"],
                           ["I", "L"], ["N", "Z"], ["C", "G"], ["U", "V"], ["R", "P"],
                           ["K", "X"], ["S", "Z"]]

        var options: [QuestionOption]
        let target: String
        if difficulty >= 4, let pair = trickyPairs.randomElement() {
            target = pair[0]
            var pool = pair + pool0.shuffled().prefix(optionCount(difficulty) - 2)
            pool = Array(Set(pool)).shuffled()
            options = pool.map { QuestionOption(display: $0, label: letterLabel($0)) }
        } else {
            let pool = pool0.shuffled().prefix(optionCount(difficulty))
            target = pool.first!
            options = pool.map { QuestionOption(display: $0, label: letterLabel($0)) }.shuffled()
        }
        let correctID = options.first(where: { $0.display == target })!.id
        let prompt = spokenSound
            ? String(localized: "Which letter makes the '\(target.lowercased())' sound?")
            : String(localized: "Can you find the letter \(target)?")
        return MissionQuestion(id: UUID(), prompt: prompt,
                               content: .tapCorrect(options: options, correctID: correctID))
    }

    private func letterLabel(_ letter: String) -> String {
        String(localized: "Letter \(letter)")
    }

    /// Age 5+ word reading: find the spoken word among 4 word options.
    func wordQuestion(target: String) -> MissionQuestion {
        let display = target.uppercased()
        var options = WordBank.distractors(for: target, count: 3).map {
            QuestionOption(display: $0.uppercased(), label: wordLabel($0))
        }
        options.append(QuestionOption(display: display, label: wordLabel(target)))
        options.shuffle()
        let correctID = options.first(where: { $0.display == display })!.id
        return MissionQuestion(
            id: UUID(),
            prompt: String(localized: "Can you find the word \(display)?"),
            content: .tapCorrect(options: options, correctID: correctID)
        )
    }

    private func wordLabel(_ word: String) -> String {
        String(localized: "Word \(word)")
    }

    /// Age-6 addition: shows "6 + 2 = ?" while Bunny SAYS
    /// "What is 6 plus 2?" — symbol on screen, words in the ear.
    func additionChoiceQuestion(_ problem: AdditionProblem, engine: AdditionEngine) -> MissionQuestion {
        let options = engine.choices(for: problem).map {
            QuestionOption(display: "\($0)", label: String(localized: "Number \($0)"))
        }
        let correctID = options.first(where: { $0.display == "\(problem.sum)" })!.id
        return MissionQuestion(
            id: UUID(),
            prompt: "\(problem.a) + \(problem.b) = ?",
            content: .tapCorrect(options: options, correctID: correctID),
            spokenPrompt: String(localized: "What is \(problem.a) plus \(problem.b)?")
        )
    }

    private func traceQuestion(difficulty: Int) -> MissionQuestion {
        // Simple normalized guide paths (production: load from letter-path assets).
        // Straight-stroke letters first; the curved ones join from level 3.
        let guides: [String: [TracePoint]] = [
            "L": [TracePoint(x: 0.35, y: 0.2), TracePoint(x: 0.35, y: 0.8), TracePoint(x: 0.7, y: 0.8)],
            "T": [TracePoint(x: 0.2, y: 0.2), TracePoint(x: 0.8, y: 0.2), TracePoint(x: 0.5, y: 0.2), TracePoint(x: 0.5, y: 0.8)],
            "I": [TracePoint(x: 0.5, y: 0.2), TracePoint(x: 0.5, y: 0.8)],
            "V": [TracePoint(x: 0.3, y: 0.2), TracePoint(x: 0.5, y: 0.8), TracePoint(x: 0.7, y: 0.2)],
            "O": [TracePoint(x: 0.5, y: 0.2), TracePoint(x: 0.25, y: 0.5), TracePoint(x: 0.5, y: 0.8),
                  TracePoint(x: 0.75, y: 0.5), TracePoint(x: 0.5, y: 0.2)],
            "C": [TracePoint(x: 0.7, y: 0.25), TracePoint(x: 0.35, y: 0.35), TracePoint(x: 0.3, y: 0.55),
                  TracePoint(x: 0.45, y: 0.75), TracePoint(x: 0.7, y: 0.75)],
            "X": [TracePoint(x: 0.3, y: 0.2), TracePoint(x: 0.7, y: 0.8),
                  TracePoint(x: 0.7, y: 0.2), TracePoint(x: 0.3, y: 0.8)],
            "A": [TracePoint(x: 0.3, y: 0.8), TracePoint(x: 0.5, y: 0.2), TracePoint(x: 0.7, y: 0.8),
                  TracePoint(x: 0.38, y: 0.55), TracePoint(x: 0.62, y: 0.55)],
            "H": [TracePoint(x: 0.3, y: 0.2), TracePoint(x: 0.3, y: 0.8),
                  TracePoint(x: 0.3, y: 0.5), TracePoint(x: 0.7, y: 0.5),
                  TracePoint(x: 0.7, y: 0.2), TracePoint(x: 0.7, y: 0.8)],
            "E": [TracePoint(x: 0.7, y: 0.2), TracePoint(x: 0.32, y: 0.2),
                  TracePoint(x: 0.32, y: 0.5), TracePoint(x: 0.62, y: 0.5),
                  TracePoint(x: 0.32, y: 0.5), TracePoint(x: 0.32, y: 0.8),
                  TracePoint(x: 0.7, y: 0.8)],
            "F": [TracePoint(x: 0.7, y: 0.2), TracePoint(x: 0.32, y: 0.2),
                  TracePoint(x: 0.32, y: 0.8), TracePoint(x: 0.32, y: 0.5),
                  TracePoint(x: 0.62, y: 0.5)],
            "N": [TracePoint(x: 0.3, y: 0.8), TracePoint(x: 0.3, y: 0.2),
                  TracePoint(x: 0.7, y: 0.8), TracePoint(x: 0.7, y: 0.2)],
            "M": [TracePoint(x: 0.25, y: 0.8), TracePoint(x: 0.25, y: 0.2),
                  TracePoint(x: 0.5, y: 0.55), TracePoint(x: 0.75, y: 0.2),
                  TracePoint(x: 0.75, y: 0.8)],
            "U": [TracePoint(x: 0.3, y: 0.2), TracePoint(x: 0.3, y: 0.62),
                  TracePoint(x: 0.5, y: 0.8), TracePoint(x: 0.7, y: 0.62),
                  TracePoint(x: 0.7, y: 0.2)],
            "S": [TracePoint(x: 0.68, y: 0.28), TracePoint(x: 0.36, y: 0.24),
                  TracePoint(x: 0.34, y: 0.46), TracePoint(x: 0.66, y: 0.56),
                  TracePoint(x: 0.64, y: 0.76), TracePoint(x: 0.32, y: 0.74)]
        ]
        let straight = ["L", "T", "I", "V", "X", "H", "E", "F", "N", "M"]
        let letters = difficulty <= 2 ? straight : Array(guides.keys)
        let letter = letters.randomElement() ?? "L"
        return MissionQuestion(
            id: UUID(),
            prompt: String(localized: "Trace the letter \(letter) with your finger!"),
            content: .traceLetter(letter: letter, guidePoints: guides[letter] ?? [])
        )
    }

    private func countingQuestion(difficulty: Int) -> MissionQuestion {
        let maxCount = [3, 5, 7, 9, 10][difficulty - 1]
        let count = Int.random(in: 1...maxCount)
        let objects = ["🍎", "🌸", "🐞", "🍄", "⭐", "🐟", "🥕"].randomElement()!
        var choices = Set([count])
        while choices.count < min(3, maxCount) {
            choices.insert((count + Int.random(in: -2...2)).clamped(to: 1...maxCount + 2))
        }
        return MissionQuestion(
            id: UUID(),
            prompt: String(localized: "How many do you see? Count them!"),
            content: .countObjects(objectEmoji: objects, count: count, choices: choices.sorted())
        )
    }

    private func biggerNumberQuestion(difficulty: Int) -> MissionQuestion {
        let range = difficulty <= 3 ? 1...9 : 1...20
        var a = Int.random(in: range), b = Int.random(in: range)
        while a == b { b = Int.random(in: range) }
        let options = [a, b].map { QuestionOption(display: "\($0)", label: "\($0)") }
        let correctID = options[a > b ? 0 : 1].id
        return MissionQuestion(
            id: UUID(),
            prompt: String(localized: "Which number is bigger?"),
            content: .tapCorrect(options: options, correctID: correctID)
        )
    }

    private func additionQuestion(difficulty: Int) -> MissionQuestion {
        let a = Int.random(in: 1...4), b = Int.random(in: 1...(difficulty >= 5 ? 5 : 3))
        let answer = a + b
        var choices = Set([answer])
        while choices.count < 3 { choices.insert((answer + Int.random(in: -2...2)).clamped(to: 1...12)) }
        let options = choices.sorted().map { QuestionOption(display: "\($0)", label: "\($0)") }
        let correctID = options.first(where: { $0.display == "\(answer)" })!.id
        return MissionQuestion(
            id: UUID(),
            prompt: String(localized: "\(a) apples plus \(b) apples — how many?"),
            content: .tapCorrect(options: options, correctID: correctID)
        )
    }

    private func shapeQuestion(difficulty: Int) -> MissionQuestion {
        let shapes: [(String, String)] = [
            ("🔵", String(localized: "Circle")), ("🟦", String(localized: "Square")),
            ("🔺", String(localized: "Triangle")), ("🟧", String(localized: "Rectangle")),
            ("⭐", String(localized: "Star")), ("💜", String(localized: "Heart")),
            ("🔶", String(localized: "Diamond")), ("🥚", String(localized: "Oval")),
            ("➕", String(localized: "Cross")), ("🌙", String(localized: "Crescent")),
            ("🔻", String(localized: "Arrow")), ("⬡", String(localized: "Hexagon"))
        ]
        let pool = shapes.shuffled().prefix(optionCount(difficulty))
        let target = pool.first!
        let options = pool.map { QuestionOption(display: $0.0, label: $0.1) }.shuffled()
        let correctID = options.first(where: { $0.display == target.0 })!.id
        return MissionQuestion(
            id: UUID(),
            prompt: String(localized: "Can you find the \(target.1)?"),
            content: .tapCorrect(options: options, correctID: correctID)
        )
    }

    private func memoryQuestion(difficulty: Int) -> MissionQuestion {
        let pairCount = [2, 2, 3, 3, 4][difficulty - 1]
        let pool = ["🐰", "🦊", "🐻", "🦉", "🐿️", "🦔", "🐸", "🦋"].shuffled().prefix(pairCount)
        return MissionQuestion(
            id: UUID(),
            prompt: String(localized: "Find the matching friends!"),
            content: .memoryPairs(pairs: Array(pool))
        )
    }

    private func sequenceQuestion(difficulty: Int) -> MissionQuestion {
        let length = [2, 2, 3, 3, 4][difficulty - 1]
        let pool = ["🥁", "🔔", "🎺", "🪇"].shuffled()
        let items = (0..<length).map { index in
            let symbol = pool[index % pool.count]
            return QuestionOption(display: symbol, label: symbol)
        }
        return MissionQuestion(
            id: UUID(),
            prompt: String(localized: "Watch closely, then repeat the pattern!"),
            content: .sequence(items: items, playbackInterval: difficulty >= 4 ? 0.7 : 1.0)
        )
    }

    private func animalSoundQuestion(difficulty: Int) -> MissionQuestion {
        let animals: [(sound: String, emoji: String, name: String)] = [
            ("lion_roar", "🦁", String(localized: "Lion")),
            ("cow_moo", "🐮", String(localized: "Cow")),
            ("duck_quack", "🦆", String(localized: "Duck")),
            ("dog_woof", "🐶", String(localized: "Dog")),
            ("cat_meow", "🐱", String(localized: "Cat")),
            ("owl_hoot", "🦉", String(localized: "Owl")),
            ("sheep_baa", "🐑", String(localized: "Sheep")),
            ("horse_neigh", "🐴", String(localized: "Horse")),
            ("frog_croak", "🐸", String(localized: "Frog")),
            ("bee_buzz", "🐝", String(localized: "Bee")),
            ("elephant_trumpet", "🐘", String(localized: "Elephant")),
            ("bird_tweet", "🐦", String(localized: "Bird"))
        ]
        let pool = animals.shuffled().prefix(optionCount(difficulty))
        let target = pool.first!
        let options = pool.map { QuestionOption(display: $0.emoji, label: $0.name) }.shuffled()
        let correctID = options.first(where: { $0.label == target.name })!.id
        return MissionQuestion(
            id: UUID(),
            prompt: String(localized: "Listen! Which animal makes this sound?"),
            content: .soundGuess(soundName: target.sound, options: options, correctID: correctID)
        )
    }

    private func colorQuestion(difficulty: Int) -> MissionQuestion {
        // Colors get their own, more generous option curve: 4 at the gentlest
        // level, growing to the entire 10-color palette at the top level.
        let counts = [4, 5, 6, 8, 10]
        let count = min(counts[difficulty - 1], ForestTheme.GameColor.allCases.count)
        let colors = ForestTheme.GameColor.allCases.shuffled().prefix(count)
        let target = colors.first!
        let options = colors.map {
            QuestionOption(display: "●", label: $0.localizedName, gameColor: $0)
        }.shuffled()
        let correctID = options.first(where: { $0.gameColor == target })!.id
        return MissionQuestion(
            id: UUID(),
            prompt: String(localized: "Tap the color \(target.localizedName)!"),
            content: .tapCorrect(options: options, correctID: correctID)
        )
    }

    private func animalQuestion(type: MissionType, difficulty: Int) -> MissionQuestion {
        let animals: [(String, String)] = [
            ("🦁", String(localized: "Lion")), ("🐰", String(localized: "Rabbit")),
            ("🐵", String(localized: "Monkey")), ("🦊", String(localized: "Fox")),
            ("🐻", String(localized: "Bear")), ("🦒", String(localized: "Giraffe")),
            ("🐘", String(localized: "Elephant")), ("🦓", String(localized: "Zebra")),
            ("🐧", String(localized: "Penguin")), ("🦔", String(localized: "Hedgehog")),
            ("🐢", String(localized: "Turtle")), ("🦉", String(localized: "Owl")),
            ("🐿️", String(localized: "Squirrel")), ("🦌", String(localized: "Deer"))
        ]
        let pool = animals.shuffled().prefix(optionCount(difficulty))
        let target = pool.first!
        let options = pool.map { QuestionOption(display: $0.0, label: $0.1) }.shuffled()
        let correctID = options.first(where: { $0.display == target.0 })!.id
        let prompt = switch type {
        case .feedAnimal: String(localized: "The \(target.1) is hungry! Can you find them?")
        case .helpAnimal: String(localized: "Let's help the \(target.1)! Where are they?")
        default: String(localized: "Can you find the \(target.1)?")
        }
        return MissionQuestion(id: UUID(), prompt: prompt,
                               content: .tapCorrect(options: options, correctID: correctID))
    }
}
