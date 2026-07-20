//
//  Forest3DAmbience.swift
//  Focus Forest Adventure
//
//  Procedural ambient sound for the 3D forest — no audio files.
//  Meadow: soft wind + random birdsong chirps. Cottage: warm fire
//  crackle. Castle: deep stone hum with echoing water drips.
//  Treehouse: gentle high birds + wind.
//
//  Follows the project's iOS 18 audio rule: everything runs on a plain
//  GCD queue + the audio render thread. No Swift Concurrency near
//  AVFoundation.
//

import AVFoundation
import os

enum AmbienceMood: Int {
    case meadow, cottage, castle, treehouse
}

final class Forest3DAmbience {

    private nonisolated static let log = Logger(subsystem: "com.focusforest.adventure", category: "ambience")

    private nonisolated let workQueue = DispatchQueue(label: "com.focusforest.ambience", qos: .userInitiated)
    nonisolated(unsafe) private var engine: AVAudioEngine?
    nonisolated(unsafe) private var started = false

    /// Written on the work queue, read on the audio render thread.
    private final class MoodBox: @unchecked Sendable {
        var mood: AmbienceMood = .meadow
    }
    private nonisolated let moodBox = MoodBox()

    /// All DSP state — touched ONLY on the audio render thread.
    private final class DSP: @unchecked Sendable {
        var rng: UInt64 = 0x9E3779B97F4A7C15
        var windLP: Float = 0
        var brown: Float = 0
        var chirpT: Float = -1          // <0 = idle
        var chirpDur: Float = 0.22
        var chirpF0: Float = 2400
        var chirpF1: Float = 1800
        var chirpPhase: Float = 0
        var nextChirp: Float = 1.0
        var crackleAmp: Float = 0
        var nextCrackle: Float = 0.1
        var dripT: Float = -1
        var dripPhase: Float = 0
        var nextDrip: Float = 2.0
        var dronePhase: Float = 0
        var lfoPhase: Float = 0
        func white() -> Float {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            return Float((rng >> 33) & 0xFFFFFF) / Float(0xFFFFFF) * 2 - 1
        }
    }

    func start(mood: AmbienceMood) {
        moodBox.mood = mood
        guard !started else { return }
        started = true
        workQueue.async { [weak self] in self?.startOnWorkQueue() }
    }

    func setMood(_ mood: AmbienceMood) {
        moodBox.mood = mood
    }

    func stop() {
        guard started else { return }
        started = false
        workQueue.async { [weak self] in
            self?.engine?.stop()
            self?.engine = nil
        }
    }

    private nonisolated func startOnWorkQueue() {
        guard engine == nil else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: .mixWithOthers)
        try? session.setActive(true)

        let audioEngine = AVAudioEngine()
        let hardwareRate = audioEngine.outputNode.outputFormat(forBus: 0).sampleRate
        let sampleRate = Float(hardwareRate > 0 ? hardwareRate : 44_100)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1) else {
            Self.log.error("🥕 ambience: no format at \(sampleRate)Hz")
            return
        }
        let dsp = DSP()
        let moods = moodBox

        let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let out = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let mood = moods.mood
            let dt: Float = 1 / sampleRate
            for frame in 0..<Int(frameCount) {
                var sample: Float = 0
                switch mood {
                case .meadow, .treehouse:
                    // Wind: heavily low-passed noise, slowly breathing
                    dsp.lfoPhase += dt * 0.13
                    let breathe = 0.6 + 0.4 * sinf(dsp.lfoPhase * 2 * .pi)
                    dsp.windLP += 0.015 * (dsp.white() - dsp.windLP)
                    sample += dsp.windLP * 0.55 * breathe
                    // Birdsong
                    if dsp.chirpT < 0 {
                        dsp.nextChirp -= dt
                        if dsp.nextChirp <= 0 {
                            dsp.chirpT = 0
                            dsp.chirpDur = 0.14 + abs(dsp.white()) * 0.18
                            let base: Float = mood == .treehouse ? 2900 : 2300
                            dsp.chirpF0 = base + dsp.white() * 500
                            dsp.chirpF1 = dsp.chirpF0 - 400 - abs(dsp.white()) * 500
                            dsp.nextChirp = 0.9 + abs(dsp.white()) * 3.2
                        }
                    } else {
                        let x = dsp.chirpT / dsp.chirpDur
                        if x >= 1 {
                            dsp.chirpT = -1
                        } else {
                            let freq = dsp.chirpF0 + (dsp.chirpF1 - dsp.chirpF0) * x
                                + 220 * sinf(x * 22)
                            dsp.chirpPhase += 2 * .pi * freq * dt
                            sample += sinf(dsp.chirpPhase) * sinf(.pi * x) * 0.10
                            dsp.chirpT += dt
                        }
                    }
                case .cottage:
                    // Warm fire: leaky-integrated (brown) noise + crackles
                    dsp.brown = (dsp.brown + 0.02 * dsp.white()) * 0.985
                    sample += dsp.brown * 1.6
                    dsp.nextCrackle -= dt
                    if dsp.nextCrackle <= 0 {
                        dsp.crackleAmp = 0.25 + abs(dsp.white()) * 0.3
                        dsp.nextCrackle = 0.05 + abs(dsp.white()) * 0.45
                    }
                    if dsp.crackleAmp > 0.001 {
                        sample += dsp.white() * dsp.crackleAmp
                        dsp.crackleAmp *= 1 - 900 * dt   // ~1ms snap decay
                        if dsp.crackleAmp < 0 { dsp.crackleAmp = 0 }
                    }
                case .castle:
                    // Deep stone hum + echoing drips
                    dsp.dronePhase += 2 * .pi * 66 * dt
                    dsp.lfoPhase += dt * 0.07
                    let swell = 0.7 + 0.3 * sinf(dsp.lfoPhase * 2 * .pi)
                    sample += (sinf(dsp.dronePhase) * 0.05
                        + sinf(dsp.dronePhase * 2.01) * 0.02) * swell
                    if dsp.dripT < 0 {
                        dsp.nextDrip -= dt
                        if dsp.nextDrip <= 0 {
                            dsp.dripT = 0
                            dsp.dripPhase = 0
                            dsp.nextDrip = 1.6 + abs(dsp.white()) * 4
                        }
                    } else if dsp.dripT < 0.5 {
                        dsp.dripPhase += 2 * .pi * (1350 - dsp.dripT * 900) * dt
                        sample += sinf(dsp.dripPhase) * expf(-dsp.dripT * 11) * 0.14
                        dsp.dripT += dt
                    } else {
                        dsp.dripT = -1
                    }
                }
                out[frame] = sample * 0.5
            }
            return noErr
        }

        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
        do {
            try audioEngine.start()
            engine = audioEngine
            Self.log.debug("🥕 ambience: running at \(sampleRate)Hz")
        } catch {
            Self.log.error("🥕 ambience: start failed: \(error)")
            engine = nil
        }
    }
}
