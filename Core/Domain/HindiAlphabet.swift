//
//  HindiAlphabet.swift
//  Focus Forest Adventure
//
//  Hindi varnamala (consonants) with the classic example words —
//  क से कबूतर, ख से खरगोश… matching the standard learning charts.
//  Every letter has an emoji illustration so the feature is fully
//  offline (no downloaded images, per the app's privacy rules).
//

import Foundation

struct HindiLetter: Identifiable, Hashable, Sendable {
    let letter: String            // Devanagari, e.g. "क"
    let roman: String             // transliteration of the letter, e.g. "K"
    let word: String              // example word in Devanagari, e.g. "कबूतर"
    let wordRoman: String         // e.g. "Kabootar"
    let wordMeaning: String       // English meaning for parents, e.g. "Pigeon"
    let emoji: String             // offline illustration
    /// TTS override for letters the Hindi voice can't pronounce in
    /// isolation (the nasals ङ/ञ) — spoken in real word context instead.
    var spokenOverride: String? = nil

    var id: String { letter }

    /// What Bunny says (in Hindi): "क से कबूतर" — exactly the classroom
    /// phrase. (No standalone "क!" prefix: isolated letters make the TTS
    /// glitch — a bare "अ" came out as "dollar".) Sound-only letters use
    /// their override so the nasal is heard inside a real word.
    var spokenText: String {
        if let spokenOverride { return spokenOverride }
        return word.isEmpty ? letter : "\(letter) से \(word)"
    }

    /// Sound-only letters have no example word (per the charts).
    var isSoundOnly: Bool { word.isEmpty }

    /// Bundled illustration name, e.g. "hindi_kabootar". When an image with
    /// this name exists in the asset catalog it is shown instead of the
    /// emoji — drop in licensed artwork anytime, no code changes needed.
    var imageName: String { "hindi_\(wordRoman.lowercased())" }
}

enum HindiAlphabet {

    /// स्वर — the thirteen vowels, standard chart words.
    /// (अ से अनार: no pomegranate emoji exists, so the flash card draws a
    /// custom SwiftUI pomegranate — see PomegranateArt.)
    static let vowels: [HindiLetter] = [
        HindiLetter(letter: "अ", roman: "A", word: "अनार", wordRoman: "Anaar", wordMeaning: "Pomegranate", emoji: "🔴"),
        HindiLetter(letter: "आ", roman: "Aa", word: "आम", wordRoman: "Aam", wordMeaning: "Mango", emoji: "🥭"),
        HindiLetter(letter: "इ", roman: "I", word: "इमली", wordRoman: "Imlee", wordMeaning: "Tamarind", emoji: "🫘"),
        HindiLetter(letter: "ई", roman: "Ee", word: "ईख", wordRoman: "Eekh", wordMeaning: "Sugarcane", emoji: "🎋"),
        HindiLetter(letter: "उ", roman: "U", word: "उल्लू", wordRoman: "Ulloo", wordMeaning: "Owl", emoji: "🦉"),
        HindiLetter(letter: "ऊ", roman: "Oo", word: "ऊन", wordRoman: "Oon", wordMeaning: "Wool", emoji: "🧶"),
        HindiLetter(letter: "ऋ", roman: "Ri", word: "ऋषि", wordRoman: "Rishi", wordMeaning: "Sage", emoji: "🧘‍♂️"),
        HindiLetter(letter: "ए", roman: "E", word: "एड़ी", wordRoman: "Edee", wordMeaning: "Heel", emoji: "🦶"),
        HindiLetter(letter: "ऐ", roman: "Ai", word: "ऐनक", wordRoman: "Ainak", wordMeaning: "Glasses", emoji: "👓"),
        HindiLetter(letter: "ओ", roman: "O", word: "ओखली", wordRoman: "Okhlee", wordMeaning: "Mortar", emoji: "🥣"),
        HindiLetter(letter: "औ", roman: "Au", word: "औरत", wordRoman: "Aurat", wordMeaning: "Woman", emoji: "👩"),
        HindiLetter(letter: "अं", roman: "An", word: "अंगूर", wordRoman: "Angoor", wordMeaning: "Grapes", emoji: "🍇"),
        HindiLetter(letter: "अः", roman: "Ah", word: "अःहा", wordRoman: "Ahaa", wordMeaning: "Aha!", emoji: "😄")
    ]

    /// व्यंजन — the consonants with classic chart words.
    static let consonants: [HindiLetter] = [
        HindiLetter(letter: "क", roman: "K", word: "कबूतर", wordRoman: "Kabootar", wordMeaning: "Pigeon", emoji: "🕊️"),
        HindiLetter(letter: "ख", roman: "Kh", word: "खरगोश", wordRoman: "Khargosh", wordMeaning: "Rabbit", emoji: "🐇"),
        HindiLetter(letter: "ग", roman: "G", word: "गमला", wordRoman: "Gamlaa", wordMeaning: "Flower pot", emoji: "🪴"),
        HindiLetter(letter: "घ", roman: "Gh", word: "घर", wordRoman: "Ghar", wordMeaning: "House", emoji: "🏠"),
        HindiLetter(letter: "ङ", roman: "Nga", word: "", wordRoman: "Nga",
                    wordMeaning: "The 'ng' sound, as in रंग (rang)", emoji: "🌈",
                    spokenOverride: "ङ्ग! जैसे रंग!"),
        HindiLetter(letter: "च", roman: "Ch", word: "चरखा", wordRoman: "Charkhaa", wordMeaning: "Spinning wheel", emoji: "🧵"),
        HindiLetter(letter: "छ", roman: "Chh", word: "छतरी", wordRoman: "Chhataree", wordMeaning: "Umbrella", emoji: "☂️"),
        HindiLetter(letter: "ज", roman: "J", word: "जहाज", wordRoman: "Jahaaj", wordMeaning: "Ship", emoji: "🚢"),
        HindiLetter(letter: "झ", roman: "Jh", word: "झंडा", wordRoman: "Jhandaa", wordMeaning: "Flag", emoji: "🚩"),
        HindiLetter(letter: "ञ", roman: "Nya", word: "", wordRoman: "Nya",
                    wordMeaning: "The 'ny' sound, as in पंजा (panja)", emoji: "🐾",
                    spokenOverride: "ञ्ज! जैसे पंजा!"),
        HindiLetter(letter: "ट", roman: "T", word: "टमाटर", wordRoman: "Tamaatar", wordMeaning: "Tomato", emoji: "🍅"),
        HindiLetter(letter: "ठ", roman: "Th", word: "ठठेरा", wordRoman: "Thatheraa", wordMeaning: "Tinsmith", emoji: "🔨"),
        HindiLetter(letter: "ड", roman: "D", word: "डमरू", wordRoman: "Damaroo", wordMeaning: "Hand drum", emoji: "🥁"),
        HindiLetter(letter: "ढ", roman: "Dh", word: "ढक्कन", wordRoman: "Dhakkan", wordMeaning: "Lid", emoji: "🍲"),
        HindiLetter(letter: "ण", roman: "N", word: "फण", wordRoman: "Phan", wordMeaning: "Cobra hood", emoji: "🐍"),
        HindiLetter(letter: "त", roman: "T", word: "तरबूज", wordRoman: "Tarbooj", wordMeaning: "Watermelon", emoji: "🍉"),
        HindiLetter(letter: "थ", roman: "Th", word: "थरमस", wordRoman: "Tharamas", wordMeaning: "Thermos", emoji: "🫙"),
        HindiLetter(letter: "द", roman: "D", word: "दवात", wordRoman: "Dawaat", wordMeaning: "Inkpot", emoji: "🖋️"),
        HindiLetter(letter: "ध", roman: "Dh", word: "धनुष", wordRoman: "Dhanush", wordMeaning: "Bow", emoji: "🏹"),
        HindiLetter(letter: "न", roman: "N", word: "नल", wordRoman: "Nal", wordMeaning: "Tap", emoji: "🚰"),
        HindiLetter(letter: "प", roman: "P", word: "पतंग", wordRoman: "Patang", wordMeaning: "Kite", emoji: "🪁"),
        HindiLetter(letter: "फ", roman: "Ph", word: "फल", wordRoman: "Phal", wordMeaning: "Fruit", emoji: "🍎"),
        HindiLetter(letter: "ब", roman: "B", word: "बत्तख", wordRoman: "Batakh", wordMeaning: "Duck", emoji: "🦆"),
        HindiLetter(letter: "भ", roman: "Bh", word: "भालू", wordRoman: "Bhaaloo", wordMeaning: "Bear", emoji: "🐻"),
        HindiLetter(letter: "म", roman: "M", word: "मछली", wordRoman: "Machhalee", wordMeaning: "Fish", emoji: "🐟"),
        HindiLetter(letter: "य", roman: "Y", word: "यज्ञ", wordRoman: "Yagya", wordMeaning: "Sacred fire", emoji: "🔥"),
        HindiLetter(letter: "र", roman: "R", word: "रथ", wordRoman: "Rath", wordMeaning: "Chariot", emoji: "🐎"),
        HindiLetter(letter: "ल", roman: "L", word: "लट्टू", wordRoman: "Lattoo", wordMeaning: "Spinning top", emoji: "🪀"),
        HindiLetter(letter: "व", roman: "V", word: "वक", wordRoman: "Vak", wordMeaning: "Stork", emoji: "🪿"),
        HindiLetter(letter: "श", roman: "Sh", word: "शलगम", wordRoman: "Shalgam", wordMeaning: "Turnip", emoji: "🥕"),
        HindiLetter(letter: "ष", roman: "Sh", word: "षट्कोण", wordRoman: "Shatkon", wordMeaning: "Hexagon", emoji: "🔶"),
        HindiLetter(letter: "स", roman: "S", word: "सपेरा", wordRoman: "Saperaa", wordMeaning: "Snake charmer", emoji: "🪈"),
        HindiLetter(letter: "ह", roman: "H", word: "हंस", wordRoman: "Hans", wordMeaning: "Swan", emoji: "🦢"),
        HindiLetter(letter: "क्ष", roman: "Ksh", word: "क्षत्रिय", wordRoman: "Kshatriya", wordMeaning: "Warrior", emoji: "🛡️"),
        HindiLetter(letter: "त्र", roman: "Tr", word: "त्रिशूल", wordRoman: "Trishul", wordMeaning: "Trident", emoji: "🔱"),
        HindiLetter(letter: "ज्ञ", roman: "Gy", word: "ज्ञानी", wordRoman: "Gyanee", wordMeaning: "Wise sage", emoji: "🧙‍♂️"),
        HindiLetter(letter: "श्र", roman: "Shr", word: "श्रमिक", wordRoman: "Shramik", wordMeaning: "Worker", emoji: "👷"),
        HindiLetter(letter: "ड़", roman: "D", word: "भेड़", wordRoman: "Bhed", wordMeaning: "Sheep", emoji: "🐑"),
        HindiLetter(letter: "ढ़", roman: "Rh", word: "ओढ़नी", wordRoman: "Orhanee", wordMeaning: "Shawl", emoji: "🧣")
    ]

    /// Full varnamala in chart order: vowels, then consonants.
    static let letters: [HindiLetter] = vowels + consonants
}
