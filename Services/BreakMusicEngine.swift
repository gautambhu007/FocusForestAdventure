//
//  BreakMusicEngine.swift
//  Focus Forest Adventure
//
//  Gentle procedural music for movement breaks ("Grow Like a Tree" etc.).
//  No audio assets required: a soft sine melody is synthesized live —
//  a slow C-major pentatonic phrase timed to stretching and breathing.
//
//  CONCURRENCY RULE (same as VoiceManager/HandTrackingService): AVAudioEngine
//  does forced dispatch_syncs that ABORT when driven from Swift Concurrency
//  contexts (SwiftUI .task, MainActor). ALL engine work happens on a plain
//  serial GCD queue; only the isPlaying flag lives on @MainActor.
//

import Foundation
import AVFoundation
import os

/// Which synthesized melody to play.
enum MusicMood: Sendable {
    case gentle    // slow breathing melody (movement breaks)
    case sparkle   // brighter, quicker phrase (puzzles)

    var notes: [Double] {
        switch self {
        case .gentle:
            [261.63, 329.63, 392.00, 440.00, 523.25, 440.00, 392.00, 329.63]
        case .sparkle:
            [659.26, 783.99, 880.00, 1046.50, 987.77, 783.99, 659.26, 587.33]
        }
    }

    var secondsPerNote: Double {
        switch self {
        case .gentle: 1.0
        case .sparkle: 0.55
        }
    }

    var volume: Float {
        switch self {
        case .gentle: 0.16
        case .sparkle: 0.12
        }
    }
}

@MainActor
final class BreakMusicEngine {

    private nonisolated static let log = Logger(subsystem: "com.focusforest.adventure", category: "music")

    private(set) var isPlaying = false
    nonisolated(unsafe) private var mood: MusicMood = .gentle

    private nonisolated let workQueue = DispatchQueue(label: "com.focusforest.breakmusic", qos: .userInitiated)
    nonisolated(unsafe) private var engine: AVAudioEngine?

    /// Sample clock advanced only on the audio render thread.
    private final class Clock: @unchecked Sendable {
        var sample: Int = 0
    }

    func start(mood: MusicMood = .gentle) {
        guard !isPlaying else { return }
        isPlaying = true
        self.mood = mood
        workQueue.async { [weak self] in
            self?.startOnWorkQueue()
        }
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        workQueue.async { [weak self] in
            self?.engine?.stop()
            self?.engine = nil
        }
    }

    /// Runs on `workQueue` — plain GCD, no Swift Concurrency.
    private nonisolated func startOnWorkQueue() {
        guard engine == nil else { return }

        // Make sure the playback session is live (speech/mic flows may have
        // touched it) before spinning up our engine.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: .mixWithOthers)
        try? session.setActive(true)

        let audioEngine = AVAudioEngine()
        // CRITICAL: match the HARDWARE sample rate (48kHz on modern iPhones).
        // A hard-coded 44.1kHz source can start silently or fail outright.
        let hardwareRate = audioEngine.outputNode.outputFormat(forBus: 0).sampleRate
        let sampleRate = hardwareRate > 0 ? hardwareRate : 44_100.0

        let melody = mood.notes
        let samplesPerNote = Int(sampleRate * mood.secondsPerNote)
        let volume = mood.volume
        let clock = Clock()

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            Self.log.error("🥕 music: could not create format at \(sampleRate)Hz")
            return
        }
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let samples = buffers[0].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            for frame in 0..<Int(frameCount) {
                let position = clock.sample + frame
                let noteIndex = (position / samplesPerNote) % melody.count
                let inNote = Double(position % samplesPerNote) / sampleRate
                let frequency = melody[noteIndex]

                // Soft chime envelope: quick bloom, long fade (scaled to
                // the mood's note length).
                let noteSeconds = Double(samplesPerNote) / sampleRate
                let attack = min(inNote / 0.06, 1.0)
                let release = max(0.0, 1.0 - inNote / (noteSeconds * 0.95))
                let envelope = attack * release * release

                let t = Double(position) / sampleRate
                // Fundamental + quiet octave for a warm music-box tone.
                let tone = sin(2 * .pi * frequency * t)
                    + 0.3 * sin(2 * .pi * frequency * 2 * t)
                samples[frame] = Float(tone * envelope) * volume
            }
            clock.sample += Int(frameCount)
            return noErr
        }

        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
        do {
            try audioEngine.start()
            engine = audioEngine
            Self.log.debug("🥕 music: playing at \(sampleRate)Hz")
        } catch {
            // No music is never an error worth surfacing to a child —
            // but the console should say why.
            Self.log.error("🥕 music: engine start failed: \(error)")
            engine = nil
        }
    }
}
