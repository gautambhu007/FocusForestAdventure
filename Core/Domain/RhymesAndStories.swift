//
//  RhymesAndStories.swift
//  Focus Forest Adventure
//
//  Nursery rhymes (traditional Hindi folk rhymes — public domain) and
//  moral stories (classic Panchatantra/Aesop fables retold in simple
//  original wording). All narrated offline via hi-IN speech.
//

import Foundation

// MARK: - Rhymes

struct NurseryRhyme: Identifiable, Sendable {
    let id: String
    let emoji: String
    let title: String
    let lines: [String]
}

enum RhymeCatalog {
    static let rhymes: [NurseryRhyme] = [
        NurseryRhyme(id: "machli", emoji: "🐟", title: "मछली जल की रानी है", lines: [
            "मछली जल की रानी है",
            "जीवन उसका पानी है",
            "हाथ लगाओ डर जाएगी",
            "बाहर निकालो मर जाएगी"
        ]),
        NurseryRhyme(id: "chanda", emoji: "🌙", title: "चंदा मामा दूर के", lines: [
            "चंदा मामा दूर के",
            "पुए पकाएँ गुड़ के",
            "आप खाएँ थाली में",
            "मुन्ने को दें प्याली में"
        ]),
        NurseryRhyme(id: "haathi", emoji: "🐘", title: "हाथी राजा", lines: [
            "हाथी राजा बहुत बड़े",
            "सूंड उठाकर कहाँ चले",
            "मेरे घर भी आओ ना",
            "हलवा पूरी खाओ ना"
        ]),
        NurseryRhyme(id: "aloo", emoji: "🥔", title: "आलू कचालू", lines: [
            "आलू कचालू बेटा कहाँ गए थे",
            "बंदर की झोपड़ी में सो रहे थे",
            "बंदर ने लात मारी रो रहे थे",
            "मम्मी ने प्यार किया हँस रहे थे"
        ]),
        NurseryRhyme(id: "morni", emoji: "🦚", title: "नानी तेरी मोरनी", lines: [
            "नानी तेरी मोरनी को मोर ले गए",
            "बाकी जो बचा था काले चोर ले गए",
            "खाके पीके मोटे होके चोर बैठे रेल में",
            "चोरों वाला डिब्बा कटके पहुँचा सीधे जेल में"
        ])
    ]
}

// MARK: - Moral stories

struct MoralStory: Identifiable, Sendable {
    struct Page: Sendable {
        let hindi: String
        let english: String
    }

    let id: String
    let emoji: String
    let titleHindi: String
    let titleEnglish: String
    let pages: [Page]
    let moralHindi: String
    let moralEnglish: String
}

enum StoryCatalog {
    static let stories: [MoralStory] = [
        MoralStory(
            id: "crow", emoji: "🐦‍⬛",
            titleHindi: "प्यासा कौआ", titleEnglish: "The Thirsty Crow",
            pages: [
                .init(hindi: "गर्मी का दिन था। एक कौए को बहुत प्यास लगी।",
                      english: "It was a hot day. A crow was very thirsty."),
                .init(hindi: "उसे एक घड़ा दिखा, पर पानी बहुत नीचे था।",
                      english: "He found a pot, but the water was very low."),
                .init(hindi: "कौए ने एक-एक करके कंकड़ डाले।",
                      english: "The crow dropped pebbles in, one by one."),
                .init(hindi: "पानी ऊपर आ गया! कौए ने पानी पिया और उड़ गया।",
                      english: "The water rose up! The crow drank and flew away.")
            ],
            moralHindi: "कोशिश करने से हर मुश्किल हल होती है।",
            moralEnglish: "Where there's a will, there's a way."
        ),
        MoralStory(
            id: "tortoise", emoji: "🐢",
            titleHindi: "खरगोश और कछुआ", titleEnglish: "The Hare and the Tortoise",
            pages: [
                .init(hindi: "खरगोश को अपनी तेज़ चाल पर घमंड था।",
                      english: "The hare was proud of being fast."),
                .init(hindi: "उसने कछुए से दौड़ लगाई। कछुआ धीरे-धीरे चलता रहा।",
                      english: "He raced the tortoise. The tortoise walked slowly and steadily."),
                .init(hindi: "खरगोश ने सोचा, 'मैं थोड़ा सो लूँ।' और वह सो गया।",
                      english: "The hare thought, 'I'll nap a little,' and fell asleep."),
                .init(hindi: "कछुआ चलता रहा और जीत गया!",
                      english: "The tortoise kept going and won the race!")
            ],
            moralHindi: "धीरे और लगातार चलने वाला जीतता है।",
            moralEnglish: "Slow and steady wins the race."
        ),
        MoralStory(
            id: "lionmouse", emoji: "🦁",
            titleHindi: "शेर और चूहा", titleEnglish: "The Lion and the Mouse",
            pages: [
                .init(hindi: "एक चूहा सोते हुए शेर के ऊपर चढ़ गया।",
                      english: "A little mouse ran over a sleeping lion."),
                .init(hindi: "शेर जागा, पर उसने चूहे को छोड़ दिया।",
                      english: "The lion woke up, but let the mouse go."),
                .init(hindi: "एक दिन शेर जाल में फँस गया।",
                      english: "One day the lion was caught in a net."),
                .init(hindi: "चूहे ने जाल कुतर दिया और शेर आज़ाद हो गया!",
                      english: "The mouse nibbled the net and set the lion free!")
            ],
            moralHindi: "छोटे दोस्त भी बड़े काम आते हैं।",
            moralEnglish: "Even little friends can be great helpers."
        ),
        MoralStory(
            id: "greedydog", emoji: "🐶",
            titleHindi: "लालची कुत्ता", titleEnglish: "The Greedy Dog",
            pages: [
                .init(hindi: "एक कुत्ते को रोटी मिली। वह खुश होकर चला।",
                      english: "A dog found a roti and trotted off happily."),
                .init(hindi: "नदी में उसे अपनी परछाईं दिखी।",
                      english: "In the river he saw his own reflection."),
                .init(hindi: "उसने सोचा, 'उस कुत्ते की रोटी भी ले लूँ!' और भौंका।",
                      english: "He thought, 'I'll take that dog's roti too!' and barked."),
                .init(hindi: "उसकी अपनी रोटी पानी में गिर गई।",
                      english: "His own roti fell into the water.")
            ],
            moralHindi: "लालच बुरी बला है।",
            moralEnglish: "Greed never pays."
        )
    ]
}
