//
//  MediaServices.swift
//  Focus Forest Adventure
//
//  SoundEngine (AVFoundation), SpeechService (AVSpeechSynthesizer),
//  HapticsService (CoreHaptics). All behind protocols for testability.
//

import Foundation
import AVFoundation
import AudioToolbox
import CoreHaptics
import os

// MARK: - Sound

@MainActor
protocol SoundEngineProtocol: AnyObject {
    var isMusicEnabled: Bool { get set }
    var isEffectsEnabled: Bool { get set }
    func playAmbience()
    func stopAmbience()
    /// Returns false if nothing could be played (no asset, no fallback) —
    /// callers may then use a spoken fallback.
    @discardableResult
    func play(_ effect: SoundEffect) -> Bool
}

enum SoundEffect: String, CaseIterable {
    case tapPop = "tap_pop"
    case correctChime = "correct_chime"
    case gentleTryAgain = "gentle_try_again"
    case starEarned = "star_earned"
    case chestOpen = "chest_open"
    case forestGrow = "forest_grow"
    case cardFlip = "card_flip"
    // Animal sounds for listening games
    case lionRoar = "lion_roar", cowMoo = "cow_moo", duckQuack = "duck_quack"
    case dogWoof = "dog_woof", catMeow = "cat_meow", owlHoot = "owl_hoot"

    /// Built-in system sound played when the bundled asset is missing,
    /// so UI feedback works before real audio files are added.
    var fallbackSystemSoundID: SystemSoundID? {
        switch self {
        case .tapPop, .cardFlip: 1104          // keyboard tap
        case .correctChime, .starEarned: 1025  // short positive chime
        case .chestOpen, .forestGrow: 1022
        case .gentleTryAgain: 1057             // soft neutral "tink"
        default: nil
        }
    }

    /// Bunny "performs" the animal when no recording exists.
    var spokenFallback: String? {
        switch self {
        case .lionRoar: String(localized: "Roaaar! Roaaar!")
        case .cowMoo: String(localized: "Moooo! Moooo!")
        case .duckQuack: String(localized: "Quack quack quack!")
        case .dogWoof: String(localized: "Woof woof!")
        case .catMeow: String(localized: "Meow meow!")
        case .owlHoot: String(localized: "Hoo hoo! Hoo hoo!")
        default: nil
        }
    }
}

/// Plays soft piano ambience + short positive effects. All audio is mixed at a
/// gentle volume ceiling — this is a children's app, nothing is ever loud.
@MainActor
final class SoundEngine: SoundEngineProtocol {

    var isMusicEnabled = true {
        didSet { isMusicEnabled ? playAmbience() : stopAmbience() }
    }
    var isEffectsEnabled = true

    private var ambiencePlayer: AVAudioPlayer?
    private var effectPlayers: [AVAudioPlayer] = []
    private let maxVolume: Float = 0.55   // hard ceiling — never loud

    init() {
        // .playback (not .ambient): a kids' game must be audible even when the
        // ringer/silent switch is off. mixWithOthers keeps us polite to other audio.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func playAmbience() {
        guard isMusicEnabled, ambiencePlayer?.isPlaying != true else { return }
        guard let url = Bundle.main.url(forResource: "forest_piano_ambience", withExtension: "m4a") else { return }
        ambiencePlayer = try? AVAudioPlayer(contentsOf: url)
        ambiencePlayer?.numberOfLoops = -1
        ambiencePlayer?.volume = maxVolume * 0.6
        ambiencePlayer?.play()
    }

    func stopAmbience() {
        ambiencePlayer?.setVolume(0, fadeDuration: 0.8)
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            ambiencePlayer?.stop()
        }
    }

    @discardableResult
    func play(_ effect: SoundEffect) -> Bool {
        guard isEffectsEnabled else { return true }   // intentionally silent

        if let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "m4a"),
           let player = try? AVAudioPlayer(contentsOf: url) {
            effectPlayers.removeAll { !$0.isPlaying }
            player.volume = maxVolume
            player.play()
            effectPlayers.append(player)
            return true
        }

        // No bundled asset yet — use a quiet system sound where one fits.
        if let systemID = effect.fallbackSystemSoundID {
            AudioServicesPlaySystemSound(systemID)
            return true
        }
        return false
    }
}

// MARK: - Speech (the Bunny's voice)

@MainActor
protocol SpeechServiceProtocol: AnyObject {
    var isEnabled: Bool { get set }
    /// True when an enhanced/premium (natural-sounding) voice is installed
    /// for the user's language. False means iOS will use the compact
    /// (robotic) voice — the UI can then point parents at the voice download.
    var hasNaturalVoice: Bool { get }
    func speak(_ text: String) async
    func stop()
    /// Re-scan installed voices (call on foreground: the user may have just
    /// downloaded a better voice in Settings — no relaunch required).
    func refreshVoice()
}

@MainActor
final class SpeechService: SpeechServiceProtocol {

    var isEnabled = true
    private let worker = SpeechWorker()

    var hasNaturalVoice: Bool { SpeechWorker.hasNaturalVoiceInstalled() }

    func speak(_ text: String) async {
        guard isEnabled else { return }
        worker.enqueue(text)   // returns immediately; synthesis runs off-main
    }

    func stop() {
        worker.stop()
    }

    func refreshVoice() {
        worker.refreshVoice()
    }
}

/// Runs AVSpeechSynthesizer on a serial background queue.
///
/// Why: the synthesizer loads voice assets lazily on the *calling* thread —
/// the first `speak()` can stall for seconds. Keeping every synthesizer call
/// on this queue means the UI can never freeze on speech, and the prewarm in
/// `init` pays that loading cost at launch, behind the splash screen.
final class SpeechWorker: @unchecked Sendable {

    private static let log = Logger(subsystem: "com.focusforest.adventure", category: "speech")

    private let queue = DispatchQueue(label: "com.focusforest.speech", qos: .userInitiated)
    private let synthesizer = AVSpeechSynthesizer()
    private var cachedVoice: AVSpeechSynthesisVoice?

    init() {
        queue.async { [self] in
            // Share the app's audio session instead of letting the synthesizer
            // activate/deactivate its own — its deactivation can silence all
            // later app audio (a common "speech stops working" cause).
            synthesizer.usesApplicationAudioSession = true
            cachedVoice = Self.bestVoice()      // resolve once, off-main
            let warmup = AVSpeechUtterance(string: " ")
            warmup.volume = 0
            synthesizer.speak(warmup)
        }
    }

    func enqueue(_ text: String) {
        Self.log.debug("🥕 speech enqueue")
        queue.async { [self] in
            // Must be .immediate: a deferred .word stop fires *later* and clears
            // the queue — including the utterance we're about to add. That bug
            // silences all speech after a few rapid interruptions.
            _ = synthesizer.stopSpeaking(at: .immediate)

            let utterance = AVSpeechUtterance(string: text)
            // Near-natural rate & pitch; heavy pitch shifting makes any voice robotic.
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
            utterance.pitchMultiplier = 1.08
            utterance.volume = 0.9
            utterance.voice = cachedVoice
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        queue.async { [synthesizer] in
            _ = synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// Re-rank installed voices. Cheap enough to run on every foreground:
    /// the user may have downloaded an enhanced voice while the app was
    /// backgrounded, and the old cache would keep speaking robotically.
    func refreshVoice() {
        queue.async { [self] in
            Self.log.debug("🥕 speech refreshVoice: rescanning voices…")
            cachedVoice = Self.bestVoice()
            Self.log.debug("🥕 speech refreshVoice: picked \(self.cachedVoice?.name ?? "nil") quality=\(self.cachedVoice?.quality.rawValue ?? -1)")
        }
    }

    /// True when at least one enhanced/premium voice exists for the user's
    /// language — i.e. speech won't fall back to the compact robotic voice.
    static func hasNaturalVoiceInstalled() -> Bool {
        let preferred = Locale.preferredLanguages.first ?? "en-US"
        let langPrefix = String(preferred.prefix(2))
        return AVSpeechSynthesisVoice.speechVoices().contains { voice in
            voice.language.hasPrefix(langPrefix)
                && (voice.quality == .enhanced || voice.quality == .premium)
        }
    }

    /// Picks the most natural installed voice for the user's language.
    ///
    /// `AVSpeechSynthesisVoice(language:)` returns the *compact* voice — the
    /// robotic one. Instead we scan installed voices and rank:
    /// premium > enhanced > compact, exact locale > same language.
    /// (Users can install better voices in Settings → Accessibility →
    /// Spoken Content → Voices; the app picks them up automatically.)
    private static func bestVoice() -> AVSpeechSynthesisVoice? {
        let preferred = Locale.preferredLanguages.first ?? "en-US"   // BCP-47
        let langPrefix = String(preferred.prefix(2))

        let candidates = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(langPrefix) }
            // Novelty voices ("Bells", "Bubbles"…) and Personal Voice can
            // outrank real voices by quality; neither belongs in a kids' app.
            .filter { voice in
                !voice.voiceTraits.contains(.isNoveltyVoice)
                    && !voice.voiceTraits.contains(.isPersonalVoice)
            }

        func rank(_ voice: AVSpeechSynthesisVoice) -> Int {
            var score = 0
            switch voice.quality {
            case .premium:  score += 100
            case .enhanced: score += 50
            default:        break
            }
            if voice.language == preferred { score += 10 }
            // Friendly, widely-installed US voices as tie-breakers.
            if voice.name.contains("Samantha") || voice.name.contains("Zoe") { score += 5 }
            return score
        }

        return candidates.max { rank($0) < rank($1) }
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}

// MARK: - Haptics

@MainActor
protocol HapticsServiceProtocol: AnyObject {
    func playSuccess()
    func playGentleTap()
    func playSoftWobble()
}

@MainActor
final class HapticsService: HapticsServiceProtocol {

    private var engine: CHHapticEngine?

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.resetHandler = { [weak engine] in try? engine?.start() }
        try? engine?.start()
    }

    /// Bright rising double-tap for correct answers.
    func playSuccess() {
        playPattern([
            (intensity: 0.6, sharpness: 0.4, relativeTime: 0.0),
            (intensity: 0.9, sharpness: 0.7, relativeTime: 0.12)
        ])
    }

    /// Tiny tick on every button press.
    func playGentleTap() {
        playPattern([(intensity: 0.35, sharpness: 0.5, relativeTime: 0.0)])
    }

    /// Soft, friendly wobble for "let's try again" — deliberately mild.
    func playSoftWobble() {
        playPattern([
            (intensity: 0.3, sharpness: 0.2, relativeTime: 0.0),
            (intensity: 0.2, sharpness: 0.2, relativeTime: 0.15)
        ])
    }

    private func playPattern(_ events: [(intensity: Float, sharpness: Float, relativeTime: TimeInterval)]) {
        guard let engine else { return }
        let hapticEvents = events.map {
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: $0.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: $0.sharpness)
                ],
                relativeTime: $0.relativeTime
            )
        }
        guard let pattern = try? CHHapticPattern(events: hapticEvents, parameters: []),
              let player = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }
}
