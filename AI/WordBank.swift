//
//  WordBank.swift
//  Focus Forest Adventure
//
//  Age-5 word bank for the ABC adventure: 350+ unique 3–4 letter words a
//  five-year-old can read. Targets never repeat until the whole bank has
//  been used once (then a fresh lap starts).
//
//  Curation rules: concrete, positive, everyday words — animals, food,
//  nature, home, actions, feelings, family. Nothing violent, scary, or
//  adult. Every word is 3–4 lowercase letters (enforced by unit tests).
//

import Foundation

enum WordBank {

    static let allWords: [String] = [
        "cat", "dog", "fox", "pig", "cow", "hen", "bee", "ant", "owl", "bat", "rat", "bug",
        "frog", "bird", "duck", "bear", "lion", "wolf", "deer", "goat", "crab", "seal", "swan", "toad",
        "mole", "hare", "lamb", "foal", "pony", "mule", "hawk", "dove", "wren", "colt", "carp", "moth",
        "worm", "slug", "arm", "leg", "ear", "eye", "lip", "toe", "rib", "hip", "jaw", "chin",
        "knee", "heel", "palm", "nose", "hand", "foot", "hair", "back", "neck", "face", "skin", "brow",
        "shin", "jam", "pie", "egg", "ham", "bun", "tea", "milk", "cake", "rice", "corn", "bean",
        "pear", "plum", "lime", "kiwi", "fig", "oat", "chip", "mint", "pea", "yam", "nut", "soup",
        "taco", "stew", "roll", "date", "sun", "sky", "sea", "ice", "mud", "log", "twig",
        "leaf", "tree", "rain", "snow", "star", "moon", "rock", "sand", "wave", "pond", "lake", "hill",
        "cave", "dew", "fog", "wind", "rose", "seed", "root", "stem", "fern", "moss", "reef", "bay",
        "cove", "dirt", "soil", "vine", "wood", "bark", "nest", "hive", "bed", "cup", "pan", "pot",
        "lid", "mop", "map", "key", "pen", "box", "fan", "rug", "mat", "jar", "can", "bag",
        "hat", "cap", "sock", "shoe", "coat", "vest", "belt", "ring", "lamp", "door", "desk", "sofa",
        "oven", "sink", "tub", "soap", "comb", "fork", "bowl", "dish", "crib", "toy", "kite", "ball",
        "doll", "drum", "bell", "book", "page", "card", "gift", "flag", "tent", "rope", "net", "hook",
        "clip", "glue", "tape", "pail", "vase", "car", "bus", "van", "jet", "ship", "boat", "bike",
        "sled", "cart", "taxi", "tram", "cab", "run", "hop", "sit", "nap", "eat", "sip", "mix",
        "dig", "rub", "pat", "tap", "clap", "jump", "swim", "skip", "walk", "ride", "sing", "play",
        "read", "draw", "hug", "gulp", "yawn", "peek", "hide", "seek", "grow", "glow", "snap", "wash",
        "bake", "cook", "help", "give", "take", "pull", "push", "lift", "drop", "toss", "kick", "spin",
        "flip", "leap", "dash", "zoom", "look", "talk", "wink", "chew", "lick", "blow", "row", "tug",
        "wag", "zip", "fix", "win", "try", "ask", "say", "see", "mail", "rest", "big", "red",
        "hot", "wet", "dry", "fun", "new", "old", "shy", "tiny", "cute", "cool", "warm", "cold",
        "soft", "hard", "tall", "long", "fast", "slow", "kind", "nice", "good", "glad", "busy", "calm",
        "neat", "tidy", "wild", "blue", "pink", "teal", "gray", "gold", "tan", "navy", "mom", "dad",
        "kid", "boy", "girl", "twin", "baby", "nana", "papa", "aunt", "hero", "chef", "vet", "zoo",
        "park", "farm", "barn", "yard", "road", "path", "gate", "wall", "roof", "room", "hall", "city",
        "town", "shop", "cafe", "pool", "gym", "game", "song", "tune", "band", "note", "math", "word",
        "name", "home", "step", "moo", "baa", "woof", "meow", "roar", "purr", "hoot", "buzz", "peep",
        "oink", "dawn", "dusk", "noon", "week", "year", "day", "time", "hour"
    ]

    /// Draw `count` target words the child hasn't seen. "Never repeat" holds
    /// for a full lap of the bank; once too few unseen words remain, the lap
    /// resets and everything becomes available again.
    static func drawTargets(count: Int, excluding used: Set<String>) -> [String] {
        var unseen = allWords.filter { !used.contains($0) }
        if unseen.count < count { unseen = allWords }
        return Array(unseen.shuffled().prefix(count))
    }

    /// Decoy words for one question. Distractors may repeat across questions
    /// — only TARGETS are non-repeating.
    static func distractors(for target: String, count: Int) -> [String] {
        Array(allWords.filter { $0 != target }.shuffled().prefix(count))
    }

    /// Picture shown when the child finds the word. Emoji keeps the app
    /// asset-free; unmapped words fall back to a friendly star.
    static func emoji(for word: String) -> String {
        emojiByWord[word] ?? "🌟"
    }

    private static let emojiByWord: [String: String] = [
        // animals
        "cat": "🐱", "dog": "🐶", "fox": "🦊", "pig": "🐷", "cow": "🐮", "hen": "🐔",
        "bee": "🐝", "ant": "🐜", "owl": "🦉", "bat": "🦇", "rat": "🐀", "bug": "🐛",
        "frog": "🐸", "bird": "🐦", "duck": "🦆", "bear": "🐻", "lion": "🦁", "wolf": "🐺",
        "deer": "🦌", "goat": "🐐", "crab": "🦀", "seal": "🦭", "swan": "🦢", "toad": "🐸",
        "hare": "🐇", "lamb": "🐑", "foal": "🐴", "pony": "🐴", "hawk": "🦅", "dove": "🕊️",
        "wren": "🐦", "colt": "🐴", "carp": "🐟", "worm": "🪱", "slug": "🐌", "mole": "🐭",
        "moth": "🦋", "mule": "🐴",
        // body
        "arm": "💪", "leg": "🦵", "ear": "👂", "eye": "👁️", "lip": "👄", "toe": "🦶",
        "knee": "🦵", "heel": "🦶", "palm": "🖐️", "nose": "👃", "hand": "✋", "foot": "🦶",
        "face": "🙂", "hair": "👱",
        // food
        "jam": "🍓", "pie": "🥧", "egg": "🥚", "ham": "🍖", "bun": "🍞", "tea": "🍵",
        "milk": "🥛", "cake": "🍰", "rice": "🍚", "corn": "🌽", "bean": "🫘", "pear": "🍐",
        "kiwi": "🥝", "oat": "🌾", "chip": "🍟", "mint": "🌿", "pea": "🫛", "yam": "🍠",
        "nut": "🥜", "soup": "🍲", "taco": "🌮", "stew": "🍲", "roll": "🥐",
        // nature
        "sun": "☀️", "sky": "🌤️", "sea": "🌊", "ice": "🧊", "log": "🪵", "leaf": "🍃",
        "tree": "🌳", "rain": "🌧️", "snow": "❄️", "star": "⭐", "moon": "🌙", "rock": "🪨",
        "sand": "🏖️", "wave": "🌊", "lake": "🏞️", "hill": "⛰️", "dew": "💧", "fog": "🌫️",
        "wind": "💨", "rose": "🌹", "seed": "🌱", "root": "🌱", "stem": "🌿", "fern": "🌿",
        "moss": "🌿", "reef": "🪸", "vine": "🌿", "wood": "🪵", "bark": "🪵", "nest": "🪺",
        "hive": "🐝",
        // home & objects
        "bed": "🛏️", "cup": "🥤", "pan": "🍳", "pot": "🍲", "mop": "🧹", "map": "🗺️",
        "key": "🔑", "pen": "🖊️", "box": "📦", "jar": "🫙", "can": "🥫", "bag": "👜",
        "hat": "🎩", "cap": "🧢", "sock": "🧦", "shoe": "👟", "coat": "🧥", "vest": "🦺",
        "ring": "💍", "lamp": "💡", "door": "🚪", "sofa": "🛋️", "tub": "🛁", "soap": "🧼",
        "fork": "🍴", "bowl": "🥣", "dish": "🍽️", "toy": "🧸", "kite": "🪁", "ball": "⚽",
        "doll": "🪆", "drum": "🥁", "bell": "🔔", "book": "📖", "page": "📄", "gift": "🎁",
        "flag": "🚩", "tent": "⛺", "rope": "🪢", "net": "🥅", "hook": "🪝", "clip": "📎",
        "pail": "🪣", "vase": "🏺",
        // vehicles
        "car": "🚗", "bus": "🚌", "van": "🚐", "jet": "✈️", "ship": "🚢", "boat": "⛵",
        "bike": "🚲", "sled": "🛷", "cart": "🛒", "taxi": "🚕", "tram": "🚋", "cab": "🚕",
        // actions
        "run": "🏃", "hop": "🐇", "sit": "🪑", "nap": "😴", "eat": "🍽️", "sip": "🥤",
        "mix": "🥣", "tap": "👆", "clap": "👏", "jump": "🤸", "swim": "🏊", "walk": "🚶",
        "ride": "🚴", "sing": "🎤", "play": "🎈", "read": "📖", "draw": "🖍️", "hug": "🤗",
        "yawn": "🥱", "peek": "👀", "hide": "🙈", "seek": "🔍", "grow": "🌱", "glow": "✨",
        "wash": "🧼", "bake": "🧁", "cook": "🍳", "help": "🤝", "give": "🎁", "lift": "🏋️",
        "drop": "💧", "spin": "🌀", "flip": "🤸", "dash": "🏃", "zoom": "🚀", "look": "👀",
        "talk": "💬", "wink": "😉", "blow": "💨", "row": "🚣", "wag": "🐕", "fix": "🔧",
        "win": "🏆", "say": "💬", "see": "👀", "mail": "📬", "rest": "😴", "kick": "⚽",
        // describing words
        "big": "🐘", "red": "🔴", "hot": "🔥", "wet": "💧", "dry": "🌵", "fun": "🎉",
        "new": "✨", "tiny": "🐭", "cute": "🥰", "cool": "😎", "cold": "🥶", "soft": "☁️",
        "hard": "🪨", "tall": "🦒", "long": "🐍", "fast": "⚡", "slow": "🐢", "nice": "😊",
        "good": "👍", "glad": "😄", "busy": "🐝", "calm": "😌", "wild": "🦁", "blue": "🔵",
        "pink": "🩷", "gold": "🥇", "warm": "☀️",
        // people
        "mom": "👩", "dad": "👨", "kid": "🧒", "boy": "👦", "girl": "👧", "twin": "👯",
        "baby": "👶", "nana": "👵", "papa": "👴", "hero": "🦸", "chef": "👨‍🍳", "vet": "🩺",
        // places & things
        "zoo": "🦓", "park": "🌳", "farm": "🚜", "road": "🛣️", "wall": "🧱", "roof": "🏠",
        "city": "🏙️", "town": "🏘️", "shop": "🏪", "cafe": "☕", "pool": "🏊", "gym": "🏋️",
        "game": "🎲", "song": "🎵", "tune": "🎶", "band": "🥁", "note": "🎵", "math": "➕",
        "home": "🏠", "step": "🪜", "barn": "🚜",
        // sounds
        "moo": "🐮", "baa": "🐑", "woof": "🐶", "meow": "🐱", "roar": "🦁", "purr": "🐱",
        "hoot": "🦉", "buzz": "🐝", "peep": "🐤", "oink": "🐷",
        // time
        "dawn": "🌅", "dusk": "🌆", "noon": "☀️", "week": "📅", "year": "📅", "day": "🌞",
        "time": "⏰", "hour": "⏰"
    ]
}
