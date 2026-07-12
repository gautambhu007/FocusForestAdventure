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
    let theme: StoryTheme
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
    /// Phase 2.8: story flavor from the daily recommendations.
    var theme: StoryTheme = .friendship
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
            themeLine(context.theme, nickname: nickname, animalName: animal.name),
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
            favoriteActivity: context.favoriteActivity,
            theme: context.theme
        )
    }

    /// Phase 2.8: one page whose flavor follows the recommended story theme.
    private func themeLine(_ theme: StoryTheme, nickname: String, animalName: String) -> String {
        switch theme {
        case .discovery:
            String(localized: "\"There's so much we haven't explored!\" said the \(animalName), pointing at a path of new footprints — tomorrow, another discovery awaits.")
        case .courage:
            String(localized: "\"Remember,\" whispered the \(animalName), \"even tall trees started as tiny seeds. Trying again is the bravest magic of all, \(nickname).\"")
        case .celebration:
            String(localized: "The whole forest threw a tiny party — fireflies danced, drums of acorns rolled, all to celebrate how wonderfully \(nickname) had played today!")
        case .friendship:
            String(localized: "\(nickname) and the \(animalName) sat together watching the fireflies, happy just to be friends in their growing forest.")
        }
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
