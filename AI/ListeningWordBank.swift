//
//  ListeningWordBank.swift
//  Focus Forest Adventure
//
//  Listening Corner · Word Explorer: a large browsable word list (2–5
//  lowercase letters, every real English 2-letter word plus curated 3–5
//  letter words) for tap-to-hear practice — ages 3–7. Unlike WordBank (the
//  age-5 ABC "find the word" quiz bank, strictly 3–4 letters with
//  non-repeating targets), this bank is for open browsing: no quiz, no
//  exclusion tracking, just "tap it, hear it."
//
//  Curation rules match WordBank: concrete, positive, everyday words.
//  Nothing violent, scary, or adult.
//

import Foundation

enum ListeningWordBank {

    static let allWords: [String] = [
        "am", "an", "as", "at", "be", "by", "do", "go", "he", "hi", "if", "in",
        "is", "it", "me", "my", "no", "of", "oh", "on", "or", "ox", "so", "to",
        "up", "us", "we", "ah", "ha", "um", "cat", "dog", "fox", "pig", "cow", "hen",
        "bee", "ant", "owl", "bat", "rat", "bug", "frog", "bird", "duck", "bear", "lion", "wolf",
        "deer", "goat", "crab", "seal", "swan", "toad", "mole", "hare", "lamb", "foal", "pony", "mule",
        "hawk", "dove", "wren", "colt", "carp", "moth", "worm", "slug", "newt", "lynx", "puma", "mouse",
        "camel", "zebra", "tiger", "horse", "sheep", "goose", "otter", "llama", "koala", "panda", "skunk", "shrew",
        "crane", "heron", "gecko", "viper", "cobra", "shark", "whale", "moose", "hyena", "eagle", "robin", "finch",
        "quail", "snake", "snail", "apple", "mango", "grape", "lemon", "peach", "melon", "berry", "olive", "onion",
        "beans", "wheat", "bread", "toast", "bagel", "pasta", "pizza", "salad", "sugar", "honey", "syrup", "gravy",
        "sauce", "spice", "curry", "broth", "cream", "fudge", "candy", "mints", "chips", "fries", "donut", "bacon",
        "steak", "roast", "chick", "fish", "clam", "shell", "squid", "algae", "kelp", "sun", "sky", "sea",
        "ice", "mud", "log", "leaf", "tree", "rain", "snow", "star", "moon", "rock", "sand", "wave",
        "pond", "lake", "hill", "cave", "dew", "fog", "wind", "rose", "seed", "root", "stem", "fern",
        "moss", "reef", "bay", "cove", "dirt", "soil", "vine", "wood", "bark", "nest", "hive", "cloud",
        "storm", "ocean", "river", "beach", "shore", "coast", "plain", "field", "grove", "marsh", "swamp", "glade",
        "cliff", "peak", "ridge", "bed", "cup", "pan", "pot", "lid", "mop", "map", "key", "pen",
        "box", "fan", "rug", "mat", "jar", "can", "bag", "hat", "cap", "sock", "shoe", "coat",
        "vest", "belt", "ring", "lamp", "door", "desk", "sofa", "oven", "sink", "tub", "soap", "comb",
        "fork", "bowl", "dish", "crib", "toy", "kite", "ball", "doll", "drum", "bell", "book", "page",
        "card", "gift", "flag", "tent", "rope", "net", "hook", "clip", "glue", "tape", "pail", "vase",
        "chair", "table", "couch", "rake", "hose", "broom", "brush", "towel", "plate", "spoon", "knife", "glass",
        "mug", "tray", "clock", "frame", "shelf", "car", "bus", "van", "jet", "ship", "boat", "bike",
        "sled", "cart", "taxi", "tram", "cab", "train", "truck", "plane", "wagon", "ferry", "canoe", "kayak",
        "run", "hop", "sit", "nap", "eat", "sip", "mix", "dig", "rub", "pat", "tap", "clap",
        "jump", "swim", "skip", "walk", "ride", "sing", "play", "read", "draw", "hug", "gulp", "yawn",
        "peek", "hide", "seek", "grow", "glow", "snap", "wash", "bake", "cook", "help", "give", "take",
        "pull", "push", "lift", "drop", "toss", "kick", "spin", "flip", "leap", "dash", "zoom", "look",
        "talk", "wink", "chew", "lick", "blow", "row", "tug", "wag", "zip", "fix", "win", "try",
        "ask", "say", "see", "mail", "rest", "jog", "trot", "climb", "crawl", "slide", "swing", "dance",
        "smile", "laugh", "cry", "cough", "sleep", "dream", "wake", "point", "catch", "throw", "carry", "chase",
        "clean", "paint", "color", "trace", "write", "count", "shout", "skate", "surf", "dive", "float", "sail",
        "fly", "march", "stomp", "big", "red", "hot", "wet", "dry", "fun", "new", "old", "shy",
        "tiny", "cute", "cool", "warm", "cold", "soft", "hard", "tall", "long", "fast", "slow", "kind",
        "nice", "good", "glad", "busy", "calm", "neat", "tidy", "wild", "blue", "pink", "teal", "gray",
        "gold", "tan", "navy", "loud", "quiet", "happy", "sad", "angry", "brave", "silly", "funny", "lucky",
        "messy", "shiny", "fuzzy", "round", "rough", "bumpy", "heavy", "light", "dark", "early", "late", "young",
        "proud", "mom", "dad", "kid", "boy", "girl", "twin", "baby", "nana", "papa", "aunt", "hero",
        "chef", "vet", "zoo", "uncle", "nurse", "pilot", "queen", "king", "fairy", "giant", "robot", "ghost",
        "park", "farm", "barn", "yard", "road", "path", "gate", "wall", "roof", "room", "hall", "city",
        "town", "shop", "cafe", "pool", "gym", "game", "song", "tune", "band", "note", "math", "word",
        "name", "home", "step", "cabin", "attic", "porch", "moo", "baa", "woof", "meow", "roar", "purr",
        "hoot", "buzz", "peep", "oink", "hiss", "quack", "cluck", "growl", "chirp", "tweet", "honk", "beep",
        "thud", "pop", "bang", "boom", "crash", "drip", "plop", "whir", "hum", "dawn", "dusk", "noon",
        "week", "year", "day", "time", "hour", "night", "today", "month", "one", "two", "six", "ten",
        "five", "four", "nine", "zero", "eight", "three", "seven", "dozen", "first", "third", "half", "whole",
        "pair", "black", "white", "brown", "green", "oval", "heart", "cross", "arrow", "bored", "tired", "eager",
        "jolly", "sunny", "windy", "foggy", "rainy", "snowy", "humid", "chalk", "paper", "ruler", "shirt", "pants",
        "socks", "shoes", "dress", "skirt", "jeans", "scarf", "drill", "saw", "screw", "nail", "bolt", "nut",
        "wire", "rugby", "milk", "juice", "soda", "water", "cocoa", "cider", "punch", "shake", "latte", "niece",
        "bloom", "piano", "drums", "flute", "cello", "banjo", "harp", "organ", "north", "south", "east", "west",
        "down", "left", "right", "near", "far", "high", "low", "above", "below", "front", "trout", "perch",
        "bass", "eel", "ray", "ling", "cod", "pike", "sole", "hake", "plum", "kiwi", "date", "fig",
        "lime", "pear", "corn", "peas", "rice", "oats", "nuts", "hut", "den", "lair", "grin", "nod",
        "shrug", "quick", "short", "wide", "deep", "thick", "thin", "fancy", "weak", "sleek", "all", "and",
        "any", "are", "but", "did", "for", "from", "get", "had", "has", "her", "him", "his",
        "how", "its", "let", "lot", "may", "not", "now", "off", "our", "out", "own", "put",
        "ran", "she", "the", "too", "use", "was", "way", "who", "why", "yes", "yet", "you",
        "your", "just", "been", "come", "does", "done", "each", "even", "find", "gave", "goes", "have",
        "here", "into", "keep", "knew", "know", "made", "make", "many", "more", "must", "need", "next",
        "once", "only", "over", "part", "said", "same", "seen", "show", "side", "some", "soon", "such",
        "tell", "than", "that", "them", "then", "they", "this", "thus", "told", "upon", "very", "want",
        "went", "were", "what", "when", "will", "wish", "with", "work", "zone", "blob", "bond", "bone",
        "boot", "bore", "born", "both", "bran", "brew", "brim", "brow", "buck", "bulb", "bump", "bunk",
        "bush", "bust", "cage", "calf", "call", "camp", "cane", "case", "cash", "chin", "chip", "chop",
        "clan", "claw", "clay", "coal", "coil", "cord", "cork", "cost", "crop", "crow", "curl", "daze",
        "deal", "dear", "deck", "dent", "dial", "dice", "dime", "dock", "dome", "dune", "dust", "ease",
        "edge", "else", "empty", "ever", "face", "fact", "fail", "fair", "fall", "fame", "feed", "feel",
        "felt", "fence", "film", "fine", "firm", "fist", "flat", "flee", "flex", "flow", "flux", "foam",
        "fold", "folk", "fond", "food", "fool", "foot", "form", "fort", "free", "full", "fume", "fund",
        "gain", "gaze", "germ", "goal", "golf", "gong", "gown", "grab", "grid", "grip", "gulf", "hand",
        "hang", "haze", "head", "heal", "heap", "hear", "heat", "herd", "hike", "hire", "hold", "hole",
        "holy", "hood", "hope", "horn", "host", "huge", "hull", "hunt", "hush", "icon", "idea", "idle",
        "inch", "iris", "item", "jazz", "joke", "junk", "keen", "keys", "kids", "kilt", "kiss", "knee",
        "knit", "knot", "lace", "lack", "lady", "land", "lane", "last", "lawn", "lead", "leak", "lean",
        "legs", "lens", "life", "like", "limb", "line", "link", "lips", "list", "load", "loaf", "loan",
        "lock", "loft", "logo", "lone", "loop", "lord", "lose", "love", "luck", "lull", "lump", "lung",
        "lure", "lush", "maid", "main", "male", "mall", "mask", "mast", "mate", "meal", "mean", "meat",
        "melt", "mend", "mesh", "mild", "mile", "mind", "mine", "mint", "mist", "mold", "mono", "mood",
        "most", "move", "myth", "neck", "news", "node", "none", "nose", "noun", "oath", "obey", "oboe",
        "odor", "okay", "omen", "open", "oral", "pace", "pack", "pact", "paid", "pain", "pale", "palm",
        "past", "pave", "peel", "peer", "perk", "pest", "pick", "pier", "pile", "pill", "pine", "pint",
        "pipe", "plan", "plot", "plow", "plug", "plus", "poem", "poet", "pole", "polo", "poor", "pork",
        "port", "pose", "post", "pour", "prep", "prey", "prod", "prop", "pump", "punt", "quill", "race",
        "raft", "rage", "rail", "rank", "rare", "rate", "rays", "real", "rich", "rig", "ripe", "rise",
        "roam", "rode", "role", "roll", "rows", "rule", "rush", "rust", "safe", "sake", "salt", "save",
        "scan", "seat", "seem", "self", "sell", "send", "sent", "shed", "shot", "shut", "sick", "sigh",
        "sign", "silk", "site", "skin", "slap", "slid", "slim", "snip", "sort", "soul", "soup", "sour",
        "spot", "spun", "stay", "stew", "stir", "stop", "stow", "stub", "suit", "sung", "swap", "tack",
        "tail", "tale", "tame", "tank", "task", "team", "tear", "tend", "term", "test", "text", "tick",
        "tide", "tile", "toes", "toll", "tone", "tool", "tore", "torn", "toys", "trail", "trap", "trek",
        "trim", "trip", "true", "tube", "turf", "turn", "twig", "type", "unit", "used", "user", "vast",
        "veil", "vein", "verb", "view", "visa", "vote", "wage", "wand", "ward", "warn", "wear", "weep",
        "well", "whip", "whiz", "wife", "wine", "wing", "wipe", "wise", "wool", "wore", "wrap", "yarn",
        "yell", "yolk"
    ]

    /// Draw `count` random words the child hasn't just seen in this batch —
    /// unlike `WordBank`, there's no persisted exclusion set (this is
    /// browsing, not a non-repeating quiz), so `excluding` only needs to
    /// cover the current on-screen batch.
    static func randomBatch(count: Int, excluding used: Set<String> = []) -> [String] {
        var pool = allWords.filter { !used.contains($0) }
        if pool.count < count { pool = allWords }
        return Array(pool.shuffled().prefix(count))
    }

    /// Picture shown next to a word. Falls back to `WordBank`'s picture for
    /// words the two banks share, then this bank's own map, then a star.
    static func emoji(for word: String) -> String {
        if let shared = WordBank.emojiIfKnown(word) { return shared }
        return supplementalEmoji[word] ?? "🌟"
    }

    private static let supplementalEmoji: [String: String] = [
        "mouse": "🐭", "camel": "🐫", "zebra": "🦓", "tiger": "🐯", "horse": "🐴", "sheep": "🐑",
        "goose": "🦢", "otter": "🦦", "llama": "🦙", "koala": "🐨", "panda": "🐼", "skunk": "🦨",
        "crane": "🦩", "heron": "🦩", "gecko": "🦎", "viper": "🐍", "cobra": "🐍", "shark": "🦈",
        "whale": "🐳", "moose": "🫎", "hyena": "🐆", "eagle": "🦅", "robin": "🐦", "finch": "🐦",
        "quail": "🐦", "snake": "🐍", "snail": "🐌", "apple": "🍎", "mango": "🥭", "grape": "🍇",
        "lemon": "🍋", "peach": "🍑", "melon": "🍈", "berry": "🫐", "olive": "🫒", "onion": "🧅",
        "beans": "🫘", "wheat": "🌾", "bread": "🍞", "toast": "🍞", "bagel": "🥯", "pasta": "🍝",
        "pizza": "🍕", "salad": "🥗", "sugar": "🧂", "honey": "🍯", "syrup": "🍯", "gravy": "🍲",
        "sauce": "🥫", "spice": "🌶️", "curry": "🍛", "candy": "🍬", "chips": "🍟", "fries": "🍟",
        "donut": "🍩", "bacon": "🥓", "steak": "🥩", "roast": "🍗", "chick": "🐤", "squid": "🦑",
        "cloud": "☁️", "storm": "⛈️", "ocean": "🌊", "river": "🏞️", "beach": "🏖️", "field": "🌾",
        "chair": "🪑", "table": "🍽️", "couch": "🛋️", "broom": "🧹", "brush": "🖌️", "towel": "🧻",
        "plate": "🍽️", "spoon": "🥄", "knife": "🔪", "glass": "🥛", "mug": "☕", "clock": "🕐",
        "bus": "🚌", "van": "🚐", "jet": "✈️", "ship": "🚢", "boat": "⛵", "bike": "🚲",
        "sled": "🛷", "cart": "🛒", "taxi": "🚕", "tram": "🚋", "cab": "🚕", "train": "🚆",
        "truck": "🚚", "plane": "✈️", "wagon": "🛒", "ferry": "⛴️", "canoe": "🛶", "kayak": "🛶",
        "run": "🏃", "hop": "🐇", "swim": "🏊", "dance": "💃", "laugh": "😄", "smile": "😊",
        "cry": "😢", "sleep": "😴", "dream": "💭", "wake": "⏰", "wave": "👋", "catch": "🧤",
        "throw": "🤾", "climb": "🧗", "skate": "⛸️", "surf": "🏄", "dive": "🤿", "fly": "🪽",
        "happy": "😊", "angry": "😠", "sad": "😢", "brave": "🦁", "proud": "😌", "shy": "🙈",
        "silly": "🤪", "bored": "😑", "tired": "😴", "eager": "🤩", "kind": "💛", "jolly": "😄",
        "rain": "🌧️", "snow": "❄️", "wind": "💨", "sunny": "☀️", "windy": "💨", "foggy": "🌫️",
        "rainy": "🌧️", "snowy": "❄️", "chalk": "✏️", "paper": "📄", "ruler": "📏", "shirt": "👕",
        "pants": "👖", "socks": "🧦", "shoes": "👟", "dress": "👗", "skirt": "👗", "jeans": "👖",
        "scarf": "🧣", "drill": "🪛", "saw": "🪚", "screw": "🔩", "nail": "🔩", "bolt": "🔩",
        "wire": "🔌", "rugby": "🏉", "milk": "🥛", "juice": "🧃", "soda": "🥤", "water": "💧",
        "cocoa": "🍫", "cider": "🧃", "shake": "🥤", "latte": "☕", "cream": "🍦", "niece": "👧",
        "bloom": "🌸", "piano": "🎹", "drums": "🥁", "flute": "🎼", "cello": "🎻", "banjo": "🪕",
        "harp": "🎼", "organ": "🎹", "trout": "🐟", "perch": "🐟", "bass": "🐟", "eel": "🐍",
        "cod": "🐟", "pike": "🐟", "plum": "🍑", "kiwi": "🥝", "date": "📅", "fig": "🌿",
        "lime": "🍋", "pear": "🍐", "corn": "🌽", "peas": "🫛", "rice": "🍚", "oats": "🌾",
        "nuts": "🥜", "hut": "🛖", "den": "🕳️", "nest": "🪺", "cave": "🕳️", "cabin": "🏡",
        "grin": "😁", "wink": "😉", "nod": "🙂", "shrug": "🤷", "hug": "🤗", "pat": "🤚",
        "clap": "👏"
    ]
}
