//
//  TreasureCatalog.swift
//  Focus Forest Adventure
//
//  The things a child earns by answering questions: furniture for the
//  cottage, castle and treehouse, staircases and bridges, animals to
//  befriend, and decorations for the grounds.
//
//  Earning is the key that opens the Magic Forest. One treasure buys one
//  visit (`ForestPass`), and a visit lasts four minutes — then it's back
//  to the adventures to earn the next one. That loop is deliberate: the
//  forest is the reward for focus, never a place to drift in.
//
//  Pure domain — the 3D layer maps `TreasureForm` to geometry, exactly
//  like `PlantForm`.
//

import Foundation

// MARK: - Where a treasure lives

enum TreasurePlacement: String, Codable, Sendable, CaseIterable {
    case cottage, castle, treehouse, grounds
}

// MARK: - What it looks like

/// Geometry archetypes the 3D builder knows how to make.
enum TreasureForm: String, Codable, Sendable, CaseIterable {
    case chair, table, bed, chest, rug, lamp, shelf, painting, banner
    case staircase, bridge, fountain, statue, bench, swing, planter
    case lantern, birdhouse, animal
}

// MARK: - A treasure

struct ForestTreasure: Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let emoji: String
    let blurb: String
    let form: TreasureForm
    let placement: TreasurePlacement
    let accent: PlantColor

    /// How many treasures must already be earned before this one appears.
    /// Set from the catalog order, so progression is steady and the child
    /// always knows roughly what comes next.
    var order: Int = 0
}

// MARK: - Catalog

enum TreasureCatalog {

    private static func t(
        _ id: String, _ name: String, _ emoji: String,
        _ form: TreasureForm, _ placement: TreasurePlacement,
        _ accent: PlantColor, _ blurb: String
    ) -> ForestTreasure {
        ForestTreasure(id: id, name: name, emoji: emoji, blurb: blurb,
                       form: form, placement: placement, accent: accent)
    }

    /// Every earnable treasure, in the order they are awarded. Early items
    /// are cosy and immediately visible (a rug, a chair); the grand ones
    /// (the grand staircase, the fountain) come later so there is always
    /// something to look forward to.
    static let all: [ForestTreasure] = {
        var items: [ForestTreasure] = [

            // MARK: First cosy things — the cottage
            t("rug_cottage", String(localized: "Round Rug"), "🟠", .rug, .cottage, .crimson,
              String(localized: "A soft rug for the cottage floor!")),
            t("chair_rocking", String(localized: "Rocking Chair"), "🪑", .chair, .cottage, .brown,
              String(localized: "A rocking chair by the fire!")),
            t("table_kitchen", String(localized: "Kitchen Table"), "🪵", .table, .cottage, .tan,
              String(localized: "A table for breakfast in the cottage!")),
            t("lamp_bedside", String(localized: "Bedside Lamp"), "💡", .lamp, .cottage, .gold,
              String(localized: "A warm little lamp for reading!")),
            t("bed_bunk", String(localized: "Bunk Bed"), "🛏️", .bed, .cottage, .blue,
              String(localized: "A bunk bed — you get the top one!")),
            t("shelf_pots", String(localized: "Pot Shelf"), "🫙", .shelf, .cottage, .teal,
              String(localized: "A shelf full of jars and pots!")),
            t("painting_meadow", String(localized: "Meadow Painting"), "🖼️", .painting, .cottage, .lime,
              String(localized: "A painting of your own meadow!")),
            t("chest_toys", String(localized: "Toy Chest"), "🧰", .chest, .cottage, .orange,
              String(localized: "A chest to keep your treasures in!")),
            t("lantern_porch", String(localized: "Porch Lantern"), "🏮", .lantern, .cottage, .gold,
              String(localized: "A lantern to light the cottage door!")),
            t("planter_window", String(localized: "Window Box"), "🪴", .planter, .cottage, .pink,
              String(localized: "Flowers on the cottage windowsill!")),

            // MARK: Steps and ways through
            t("stair_cottage", String(localized: "Cottage Stairs"), "🪜", .staircase, .cottage, .tan,
              String(localized: "Stairs up to the cottage loft!")),
            t("stair_spiral", String(localized: "Spiral Staircase"), "🌀", .staircase, .treehouse, .brown,
              String(localized: "A twisty staircase up the big tree!")),
            t("bridge_brook", String(localized: "Little Bridge"), "🌉", .bridge, .grounds, .tan,
              String(localized: "A bridge over the sparkling brook!")),
            t("stair_hill", String(localized: "Hill Steps"), "🪜", .staircase, .grounds, .grey,
              String(localized: "Stone steps up the castle hill!")),

            // MARK: The treehouse
            t("cushion_pile", String(localized: "Cushion Pile"), "🛋️", .chair, .treehouse, .magenta,
              String(localized: "Squishy cushions for the treehouse!")),
            t("shelf_books", String(localized: "Book Shelf"), "📚", .shelf, .treehouse, .brown,
              String(localized: "A shelf of story books!")),
            t("swing_rope", String(localized: "Rope Swing"), "🪢", .swing, .treehouse, .tan,
              String(localized: "A rope swing under the branches!")),
            t("lantern_paper", String(localized: "Paper Lanterns"), "🏮", .lantern, .treehouse, .coral,
              String(localized: "Glowing paper lanterns on a string!")),
            t("table_low", String(localized: "Little Table"), "🪑", .table, .treehouse, .tan,
              String(localized: "A low table for snacks up high!")),
            t("birdhouse_blue", String(localized: "Birdhouse"), "🏠", .birdhouse, .treehouse, .sky,
              String(localized: "A birdhouse for feathered neighbours!")),
            t("banner_flags", String(localized: "Bunting Flags"), "🎏", .banner, .treehouse, .gold,
              String(localized: "Colourful flags around the treehouse!")),
            t("bed_hammock", String(localized: "Hammock"), "🛌", .bed, .treehouse, .lime,
              String(localized: "A hammock for treetop naps!")),

            // MARK: The castle
            t("rug_throne", String(localized: "Throne Carpet"), "🟥", .rug, .castle, .crimson,
              String(localized: "A red carpet to the throne!")),
            t("chair_throne", String(localized: "Golden Throne"), "👑", .chair, .castle, .gold,
              String(localized: "A golden throne — sit like a monarch!")),
            t("table_feast", String(localized: "Feast Table"), "🍽️", .table, .castle, .brown,
              String(localized: "A long table for a royal feast!")),
            t("banner_royal", String(localized: "Royal Banners"), "🚩", .banner, .castle, .indigo,
              String(localized: "Banners hanging in the great hall!")),
            t("chest_treasure", String(localized: "Treasure Chest"), "💰", .chest, .castle, .gold,
              String(localized: "A treasure chest full of gold!")),
            t("painting_dragon", String(localized: "Dragon Portrait"), "🐉", .painting, .castle, .teal,
              String(localized: "A painting of the friendly dragon!")),
            t("stair_grand", String(localized: "Grand Staircase"), "🪜", .staircase, .castle, .gold,
              String(localized: "A grand staircase up to the balconies!")),
            t("lamp_chandelier", String(localized: "Chandelier"), "✨", .lamp, .castle, .gold,
              String(localized: "A sparkling chandelier overhead!")),
            t("shelf_library", String(localized: "Library Shelves"), "📖", .shelf, .castle, .brown,
              String(localized: "Tall shelves for the castle library!")),
            t("statue_knight", String(localized: "Knight Statue"), "🗿", .statue, .castle, .grey,
              String(localized: "A stone knight standing guard!")),
            t("bed_royal", String(localized: "Royal Bed"), "🛏️", .bed, .castle, .purple,
              String(localized: "A four-poster bed fit for royalty!")),

            // MARK: Out on the grounds
            t("bench_garden", String(localized: "Garden Bench"), "🪑", .bench, .grounds, .tan,
              String(localized: "A bench to sit and watch the butterflies!")),
            t("fountain_stone", String(localized: "Stone Fountain"), "⛲", .fountain, .grounds, .sky,
              String(localized: "A splashing fountain in the courtyard!")),
            t("statue_bunny", String(localized: "Bunny Statue"), "🗿", .statue, .grounds, .ivory,
              String(localized: "A statue of Bunny, your guide!")),
            t("swing_garden", String(localized: "Garden Swing"), "🎠", .swing, .grounds, .coral,
              String(localized: "A swing hanging from the old oak!")),
            t("planter_herbs", String(localized: "Herb Planter"), "🪴", .planter, .grounds, .lime,
              String(localized: "A planter of mint and lemongrass!")),
            t("lantern_path", String(localized: "Path Lanterns"), "🏮", .lantern, .grounds, .gold,
              String(localized: "Lanterns lighting the forest path!")),
            t("birdhouse_tall", String(localized: "Bird Tower"), "🕊️", .birdhouse, .grounds, .white,
              String(localized: "A tall tower of little bird homes!")),
            t("bench_picnic", String(localized: "Picnic Table"), "🧺", .table, .grounds, .tan,
              String(localized: "A picnic table by the brook!")),
            t("bridge_stone", String(localized: "Stone Bridge"), "🌁", .bridge, .grounds, .grey,
              String(localized: "A grand stone bridge across the water!")),
            t("statue_dragon", String(localized: "Dragon Statue"), "🐲", .statue, .grounds, .teal,
              String(localized: "A dragon carved from green stone!")),
            t("fountain_star", String(localized: "Star Fountain"), "🌟", .fountain, .grounds, .gold,
              String(localized: "A fountain that sparkles like stars!")),

            // MARK: Forest friends
            t("animal_hedgehog", String(localized: "Hedgehog"), "🦔", .animal, .grounds, .brown,
              String(localized: "A snuffly hedgehog moved into the leaves!")),
            t("animal_squirrel", String(localized: "Squirrel"), "🐿️", .animal, .grounds, .orange,
              String(localized: "A squirrel is burying nuts in your forest!")),
            t("animal_deer", String(localized: "Deer"), "🦌", .animal, .grounds, .tan,
              String(localized: "A gentle deer came to the clearing!")),
            t("animal_owl", String(localized: "Owl"), "🦉", .animal, .grounds, .brown,
              String(localized: "An owl is watching from the branches!")),
            t("animal_badger", String(localized: "Badger"), "🦡", .animal, .grounds, .grey,
              String(localized: "A stripy badger dug a burrow!")),
            t("animal_duck", String(localized: "Duck"), "🦆", .animal, .grounds, .yellow,
              String(localized: "A duck is paddling on the brook!")),
            t("animal_frog", String(localized: "Frog"), "🐸", .animal, .grounds, .lime,
              String(localized: "A frog is hopping by the water!")),
            t("animal_turtle", String(localized: "Turtle"), "🐢", .animal, .grounds, .deepLeaf,
              String(localized: "A slow, wise turtle sunning on a rock!")),
            t("animal_bear", String(localized: "Bear Cub"), "🐻", .animal, .grounds, .brown,
              String(localized: "A friendly bear cub is exploring!")),
            t("animal_mouse", String(localized: "Field Mouse"), "🐭", .animal, .grounds, .grey,
              String(localized: "A tiny mouse is nesting in the grass!")),
            t("animal_hare", String(localized: "Hare"), "🐇", .animal, .grounds, .tan,
              String(localized: "A long-eared hare bounded in!")),
            t("animal_fawn", String(localized: "Spotted Fawn"), "🦌", .animal, .grounds, .peach,
              String(localized: "A spotted fawn is following the deer!")),
            t("animal_robin", String(localized: "Robin"), "🐦", .animal, .grounds, .red,
              String(localized: "A red-breasted robin is singing!")),
            t("animal_kingfisher", String(localized: "Kingfisher"), "🐦", .animal, .grounds, .teal,
              String(localized: "A flash of blue — a kingfisher by the brook!")),
            t("animal_peacock", String(localized: "Peacock"), "🦚", .animal, .grounds, .teal,
              String(localized: "A peacock is showing off its tail!")),
            t("animal_swan", String(localized: "Swan"), "🦢", .animal, .grounds, .white,
              String(localized: "A white swan glides across the water!")),

            // MARK: Grand finishes
            t("lamp_firefly", String(localized: "Firefly Jar"), "🫙", .lamp, .grounds, .lime,
              String(localized: "A jar of fireflies that glow at night!")),
            t("painting_family", String(localized: "Family Portrait"), "🖼️", .painting, .cottage, .peach,
              String(localized: "A picture of everyone you love!")),
            t("statue_star", String(localized: "Star Pillar"), "⭐", .statue, .grounds, .gold,
              String(localized: "A pillar with a star on top!")),
            t("fountain_rainbow", String(localized: "Rainbow Fountain"), "🌈", .fountain, .grounds, .violet,
              String(localized: "A fountain that makes its own rainbow!"))
        ]
        for i in items.indices { items[i].order = i }
        return items
    }()

    static let byID: [String: ForestTreasure] = Dictionary(
        all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
    )

    static func treasure(_ id: String) -> ForestTreasure? { byID[id] }

    /// The next treasure the child has not yet earned.
    static func next(after earned: Set<String>) -> ForestTreasure? {
        all.first { !earned.contains($0.id) }
    }

    /// The `count` treasures that come next, in order. Fewer are returned
    /// when the child has collected nearly everything.
    static func next(_ count: Int, after earned: Set<String>) -> [ForestTreasure] {
        Array(all.lazy.filter { !earned.contains($0.id) }.prefix(count))
    }

    static func treasures(for placement: TreasurePlacement,
                          earned: Set<String>) -> [ForestTreasure] {
        all.filter { $0.placement == placement && earned.contains($0.id) }
    }
}

// MARK: - Magic Forest visit rules

/// The rules that gate the Magic Forest. Kept here, in the domain, so the
/// UI can't quietly drift away from them.
enum MagicForestRules {

    /// A visit lasts four minutes, then the child heads back to the
    /// adventures. Short enough to stay a treat, long enough to explore.
    static let visitDuration: TimeInterval = 4 * 60

    /// Warn the child gently before the visit ends, so leaving is never a
    /// surprise.
    static let warningTime: TimeInterval = 30

    /// The forest opens only when something new has been earned.
    static func canEnter(passes: Int) -> Bool { passes > 0 }
}

// MARK: - Treasure engine

/// Decides what a finished mission earns. Pure and deterministic.
struct TreasureEngine: Sendable {

    /// Treasures awarded for one mission: always one for finishing, plus a
    /// bonus one for a strong run. Effort is what counts — even a shaky
    /// mission earns something, so the forest is never out of reach.
    func award(alreadyEarned: Set<String>,
               accuracy: Double,
               questionsAnswered: Int) -> [ForestTreasure] {
        guard questionsAnswered > 0 else { return [] }
        let bonus = (accuracy >= 0.8 && questionsAnswered >= 10) ? 1 : 0
        return TreasureCatalog.next(1 + bonus, after: alreadyEarned)
    }

    /// One earned treasure opens one visit to the Magic Forest.
    func passesEarned(for treasures: [ForestTreasure]) -> Int { treasures.count }
}
