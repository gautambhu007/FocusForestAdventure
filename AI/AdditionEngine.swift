//
//  AdditionEngine.swift
//  Focus Forest Adventure
//
//  Age-6 addition practice: four graded sections of two-addend problems.
//  Shared by the in-app Numbers missions AND the printable worksheet
//  (Teacher Mode). Pure and deterministic-enough to unit test.
//
//  Global rules: addition only, no negatives, sums never exceed 20,
//  20 unique questions per section, difficulty rises gradually.
//

import Foundation

/// The four Numbers sub-sections for 6-year-olds.
enum AdditionSection: String, CaseIterable, Codable, Sendable, Identifiable {
    case easy, medium, hard, challenge

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .easy: String(localized: "Easy")
        case .medium: String(localized: "Medium")
        case .hard: String(localized: "Hard")
        case .challenge: String(localized: "Challenge")
        }
    }

    var stars: String {
        switch self {
        case .easy: "⭐"
        case .medium: "⭐⭐"
        case .hard: "⭐⭐⭐"
        case .challenge: "🌟🌟🌟🌟"
        }
    }

    var localizedDescription: String {
        switch self {
        case .easy: String(localized: "Numbers 1 to 9 — comfy first sums!")
        case .medium: String(localized: "Numbers 5 to 14 — a little trickier!")
        case .hard: String(localized: "Big numbers close to 20!")
        case .challenge: String(localized: "A wild mix of everything!")
        }
    }
}

struct AdditionProblem: Hashable, Sendable {
    let a: Int
    let b: Int
    var sum: Int { a + b }
    var display: String { "\(a) + \(b)" }
}

struct AdditionEngine: Sendable {

    static let questionsPerSection = 20
    static let maxSum = 20

    /// 20 unique problems for a section, ordered easiest → hardest
    /// (challenge stays randomly mixed by design).
    func problems(
        for section: AdditionSection,
        count: Int = AdditionEngine.questionsPerSection
    ) -> [AdditionProblem] {
        var chosen: Set<AdditionProblem> = []
        var attempts = 0
        while chosen.count < count && attempts < 2000 {
            attempts += 1
            if let problem = randomProblem(for: section) {
                chosen.insert(problem)   // Set = "avoid repeating the same question"
            }
        }

        switch section {
        case .challenge:
            // Deliberately unsorted: easy, medium, and hard mixed randomly.
            return Array(chosen).shuffled()
        default:
            // Gradual difficulty: sort by sum; equal sums stay shuffled so
            // no visible pattern emerges.
            return Array(chosen).shuffled().sorted { $0.sum < $1.sum }
        }
    }

    /// One valid random problem for the section, or nil if the roll broke
    /// a constraint (caller just rolls again).
    private func randomProblem(for section: AdditionSection) -> AdditionProblem? {
        let a: Int, b: Int
        switch section {
        case .easy:
            // Both addends 1–9.
            a = Int.random(in: 1...9)
            b = Int.random(in: 1...9)
        case .medium:
            // Both addends 5–14, sum capped at 20.
            a = Int.random(in: 5...14)
            b = Int.random(in: 5...14)
        case .hard:
            // Larger addend 8–19, sum ≤ 20. (Spec said "both 8–20", but that
            // allows only 15 unique sums ≤ 20 and its own examples — like
            // 15 + 5 — break it; this reading matches the examples.)
            a = Int.random(in: 8...19)
            b = Int.random(in: 1...(AdditionEngine.maxSum - a))
        case .challenge:
            // Anything 1–20 with a valid sum.
            a = Int.random(in: 1...19)
            b = Int.random(in: 1...(AdditionEngine.maxSum - a))
        }
        guard a + b <= AdditionEngine.maxSum, a >= 1, b >= 1 else { return nil }
        // Randomize addend order so the bigger number isn't always first.
        return Bool.random() ? AdditionProblem(a: a, b: b) : AdditionProblem(a: b, b: a)
    }

    /// Answer choices for the in-app game: the correct sum + 3 plausible
    /// near-miss distractors, all in 0...20, shuffled.
    func choices(for problem: AdditionProblem) -> [Int] {
        var options: Set<Int> = [problem.sum]
        var candidates = [problem.sum - 1, problem.sum + 1, problem.sum - 2,
                          problem.sum + 2, problem.a, problem.sum + 10 <= 20 ? problem.sum + 10 : problem.sum - 10]
        candidates.removeAll { $0 < 0 || $0 > 20 }
        for candidate in candidates.shuffled() where options.count < 4 {
            options.insert(candidate)
        }
        var filler = 0
        while options.count < 4 && filler <= 20 {   // degenerate safety net
            options.insert(filler)
            filler += 1
        }
        return Array(options).shuffled()
    }
}
