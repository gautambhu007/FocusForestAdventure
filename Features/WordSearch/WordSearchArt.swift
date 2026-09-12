//
//  WordSearchArt.swift
//  Focus Forest Adventure
//
//  The art contract for Word Hunt. Every sheet plays today on an emoji
//  mascot, an emoji per word and either a painted forest scene or a
//  gradient; each of those is a layer that painted art replaces by
//  dropping an image set with the right name into Assets.xcassets —
//  nothing else changes. The names are fixed here and listed for artists
//  in docs/WordSearch/ArtContract.md.
//
//  Same pattern as `ForestAnimation.isBundled`: presence is checked once
//  per name and cached, and a missing asset is a fallback, never an error.
//

import os
import SwiftUI

/// The mascot's animation states, from the brief's §13. `idle` is the
/// resting loop; the rest are short reactions the play screen requests.
enum WordSearchMascotState: String, CaseIterable, Sendable {
    case idle = "Idle"
    case look = "Look"
    case point = "Point"
    case wordFound = "WordFound"
    case happy = "Happy"
    case celebrate = "Celebrate"
    case encourage = "Encourage"
    case hint = "Hint"
}

enum WordSearchArt {

    // MARK: Names

    /// `WS_CHAR_07_Idle` — the character for sheet 7 at rest.
    static func mascotName(sheet: Int, state: WordSearchMascotState) -> String {
        "WS_CHAR_\(twoDigits(sheet))_\(state.rawValue)"
    }

    /// `WS_ENV_07` — the painted scene behind sheet 7's page.
    static func sceneName(sheet: Int) -> String {
        "WS_ENV_\(twoDigits(sheet))"
    }

    /// `WS_WORD_BEE` — the little picture beside the word in WORDS TO FIND.
    static func wordName(_ word: String) -> String {
        "WS_WORD_\(word.uppercased())"
    }

    private static func twoDigits(_ number: Int) -> String {
        number < 10 ? "0\(number)" : "\(number)"
    }

    // MARK: Lookup

    /// The asset if it has been added to the catalog, else nil so the
    /// caller falls back. Cached per name; the catalog can't change at
    /// runtime.
    static func image(named name: String) -> Image? {
        isBundled(name) ? Image(name) : nil
    }

    static func isBundled(_ name: String) -> Bool {
        cache.withLock { cache in
            if let known = cache[name] { return known }
            let present = UIImage(named: name) != nil
            cache[name] = present
            return present
        }
    }

    private static let cache = OSAllocatedUnfairLock(initialState: [String: Bool]())

    static func mascot(sheet: Int, state: WordSearchMascotState) -> Image? {
        image(named: mascotName(sheet: sheet, state: state))
            // A character with only an idle pose still shows up in every state.
            ?? image(named: mascotName(sheet: sheet, state: .idle))
    }

    static func scene(sheet: Int) -> Image? {
        image(named: sceneName(sheet: sheet))
    }

    static func wordPicture(_ word: String) -> Image? {
        image(named: wordName(word))
    }
}

// MARK: - Scenes the forest already paints

extension WordSearchPalette {
    /// A painted place for the themes the forest can already stand in.
    /// Nil means the sheet keeps its gradient until `WS_ENV_nn` arrives.
    var forestPlace: ForestPlace? {
        switch self {
        case .meadow: .meadow
        case .enchanted, .jungle: .deepWoods
        case .mountain, .rescue: .glade
        case .river: .riverbank
        case .autumn, .harvest: .dusk
        case .space, .cave: .night
        case .fantasy, .celebration: .magicGrove
        case .farm, .ocean, .prehistoric, .city, .beach, .winter, .tropical,
             .savanna, .arctic, .robot, .construction, .railway: nil
        }
    }
}

// MARK: - Mascot

/// The character beside the panel. A painted pose if the sheet has one;
/// otherwise the sheet's emoji, moved the way the state asks.
struct WordSearchMascotView: View {
    let sheet: WordSearchSheet
    let state: WordSearchMascotState
    var size: CGFloat = 44

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let painted = WordSearchArt.mascot(sheet: sheet.number, state: state) {
                painted
                    .resizable()
                    .scaledToFit()
            } else {
                Text(sheet.mascot)
                    .font(.system(size: size))
            }
        }
        .frame(width: size * 1.3, height: size * 1.3)
        .scaleEffect(motion.scale)
        .rotationEffect(motion.tilt)
        .offset(y: motion.lift)
        .animation(reduceMotion ? nil : .bouncy(duration: 0.35), value: state)
        .accessibilityHidden(true)
    }

    /// What the character does in each state until a rigged one does it
    /// properly: a big bounce to celebrate, a small tilt to encourage, a
    /// lean toward the grid for a hint. The found-word hop is a separate
    /// keyframe animation (`WordSearchMascotHop`) because it travels.
    private struct Motion {
        var scale: CGFloat = 1
        var tilt: Angle = .zero
        var lift: CGFloat = 0
    }

    private var motion: Motion {
        guard !reduceMotion else { return Motion() }
        switch state {
        case .idle, .look: return Motion()
        case .point, .hint: return Motion(scale: 1.05, tilt: .degrees(-12), lift: 2)
        case .wordFound: return Motion()                      // the hop animation carries this one
        case .happy: return Motion(scale: 1.25, lift: -10)
        case .celebrate: return Motion(scale: 1.4, tilt: .degrees(8), lift: -16)
        case .encourage: return Motion(scale: 0.95, tilt: .degrees(-6))
        }
    }
}

// MARK: - The victory lap

/// How long each leg of the lap takes, in seconds. Total ≈ 2.6s: slower
/// than the brief's 0.5–1.0s on purpose — Gautam found the quick version
/// frustrating to watch, and a child has just done something good.
enum WordSearchLapTiming {
    static let run = 0.9, drop = 0.6, home = 1.1
    static var total: Double { run + drop + home }
    /// When the two footfalls happen — the landing at the bottom-left and
    /// the landing back home — for the "ping!" that goes with them.
    static var landings: [Double] { [run + drop * 0.85, total] }
}

/// The found-word reaction, as Gautam described it: the character runs
/// from its corner along the top of the panel to the left, hops down to
/// the bottom-left corner, then takes one big diagonal hop back up to
/// the top-right corner where it sat. Keyed on the play view model's
/// `sparkleTrigger`; pass 0 as the trigger under Reduce Motion and it
/// never moves. `runDistance` is how far left the top-left corner is,
/// `dropDistance` how far down the bottom edge is.
struct WordSearchMascotHop<Content: View>: View {
    let trigger: Int
    let runDistance: CGFloat
    let dropDistance: CGFloat
    @ViewBuilder let content: () -> Content

    private struct Lap {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var scale: CGFloat = 1
        /// -1 faces left (running away), +1 faces right (coming home).
        var facing: CGFloat = 1
    }

    /// Timing of the three legs, in seconds.
    private var run: Double { WordSearchLapTiming.run }
    private var drop: Double { WordSearchLapTiming.drop }
    private var home: Double { WordSearchLapTiming.home }

    var body: some View {
        let left = -max(0, runDistance), bottom = max(0, dropDistance)
        KeyframeAnimator(initialValue: Lap(), trigger: trigger) { lap in
            content()
                .scaleEffect(x: lap.facing * lap.scale, y: lap.scale)
                .offset(x: lap.x, y: lap.y)
        } keyframes: { _ in
            KeyframeTrack(\.x) {
                CubicKeyframe(left, duration: run)                  // run left along the top
                LinearKeyframe(left, duration: drop)                // stay in the left column
                CubicKeyframe(0, duration: home)                    // diagonal hop home
            }
            KeyframeTrack(\.y) {
                // Little bobs while running, so it reads as steps.
                CubicKeyframe(-8, duration: run * 0.25)
                CubicKeyframe(0, duration: run * 0.25)
                CubicKeyframe(-8, duration: run * 0.25)
                CubicKeyframe(0, duration: run * 0.25)
                // Hop down: a small lift, then the fall, then a landing bounce.
                CubicKeyframe(-24, duration: drop * 0.3)
                CubicKeyframe(bottom, duration: drop * 0.55)
                CubicKeyframe(bottom - 10, duration: drop * 0.15)
                // The big diagonal: up over an arc and down onto the corner.
                CubicKeyframe(bottom * 0.3 - 60, duration: home * 0.5)
                SpringKeyframe(0, duration: home * 0.5, spring: .bouncy)
            }
            KeyframeTrack(\.facing) {
                LinearKeyframe(-1, duration: 0.05)                       // turn to run left
                LinearKeyframe(-1, duration: run + drop - 0.05)
                LinearKeyframe(1, duration: 0.05)                        // turn for the hop home
                LinearKeyframe(1, duration: home - 0.05)
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(1.18, duration: run * 0.3)             // grows a little as it sets off
                LinearKeyframe(1.18, duration: run * 0.7)
                CubicKeyframe(1.05, duration: drop * 0.85)           // squash on landing
                CubicKeyframe(1.22, duration: drop * 0.15)
                CubicKeyframe(1.35, duration: home * 0.5)            // biggest at the top of the arc
                SpringKeyframe(1, duration: home * 0.5, spring: .bouncy)
            }
        }
    }
}

// MARK: - Word picture

/// The picture beside a word: painted if it exists, else the emoji.
struct WordSearchWordPicture: View {
    let word: WordSearchWord

    var body: some View {
        if let painted = WordSearchArt.wordPicture(word.text) {
            painted.resizable().scaledToFit().frame(width: 28, height: 28)
        } else {
            Text(word.emoji).font(.title3)
        }
    }
}

// MARK: - Scene

/// What the page stands on: a painted `WS_ENV_nn` for the sheet, else a
/// place the forest already paints, else a scene painted in code for the
/// theme (`WordSearchPaintedScene`), else — unreachable today, every
/// palette has one of the two — the palette's gradient.
struct WordSearchSceneBackground: View {
    let sheet: WordSearchSheet

    var body: some View {
        if let painted = WordSearchArt.scene(sheet: sheet.number) {
            painted
                .resizable()
                .scaledToFill()
                .overlay(ForestTheme.Colors.cloudWhite.opacity(0.25))
        } else if let place = sheet.palette.forestPlace {
            ForestSceneBackground(place: place, legibility: 0.4)
        } else if let family = sheet.palette.paintedScene {
            WordSearchPaintedScene(family: family, seed: sheet.number, legibility: 0.3)
        } else {
            LinearGradient(colors: [sheet.palette.tint.opacity(0.55), ForestTheme.Colors.cloudWhite],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}
