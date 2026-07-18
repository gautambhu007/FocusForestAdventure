//
//  LearningModules.swift
//  Focus Forest Adventure
//
//  Data-driven Hindi learning engine. Every category (fruits, animals,
//  numbers…) is pure data rendered by ONE reusable lesson + quiz UI —
//  adding a new module later means adding an array, not writing code.
//  Fully offline: emoji illustrations + on-device hi-IN/en speech.
//

import Foundation

struct LearningItem: Identifiable, Hashable, Sendable {
    let hindi: String
    let english: String
    let emoji: String

    var id: String { hindi }
}

struct LearningModule: Identifiable, Sendable {
    let id: String                // stable key for progress storage
    let emoji: String             // card illustration
    let titleHindi: String
    let titleEnglish: String
    let items: [LearningItem]
    /// Speech language for the primary text ("hi-IN" default; nil = the
    /// app's default English voice — used by the English alphabet module).
    var language: String? = "hi-IN"
}

enum HindiLearningCatalog {

    static func module(id: String) -> LearningModule? {
        modules.first { $0.id == id }
    }

    static let modules: [LearningModule] = base + generated

    // MARK: Generated modules (numbers 21–100)

    private static let hindiTens: [String] = [
        // 21–100 in order
        "इक्कीस", "बाईस", "तेईस", "चौबीस", "पच्चीस", "छब्बीस", "सत्ताईस", "अट्ठाईस", "उनतीस", "तीस",
        "इकतीस", "बत्तीस", "तैंतीस", "चौंतीस", "पैंतीस", "छत्तीस", "सैंतीस", "अड़तीस", "उनतालीस", "चालीस",
        "इकतालीस", "बयालीस", "तैंतालीस", "चवालीस", "पैंतालीस", "छियालीस", "सैंतालीस", "अड़तालीस", "उनचास", "पचास",
        "इक्यावन", "बावन", "तिरपन", "चौवन", "पचपन", "छप्पन", "सत्तावन", "अट्ठावन", "उनसठ", "साठ",
        "इकसठ", "बासठ", "तिरसठ", "चौंसठ", "पैंसठ", "छियासठ", "सड़सठ", "अड़सठ", "उनहत्तर", "सत्तर",
        "इकहत्तर", "बहत्तर", "तिहत्तर", "चौहत्तर", "पचहत्तर", "छिहत्तर", "सतहत्तर", "अठहत्तर", "उन्यासी", "अस्सी",
        "इक्यासी", "बयासी", "तिरासी", "चौरासी", "पचासी", "छियासी", "सत्तासी", "अट्ठासी", "नवासी", "नब्बे",
        "इक्यानवे", "बानवे", "तिरानवे", "चौरानवे", "पंचानवे", "छियानवे", "सत्तानवे", "अट्ठानवे", "निन्यानवे", "सौ"
    ]

    private static func devanagari(_ n: Int) -> String {
        let digits: [Character: Character] = ["0": "०", "1": "१", "2": "२", "3": "३", "4": "४",
                                              "5": "५", "6": "६", "7": "७", "8": "८", "9": "९"]
        return String(String(n).map { digits[$0] ?? $0 })
    }

    private static func englishNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: n))?.capitalized ?? "\(n)"
    }

    private static func numberModule(id: String, from: Int, to: Int, emoji: String) -> LearningModule {
        LearningModule(
            id: id, emoji: emoji,
            titleHindi: "गिनती \(devanagari(from))–\(devanagari(to))",
            titleEnglish: "Numbers \(from)–\(to)",
            items: (from...to).map { n in
                LearningItem(hindi: hindiTens[n - 21], english: englishNumber(n), emoji: devanagari(n))
            }
        )
    }

    private static let generated: [LearningModule] = [
        numberModule(id: "numbers2150", from: 21, to: 50, emoji: "3️⃣"),
        numberModule(id: "numbers51100", from: 51, to: 100, emoji: "💯")
    ]

    private static let base: [LearningModule] = [
        LearningModule(id: "numbers", emoji: "🔢", titleHindi: "गिनती", titleEnglish: "Numbers 1–20", items: [
            LearningItem(hindi: "एक", english: "One", emoji: "१"),
            LearningItem(hindi: "दो", english: "Two", emoji: "२"),
            LearningItem(hindi: "तीन", english: "Three", emoji: "३"),
            LearningItem(hindi: "चार", english: "Four", emoji: "४"),
            LearningItem(hindi: "पाँच", english: "Five", emoji: "५"),
            LearningItem(hindi: "छह", english: "Six", emoji: "६"),
            LearningItem(hindi: "सात", english: "Seven", emoji: "७"),
            LearningItem(hindi: "आठ", english: "Eight", emoji: "८"),
            LearningItem(hindi: "नौ", english: "Nine", emoji: "९"),
            LearningItem(hindi: "दस", english: "Ten", emoji: "१०"),
            LearningItem(hindi: "ग्यारह", english: "Eleven", emoji: "११"),
            LearningItem(hindi: "बारह", english: "Twelve", emoji: "१२"),
            LearningItem(hindi: "तेरह", english: "Thirteen", emoji: "१३"),
            LearningItem(hindi: "चौदह", english: "Fourteen", emoji: "१४"),
            LearningItem(hindi: "पंद्रह", english: "Fifteen", emoji: "१५"),
            LearningItem(hindi: "सोलह", english: "Sixteen", emoji: "१६"),
            LearningItem(hindi: "सत्रह", english: "Seventeen", emoji: "१७"),
            LearningItem(hindi: "अठारह", english: "Eighteen", emoji: "१८"),
            LearningItem(hindi: "उन्नीस", english: "Nineteen", emoji: "१९"),
            LearningItem(hindi: "बीस", english: "Twenty", emoji: "२०")
        ]),
        LearningModule(id: "fruits", emoji: "🍎", titleHindi: "फल", titleEnglish: "Fruits", items: [
            LearningItem(hindi: "सेब", english: "Apple", emoji: "🍎"),
            LearningItem(hindi: "केला", english: "Banana", emoji: "🍌"),
            LearningItem(hindi: "आम", english: "Mango", emoji: "🥭"),
            LearningItem(hindi: "अंगूर", english: "Grapes", emoji: "🍇"),
            LearningItem(hindi: "संतरा", english: "Orange", emoji: "🍊"),
            LearningItem(hindi: "तरबूज", english: "Watermelon", emoji: "🍉"),
            LearningItem(hindi: "अनानास", english: "Pineapple", emoji: "🍍"),
            LearningItem(hindi: "स्ट्रॉबेरी", english: "Strawberry", emoji: "🍓"),
            LearningItem(hindi: "नारियल", english: "Coconut", emoji: "🥥"),
            LearningItem(hindi: "कीवी", english: "Kiwi", emoji: "🥝"),
            LearningItem(hindi: "चेरी", english: "Cherry", emoji: "🍒"),
            LearningItem(hindi: "नाशपाती", english: "Pear", emoji: "🍐"),
            LearningItem(hindi: "नींबू", english: "Lemon", emoji: "🍋")
        ]),
        LearningModule(id: "vegetables", emoji: "🥕", titleHindi: "सब्ज़ियाँ", titleEnglish: "Vegetables", items: [
            LearningItem(hindi: "आलू", english: "Potato", emoji: "🥔"),
            LearningItem(hindi: "टमाटर", english: "Tomato", emoji: "🍅"),
            LearningItem(hindi: "गाजर", english: "Carrot", emoji: "🥕"),
            LearningItem(hindi: "प्याज", english: "Onion", emoji: "🧅"),
            LearningItem(hindi: "मटर", english: "Peas", emoji: "🫛"),
            LearningItem(hindi: "बैंगन", english: "Brinjal", emoji: "🍆"),
            LearningItem(hindi: "मिर्च", english: "Chilli", emoji: "🌶️"),
            LearningItem(hindi: "मक्का", english: "Corn", emoji: "🌽"),
            LearningItem(hindi: "खीरा", english: "Cucumber", emoji: "🥒"),
            LearningItem(hindi: "ब्रोकली", english: "Broccoli", emoji: "🥦"),
            LearningItem(hindi: "मशरूम", english: "Mushroom", emoji: "🍄"),
            LearningItem(hindi: "लहसुन", english: "Garlic", emoji: "🧄")
        ]),
        LearningModule(id: "animals", emoji: "🦁", titleHindi: "जानवर", titleEnglish: "Animals", items: [
            LearningItem(hindi: "कुत्ता", english: "Dog", emoji: "🐶"),
            LearningItem(hindi: "बिल्ली", english: "Cat", emoji: "🐱"),
            LearningItem(hindi: "गाय", english: "Cow", emoji: "🐮"),
            LearningItem(hindi: "बकरी", english: "Goat", emoji: "🐐"),
            LearningItem(hindi: "घोड़ा", english: "Horse", emoji: "🐴"),
            LearningItem(hindi: "शेर", english: "Lion", emoji: "🦁"),
            LearningItem(hindi: "बाघ", english: "Tiger", emoji: "🐯"),
            LearningItem(hindi: "हाथी", english: "Elephant", emoji: "🐘"),
            LearningItem(hindi: "बंदर", english: "Monkey", emoji: "🐵"),
            LearningItem(hindi: "भालू", english: "Bear", emoji: "🐻"),
            LearningItem(hindi: "हिरण", english: "Deer", emoji: "🦌"),
            LearningItem(hindi: "लोमड़ी", english: "Fox", emoji: "🦊"),
            LearningItem(hindi: "खरगोश", english: "Rabbit", emoji: "🐰"),
            LearningItem(hindi: "ऊँट", english: "Camel", emoji: "🐫"),
            LearningItem(hindi: "ज़ेबरा", english: "Zebra", emoji: "🦓")
        ]),
        LearningModule(id: "birds", emoji: "🦚", titleHindi: "पक्षी", titleEnglish: "Birds", items: [
            LearningItem(hindi: "तोता", english: "Parrot", emoji: "🦜"),
            LearningItem(hindi: "मोर", english: "Peacock", emoji: "🦚"),
            LearningItem(hindi: "कबूतर", english: "Pigeon", emoji: "🕊️"),
            LearningItem(hindi: "मुर्गा", english: "Rooster", emoji: "🐓"),
            LearningItem(hindi: "बत्तख", english: "Duck", emoji: "🦆"),
            LearningItem(hindi: "उल्लू", english: "Owl", emoji: "🦉"),
            LearningItem(hindi: "गौरैया", english: "Sparrow", emoji: "🐦"),
            LearningItem(hindi: "हंस", english: "Swan", emoji: "🦢"),
            LearningItem(hindi: "पेंगुइन", english: "Penguin", emoji: "🐧"),
            LearningItem(hindi: "बाज", english: "Eagle", emoji: "🦅"),
            LearningItem(hindi: "कौआ", english: "Crow", emoji: "🐦‍⬛")
        ]),
        LearningModule(id: "colors", emoji: "🎨", titleHindi: "रंग", titleEnglish: "Colours", items: [
            LearningItem(hindi: "लाल", english: "Red", emoji: "🔴"),
            LearningItem(hindi: "नीला", english: "Blue", emoji: "🔵"),
            LearningItem(hindi: "हरा", english: "Green", emoji: "🟢"),
            LearningItem(hindi: "पीला", english: "Yellow", emoji: "🟡"),
            LearningItem(hindi: "नारंगी", english: "Orange", emoji: "🟠"),
            LearningItem(hindi: "बैंगनी", english: "Purple", emoji: "🟣"),
            LearningItem(hindi: "काला", english: "Black", emoji: "⚫"),
            LearningItem(hindi: "सफेद", english: "White", emoji: "⚪"),
            LearningItem(hindi: "गुलाबी", english: "Pink", emoji: "🩷"),
            LearningItem(hindi: "भूरा", english: "Brown", emoji: "🟤")
        ]),
        LearningModule(id: "shapes", emoji: "🧩", titleHindi: "आकार", titleEnglish: "Shapes", items: [
            LearningItem(hindi: "वृत्त", english: "Circle", emoji: "⭕"),
            LearningItem(hindi: "त्रिभुज", english: "Triangle", emoji: "🔺"),
            LearningItem(hindi: "वर्ग", english: "Square", emoji: "⬜"),
            LearningItem(hindi: "तारा", english: "Star", emoji: "⭐"),
            LearningItem(hindi: "दिल", english: "Heart", emoji: "❤️"),
            LearningItem(hindi: "चाँद", english: "Crescent", emoji: "🌙"),
            LearningItem(hindi: "हीरा", english: "Diamond", emoji: "🔷"),
            LearningItem(hindi: "अंडाकार", english: "Oval", emoji: "🥚")
        ]),
        LearningModule(id: "body", emoji: "🖐️", titleHindi: "शरीर के अंग", titleEnglish: "Body Parts", items: [
            LearningItem(hindi: "आँख", english: "Eye", emoji: "👁️"),
            LearningItem(hindi: "कान", english: "Ear", emoji: "👂"),
            LearningItem(hindi: "नाक", english: "Nose", emoji: "👃"),
            LearningItem(hindi: "मुँह", english: "Mouth", emoji: "👄"),
            LearningItem(hindi: "हाथ", english: "Hand", emoji: "✋"),
            LearningItem(hindi: "पैर", english: "Foot", emoji: "🦶"),
            LearningItem(hindi: "दाँत", english: "Teeth", emoji: "🦷"),
            LearningItem(hindi: "जीभ", english: "Tongue", emoji: "👅"),
            LearningItem(hindi: "उँगली", english: "Finger", emoji: "☝️")
        ]),
        LearningModule(id: "vehicles", emoji: "🚗", titleHindi: "वाहन", titleEnglish: "Vehicles", items: [
            LearningItem(hindi: "कार", english: "Car", emoji: "🚗"),
            LearningItem(hindi: "बस", english: "Bus", emoji: "🚌"),
            LearningItem(hindi: "रेलगाड़ी", english: "Train", emoji: "🚆"),
            LearningItem(hindi: "हवाई जहाज", english: "Airplane", emoji: "✈️"),
            LearningItem(hindi: "नाव", english: "Boat", emoji: "⛵"),
            LearningItem(hindi: "साइकिल", english: "Bicycle", emoji: "🚲"),
            LearningItem(hindi: "ट्रक", english: "Truck", emoji: "🚚"),
            LearningItem(hindi: "ऑटो रिक्शा", english: "Auto rickshaw", emoji: "🛺"),
            LearningItem(hindi: "एम्बुलेंस", english: "Ambulance", emoji: "🚑"),
            LearningItem(hindi: "दमकल", english: "Fire engine", emoji: "🚒"),
            LearningItem(hindi: "पुलिस गाड़ी", english: "Police car", emoji: "🚓"),
            LearningItem(hindi: "हेलीकॉप्टर", english: "Helicopter", emoji: "🚁"),
            LearningItem(hindi: "रॉकेट", english: "Rocket", emoji: "🚀")
        ]),
        LearningModule(id: "actions", emoji: "🏃", titleHindi: "क्रियाएँ", titleEnglish: "Actions", items: [
            LearningItem(hindi: "दौड़ना", english: "Run", emoji: "🏃"),
            LearningItem(hindi: "चलना", english: "Walk", emoji: "🚶"),
            LearningItem(hindi: "कूदना", english: "Jump", emoji: "🤸"),
            LearningItem(hindi: "सोना", english: "Sleep", emoji: "😴"),
            LearningItem(hindi: "खाना", english: "Eat", emoji: "🍽️"),
            LearningItem(hindi: "पीना", english: "Drink", emoji: "🥤"),
            LearningItem(hindi: "पढ़ना", english: "Read", emoji: "📖"),
            LearningItem(hindi: "लिखना", english: "Write", emoji: "✍️"),
            LearningItem(hindi: "खेलना", english: "Play", emoji: "⚽"),
            LearningItem(hindi: "हँसना", english: "Laugh", emoji: "😄"),
            LearningItem(hindi: "नाचना", english: "Dance", emoji: "💃"),
            LearningItem(hindi: "गाना", english: "Sing", emoji: "🎤"),
            LearningItem(hindi: "तैरना", english: "Swim", emoji: "🏊")
        ]),
        LearningModule(id: "helpers", emoji: "🧑‍⚕️", titleHindi: "सहायक", titleEnglish: "Community Helpers", items: [
            LearningItem(hindi: "डॉक्टर", english: "Doctor", emoji: "🧑‍⚕️"),
            LearningItem(hindi: "शिक्षक", english: "Teacher", emoji: "🧑‍🏫"),
            LearningItem(hindi: "पुलिस", english: "Police", emoji: "👮"),
            LearningItem(hindi: "किसान", english: "Farmer", emoji: "🧑‍🌾"),
            LearningItem(hindi: "दमकलकर्मी", english: "Firefighter", emoji: "🧑‍🚒"),
            LearningItem(hindi: "रसोइया", english: "Cook", emoji: "🧑‍🍳"),
            LearningItem(hindi: "पायलट", english: "Pilot", emoji: "🧑‍✈️"),
            LearningItem(hindi: "वैज्ञानिक", english: "Scientist", emoji: "🧑‍🔬")
        ]),
        LearningModule(id: "habits", emoji: "🪥", titleHindi: "अच्छी आदतें", titleEnglish: "Good Habits", items: [
            LearningItem(hindi: "दाँत साफ करो", english: "Brush your teeth", emoji: "🪥"),
            LearningItem(hindi: "हाथ धोओ", english: "Wash your hands", emoji: "🧼"),
            LearningItem(hindi: "पानी पियो", english: "Drink water", emoji: "💧"),
            LearningItem(hindi: "फल खाओ", english: "Eat fruits", emoji: "🍎"),
            LearningItem(hindi: "व्यायाम करो", english: "Exercise", emoji: "🤸"),
            LearningItem(hindi: "जल्दी सोओ", english: "Sleep early", emoji: "🛏️"),
            LearningItem(hindi: "खिलौने बाँटो", english: "Share your toys", emoji: "🧸"),
            LearningItem(hindi: "बड़ों का आदर करो", english: "Respect elders", emoji: "🙏"),
            LearningItem(hindi: "धन्यवाद कहो", english: "Say thank you", emoji: "😊"),
            LearningItem(hindi: "कचरा कूड़ेदान में डालो", english: "Use the dustbin", emoji: "🗑️")
        ]),
        LearningModule(id: "flowers", emoji: "🌹", titleHindi: "फूल", titleEnglish: "Flowers", items: [
            LearningItem(hindi: "गुलाब", english: "Rose", emoji: "🌹"),
            LearningItem(hindi: "कमल", english: "Lotus", emoji: "🪷"),
            LearningItem(hindi: "सूरजमुखी", english: "Sunflower", emoji: "🌻"),
            LearningItem(hindi: "गेंदा", english: "Marigold", emoji: "🏵️"),
            LearningItem(hindi: "ट्यूलिप", english: "Tulip", emoji: "🌷"),
            LearningItem(hindi: "गुड़हल", english: "Hibiscus", emoji: "🌺"),
            LearningItem(hindi: "चमेली", english: "Jasmine", emoji: "💮"),
            LearningItem(hindi: "चेरी का फूल", english: "Blossom", emoji: "🌸")
        ]),
        LearningModule(id: "insects", emoji: "🦋", titleHindi: "कीड़े-मकोड़े", titleEnglish: "Insects", items: [
            LearningItem(hindi: "तितली", english: "Butterfly", emoji: "🦋"),
            LearningItem(hindi: "मधुमक्खी", english: "Bee", emoji: "🐝"),
            LearningItem(hindi: "चींटी", english: "Ant", emoji: "🐜"),
            LearningItem(hindi: "मकड़ी", english: "Spider", emoji: "🕷️"),
            LearningItem(hindi: "टिड्डा", english: "Grasshopper", emoji: "🦗"),
            LearningItem(hindi: "केंचुआ", english: "Worm", emoji: "🪱"),
            LearningItem(hindi: "घोंघा", english: "Snail", emoji: "🐌"),
            LearningItem(hindi: "गुबरैला", english: "Beetle", emoji: "🪲"),
            LearningItem(hindi: "मच्छर", english: "Mosquito", emoji: "🦟")
        ]),
        LearningModule(id: "waterAnimals", emoji: "🐬", titleHindi: "जलीय जीव", titleEnglish: "Water Animals", items: [
            LearningItem(hindi: "मछली", english: "Fish", emoji: "🐟"),
            LearningItem(hindi: "ऑक्टोपस", english: "Octopus", emoji: "🐙"),
            LearningItem(hindi: "केकड़ा", english: "Crab", emoji: "🦀"),
            LearningItem(hindi: "कछुआ", english: "Turtle", emoji: "🐢"),
            LearningItem(hindi: "डॉल्फिन", english: "Dolphin", emoji: "🐬"),
            LearningItem(hindi: "व्हेल", english: "Whale", emoji: "🐳"),
            LearningItem(hindi: "शार्क", english: "Shark", emoji: "🦈"),
            LearningItem(hindi: "झींगा", english: "Shrimp", emoji: "🦐"),
            LearningItem(hindi: "जेलीफिश", english: "Jellyfish", emoji: "🪼"),
            LearningItem(hindi: "सीप", english: "Seashell", emoji: "🐚")
        ]),
        LearningModule(id: "stationery", emoji: "✏️", titleHindi: "स्टेशनरी", titleEnglish: "Stationery", items: [
            LearningItem(hindi: "किताब", english: "Book", emoji: "📚"),
            LearningItem(hindi: "कॉपी", english: "Notebook", emoji: "📓"),
            LearningItem(hindi: "पेंसिल", english: "Pencil", emoji: "✏️"),
            LearningItem(hindi: "कलम", english: "Pen", emoji: "🖊️"),
            LearningItem(hindi: "स्केल", english: "Ruler", emoji: "📏"),
            LearningItem(hindi: "कैंची", english: "Scissors", emoji: "✂️"),
            LearningItem(hindi: "क्रेयॉन", english: "Crayon", emoji: "🖍️"),
            LearningItem(hindi: "कागज़", english: "Paper", emoji: "📄"),
            LearningItem(hindi: "बस्ता", english: "School bag", emoji: "🎒")
        ]),
        LearningModule(id: "computer", emoji: "💻", titleHindi: "कंप्यूटर", titleEnglish: "Computer Parts", items: [
            LearningItem(hindi: "कंप्यूटर", english: "Computer", emoji: "💻"),
            LearningItem(hindi: "माउस", english: "Mouse", emoji: "🖱️"),
            LearningItem(hindi: "कीबोर्ड", english: "Keyboard", emoji: "⌨️"),
            LearningItem(hindi: "मॉनिटर", english: "Monitor", emoji: "🖥️"),
            LearningItem(hindi: "प्रिंटर", english: "Printer", emoji: "🖨️"),
            LearningItem(hindi: "फोन", english: "Phone", emoji: "📱"),
            LearningItem(hindi: "हेडफोन", english: "Headphones", emoji: "🎧"),
            LearningItem(hindi: "कैमरा", english: "Camera", emoji: "📷"),
            LearningItem(hindi: "बैटरी", english: "Battery", emoji: "🔋")
        ]),
        LearningModule(id: "seasons", emoji: "🌦️", titleHindi: "ऋतुएँ", titleEnglish: "Seasons", items: [
            LearningItem(hindi: "गर्मी", english: "Summer", emoji: "☀️"),
            LearningItem(hindi: "सर्दी", english: "Winter", emoji: "❄️"),
            LearningItem(hindi: "वर्षा", english: "Rainy season", emoji: "🌧️"),
            LearningItem(hindi: "वसंत", english: "Spring", emoji: "🌸"),
            LearningItem(hindi: "पतझड़", english: "Autumn", emoji: "🍂")
        ]),
        LearningModule(id: "months", emoji: "📅", titleHindi: "महीने", titleEnglish: "Months", items: [
            LearningItem(hindi: "जनवरी", english: "January", emoji: "❄️"),
            LearningItem(hindi: "फरवरी", english: "February", emoji: "💝"),
            LearningItem(hindi: "मार्च", english: "March", emoji: "🎨"),
            LearningItem(hindi: "अप्रैल", english: "April", emoji: "🌷"),
            LearningItem(hindi: "मई", english: "May", emoji: "☀️"),
            LearningItem(hindi: "जून", english: "June", emoji: "🥭"),
            LearningItem(hindi: "जुलाई", english: "July", emoji: "🌧️"),
            LearningItem(hindi: "अगस्त", english: "August", emoji: "🇮🇳"),
            LearningItem(hindi: "सितंबर", english: "September", emoji: "📚"),
            LearningItem(hindi: "अक्टूबर", english: "October", emoji: "🍂"),
            LearningItem(hindi: "नवंबर", english: "November", emoji: "🪔"),
            LearningItem(hindi: "दिसंबर", english: "December", emoji: "🎄")
        ]),
        LearningModule(id: "days", emoji: "🗓️", titleHindi: "सप्ताह के दिन", titleEnglish: "Days of the Week", items: [
            LearningItem(hindi: "सोमवार", english: "Monday", emoji: "🌙"),
            LearningItem(hindi: "मंगलवार", english: "Tuesday", emoji: "🔴"),
            LearningItem(hindi: "बुधवार", english: "Wednesday", emoji: "🟢"),
            LearningItem(hindi: "गुरुवार", english: "Thursday", emoji: "🟡"),
            LearningItem(hindi: "शुक्रवार", english: "Friday", emoji: "⚪"),
            LearningItem(hindi: "शनिवार", english: "Saturday", emoji: "⚫"),
            LearningItem(hindi: "रविवार", english: "Sunday", emoji: "☀️")
        ]),
        LearningModule(id: "manners", emoji: "🙏", titleHindi: "अच्छे संस्कार", titleEnglish: "Good Manners", items: [
            LearningItem(hindi: "नमस्ते", english: "Greeting", emoji: "🙏"),
            LearningItem(hindi: "धन्यवाद", english: "Thank you", emoji: "😊"),
            LearningItem(hindi: "कृपया", english: "Please", emoji: "🤲"),
            LearningItem(hindi: "माफ़ करना", english: "Sorry", emoji: "😔"),
            LearningItem(hindi: "मदद करो", english: "Help others", emoji: "🤝"),
            LearningItem(hindi: "धीरे बोलो", english: "Speak softly", emoji: "🤫"),
            LearningItem(hindi: "बारी का इंतज़ार करो", english: "Wait your turn", emoji: "⏳")
        ]),
        LearningModule(id: "safety", emoji: "🚸", titleHindi: "सुरक्षा", titleEnglish: "Safety", items: [
            LearningItem(hindi: "सड़क ध्यान से पार करो", english: "Cross the road carefully", emoji: "🚸"),
            LearningItem(hindi: "लाल बत्ती पर रुको", english: "Stop at the red light", emoji: "🚦"),
            LearningItem(hindi: "हेलमेट पहनो", english: "Wear a helmet", emoji: "⛑️"),
            LearningItem(hindi: "सीट बेल्ट लगाओ", english: "Wear your seat belt", emoji: "💺"),
            LearningItem(hindi: "आग से दूर रहो", english: "Stay away from fire", emoji: "🔥"),
            LearningItem(hindi: "पानी के पास ध्यान रखो", english: "Be careful near water", emoji: "🌊"),
            LearningItem(hindi: "अजनबी से सावधान", english: "Careful with strangers", emoji: "🙅"),
            LearningItem(hindi: "आपातकालीन नंबर 112", english: "Emergency number 112", emoji: "📞")
        ]),
        LearningModule(id: "festivals", emoji: "🪔", titleHindi: "त्योहार", titleEnglish: "Festivals", items: [
            LearningItem(hindi: "दिवाली", english: "Diwali", emoji: "🪔"),
            LearningItem(hindi: "होली", english: "Holi", emoji: "🎨"),
            LearningItem(hindi: "रक्षाबंधन", english: "Raksha Bandhan", emoji: "🎀"),
            LearningItem(hindi: "ईद", english: "Eid", emoji: "🌙"),
            LearningItem(hindi: "क्रिसमस", english: "Christmas", emoji: "🎄"),
            LearningItem(hindi: "दशहरा", english: "Dussehra", emoji: "🏹"),
            LearningItem(hindi: "गणेश चतुर्थी", english: "Ganesh Chaturthi", emoji: "🐘"),
            LearningItem(hindi: "गुरु पर्व", english: "Gurpurab", emoji: "🪯"),
            LearningItem(hindi: "पोंगल", english: "Pongal", emoji: "🌾"),
            LearningItem(hindi: "स्वतंत्रता दिवस", english: "Independence Day", emoji: "🇮🇳")
        ]),
        LearningModule(id: "national", emoji: "🇮🇳", titleHindi: "राष्ट्रीय प्रतीक", titleEnglish: "National Symbols", items: [
            LearningItem(hindi: "तिरंगा", english: "National Flag", emoji: "🇮🇳"),
            LearningItem(hindi: "बाघ", english: "National Animal — Tiger", emoji: "🐯"),
            LearningItem(hindi: "मोर", english: "National Bird — Peacock", emoji: "🦚"),
            LearningItem(hindi: "कमल", english: "National Flower — Lotus", emoji: "🪷"),
            LearningItem(hindi: "आम", english: "National Fruit — Mango", emoji: "🥭"),
            LearningItem(hindi: "बरगद", english: "National Tree — Banyan", emoji: "🌳"),
            LearningItem(hindi: "अशोक चक्र", english: "Ashoka Chakra", emoji: "☸️"),
            LearningItem(hindi: "हॉकी", english: "National Sport — Hockey", emoji: "🏑")
        ]),
        LearningModule(id: "food", emoji: "🫓", titleHindi: "खाना-पीना", titleEnglish: "Food & Drinks", items: [
            LearningItem(hindi: "रोटी", english: "Roti", emoji: "🫓"),
            LearningItem(hindi: "चावल", english: "Rice", emoji: "🍚"),
            LearningItem(hindi: "दाल", english: "Dal", emoji: "🍲"),
            LearningItem(hindi: "दूध", english: "Milk", emoji: "🥛"),
            LearningItem(hindi: "पानी", english: "Water", emoji: "💧"),
            LearningItem(hindi: "चाय", english: "Tea", emoji: "🍵"),
            LearningItem(hindi: "समोसा", english: "Samosa", emoji: "🥟"),
            LearningItem(hindi: "आइसक्रीम", english: "Ice cream", emoji: "🍦"),
            LearningItem(hindi: "अंडा", english: "Egg", emoji: "🥚"),
            LearningItem(hindi: "मिठाई", english: "Sweets", emoji: "🍬")
        ]),
        LearningModule(id: "englishAlphabet", emoji: "🔠", titleHindi: "अंग्रेज़ी वर्णमाला",
                       titleEnglish: "English A–Z", items: [
            LearningItem(hindi: "A", english: "a · Apple", emoji: "🍎"),
            LearningItem(hindi: "B", english: "b · Ball", emoji: "⚽"),
            LearningItem(hindi: "C", english: "c · Cat", emoji: "🐱"),
            LearningItem(hindi: "D", english: "d · Dog", emoji: "🐶"),
            LearningItem(hindi: "E", english: "e · Elephant", emoji: "🐘"),
            LearningItem(hindi: "F", english: "f · Fish", emoji: "🐟"),
            LearningItem(hindi: "G", english: "g · Grapes", emoji: "🍇"),
            LearningItem(hindi: "H", english: "h · Hat", emoji: "🎩"),
            LearningItem(hindi: "I", english: "i · Ice cream", emoji: "🍦"),
            LearningItem(hindi: "J", english: "j · Juice", emoji: "🧃"),
            LearningItem(hindi: "K", english: "k · Kite", emoji: "🪁"),
            LearningItem(hindi: "L", english: "l · Lion", emoji: "🦁"),
            LearningItem(hindi: "M", english: "m · Mango", emoji: "🥭"),
            LearningItem(hindi: "N", english: "n · Nest", emoji: "🪺"),
            LearningItem(hindi: "O", english: "o · Orange", emoji: "🍊"),
            LearningItem(hindi: "P", english: "p · Parrot", emoji: "🦜"),
            LearningItem(hindi: "Q", english: "q · Queen", emoji: "👑"),
            LearningItem(hindi: "R", english: "r · Rabbit", emoji: "🐰"),
            LearningItem(hindi: "S", english: "s · Sun", emoji: "☀️"),
            LearningItem(hindi: "T", english: "t · Tree", emoji: "🌳"),
            LearningItem(hindi: "U", english: "u · Umbrella", emoji: "☂️"),
            LearningItem(hindi: "V", english: "v · Van", emoji: "🚐"),
            LearningItem(hindi: "W", english: "w · Watch", emoji: "⌚"),
            LearningItem(hindi: "X", english: "x · X-ray", emoji: "🩻"),
            LearningItem(hindi: "Y", english: "y · Yo-yo", emoji: "🪀"),
            LearningItem(hindi: "Z", english: "z · Zebra", emoji: "🦓")
        ], language: nil),
        LearningModule(id: "time", emoji: "🕐", titleHindi: "समय", titleEnglish: "Time", items: [
            LearningItem(hindi: "घड़ी", english: "Clock", emoji: "🕐"),
            LearningItem(hindi: "सुबह", english: "Morning", emoji: "🌅"),
            LearningItem(hindi: "दोपहर", english: "Afternoon", emoji: "☀️"),
            LearningItem(hindi: "शाम", english: "Evening", emoji: "🌇"),
            LearningItem(hindi: "रात", english: "Night", emoji: "🌙"),
            LearningItem(hindi: "दिन", english: "Day", emoji: "📅"),
            LearningItem(hindi: "सप्ताह", english: "Week", emoji: "🗓️"),
            LearningItem(hindi: "महीना", english: "Month", emoji: "🌕"),
            LearningItem(hindi: "साल", english: "Year", emoji: "🎂"),
            LearningItem(hindi: "कैलेंडर", english: "Calendar", emoji: "📆")
        ]),
        LearningModule(id: "currency", emoji: "💰", titleHindi: "भारतीय मुद्रा", titleEnglish: "Indian Currency", items: [
            LearningItem(hindi: "सिक्का", english: "Coin", emoji: "🪙"),
            LearningItem(hindi: "नोट", english: "Note", emoji: "💵"),
            LearningItem(hindi: "एक रुपया", english: "One rupee", emoji: "₹1"),
            LearningItem(hindi: "दो रुपये", english: "Two rupees", emoji: "₹2"),
            LearningItem(hindi: "पाँच रुपये", english: "Five rupees", emoji: "₹5"),
            LearningItem(hindi: "दस रुपये", english: "Ten rupees", emoji: "₹10"),
            LearningItem(hindi: "बीस रुपये", english: "Twenty rupees", emoji: "₹20"),
            LearningItem(hindi: "पचास रुपये", english: "Fifty rupees", emoji: "₹50"),
            LearningItem(hindi: "सौ रुपये", english: "Hundred rupees", emoji: "₹100"),
            LearningItem(hindi: "पाँच सौ रुपये", english: "Five hundred rupees", emoji: "₹500")
        ]),
        LearningModule(id: "religions", emoji: "🤝", titleHindi: "धर्म", titleEnglish: "Religions", items: [
            // Child-friendly and even-handed: places of worship + one message
            // of equal respect. No doctrine, no comparisons.
            LearningItem(hindi: "मंदिर", english: "Temple", emoji: "🛕"),
            LearningItem(hindi: "मस्जिद", english: "Mosque", emoji: "🕌"),
            LearningItem(hindi: "गिरजाघर", english: "Church", emoji: "⛪"),
            LearningItem(hindi: "गुरुद्वारा", english: "Gurudwara", emoji: "🪯"),
            LearningItem(hindi: "बौद्ध विहार", english: "Buddhist temple", emoji: "☸️"),
            LearningItem(hindi: "सब धर्म समान हैं", english: "All religions are equal", emoji: "🤝"),
            LearningItem(hindi: "सबका आदर करो", english: "Respect everyone", emoji: "🙏")
        ]),
        LearningModule(id: "personalities", emoji: "🕊️", titleHindi: "महान व्यक्ति", titleEnglish: "Great Personalities", items: [
            LearningItem(hindi: "महात्मा गांधी", english: "Mahatma Gandhi — Father of the Nation", emoji: "🕊️"),
            LearningItem(hindi: "डॉ. अब्दुल कलाम", english: "A.P.J. Abdul Kalam — Missile Man & President", emoji: "🚀"),
            LearningItem(hindi: "रानी लक्ष्मीबाई", english: "Rani Lakshmibai — Brave queen of Jhansi", emoji: "🐎"),
            LearningItem(hindi: "सुभाष चंद्र बोस", english: "Subhash Chandra Bose — Netaji", emoji: "🇮🇳"),
            LearningItem(hindi: "भगत सिंह", english: "Bhagat Singh — Young freedom fighter", emoji: "⭐"),
            LearningItem(hindi: "सरदार पटेल", english: "Sardar Patel — Iron Man of India", emoji: "🗿"),
            LearningItem(hindi: "डॉ. अंबेडकर", english: "Dr. Ambedkar — Wrote our Constitution", emoji: "📜"),
            LearningItem(hindi: "मदर टेरेसा", english: "Mother Teresa — Helped the poor", emoji: "❤️")
        ])
    ]
}
