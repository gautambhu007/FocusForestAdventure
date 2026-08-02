//
//  BrainlandStory.swift
//  Focus Forest Adventure
//
//  The Puzzle Adventure World script: the kingdom of Brainland, the Shadow
//  Wizard who stole the Crystal of Wisdom, and the nine worlds a Young
//  Explorer restores.
//
//  Everything here is hand-written and offline — same rule as the Bunny
//  assistant (see ARCHITECTURE 4b). There is no generated prose anywhere in
//  the app, so a child can never be told something unreviewed.
//
//  A chapter is the join between story and mechanics: "Hidden Acorns" is the
//  story name, `.hiddenObject` is the rule that generates it. Adding a
//  chapter is a data edit, not a code change.
//

import Foundation

// MARK: - Cast

struct StoryCharacter: Hashable, Sendable, Identifiable {
    let id: String
    let emoji: String
    let name: String
    /// Said when the world opens.
    let greeting: String
    /// Said when a level starts.
    let cheer: String

    var spokenIntroduction: String { "\(name). \(greeting)" }
}

// MARK: - Chapters

/// One named level in a world. `kind` is the generator recipe behind it.
struct StoryChapter: Hashable, Sendable, Identifiable {
    /// Stable key: "forest.leafPattern".
    let id: String
    let title: String
    let kind: PuzzleKind
    /// One line of story shown on the card before the level starts.
    let blurb: String
}

// MARK: - Worlds

struct WorldStory: Hashable, Sendable {
    let world: PuzzleWorld
    /// What has gone wrong here.
    let premise: String
    /// What the child is being asked to do about it.
    let quest: String
    let characters: [StoryCharacter]
    let chapters: [StoryChapter]
    let bossTitle: String
    let bossPremise: String
    let crystal: MagicCrystal
    /// Said once the boss falls and the crystal is won.
    let victory: String

    /// Pictures this world's puzzles are drawn from. Rules that depend on
    /// color use tintable shapes instead (see `PuzzleKind.needsTintableShapes`).
    let motifs: [PuzzleMotif]

    func chapter(forLevel level: Int) -> StoryChapter? {
        guard level >= 1, level <= chapters.count else { return nil }
        return chapters[level - 1]
    }

    func character(forLevel level: Int) -> StoryCharacter? {
        guard !characters.isEmpty else { return nil }
        return characters[(max(level, 1) - 1) % characters.count]
    }
}

// MARK: - The script

enum BrainlandStory {

    /// Told once, the first time a child opens Puzzle Adventure World.
    static let prologue = String(localized: """
        Brainland is losing its colors! The Shadow Wizard has stolen the \
        Crystal of Wisdom and hidden its magic across nine worlds. \
        You are the Young Explorer — solve the puzzles, win back every \
        crystal, and bring the colors home.
        """)

    static let epilogue = String(localized: """
        Every crystal is shining! The Rainbow Castle glows again, the Shadow \
        Wizard fades away, and Brainland bursts back into color. \
        You are the Master Puzzle Explorer!
        """)

    /// The crystal the child is ultimately restoring.
    static let crystalOfWisdom = String(localized: "Crystal of Wisdom")

    static func story(for world: PuzzleWorld) -> WorldStory {
        switch world {
        case .forest: forest
        case .pirate: pirate
        case .space: space
        case .castle: castle
        case .dinosaur: dinosaur
        case .ocean: ocean
        case .ice: ice
        case .volcano: volcano
        case .rainbow: rainbow
        }
    }

    /// Crystals that power the Rainbow Castle. The Volcano Lab is a bonus
    /// world, so its crystal is a trophy rather than a key.
    static var keyCrystals: [MagicCrystal] {
        PuzzleWorld.allCases
            .filter { $0 != .rainbow && $0 != .volcano }
            .map { story(for: $0).crystal }
    }

    // MARK: World 1 — Forest of Patterns

    private static let forest = WorldStory(
        world: .forest,
        premise: String(localized: "The forest animals have forgotten their patterns, and the leaves are turning grey."),
        quest: String(localized: "Help Sammy and his friends remember, and the colors will come back."),
        characters: [
            StoryCharacter(id: "sammy", emoji: "🐿", name: String(localized: "Sammy Squirrel"),
                           greeting: String(localized: "My acorns are all muddled up! Will you help me?"),
                           cheer: String(localized: "You're so good at this!")),
            StoryCharacter(id: "fiona", emoji: "🦊", name: String(localized: "Fiona Fox"),
                           greeting: String(localized: "I know every path in this forest — but not this puzzle!"),
                           cheer: String(localized: "Clever, clever!")),
            StoryCharacter(id: "benny", emoji: "🐰", name: String(localized: "Benny Rabbit"),
                           greeting: String(localized: "Hop hop! Let's fix the flowers together."),
                           cheer: String(localized: "Hooray! Hop hop!")),
            StoryCharacter(id: "oliver", emoji: "🦉", name: String(localized: "Oliver Owl"),
                           greeting: String(localized: "Whoo is ready to think? You are!"),
                           cheer: String(localized: "Very wise indeed."))
        ],
        chapters: [
            StoryChapter(id: "forest.leaf", title: String(localized: "Leaf Pattern"), kind: .completePattern,
                         blurb: String(localized: "The falling leaves lost their order.")),
            StoryChapter(id: "forest.flowers", title: String(localized: "Flower Colors"), kind: .missingColor,
                         blurb: String(localized: "One flower forgot which color it was.")),
            StoryChapter(id: "forest.tracks", title: String(localized: "Animal Tracks"), kind: .matchTheShape,
                         blurb: String(localized: "Whose footprints are these?")),
            StoryChapter(id: "forest.tree", title: String(localized: "Complete the Tree"), kind: .continueSequence,
                         blurb: String(localized: "The old oak is missing a branch of leaves.")),
            StoryChapter(id: "forest.butterfly", title: String(localized: "Butterfly Wings"), kind: .buildSymmetry,
                         blurb: String(localized: "A butterfly needs both wings to match.")),
            StoryChapter(id: "forest.acorns", title: String(localized: "Hidden Acorns"), kind: .hiddenObject,
                         blurb: String(localized: "Sammy hid his acorns — find every one!")),
            StoryChapter(id: "forest.mushrooms", title: String(localized: "Mushroom Sorting"), kind: .oddOneOut,
                         blurb: String(localized: "One mushroom doesn't belong in this patch.")),
            StoryChapter(id: "forest.river", title: String(localized: "River Crossing"), kind: .maze,
                         blurb: String(localized: "Hop the safe stones — don't fall in the water!")),
            StoryChapter(id: "forest.nest", title: String(localized: "Bird Nest Puzzle"), kind: .sameOrDifferent,
                         blurb: String(localized: "Are these two eggs from the same nest?")),
            StoryChapter(id: "forest.rainbow", title: String(localized: "Rainbow Builder"), kind: .missingColor,
                         blurb: String(localized: "The forest rainbow lost one of its stripes."))
        ],
        bossTitle: String(localized: "The Tree of Knowledge"),
        bossPremise: String(localized: "The great Tree of Knowledge has gone grey. Solve its puzzles and it will bloom again!"),
        crystal: MagicCrystal(world: .forest, emoji: "🌿", localizedName: String(localized: "Green Crystal")),
        victory: String(localized: "The tree bursts into green! Sammy hands you the Green Crystal."),
        motifs: [
            .picture("🍃", name: String(localized: "leaf")),
            .picture("🍂", name: String(localized: "brown leaf")),
            .picture("🌰", name: String(localized: "acorn")),
            .picture("🍄", name: String(localized: "mushroom")),
            .picture("🌸", name: String(localized: "flower")),
            .picture("🐿", name: String(localized: "squirrel")),
            .picture("🦊", name: String(localized: "fox")),
            .picture("🐰", name: String(localized: "rabbit")),
            .picture("🦉", name: String(localized: "owl")),
            .picture("🦋", name: String(localized: "butterfly"))
        ]
    )

    // MARK: World 2 — Pirate Island

    private static let pirate = WorldStory(
        world: .pirate,
        premise: String(localized: "Captain Compass has lost the treasure map — the pieces blew all over the island."),
        quest: String(localized: "Rebuild the map and find the golden treasure."),
        characters: [
            StoryCharacter(id: "compass", emoji: "🏴", name: String(localized: "Captain Compass"),
                           greeting: String(localized: "Ahoy, explorer! Me map is in pieces!"),
                           cheer: String(localized: "Well sailed, matey!")),
            StoryCharacter(id: "polly", emoji: "🦜", name: String(localized: "Polly"),
                           greeting: String(localized: "Squawk! Puzzle time! Puzzle time!"),
                           cheer: String(localized: "Squawk! Brilliant!")),
            StoryCharacter(id: "shellby", emoji: "🐢", name: String(localized: "Shellby"),
                           greeting: String(localized: "Slow and steady solves the puzzle."),
                           cheer: String(localized: "Steady as she goes!"))
        ],
        chapters: [
            StoryChapter(id: "pirate.maze", title: String(localized: "Treasure Maze"), kind: .maze,
                         blurb: String(localized: "Follow the map to the X, around the waves.")),
            StoryChapter(id: "pirate.compass", title: String(localized: "Compass Directions"), kind: .rotateShape,
                         blurb: String(localized: "Which way does the needle point next?")),
            StoryChapter(id: "pirate.findx", title: String(localized: "Find the X"), kind: .oddOneOut,
                         blurb: String(localized: "One mark on the sand isn't like the others.")),
            StoryChapter(id: "pirate.ship", title: String(localized: "Move the Ship"), kind: .continueSequence,
                         blurb: String(localized: "Keep the ship sailing in order.")),
            StoryChapter(id: "pirate.islandmap", title: String(localized: "Island Map"), kind: .matchTheShape,
                         blurb: String(localized: "Match the island to its shape on the map.")),
            StoryChapter(id: "pirate.bridge", title: String(localized: "Bridge Building"), kind: .assemble,
                         blurb: String(localized: "Lay every plank where it belongs.")),
            StoryChapter(id: "pirate.cannon", title: String(localized: "Cannon Path"), kind: .rotateShape,
                         blurb: String(localized: "Turn the cannon the right way.")),
            StoryChapter(id: "pirate.key", title: String(localized: "Key and Lock"), kind: .matchTheShape,
                         blurb: String(localized: "Which key fits the treasure chest?")),
            StoryChapter(id: "pirate.sequence", title: String(localized: "Treasure Sequence"), kind: .continueSequence,
                         blurb: String(localized: "The coins were buried in a pattern.")),
            StoryChapter(id: "pirate.flag", title: String(localized: "Pirate Flag Matching"), kind: .sameOrDifferent,
                         blurb: String(localized: "Do these two flags belong to the same crew?"))
        ],
        bossTitle: String(localized: "The Golden Treasure"),
        bossPremise: String(localized: "X marks the spot at last! Solve the chest's locks to open it."),
        crystal: MagicCrystal(world: .pirate, emoji: "🏆", localizedName: String(localized: "Gold Crystal")),
        victory: String(localized: "The chest creaks open — the Gold Crystal is yours!"),
        motifs: [
            .picture("🗺", name: String(localized: "map")),
            .picture("⚓️", name: String(localized: "anchor")),
            .picture("🏴", name: String(localized: "flag")),
            .picture("🦜", name: String(localized: "parrot")),
            .picture("🐢", name: String(localized: "turtle")),
            .picture("💰", name: String(localized: "treasure")),
            .picture("🧭", name: String(localized: "compass")),
            .picture("🔑", name: String(localized: "key")),
            .picture("⛵️", name: String(localized: "ship")),
            .picture("🪙", name: String(localized: "coin"))
        ]
    )

    // MARK: World 3 — Space Academy

    private static let space = WorldStory(
        world: .space,
        premise: String(localized: "Zog's spaceship broke apart on the way to Brainland."),
        quest: String(localized: "Help the crew put every piece back where it belongs."),
        characters: [
            StoryCharacter(id: "nova", emoji: "👨‍🚀", name: String(localized: "Nova"),
                           greeting: String(localized: "Welcome to Space Academy, cadet!"),
                           cheer: String(localized: "Stellar work!")),
            StoryCharacter(id: "pixel", emoji: "🤖", name: String(localized: "Pixel Robot"),
                           greeting: String(localized: "Beep boop. Puzzle detected. Help required."),
                           cheer: String(localized: "Beep! Correct!")),
            StoryCharacter(id: "zog", emoji: "👽", name: String(localized: "Zog"),
                           greeting: String(localized: "My ship! Can you help me fix it?"),
                           cheer: String(localized: "Zoggity zog! Yes!"))
        ],
        chapters: [
            StoryChapter(id: "space.rocket", title: String(localized: "Rotate the Rocket"), kind: .rotateShape,
                         blurb: String(localized: "The rocket must point the right way to launch.")),
            StoryChapter(id: "space.mirror", title: String(localized: "Mirror Planet"), kind: .mirrorPuzzle,
                         blurb: String(localized: "This planet reflects everything above it.")),
            StoryChapter(id: "space.satellite", title: String(localized: "Build the Satellite"), kind: .assemble,
                         blurb: String(localized: "Fit every panel back onto the satellite.")),
            StoryChapter(id: "space.constellation", title: String(localized: "Complete the Constellation"), kind: .completePattern,
                         blurb: String(localized: "A star fell out of the sky picture.")),
            StoryChapter(id: "space.sudoku", title: String(localized: "Space Sudoku"), kind: .visualSudoku,
                         blurb: String(localized: "No two lights the same in any row.")),
            StoryChapter(id: "space.symbols", title: String(localized: "Alien Symbols"), kind: .matchTheShape,
                         blurb: String(localized: "Zog's writing needs matching up.")),
            StoryChapter(id: "space.shaperotation", title: String(localized: "Shape Rotation"), kind: .blockRotation,
                         blurb: String(localized: "Turn the shape in your head.")),
            StoryChapter(id: "space.moon", title: String(localized: "Moon Landing"), kind: .maze,
                         blurb: String(localized: "Steer around the meteors to the landing pad.")),
            StoryChapter(id: "space.asteroid", title: String(localized: "Asteroid Path"), kind: .continueSequence,
                         blurb: String(localized: "The asteroids keep a steady rhythm.")),
            StoryChapter(id: "space.robot", title: String(localized: "Build the Robot"), kind: .assemble,
                         blurb: String(localized: "Pixel came apart — put the pieces back!"))
        ],
        bossTitle: String(localized: "Repair the Spaceship"),
        bossPremise: String(localized: "Every system at once! Fix them all and Zog can fly home."),
        crystal: MagicCrystal(world: .space, emoji: "🚀", localizedName: String(localized: "Blue Crystal")),
        victory: String(localized: "The engines roar to life! Zog gives you the Blue Crystal."),
        motifs: [
            .picture("🚀", name: String(localized: "rocket")),
            .picture("🛰", name: String(localized: "satellite")),
            .picture("👽", name: String(localized: "alien")),
            .picture("🤖", name: String(localized: "robot")),
            .picture("⭐️", name: String(localized: "star")),
            .picture("🌙", name: String(localized: "moon")),
            .picture("☄️", name: String(localized: "comet")),
            .picture("🪐", name: String(localized: "planet")),
            .picture("🔭", name: String(localized: "telescope")),
            .picture("🛸", name: String(localized: "flying saucer"))
        ]
    )

    // MARK: World 4 — Magic Castle

    private static let castle = WorldStory(
        world: .castle,
        premise: String(localized: "The castle's spells got scrambled and the doors won't open."),
        quest: String(localized: "Sort the magic out, one spell at a time."),
        characters: [
            StoryCharacter(id: "leo", emoji: "🧙", name: String(localized: "Wizard Leo"),
                           greeting: String(localized: "My spells are in a terrible tangle!"),
                           cheer: String(localized: "Magnificent magic!")),
            StoryCharacter(id: "luna", emoji: "🧚", name: String(localized: "Luna Fairy"),
                           greeting: String(localized: "Sparkle sparkle! Let's think this through."),
                           cheer: String(localized: "Sparkling work!")),
            StoryCharacter(id: "tiny", emoji: "🐉", name: String(localized: "Tiny Dragon"),
                           greeting: String(localized: "I'm small but I'm brave. Puzzle with me!"),
                           cheer: String(localized: "Rawr! You did it!"))
        ],
        chapters: [
            StoryChapter(id: "castle.potion", title: String(localized: "Magic Potion"), kind: .colorLogic,
                         blurb: String(localized: "Each ingredient turns a certain color.")),
            StoryChapter(id: "castle.spell", title: String(localized: "Spell Sequence"), kind: .continueSequence,
                         blurb: String(localized: "Say the spell in the right order.")),
            StoryChapter(id: "castle.doors", title: String(localized: "Castle Doors"), kind: .missingTile,
                         blurb: String(localized: "One door is missing from the hallway.")),
            StoryChapter(id: "castle.key", title: String(localized: "Hidden Key"), kind: .oddOneOut,
                         blurb: String(localized: "One of these isn't like the rest — that's the key.")),
            StoryChapter(id: "castle.colorlogic", title: String(localized: "Color Logic"), kind: .colorLogic,
                         blurb: String(localized: "Follow Leo's color rule exactly.")),
            StoryChapter(id: "castle.grid", title: String(localized: "Magic Grid"), kind: .patternMatrix,
                         blurb: String(localized: "The floor tiles follow a hidden order.")),
            StoryChapter(id: "castle.rune", title: String(localized: "Number Rune"), kind: .numberShape,
                         blurb: String(localized: "Each number carries its own rune.")),
            StoryChapter(id: "castle.mirror", title: String(localized: "Mirror Spell"), kind: .mirrorPuzzle,
                         blurb: String(localized: "The spell reflects itself.")),
            StoryChapter(id: "castle.maze", title: String(localized: "Wizard Maze"), kind: .maze,
                         blurb: String(localized: "Climb the tower without touching the fire.")),
            StoryChapter(id: "castle.chess", title: String(localized: "Chess Path"), kind: .patternMatrix,
                         blurb: String(localized: "Black, white, black — keep it going."))
        ],
        bossTitle: String(localized: "The Magic Gate"),
        bossPremise: String(localized: "The great gate needs every spell at once. You're ready!"),
        crystal: MagicCrystal(world: .castle, emoji: "✨", localizedName: String(localized: "Purple Crystal")),
        victory: String(localized: "The gate swings wide! Leo presents the Purple Crystal."),
        motifs: [
            .picture("🧙", name: String(localized: "wizard")),
            .picture("🧚", name: String(localized: "fairy")),
            .picture("🐉", name: String(localized: "dragon")),
            .picture("🔮", name: String(localized: "crystal ball")),
            .picture("🗝", name: String(localized: "key")),
            .picture("🕯", name: String(localized: "candle")),
            .picture("📜", name: String(localized: "scroll")),
            .picture("👑", name: String(localized: "crown")),
            .picture("⚗️", name: String(localized: "potion")),
            .picture("🛡", name: String(localized: "shield"))
        ]
    )

    // MARK: World 5 — Dinosaur Valley

    private static let dinosaur = WorldStory(
        world: .dinosaur,
        premise: String(localized: "The dinosaur eggs have gone missing from the valley nests."),
        quest: String(localized: "Track them down before the volcano rumbles again."),
        characters: [
            StoryCharacter(id: "rexy", emoji: "🦖", name: String(localized: "Rexy"),
                           greeting: String(localized: "ROAR! I mean… hello. Can you help?"),
                           cheer: String(localized: "ROAR! Excellent!")),
            StoryCharacter(id: "longneck", emoji: "🦕", name: String(localized: "Dot"),
                           greeting: String(localized: "I can see far, but I can't see the eggs!"),
                           cheer: String(localized: "You found it!")),
            StoryCharacter(id: "hatch", emoji: "🐣", name: String(localized: "Pip"),
                           greeting: String(localized: "Peep! I'm the first one hatched!"),
                           cheer: String(localized: "Peep peep! Yes!"))
        ],
        chapters: [
            StoryChapter(id: "dino.fossil", title: String(localized: "Fossil Match"), kind: .matchTheShape,
                         blurb: String(localized: "Which fossil fits this print?")),
            StoryChapter(id: "dino.eggs", title: String(localized: "Egg Sorting"), kind: .oddOneOut,
                         blurb: String(localized: "One egg came from a different nest.")),
            StoryChapter(id: "dino.find", title: String(localized: "Find the Dino"), kind: .hiddenObject,
                         blurb: String(localized: "Count how many are hiding here.")),
            StoryChapter(id: "dino.memory", title: String(localized: "Memory Cards"), kind: .memoryGrid,
                         blurb: String(localized: "Were those two the same?")),
            StoryChapter(id: "dino.bones", title: String(localized: "Hidden Bones"), kind: .hiddenObject,
                         blurb: String(localized: "How many bones in the dig site?")),
            StoryChapter(id: "dino.skeleton", title: String(localized: "Build the Skeleton"), kind: .assemble,
                         blurb: String(localized: "Every bone belongs somewhere. Find its place.")),
            StoryChapter(id: "dino.footprints", title: String(localized: "Footprints"), kind: .continueSequence,
                         blurb: String(localized: "Follow the tracks — what comes next?")),
            StoryChapter(id: "dino.size", title: String(localized: "Dinosaur Size"), kind: .growingSequence,
                         blurb: String(localized: "They line up from smallest to biggest.")),
            StoryChapter(id: "dino.volcano", title: String(localized: "Volcano Escape"), kind: .maze,
                         blurb: String(localized: "Run for it — mind the lava!")),
            StoryChapter(id: "dino.nest", title: String(localized: "Nest Builder"), kind: .assemble,
                         blurb: String(localized: "Every twig has its own spot in the nest."))
        ],
        bossTitle: String(localized: "Hatch the Baby Dinosaur"),
        bossPremise: String(localized: "The last egg is wobbling! Solve everything and meet the baby."),
        crystal: MagicCrystal(world: .dinosaur, emoji: "🦖", localizedName: String(localized: "Orange Crystal")),
        victory: String(localized: "Crack! A baby dinosaur peeps out, carrying the Orange Crystal."),
        motifs: [
            .picture("🦕", name: String(localized: "long-neck dinosaur")),
            .picture("🦖", name: String(localized: "t-rex")),
            .picture("🥚", name: String(localized: "egg")),
            .picture("🦴", name: String(localized: "bone")),
            .picture("🌋", name: String(localized: "volcano")),
            .picture("🌿", name: String(localized: "fern")),
            .picture("🐊", name: String(localized: "crocodile")),
            .picture("🪨", name: String(localized: "rock")),
            .picture("🐣", name: String(localized: "hatchling")),
            .picture("🦎", name: String(localized: "lizard"))
        ]
    )

    // MARK: World 6 — Ocean Kingdom

    private static let ocean = WorldStory(
        world: .ocean,
        premise: String(localized: "The reef has gone cloudy and the sea creatures can't find their homes."),
        quest: String(localized: "Sort the ocean out and bring the reef back to life."),
        characters: [
            StoryCharacter(id: "finn", emoji: "🐠", name: String(localized: "Finn"),
                           greeting: String(localized: "Everything's jumbled down here! Help?"),
                           cheer: String(localized: "Splash-tastic!")),
            StoryCharacter(id: "otto", emoji: "🐙", name: String(localized: "Otto"),
                           greeting: String(localized: "Eight arms and I still can't sort this!"),
                           cheer: String(localized: "Eight thumbs up!")),
            StoryCharacter(id: "dora", emoji: "🐬", name: String(localized: "Dora Dolphin"),
                           greeting: String(localized: "Click click! Swim along with me."),
                           cheer: String(localized: "Click click! Wonderful!"))
        ],
        chapters: [
            StoryChapter(id: "ocean.sort", title: String(localized: "Sort the Fish"), kind: .oddOneOut,
                         blurb: String(localized: "One fish swam into the wrong school.")),
            StoryChapter(id: "ocean.pearls", title: String(localized: "Find the Pearls"), kind: .hiddenObject,
                         blurb: String(localized: "Count the pearls in the oyster bed.")),
            StoryChapter(id: "ocean.coral", title: String(localized: "Coral Match"), kind: .matchTheShape,
                         blurb: String(localized: "Match the coral to its twin.")),
            StoryChapter(id: "ocean.pipe", title: String(localized: "Pipe Puzzle"), kind: .pipeConnect,
                         blurb: String(localized: "Turn the pipes so the water reaches the reef.")),
            StoryChapter(id: "ocean.dive", title: String(localized: "Treasure Dive"), kind: .continueSequence,
                         blurb: String(localized: "Dive down in the right order.")),
            StoryChapter(id: "ocean.submarine", title: String(localized: "Submarine Path"), kind: .maze,
                         blurb: String(localized: "Steer the submarine past the sharks.")),
            StoryChapter(id: "ocean.sudoku", title: String(localized: "Ocean Sudoku"), kind: .visualSudoku,
                         blurb: String(localized: "No creature twice in any row.")),
            StoryChapter(id: "ocean.shell", title: String(localized: "Shell Pattern"), kind: .completePattern,
                         blurb: String(localized: "The shells lie in a repeating line.")),
            StoryChapter(id: "ocean.memory", title: String(localized: "Sea Memory"), kind: .memoryGrid,
                         blurb: String(localized: "Same creature, or different?")),
            StoryChapter(id: "ocean.wave", title: String(localized: "Wave Logic"), kind: .ravenMatrix,
                         blurb: String(localized: "The waves follow two rules at once."))
        ],
        bossTitle: String(localized: "Restore the Coral Reef"),
        bossPremise: String(localized: "The whole reef at once — every creature is counting on you."),
        crystal: MagicCrystal(world: .ocean, emoji: "💙", localizedName: String(localized: "Aqua Crystal")),
        victory: String(localized: "Color floods back through the reef! Finn brings you the Aqua Crystal."),
        motifs: [
            .picture("🐠", name: String(localized: "fish")),
            .picture("🐟", name: String(localized: "blue fish")),
            .picture("🐙", name: String(localized: "octopus")),
            .picture("🦀", name: String(localized: "crab")),
            .picture("🐚", name: String(localized: "shell")),
            .picture("🪸", name: String(localized: "coral")),
            .picture("🐬", name: String(localized: "dolphin")),
            .picture("🦈", name: String(localized: "shark")),
            .picture("🐳", name: String(localized: "whale")),
            .picture("⭐️", name: String(localized: "starfish"))
        ]
    )

    // MARK: World 7 — Ice Mountain

    private static let ice = WorldStory(
        world: .ice,
        premise: String(localized: "Only master puzzle solvers can climb the frozen mountain."),
        quest: String(localized: "Climb to the Ice Palace, one clever step at a time."),
        characters: [
            StoryCharacter(id: "frost", emoji: "⛄️", name: String(localized: "Frosty"),
                           greeting: String(localized: "Brrr! Think fast to stay warm!"),
                           cheer: String(localized: "Ice work!")),
            StoryCharacter(id: "pingu", emoji: "🐧", name: String(localized: "Pip the Penguin"),
                           greeting: String(localized: "I'll slide ahead — you solve the way!"),
                           cheer: String(localized: "Whee! Correct!")),
            StoryCharacter(id: "deer", emoji: "🦌", name: String(localized: "Skye"),
                           greeting: String(localized: "The high paths are tricky. Ready?"),
                           cheer: String(localized: "Sure-footed!"))
        ],
        chapters: [
            StoryChapter(id: "ice.maze", title: String(localized: "Ice Maze"), kind: .maze,
                         blurb: String(localized: "Cross the ice without falling through a hole.")),
            StoryChapter(id: "ice.crystal", title: String(localized: "Crystal Rotation"), kind: .blockRotation,
                         blurb: String(localized: "The crystal is the same — just turned.")),
            StoryChapter(id: "ice.snowflake", title: String(localized: "Snowflake Symmetry"), kind: .buildSymmetry,
                         blurb: String(localized: "Every snowflake matches itself.")),
            StoryChapter(id: "ice.bridge", title: String(localized: "Bridge Puzzle"), kind: .growingSequence,
                         blurb: String(localized: "Each span is one longer than the last.")),
            StoryChapter(id: "ice.blocks", title: String(localized: "Frozen Blocks"), kind: .blockRotation,
                         blurb: String(localized: "Which block is the same one, turned around?")),
            StoryChapter(id: "ice.logic", title: String(localized: "Logic Grid"), kind: .ravenMatrix,
                         blurb: String(localized: "Row and column each have a rule.")),
            StoryChapter(id: "ice.sudoku", title: String(localized: "Ice Sudoku"), kind: .visualSudoku,
                         blurb: String(localized: "No repeats in any line.")),
            StoryChapter(id: "ice.hidden", title: String(localized: "Hidden Pattern"), kind: .memoryGrid,
                         blurb: String(localized: "The rule is hiding. Find it.")),
            StoryChapter(id: "ice.matrix", title: String(localized: "Sequence Matrix"), kind: .patternMatrix,
                         blurb: String(localized: "Read across, then down.")),
            StoryChapter(id: "ice.iq", title: String(localized: "Visual Puzzle"), kind: .ruleDiscovery,
                         blurb: String(localized: "Work out the secret before you answer."))
        ],
        bossTitle: String(localized: "Unlock the Ice Palace"),
        bossPremise: String(localized: "The palace gates test everything you know."),
        crystal: MagicCrystal(world: .ice, emoji: "❄️", localizedName: String(localized: "Diamond Crystal")),
        victory: String(localized: "The gates shine open — the Diamond Crystal is yours!"),
        motifs: [
            .picture("❄️", name: String(localized: "snowflake")),
            .picture("⛄️", name: String(localized: "snowman")),
            .picture("🧊", name: String(localized: "ice block")),
            .picture("🏔", name: String(localized: "mountain")),
            .picture("🐧", name: String(localized: "penguin")),
            .picture("💎", name: String(localized: "gem")),
            .picture("🦌", name: String(localized: "deer")),
            .picture("🎿", name: String(localized: "skis")),
            .picture("🛷", name: String(localized: "sled")),
            .picture("🌨", name: String(localized: "snow cloud"))
        ]
    )

    // MARK: World 8 — Volcano Lab (bonus)

    private static let volcano = WorldStory(
        world: .volcano,
        premise: String(localized: "The Volcano Lab is where the trickiest puzzles are invented."),
        quest: String(localized: "Two skills at once, every time. Only for brave explorers!"),
        characters: [
            StoryCharacter(id: "professor", emoji: "🧪", name: String(localized: "Professor Ember"),
                           greeting: String(localized: "Welcome to the lab! Mind the sparks."),
                           cheer: String(localized: "A fine experiment!")),
            StoryCharacter(id: "spark", emoji: "⚡️", name: String(localized: "Spark"),
                           greeting: String(localized: "Zap! Two puzzles in one. Ready?"),
                           cheer: String(localized: "Zap! Nailed it!"))
        ],
        chapters: [
            StoryChapter(id: "volcano.shapenumber", title: String(localized: "Shape and Number"), kind: .numberShape,
                         blurb: String(localized: "Numbers and pictures travel together.")),
            StoryChapter(id: "volcano.mazememory", title: String(localized: "Maze and Memory"), kind: .maze,
                         blurb: String(localized: "Plan the whole route before you move.")),
            StoryChapter(id: "volcano.logicrotation", title: String(localized: "Logic and Rotation"), kind: .blockRotation,
                         blurb: String(localized: "It turns — and it follows a rule.")),
            StoryChapter(id: "volcano.sequencedirection", title: String(localized: "Sequence and Direction"), kind: .continueSequence,
                         blurb: String(localized: "Order matters. So does which way.")),
            StoryChapter(id: "volcano.hiddencount", title: String(localized: "Hidden and Counting"), kind: .hiddenObject,
                         blurb: String(localized: "Find them all, then count them.")),
            StoryChapter(id: "volcano.rule", title: String(localized: "Secret Rule"), kind: .ruleDiscovery,
                         blurb: String(localized: "Two examples. One rule. Go.")),
            StoryChapter(id: "volcano.matrix", title: String(localized: "Double Rule Matrix"), kind: .ravenMatrix,
                         blurb: String(localized: "Shape from the row, color from the column.")),
            StoryChapter(id: "volcano.sudoku", title: String(localized: "Lab Sudoku"), kind: .visualSudoku,
                         blurb: String(localized: "Keep every line clean.")),
            StoryChapter(id: "volcano.growing", title: String(localized: "Growing Formula"), kind: .growingSequence,
                         blurb: String(localized: "Each row adds one more ingredient.")),
            StoryChapter(id: "volcano.color", title: String(localized: "Color Formula"), kind: .colorLogic,
                         blurb: String(localized: "Follow the lab's color code."))
        ],
        bossTitle: String(localized: "The Great Experiment"),
        bossPremise: String(localized: "Everything the lab can throw at you, all at once."),
        crystal: MagicCrystal(world: .volcano, emoji: "🌋", localizedName: String(localized: "Ember Crystal")),
        victory: String(localized: "The experiment works! Professor Ember awards the Ember Crystal."),
        motifs: [
            .picture("🌋", name: String(localized: "volcano")),
            .picture("🔥", name: String(localized: "fire")),
            .picture("🧪", name: String(localized: "test tube")),
            .picture("⚗️", name: String(localized: "flask")),
            .picture("💥", name: String(localized: "spark")),
            .picture("🪨", name: String(localized: "rock")),
            .picture("🔬", name: String(localized: "microscope")),
            .picture("⚡️", name: String(localized: "lightning")),
            .picture("🧫", name: String(localized: "dish")),
            .picture("☄️", name: String(localized: "meteor"))
        ]
    )

    // MARK: Final World — Rainbow Kingdom

    private static let rainbow = WorldStory(
        world: .rainbow,
        premise: String(localized: "All seven crystals are home, and the Rainbow Castle is glowing again."),
        quest: String(localized: "The Shadow Wizard wants one last contest — the Grand Puzzle Trial."),
        characters: [
            StoryCharacter(id: "shadow", emoji: "🌑", name: String(localized: "The Shadow Wizard"),
                           greeting: String(localized: "So. You made it. Let us see how clever you really are."),
                           cheer: String(localized: "…hmph. Not bad.")),
            StoryCharacter(id: "unicorn", emoji: "🦄", name: String(localized: "Iris"),
                           greeting: String(localized: "The whole kingdom is watching. You've got this!"),
                           cheer: String(localized: "The colors are coming back!"))
        ],
        chapters: [
            StoryChapter(id: "rainbow.trial1", title: String(localized: "Trial of Patterns"), kind: .completePattern,
                         blurb: String(localized: "The Forest's lesson, one more time.")),
            StoryChapter(id: "rainbow.trial2", title: String(localized: "Trial of Direction"), kind: .rotateShape,
                         blurb: String(localized: "The Captain's compass points the way.")),
            StoryChapter(id: "rainbow.trial3", title: String(localized: "Trial of Mirrors"), kind: .buildSymmetry,
                         blurb: String(localized: "Space Academy taught you this.")),
            StoryChapter(id: "rainbow.trial4", title: String(localized: "Trial of Logic"), kind: .ravenMatrix,
                         blurb: String(localized: "Two rules, like Wizard Leo's gate.")),
            StoryChapter(id: "rainbow.trial5", title: String(localized: "Trial of Secrets"), kind: .ruleDiscovery,
                         blurb: String(localized: "The last secret of Brainland."))
        ],
        bossTitle: String(localized: "The Grand Puzzle Trial"),
        bossPremise: String(localized: "Every world, every skill, one final challenge. For Brainland!"),
        crystal: MagicCrystal(world: .rainbow, emoji: "🌈", localizedName: String(localized: "Crystal of Wisdom")),
        victory: BrainlandStory.epilogue,
        motifs: [
            .picture("🌈", name: String(localized: "rainbow")),
            .picture("✨", name: String(localized: "sparkle")),
            .picture("💎", name: String(localized: "crystal")),
            .picture("🏰", name: String(localized: "castle")),
            .picture("🌟", name: String(localized: "star")),
            .picture("🦄", name: String(localized: "unicorn")),
            .picture("🎆", name: String(localized: "fireworks")),
            .picture("🎈", name: String(localized: "balloon")),
            .picture("🕊", name: String(localized: "dove")),
            .picture("🔆", name: String(localized: "sun"))
        ]
    )
}
