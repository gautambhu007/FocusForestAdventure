//
//  StoryEngine.swift
//  Focus Forest Adventure
//
//  Offline-first story generation for Phase 2.1. The engine is deterministic
//  enough to test, uses only local progress signals, and never needs network.
//

import Foundation

struct StoryDraft: Sendable, Equatable {
    let title: String
    let pages: [String]
    let adventureKind: AdventureKind
    let forestLevel: Int
    let treesPlanted: Int
    let unlockedAnimals: [ForestElement]
    let achievementIDs: [AchievementID]
    let childNickname: String
    let favoriteActivity: AdventureKind
}

struct StoryContext: Sendable, Equatable {
    let childNickname: String
    let completedAdventure: AdventureKind
    let forestLevel: Int
    let treesPlanted: Int
    let unlockedAnimals: [ForestElement]
    let achievementIDs: [AchievementID]
    let favoriteActivity: AdventureKind
    let starsEarned: Int
}

struct StoryEngine: Sendable {

    func generateStory(context: StoryContext) -> StoryDraft {
        let nickname = context.childNickname.isEmpty
            ? String(localized: "Explorer")
            : context.childNickname
        let animal = primaryAnimal(from: context.unlockedAnimals)
        let forestName = forestName(level: context.forestLevel)
        let favorite = context.favoriteActivity.localizedTitle
        let achievementLine = achievementLine(context.achievementIDs)
        let treeLine = String(localized: "\(context.treesPlanted) brave little trees shimmered nearby.")

        let title = String(localized: "\(nickname) and the \(animal.name)'s Forest Wish")
        let pages = [
            String(localized: "After today's \(context.completedAdventure.localizedTitle) adventure, \(nickname) followed a trail of golden stars into the \(forestName)."),
            String(localized: "There, a friendly \(animal.name) waved from behind the leaves. \"Your focus helped the forest grow,\" the friend said."),
            String(localized: "\(treeLine) The flowers hummed a soft tune about \(favorite), because that was one of \(nickname)'s favorite ways to learn."),
            achievementLine,
            String(localized: "Bunny placed \(context.starsEarned) bright stars in the sky and whispered, \"Every try makes our forest stronger.\""),
            String(localized: "So \(nickname), Bunny, and the \(animal.name) promised to return for another gentle adventure soon.")
        ]

        return StoryDraft(
            title: title,
            pages: pages,
            adventureKind: context.completedAdventure,
            forestLevel: context.forestLevel,
            treesPlanted: context.treesPlanted,
            unlockedAnimals: context.unlockedAnimals,
            achievementIDs: context.achievementIDs,
            childNickname: nickname,
            favoriteActivity: context.favoriteActivity
        )
    }

    private func primaryAnimal(from elements: [ForestElement]) -> (name: String, emoji: String) {
        if elements.contains(.dragon) {
            return (String(localized: "friendly dragon"), "🐉")
        }
        if elements.contains(.animals) {
            return (String(localized: "forest fox"), "🦊")
        }
        if elements.contains(.butterflies) {
            return (String(localized: "butterfly"), "🦋")
        }
        return (String(localized: "bunny"), "🐰")
    }

    private func forestName(level: Int) -> String {
        switch level {
        case ..<3: String(localized: "Sleepy Meadow")
        case ..<5: String(localized: "Flower Field")
        case ..<7: String(localized: "Friendly Forest")
        default: String(localized: "Magic Forest")
        }
    }

    private func achievementLine(_ achievements: [AchievementID]) -> String {
        guard let latest = achievements.first else {
            return String(localized: "The forest bells rang softly, celebrating effort, curiosity, and kind practice.")
        }
        return String(localized: "High above the trees, the \(latest.localizedTitle) badge sparkled like a tiny moon.")
    }
}
