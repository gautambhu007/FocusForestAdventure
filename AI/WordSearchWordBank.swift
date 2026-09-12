//
//  WordSearchWordBank.swift
//  Focus Forest Adventure
//
//  The 40 Word Hunt sheets: a fixed campaign, one theme each, four
//  difficulty stages (ages 4–5 → 6–7+). Every target word is unique across
//  the whole campaign — no plurals, stems or substrings of another sheet's
//  word either, because a child dragging "SUN" must not light up half of
//  "SUNSHINE". `WordSearchWordBankTests` fails the build on any collision,
//  which is the only reason the rule can be trusted.
//
//  Each word carries its picture: for a four-year-old the picture *is* the
//  clue and the letters are the shape to find. Words are stored uppercase.
//

import Foundation

/// One entry in a sheet's WORDS TO FIND list.
struct WordSearchWord: Hashable, Sendable, Identifiable {
    let text: String
    let emoji: String
    var id: String { text }

    init(_ text: String, _ emoji: String) {
        self.text = text.uppercased()
        self.emoji = emoji
    }
}

/// Difficulty stage. The rules here are the spec's four tables verbatim:
/// grid sizes, word counts, word lengths, directions and intersection caps.
enum WordSearchStage: Int, CaseIterable, Codable, Sendable, Comparable {
    case seedling = 1   // ages 4–5, sheets 1–10
    case sprout   = 2   // ages 5–6, sheets 11–20
    case sapling  = 3   // ages 6–7, sheets 21–30
    case tree     = 4   // ages 6–7+, sheets 31–40

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Grid sizes allowed, smallest first — the generator takes the first
    /// that fits the longest word and is not more than 70% target letters.
    var gridSizes: [Int] {
        switch self {
        case .seedling: [5, 6]
        case .sprout: [6, 7]
        case .sapling: [7, 8]
        case .tree: [8, 9, 10]
        }
    }

    var wordCount: ClosedRange<Int> {
        switch self {
        case .seedling: 3...5
        case .sprout: 5...6
        case .sapling: 6...8
        case .tree: 7...10
        }
    }

    var wordLength: ClosedRange<Int> {
        switch self {
        case .seedling: 3...5
        case .sprout: 3...6
        case .sapling: 4...8
        case .tree: 4...10
        }
    }

    /// Directions a word may be laid in. Backwards only arrives at the
    /// last stage, and even there only for a couple of words per sheet.
    var directions: [WordSearchDirection] {
        switch self {
        case .seedling: [.right, .down]
        case .sprout: [.right, .down, .downRight]
        case .sapling: [.right, .down, .downRight, .upRight]
        case .tree: [.right, .down, .downRight, .upRight, .left, .up]
        }
    }

    /// How many words per sheet may run backwards (left or up).
    var maximumBackwardsWords: Int { self == .tree ? 2 : 0 }

    /// Total shared letters allowed across the whole sheet.
    var maximumIntersections: Int {
        switch self {
        case .seedling: 1
        case .sprout: 3
        case .sapling: 4
        case .tree: 4
        }
    }

    var localizedAges: String {
        switch self {
        case .seedling: String(localized: "Ages 4–5")
        case .sprout: String(localized: "Ages 5–6")
        case .sapling: String(localized: "Ages 6–7")
        case .tree: String(localized: "Ages 6–7+")
        }
    }

    /// The one-line instruction under the title, per the spec's §7.
    var localizedInstruction: String {
        switch self {
        case .seedling: String(localized: "Find the hidden words!")
        case .sprout: String(localized: "Drag across the letters!")
        case .sapling: String(localized: "Words can go across, down & diagonal!")
        case .tree: String(localized: "Some words hide backwards too!")
        }
    }
}

/// Where a word runs. Row/column deltas; `isBackwards` is what the last
/// stage rations.
enum WordSearchDirection: CaseIterable, Sendable, Hashable {
    case right, down, downRight, upRight, left, up, downLeft, upLeft

    var delta: (row: Int, column: Int) {
        switch self {
        case .right: (0, 1)
        case .down: (1, 0)
        case .downRight: (1, 1)
        case .upRight: (-1, 1)
        case .left: (0, -1)
        case .up: (-1, 0)
        case .downLeft: (1, -1)
        case .upLeft: (-1, -1)
        }
    }

    var isBackwards: Bool {
        switch self {
        case .left, .up, .downLeft, .upLeft: true
        default: false
        }
    }
}

/// Colour direction for a sheet — the art layer swaps in behind this.
enum WordSearchPalette: String, Codable, Sendable, CaseIterable {
    case meadow, farm, ocean, prehistoric, space, jungle, enchanted, city
    case beach, winter, autumn, tropical, savanna, arctic, mountain, robot
    case construction, railway, fantasy, cave, river, harvest, rescue, celebration
}

/// One worksheet.
struct WordSearchSheet: Hashable, Sendable, Identifiable {
    let number: Int
    let title: String
    /// The theme's own emoji, used as the map tile and mascot stand-in until
    /// the art for that sheet exists.
    let emoji: String
    let mascot: String
    let palette: WordSearchPalette
    let words: [WordSearchWord]

    var id: Int { number }

    var stage: WordSearchStage {
        switch number {
        case ...10: .seedling
        case 11...20: .sprout
        case 21...30: .sapling
        default: .tree
        }
    }
}

enum WordSearchWordBank {

    static let sheets: [WordSearchSheet] = [
        // MARK: Stage 1 — ages 4–5, horizontal and vertical only

        WordSearchSheet(number: 1, title: "Sunny Garden", emoji: "🌻", mascot: "🐰", palette: .meadow, words: [
            .init("SEED", "🌱"), .init("BUD", "🌷"), .init("HOSE", "🚿"), .init("WORM", "🪱"),
        ]),
        WordSearchSheet(number: 2, title: "Friendly Farm", emoji: "🚜", mascot: "🐄", palette: .farm, words: [
            .init("COW", "🐮"), .init("PIG", "🐷"), .init("HEN", "🐔"), .init("GOAT", "🐐"),
        ]),
        WordSearchSheet(number: 3, title: "Ocean Friends", emoji: "🐬", mascot: "🐬", palette: .ocean, words: [
            .init("CRAB", "🦀"), .init("SEAL", "🦭"), .init("FISH", "🐟"), .init("WHALE", "🐳"),
        ]),
        WordSearchSheet(number: 4, title: "Dinosaur Valley", emoji: "🦕", mascot: "🦕", palette: .prehistoric, words: [
            .init("EGG", "🥚"), .init("TAIL", "🦕"), .init("HORN", "🦏"), .init("ROAR", "🦖"),
        ]),
        WordSearchSheet(number: 5, title: "Space Adventure", emoji: "🚀", mascot: "👩‍🚀", palette: .space, words: [
            .init("SUN", "☀️"), .init("MOON", "🌙"), .init("COMET", "☄️"), .init("SKY", "🌌"),
        ]),
        WordSearchSheet(number: 6, title: "Jungle Explorer", emoji: "🌴", mascot: "🐵", palette: .jungle, words: [
            .init("APE", "🦍"), .init("VINE", "🌿"), .init("FROG", "🐸"), .init("SNAKE", "🐍"),
        ]),
        WordSearchSheet(number: 7, title: "Enchanted Forest", emoji: "🍄", mascot: "🦊", palette: .enchanted, words: [
            .init("OWL", "🦉"), .init("FOX", "🦊"), .init("DEER", "🦌"), .init("FAIRY", "🧚"),
        ]),
        WordSearchSheet(number: 8, title: "Busy City", emoji: "🏙️", mascot: "🚦", palette: .city, words: [
            .init("BUS", "🚌"), .init("TAXI", "🚕"), .init("SHOP", "🏪"), .init("ROAD", "🛣️"),
        ]),
        WordSearchSheet(number: 9, title: "Beach Day", emoji: "🏖️", mascot: "🦀", palette: .beach, words: [
            .init("SAND", "🏖️"), .init("SHELL", "🐚"), .init("PAIL", "🪣"), .init("KITE", "🪁"),
        ]),
        WordSearchSheet(number: 10, title: "Winter Wonderland", emoji: "⛄", mascot: "🐧", palette: .winter, words: [
            .init("SNOW", "❄️"), .init("SLED", "🛷"), .init("SCARF", "🧣"), .init("ICE", "🧊"),
        ]),

        // MARK: Stage 2 — ages 5–6, first diagonals

        WordSearchSheet(number: 11, title: "Spring Meadow", emoji: "🌷", mascot: "🐑", palette: .meadow, words: [
            .init("LAMB", "🐑"), .init("TULIP", "🌷"), .init("GRASS", "🌱"),
            .init("DAISY", "🌼"), .init("BUNNY", "🐰"), .init("BREEZE", "🍃"),
        ]),
        WordSearchSheet(number: 12, title: "Rainy Day", emoji: "🌧️", mascot: "🐸", palette: .ocean, words: [
            .init("CLOUD", "☁️"), .init("BOOT", "🥾"), .init("DRIP", "💧"),
            .init("PUDDLE", "🌧️"), .init("COAT", "🧥"), .init("SPLASH", "💦"),
        ]),
        WordSearchSheet(number: 13, title: "Autumn Park", emoji: "🍁", mascot: "🐿️", palette: .autumn, words: [
            .init("LEAF", "🍁"), .init("MAPLE", "🍁"), .init("RAKE", "🧹"),
            .init("WIND", "💨"), .init("APPLE", "🍎"), .init("BENCH", "🪑"),
        ]),
        WordSearchSheet(number: 14, title: "Tropical Island", emoji: "🏝️", mascot: "🦜", palette: .tropical, words: [
            .init("PALM", "🌴"), .init("TOUCAN", "🦜"), .init("MANGO", "🥭"),
            .init("HUT", "🛖"), .init("LAGOON", "🏝️"), .init("SURF", "🏄"),
        ]),
        WordSearchSheet(number: 15, title: "Safari Adventure", emoji: "🦁", mascot: "🦒", palette: .savanna, words: [
            .init("LION", "🦁"), .init("ZEBRA", "🦓"), .init("HIPPO", "🦛"),
            .init("JEEP", "🚙"), .init("RHINO", "🦏"), .init("MANE", "🦁"),
        ]),
        WordSearchSheet(number: 16, title: "Arctic Adventure", emoji: "🧊", mascot: "🐻‍❄️", palette: .arctic, words: [
            .init("WALRUS", "🦭"), .init("IGLOO", "🏠"), .init("ORCA", "🐋"),
            .init("MITTEN", "🧤"), .init("FROST", "❄️"), .init("SKATE", "⛸️"),
        ]),
        WordSearchSheet(number: 17, title: "Butterfly Garden", emoji: "🦋", mascot: "🦋", palette: .meadow, words: [
            .init("WING", "🦋"), .init("NECTAR", "🍯"), .init("PETAL", "🌸"),
            .init("LILY", "🌺"), .init("POLLEN", "🌼"), .init("COCOON", "🐛"),
        ]),
        WordSearchSheet(number: 18, title: "Bug Explorer", emoji: "🐞", mascot: "🐛", palette: .jungle, words: [
            .init("ANT", "🐜"), .init("SNAIL", "🐌"), .init("WEB", "🕸️"),
            .init("SPIDER", "🕷️"), .init("BEE", "🐝"), .init("MOTH", "🦋"),
        ]),
        WordSearchSheet(number: 19, title: "Bird Paradise", emoji: "🐦", mascot: "🦜", palette: .tropical, words: [
            .init("ROBIN", "🐦"), .init("NEST", "🪺"), .init("BEAK", "🐤"),
            .init("PERCH", "🌳"), .init("CHIRP", "🎵"), .init("FLOCK", "🐦‍⬛"),
        ]),
        WordSearchSheet(number: 20, title: "Woodland Camp", emoji: "⛺", mascot: "🦝", palette: .enchanted, words: [
            .init("TENT", "⛺"), .init("LOG", "🪵"), .init("PATH", "🥾"),
            .init("BADGE", "🎖️"), .init("TWIG", "🌿"), .init("EMBER", "🔥"),
        ]),

        // MARK: Stage 3 — ages 6–7, all forward directions

        WordSearchSheet(number: 21, title: "Mountain Adventure", emoji: "🏔️", mascot: "🐐", palette: .mountain, words: [
            .init("PEAK", "🏔️"), .init("HIKE", "🥾"), .init("TRAIL", "🪧"), .init("CLIMB", "🧗"),
            .init("CABIN", "🏡"), .init("EAGLE", "🦅"), .init("SUMMIT", "⛰️"),
        ]),
        WordSearchSheet(number: 22, title: "Underwater Adventure", emoji: "🐙", mascot: "🐙", palette: .ocean, words: [
            .init("OCTOPUS", "🐙"), .init("DOLPHIN", "🐬"), .init("SEAHORSE", "🐴"), .init("SQUID", "🦑"),
            .init("BUBBLE", "🫧"), .init("DIVER", "🤿"), .init("KELP", "🌿"),
        ]),
        WordSearchSheet(number: 23, title: "Coral Reef", emoji: "🪸", mascot: "🐠", palette: .ocean, words: [
            .init("CORAL", "🪸"), .init("ANEMONE", "🌸"), .init("TURTLE", "🐢"), .init("URCHIN", "🟣"),
            .init("CLAM", "🐚"), .init("SPONGE", "🧽"), .init("LOBSTER", "🦞"),
        ]),
        WordSearchSheet(number: 24, title: "Space Station", emoji: "🛰️", mascot: "🤖", palette: .space, words: [
            .init("ROCKET", "🚀"), .init("PLANET", "🪐"), .init("ORBIT", "🛰️"), .init("ALIEN", "👽"),
            .init("HELMET", "⛑️"), .init("LAUNCH", "🚀"), .init("GALAXY", "🌌"),
        ]),
        WordSearchSheet(number: 25, title: "Robot World", emoji: "🤖", mascot: "🤖", palette: .robot, words: [
            .init("ROBOT", "🤖"), .init("GEAR", "⚙️"), .init("WIRE", "🔌"), .init("BATTERY", "🔋"),
            .init("BUTTON", "🔘"), .init("SCREEN", "📺"), .init("MOTOR", "🔧"),
        ]),
        WordSearchSheet(number: 26, title: "Construction Zone", emoji: "🏗️", mascot: "👷", palette: .construction, words: [
            .init("CRANE", "🏗️"), .init("DIGGER", "🚜"), .init("HAMMER", "🔨"), .init("BRICK", "🧱"),
            .init("CEMENT", "🪣"), .init("LADDER", "🪜"), .init("DRILL", "🔩"),
        ]),
        WordSearchSheet(number: 27, title: "Train Adventure", emoji: "🚂", mascot: "🚂", palette: .railway, words: [
            .init("TRAIN", "🚂"), .init("TRACK", "🛤️"), .init("ENGINE", "🚂"), .init("TUNNEL", "🕳️"),
            .init("TICKET", "🎫"), .init("WHISTLE", "📯"), .init("STATION", "🚉"),
        ]),
        WordSearchSheet(number: 28, title: "Airport Adventure", emoji: "✈️", mascot: "🧑‍✈️", palette: .city, words: [
            .init("AIRPLANE", "✈️"), .init("PILOT", "🧑‍✈️"), .init("RUNWAY", "🛫"), .init("LUGGAGE", "🧳"),
            .init("TOWER", "🗼"), .init("TAKEOFF", "🛫"),
        ]),
        WordSearchSheet(number: 29, title: "Magical Castle", emoji: "🏰", mascot: "🧙", palette: .fantasy, words: [
            .init("CASTLE", "🏰"), .init("PRINCE", "🤴"), .init("CROWN", "👑"), .init("WIZARD", "🧙"),
            .init("THRONE", "🪑"), .init("MOAT", "🌊"), .init("UNICORN", "🦄"),
        ]),
        WordSearchSheet(number: 30, title: "Dragon Valley", emoji: "🐉", mascot: "🐲", palette: .fantasy, words: [
            .init("DRAGON", "🐉"), .init("FLAME", "🔥"), .init("SCALE", "🐲"), .init("CAVE", "🕳️"),
            .init("SMOKE", "💨"), .init("GLIDE", "🪁"), .init("SPIKE", "🦔"),
        ]),

        // MARK: Stage 4 — ages 6–7+, a couple of backwards words

        WordSearchSheet(number: 31, title: "Pirate Island", emoji: "🏴‍☠️", mascot: "🦜", palette: .beach, words: [
            .init("PIRATE", "🏴‍☠️"), .init("CAPTAIN", "🧑‍✈️"), .init("ANCHOR", "⚓"), .init("COMPASS", "🧭"),
            .init("SAIL", "⛵"), .init("DECK", "🚢"), .init("PLANK", "🪵"), .init("SPYGLASS", "🔭"),
        ]),
        WordSearchSheet(number: 32, title: "Treasure Cave", emoji: "💎", mascot: "🦇", palette: .cave, words: [
            .init("TREASURE", "💰"), .init("GOLD", "🥇"), .init("CHEST", "🧰"), .init("JEWEL", "💍"),
            .init("TORCH", "🔦"), .init("CRYSTAL", "🔮"), .init("DIAMOND", "💎"), .init("RUBY", "❤️"),
        ]),
        WordSearchSheet(number: 33, title: "Dinosaur Fossil Hunt", emoji: "🦴", mascot: "🦖", palette: .prehistoric, words: [
            .init("FOSSIL", "🦴"), .init("SKULL", "💀"), .init("STONE", "🪨"), .init("BRUSH", "🖌️"),
            .init("SHOVEL", "🪏"), .init("MUSEUM", "🏛️"), .init("FOOTPRINT", "🐾"), .init("BONE", "🦴"),
        ]),
        WordSearchSheet(number: 34, title: "Rainforest Adventure", emoji: "🦥", mascot: "🦥", palette: .jungle, words: [
            .init("SLOTH", "🦥"), .init("JAGUAR", "🐆"), .init("MONKEY", "🐒"), .init("ORCHID", "🌸"),
            .init("CANOPY", "🌳"), .init("MACAW", "🦜"), .init("LIZARD", "🦎"), .init("FERN", "🌿"),
        ]),
        WordSearchSheet(number: 35, title: "River Adventure", emoji: "🛶", mascot: "🦦", palette: .river, words: [
            .init("OTTER", "🦦"), .init("BEAVER", "🦫"), .init("TROUT", "🐟"), .init("CANOE", "🛶"),
            .init("PADDLE", "🏓"), .init("BRIDGE", "🌉"), .init("REED", "🌾"), .init("STREAM", "🏞️"),
        ]),
        WordSearchSheet(number: 36, title: "Farm Harvest", emoji: "🌾", mascot: "🐓", palette: .harvest, words: [
            .init("WHEAT", "🌾"), .init("TRACTOR", "🚜"), .init("PUMPKIN", "🎃"), .init("BARN", "🏚️"),
            .init("STRAW", "🌾"), .init("BASKET", "🧺"), .init("SCARECROW", "🎃"), .init("ORCHARD", "🍎"),
        ]),
        WordSearchSheet(number: 37, title: "Animal Rescue", emoji: "🐾", mascot: "🐶", palette: .rescue, words: [
            .init("RESCUE", "🚑"), .init("LEASH", "🦮"), .init("BANDAGE", "🩹"), .init("SHELTER", "🏠"),
            .init("PUPPY", "🐶"), .init("KITTEN", "🐱"), .init("BLANKET", "🛏️"), .init("MEDICINE", "💊"),
        ]),
        WordSearchSheet(number: 38, title: "World Explorer", emoji: "🌍", mascot: "🧭", palette: .mountain, words: [
            .init("PYRAMID", "🔺"), .init("GLOBE", "🌍"), .init("PASSPORT", "🛂"), .init("TEMPLE", "🛕"),
            .init("DESERT", "🏜️"), .init("VOLCANO", "🌋"), .init("JOURNEY", "🗺️"), .init("BACKPACK", "🎒"),
        ]),
        WordSearchSheet(number: 39, title: "Nature Discovery", emoji: "🔍", mascot: "🦔", palette: .enchanted, words: [
            .init("BINOCULARS", "🔭"), .init("NOTEBOOK", "📓"), .init("PEBBLE", "🪨"), .init("FEATHER", "🪶"),
            .init("MUSHROOM", "🍄"), .init("POND", "🐸"), .init("RAINBOW", "🌈"), .init("INSECT", "🐞"),
        ]),
        WordSearchSheet(number: 40, title: "Big Adventure", emoji: "🎉", mascot: "🐰", palette: .celebration, words: [
            .init("ADVENTURE", "🗺️"), .init("EXPLORE", "🧭"), .init("BALLOON", "🎈"), .init("PICNIC", "🧺"),
            .init("PARADE", "🎺"), .init("FRIEND", "🤝"), .init("CELEBRATE", "🎉"), .init("TROPHY", "🏆"),
        ]),
    ]

    static func sheet(number: Int) -> WordSearchSheet? {
        sheets.first { $0.number == number }
    }

    static var count: Int { sheets.count }

    // MARK: Uniqueness

    /// Every target word in the campaign, in sheet order.
    static var allWords: [String] { sheets.flatMap { $0.words.map(\.text) } }

    /// The root a word is compared by. Plurals and the obvious endings
    /// collapse so BUTTERFLY and BUTTERFLIES count as the same word.
    static func stem(_ word: String) -> String {
        let upper = word.uppercased()
        for (suffix, replacement) in [("IES", "Y"), ("ING", ""), ("ES", ""), ("ED", ""), ("S", "")]
        where upper.hasSuffix(suffix) && upper.count - suffix.count >= 3 {
            return String(upper.dropLast(suffix.count)) + replacement
        }
        return upper
    }

    /// Pairs of words that break the zero-repetition rule: same stem, or one
    /// hiding inside the other. Empty is the only acceptable answer, and the
    /// test asserts it.
    static func collisions() -> [(String, String)] {
        let words = allWords
        var found: [(String, String)] = []
        for i in words.indices {
            for j in words.indices where j > i {
                let a = words[i], b = words[j]
                if a == b || stem(a) == stem(b) || a.contains(b) || b.contains(a) {
                    found.append((a, b))
                }
            }
        }
        return found
    }
}
