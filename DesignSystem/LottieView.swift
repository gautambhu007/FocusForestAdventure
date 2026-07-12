//
//  LottieView.swift
//  Focus Forest Adventure
//
//  Thin SwiftUI wrapper around Lottie (via the `lottie-ios` SPM package).
//  Falls back to an SF Symbol placeholder if the animation JSON is missing,
//  so the app never shows a blank hole during development.
//

import SwiftUI
#if canImport(Lottie)
import Lottie
#endif

/// All Lottie animations bundled in Resources/Animations.
/// Naming this enum (rather than raw strings) keeps animation usage type-safe.
enum ForestAnimation: String, CaseIterable {
    case bunnyWave      = "bunny_wave"
    case bunnyCheer     = "bunny_cheer"
    case bunnyDance     = "bunny_dance"
    case bunnyThinking  = "bunny_thinking"
    case treeGrow       = "tree_grow"
    case butterfly      = "butterfly"
    case birdFly        = "bird_fly"
    case riverFlow      = "river_flow"
    case rainbow        = "rainbow"
    case castleSparkle  = "castle_sparkle"
    case chestOpen      = "chest_open"
    case confettiBig    = "confetti_big"

    /// Placeholder shown when the JSON asset hasn't been added yet.
    var fallbackSymbol: String {
        switch self {
        case .bunnyWave, .bunnyCheer, .bunnyDance, .bunnyThinking: "hare.fill"
        case .treeGrow: "tree.fill"
        case .butterfly: "ladybug.fill"
        case .birdFly: "bird.fill"
        case .riverFlow: "water.waves"
        case .rainbow: "rainbow"
        case .castleSparkle: "building.columns.fill"
        case .chestOpen: "shippingbox.fill"
        case .confettiBig: "sparkles"
        }
    }
}

enum LottieLoopMode { case loop, playOnce, autoReverse }

struct LottieView: View {
    let animation: ForestAnimation
    var loopMode: LottieLoopMode = .loop
    var speed: Double = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        #if canImport(Lottie)
        LottieBridge(
            name: animation.rawValue,
            loopMode: reduceMotion ? .playOnce : loopMode,
            speed: reduceMotion ? 0.0 : speed,
            fallbackSymbol: animation.fallbackSymbol
        )
        #else
        fallback
        #endif
    }

    private var fallback: some View {
        Image(systemName: animation.fallbackSymbol)
            .resizable()
            .scaledToFit()
            .foregroundStyle(ForestTheme.Colors.leafGreen.gradient)
            .padding(20)
            .accessibilityHidden(true)
    }
}

#if canImport(Lottie)
private struct LottieBridge: UIViewRepresentable {
    let name: String
    let loopMode: LottieLoopMode
    let speed: Double
    let fallbackSymbol: String

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(name: name)
        view.contentMode = .scaleAspectFit
        view.loopMode = {
            switch loopMode {
            case .loop: .loop
            case .playOnce: .playOnce
            case .autoReverse: .autoReverse
            }
        }()
        view.animationSpeed = speed
        view.backgroundBehavior = .pauseAndRestore
        view.play()
        return view
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if !uiView.isAnimationPlaying { uiView.play() }
    }
}
#endif
