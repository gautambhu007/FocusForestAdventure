//
//  MuralCatalog.swift
//  Focus Forest Adventure
//
//  What 🧩 puzzle pieces are *for*. Each world has a nine-tile mural that
//  starts blank; a piece placed reveals one tile, and the finished picture is
//  the child's souvenir of that world.
//
//  Pieces are placed one at a time, by choice, rather than filling in
//  automatically — a reward you *do* something with lands harder than a
//  number that goes up on its own.
//

import Foundation

struct WorldMural: Hashable, Sendable {
    let world: PuzzleWorld
    let title: String
    /// Nine tiles, row-major: a 3×3 picture.
    let tiles: [String]
    /// Gems for finishing the picture.
    let completionBonus: Int

    static let tileCount = 9

    /// The tiles revealed so far, with the rest blanked out.
    func revealed(_ placed: Int) -> [String?] {
        tiles.enumerated().map { index, tile in index < placed ? tile : nil }
    }

    func isComplete(_ placed: Int) -> Bool { placed >= Self.tileCount }
}

enum MuralCatalog {

    static func mural(for world: PuzzleWorld) -> WorldMural {
        switch world {
        case .forest:
            WorldMural(world: .forest, title: String(localized: "The Tree of Knowledge"),
                       tiles: ["☁️", "🌤", "🦋",
                               "🌳", "🌳", "🐿",
                               "🍄", "🌷", "🌰"],
                       completionBonus: 60)
        case .pirate:
            WorldMural(world: .pirate, title: String(localized: "The Treasure Cove"),
                       tiles: ["🌤", "🦜", "⛵️",
                               "🏝", "🗺", "🧭",
                               "🌊", "💰", "🪙"],
                       completionBonus: 70)
        case .space:
            WorldMural(world: .space, title: String(localized: "Zog's Spaceship"),
                       tiles: ["⭐️", "🪐", "☄️",
                               "🛰", "🚀", "🌙",
                               "👽", "🤖", "🔭"],
                       completionBonus: 80)
        case .castle:
            WorldMural(world: .castle, title: String(localized: "The Magic Gate"),
                       tiles: ["✨", "🌙", "✨",
                               "🏰", "🗝", "🏰",
                               "🧙", "🐉", "🧚"],
                       completionBonus: 90)
        case .dinosaur:
            WorldMural(world: .dinosaur, title: String(localized: "The Hidden Valley"),
                       tiles: ["🌋", "☁️", "🦅",
                               "🦕", "🌿", "🦖",
                               "🥚", "🐣", "🦴"],
                       completionBonus: 100)
        case .ocean:
            WorldMural(world: .ocean, title: String(localized: "The Living Reef"),
                       tiles: ["🌊", "⛵️", "🌊",
                               "🐬", "🐠", "🐙",
                               "🪸", "🐚", "🦀"],
                       completionBonus: 110)
        case .ice:
            WorldMural(world: .ice, title: String(localized: "The Ice Palace"),
                       tiles: ["❄️", "🌨", "❄️",
                               "🏔", "🏰", "🏔",
                               "⛄️", "🐧", "🦌"],
                       completionBonus: 120)
        case .volcano:
            WorldMural(world: .volcano, title: String(localized: "The Great Experiment"),
                       tiles: ["💥", "⚡️", "💥",
                               "🧪", "🌋", "⚗️",
                               "🪨", "🔬", "🧫"],
                       completionBonus: 130)
        case .rainbow:
            WorldMural(world: .rainbow, title: String(localized: "Brainland Restored"),
                       tiles: ["🌈", "🎆", "🌈",
                               "🏰", "💎", "🏰",
                               "🦄", "🕊", "✨"],
                       completionBonus: 200)
        }
    }

    static var all: [WorldMural] { PuzzleWorld.allCases.map(mural(for:)) }
}
