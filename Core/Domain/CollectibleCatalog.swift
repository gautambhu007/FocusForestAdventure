//
//  CollectibleCatalog.swift
//  Focus Forest Adventure
//
//  What gems and puzzle pieces are *for*. Every collectible is cosmetic —
//  nothing here makes puzzles easier or a child stronger, so a locked item is
//  never a disadvantage, only something to look forward to.
//
//  Two currencies, two feelings:
//  • 💎 Gems are earned every level and spent freely — the small, frequent
//    reward that keeps a five-year-old going.
//  • 🧩 Puzzle pieces are the slow one: some items only open once a world's
//    crystal is won, so the story stays the real prize.
//

import Foundation

enum CollectibleKind: String, CaseIterable, Codable, Sendable, Hashable {
    case companion, hat, vehicle, place, sticker

    var localizedTitle: String {
        switch self {
        case .companion: String(localized: "Friends")
        case .hat: String(localized: "Hats")
        case .vehicle: String(localized: "Rides")
        case .place: String(localized: "Places")
        case .sticker: String(localized: "Stickers")
        }
    }

    var emoji: String {
        switch self {
        case .companion: "🐼"
        case .hat: "🎩"
        case .vehicle: "🚀"
        case .place: "🏰"
        case .sticker: "🌈"
        }
    }
}

struct Collectible: Hashable, Sendable, Identifiable {
    let id: String
    let emoji: String
    let name: String
    let kind: CollectibleKind
    /// Price in 💎 gems.
    let price: Int
    /// Some treasures only appear once a world's crystal is home.
    let requiresCrystal: PuzzleWorld?

    func isAvailable(crystals: Set<PuzzleWorld>) -> Bool {
        guard let requiresCrystal else { return true }
        return crystals.contains(requiresCrystal)
    }
}

enum CollectibleCatalog {

    static func items(of kind: CollectibleKind) -> [Collectible] {
        all.filter { $0.kind == kind }
    }

    static func item(_ id: String) -> Collectible? {
        all.first { $0.id == id }
    }

    /// Cheapest first, so the first thing a child can afford is obvious.
    static func affordable(gems: Int, crystals: Set<PuzzleWorld>, owned: Set<String>) -> [Collectible] {
        all
            .filter { !owned.contains($0.id) && $0.isAvailable(crystals: crystals) && $0.price <= gems }
            .sorted { $0.price < $1.price }
    }

    static let all: [Collectible] = companions + hats + vehicles + places + stickers

    // MARK: Friends
    //
    // The starter friends are cheap on purpose: a child should be able to
    // adopt one after their first couple of levels.

    private static let companions: [Collectible] = [
        Collectible(id: "pet.bunny", emoji: "🐰", name: String(localized: "Bunny"),
                    kind: .companion, price: 30, requiresCrystal: nil),
        Collectible(id: "pet.squirrel", emoji: "🐿", name: String(localized: "Squirrel"),
                    kind: .companion, price: 40, requiresCrystal: nil),
        Collectible(id: "pet.fox", emoji: "🦊", name: String(localized: "Fox"),
                    kind: .companion, price: 60, requiresCrystal: nil),
        Collectible(id: "pet.owl", emoji: "🦉", name: String(localized: "Owl"),
                    kind: .companion, price: 80, requiresCrystal: .forest),
        Collectible(id: "pet.parrot", emoji: "🦜", name: String(localized: "Parrot"),
                    kind: .companion, price: 90, requiresCrystal: .pirate),
        Collectible(id: "pet.turtle", emoji: "🐢", name: String(localized: "Turtle"),
                    kind: .companion, price: 90, requiresCrystal: .pirate),
        Collectible(id: "pet.robot", emoji: "🤖", name: String(localized: "Robot"),
                    kind: .companion, price: 120, requiresCrystal: .space),
        Collectible(id: "pet.alien", emoji: "👽", name: String(localized: "Alien"),
                    kind: .companion, price: 120, requiresCrystal: .space),
        Collectible(id: "pet.dragon", emoji: "🐉", name: String(localized: "Tiny Dragon"),
                    kind: .companion, price: 150, requiresCrystal: .castle),
        Collectible(id: "pet.fairy", emoji: "🧚", name: String(localized: "Fairy"),
                    kind: .companion, price: 150, requiresCrystal: .castle),
        Collectible(id: "pet.dino", emoji: "🦕", name: String(localized: "Dino"),
                    kind: .companion, price: 180, requiresCrystal: .dinosaur),
        Collectible(id: "pet.trex", emoji: "🦖", name: String(localized: "T-Rex"),
                    kind: .companion, price: 180, requiresCrystal: .dinosaur),
        Collectible(id: "pet.octopus", emoji: "🐙", name: String(localized: "Octopus"),
                    kind: .companion, price: 200, requiresCrystal: .ocean),
        Collectible(id: "pet.dolphin", emoji: "🐬", name: String(localized: "Dolphin"),
                    kind: .companion, price: 200, requiresCrystal: .ocean),
        Collectible(id: "pet.penguin", emoji: "🐧", name: String(localized: "Penguin"),
                    kind: .companion, price: 220, requiresCrystal: .ice),
        Collectible(id: "pet.deer", emoji: "🦌", name: String(localized: "Reindeer"),
                    kind: .companion, price: 220, requiresCrystal: .ice),
        Collectible(id: "pet.unicorn", emoji: "🦄", name: String(localized: "Unicorn"),
                    kind: .companion, price: 300, requiresCrystal: .rainbow),
        Collectible(id: "pet.panda", emoji: "🐼", name: String(localized: "Panda"),
                    kind: .companion, price: 100, requiresCrystal: nil),
        Collectible(id: "pet.cat", emoji: "🐱", name: String(localized: "Cat"),
                    kind: .companion, price: 50, requiresCrystal: nil),
        Collectible(id: "pet.dog", emoji: "🐶", name: String(localized: "Puppy"),
                    kind: .companion, price: 50, requiresCrystal: nil)
    ]

    // MARK: Hats

    private static let hats: [Collectible] = [
        Collectible(id: "hat.party", emoji: "🥳", name: String(localized: "Party Hat"),
                    kind: .hat, price: 25, requiresCrystal: nil),
        Collectible(id: "hat.crown", emoji: "👑", name: String(localized: "Crown"),
                    kind: .hat, price: 120, requiresCrystal: .castle),
        Collectible(id: "hat.pirate", emoji: "🏴‍☠️", name: String(localized: "Pirate Hat"),
                    kind: .hat, price: 80, requiresCrystal: .pirate),
        Collectible(id: "hat.wizard", emoji: "🎩", name: String(localized: "Magic Hat"),
                    kind: .hat, price: 100, requiresCrystal: nil),
        Collectible(id: "hat.helmet", emoji: "🪖", name: String(localized: "Explorer Helmet"),
                    kind: .hat, price: 70, requiresCrystal: nil),
        Collectible(id: "hat.flower", emoji: "🌺", name: String(localized: "Flower Crown"),
                    kind: .hat, price: 45, requiresCrystal: nil)
    ]

    // MARK: Rides

    private static let vehicles: [Collectible] = [
        Collectible(id: "ride.rocket", emoji: "🚀", name: String(localized: "Rocket"),
                    kind: .vehicle, price: 200, requiresCrystal: .space),
        Collectible(id: "ride.submarine", emoji: "🛥", name: String(localized: "Submarine"),
                    kind: .vehicle, price: 200, requiresCrystal: .ocean),
        Collectible(id: "ride.ship", emoji: "⛵️", name: String(localized: "Pirate Ship"),
                    kind: .vehicle, price: 160, requiresCrystal: .pirate),
        Collectible(id: "ride.sled", emoji: "🛷", name: String(localized: "Sled"),
                    kind: .vehicle, price: 160, requiresCrystal: .ice),
        Collectible(id: "ride.balloon", emoji: "🎈", name: String(localized: "Balloon"),
                    kind: .vehicle, price: 90, requiresCrystal: nil),
        Collectible(id: "ride.saucer", emoji: "🛸", name: String(localized: "Flying Saucer"),
                    kind: .vehicle, price: 240, requiresCrystal: .space)
    ]

    // MARK: Places

    private static let places: [Collectible] = [
        Collectible(id: "place.treehouse", emoji: "🌳", name: String(localized: "Treehouse"),
                    kind: .place, price: 150, requiresCrystal: .forest),
        Collectible(id: "place.castle", emoji: "🏰", name: String(localized: "Castle"),
                    kind: .place, price: 250, requiresCrystal: .castle),
        Collectible(id: "place.island", emoji: "🏝", name: String(localized: "Island"),
                    kind: .place, price: 200, requiresCrystal: .pirate),
        Collectible(id: "place.igloo", emoji: "🧊", name: String(localized: "Igloo"),
                    kind: .place, price: 220, requiresCrystal: .ice),
        Collectible(id: "place.reef", emoji: "🪸", name: String(localized: "Coral Reef"),
                    kind: .place, price: 220, requiresCrystal: .ocean),
        Collectible(id: "place.lab", emoji: "🧪", name: String(localized: "Laboratory"),
                    kind: .place, price: 260, requiresCrystal: .volcano)
    ]

    // MARK: Stickers

    private static let stickers: [Collectible] = [
        Collectible(id: "sticker.star", emoji: "⭐️", name: String(localized: "Gold Star"),
                    kind: .sticker, price: 15, requiresCrystal: nil),
        Collectible(id: "sticker.rainbow", emoji: "🌈", name: String(localized: "Rainbow"),
                    kind: .sticker, price: 20, requiresCrystal: nil),
        Collectible(id: "sticker.heart", emoji: "💖", name: String(localized: "Heart"),
                    kind: .sticker, price: 15, requiresCrystal: nil),
        Collectible(id: "sticker.sparkle", emoji: "✨", name: String(localized: "Sparkles"),
                    kind: .sticker, price: 20, requiresCrystal: nil),
        Collectible(id: "sticker.medal", emoji: "🏅", name: String(localized: "Medal"),
                    kind: .sticker, price: 35, requiresCrystal: nil),
        Collectible(id: "sticker.fireworks", emoji: "🎆", name: String(localized: "Fireworks"),
                    kind: .sticker, price: 40, requiresCrystal: nil),
        Collectible(id: "sticker.trophy", emoji: "🏆", name: String(localized: "Trophy"),
                    kind: .sticker, price: 60, requiresCrystal: nil),
        Collectible(id: "sticker.gem", emoji: "💎", name: String(localized: "Gem"),
                    kind: .sticker, price: 50, requiresCrystal: nil)
    ]
}
