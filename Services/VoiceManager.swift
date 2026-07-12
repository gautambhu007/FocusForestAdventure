//
//  VoiceManager.swift
//  Focus Forest Adventure
//
//  Phase 2.2 voice input for the Bunny assistant.
//
//  Privacy rules (non-negotiable for a kids' app):
//  - Recognition is ON-DEVICE ONLY. If the device/language can't do
//    on-device recognition, voice input is simply unavailable and the UI
//    falls back to tap-to-ask chips — audio never goes to a server.
//  - Listening starts only from an explicit tap and stops automatically.
//  - Nothing is recorded to disk; transcripts live in memory only.
//
//  CONCURRENCY RULE (learned the hard way on iOS 18): SFSpeechRecognizer and
//  the audio engine do forced dispatch_syncs internally and ABORT
//  (_dispatch_assert_queue_fail / "unsafeForcedSync called from Swift
//  Concurrent context") when driven from Swift Concurrency contexts. So ALL
//  speech/audio work happens on `workQueue` — a plain serial GCD queue with
//  no Task machinery — and only the observable UI state hops to @MainActor.
//

import Foundation
import Observation
import Speech
import AVFoundation
import os

@MainActor
protocol VoiceManagerProtocol: AnyObject {
    /// True when on-device recognition is supported for the user's language.
    var isAvailable: Bool { get }
    var isListening: Bool { get }
    /// Live partial transcript while listening (UI feedback).
    var transcript: String { get }
    /// Asks for mic + speech permission. Must be called from a user action.
    func requestPermission() async -> Bool
    /// Starts on-device listening; partial results stream into `transcript`.
    func startListening() throws
    /// Stops listening and finalizes the transcript.
    func stopListening()
    /// Fires once on the main actor with the final transcript whenever
    /// listening ends — manual stop, silence auto-stop, or recognizer done.
    var onListeningFinished: ((String) -> Void)? { get set }
}

enum VoiceError: Error {
    case microphoneUnavailable
}

@Observable
@MainActor
final class VoiceManager: VoiceManagerProtocol {

    private nonisolated static let log = Logger(subsystem: "com.focusforest.adventure", category: "voice")

    // MARK: Observable state (main actor only)

    private(set) var isListening = false
    private(set) var transcript = ""
    private(set) var isAvailable = false

    /// See protocol. Set by the assistant view model.
    var onListeningFinished: ((String) -> Void)?

    // MARK: Speech/audio machinery (touched ONLY on workQueue)

    /// Plain serial queue — deliberately NOT an actor and NOT the cooperative
    /// pool. See the concurrency rule in the header.
    private nonisolated let workQueue = DispatchQueue(label: "com.focusforest.voice", qos: .userInitiated)

    nonisolated(unsafe) private var recognizer: SFSpeechRecognizer?
    nonisolated(unsafe) private let audioEngine = AVAudioEngine()
    nonisolated(unsafe) private var request: SFSpeechAudioBufferRecognitionRequest?
    nonisolated(unsafe) private var task: SFSpeechRecognitionTask?
    /// Auto-stop: reset on every partial result; fires after silence.
    nonisolated(unsafe) private var silenceWork: DispatchWorkItem?
    /// Ensures onListeningFinished fires exactly once per listening session.
    nonisolated(unsafe) private var hasNotified = false

    init() {
        // Create + probe the recognizer on the work queue, where its forced
        // syncs are harmless.
        workQueue.async { [weak self] in
            let recognizer = SFSpeechRecognizer(
                locale: Locale(identifier: Locale.preferredLanguages.first ?? "en-US")
            )
            let supported = recognizer?.supportsOnDeviceRecognition ?? false
            let locale = recognizer?.locale.identifier ?? "nil"
            self?.recognizer = recognizer
            Self.log.info("🥕 availability probe: onDevice=\(supported) locale=\(locale)")
            Task { @MainActor [weak self] in
                self?.isAvailable = supported
            }
        }
    }

    // MARK: Permission

    func requestPermission() async -> Bool {
        // Ground truth from the RUNNING app: if these keys aren't in the
        // built Info.plist, requesting authorization is an instant TCC crash.
        let hasSpeechKey = Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") is String
        let hasMicKey = Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") is String
        Self.log.info("🥕 requestPermission: plist keys — speech=\(hasSpeechKey) mic=\(hasMicKey)")
        guard hasSpeechKey, hasMicKey else {
            Self.log.error("🥕 requestPermission: USAGE KEYS MISSING FROM BUILT APP — refusing to request (would crash).")
            return false
        }

        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        var speechGranted = speechStatus == .authorized
        if speechStatus == .notDetermined {
            Self.log.info("🥕 requestPermission: asking speech auth…")
            speechGranted = await withCheckedContinuation { continuation in
                self.workQueue.async {
                    SFSpeechRecognizer.requestAuthorization { status in
                        continuation.resume(returning: status == .authorized)
                    }
                }
            }
        }
        Self.log.info("🥕 requestPermission: speech=\(speechGranted)")
        guard speechGranted else { return false }

        let micStatus = AVAudioApplication.shared.recordPermission
        var micGranted = micStatus == .granted
        if micStatus == .undetermined {
            micGranted = await withCheckedContinuation { continuation in
                self.workQueue.async {
                    AVAudioApplication.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
        Self.log.info("🥕 requestPermission: mic=\(micGranted)")
        return micGranted
    }

    // MARK: Listening

    func startListening() throws {
        guard !isListening, isAvailable else { return }
        isListening = true   // optimistic; reverted on failure from workQueue
        transcript = ""
        Self.log.info("🥕 startListening: dispatching to work queue…")

        workQueue.async { [weak self] in
            self?.startOnWorkQueue()
        }
    }

    /// Runs entirely on `workQueue` — plain GCD, no Swift Concurrency.
    private nonisolated func startOnWorkQueue() {
        guard request == nil else {
            Self.log.info("🥕 start(work): already running, ignoring")
            return
        }
        hasNotified = false

        do {
            // Record + keep playback alive; restored on stop.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true)
            Self.log.info("🥕 start(work): session active, sampleRate=\(session.sampleRate)")

            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)

            let format = inputNode.outputFormat(forBus: 0)
            Self.log.info("🥕 start(work): input format sampleRate=\(format.sampleRate) channels=\(format.channelCount)")
            guard format.sampleRate > 0, format.channelCount > 0 else {
                Self.log.error("🥕 start(work): dead input format — aborting")
                failOnWorkQueue()
                return
            }

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true   // hard privacy guarantee
            request.shouldReportPartialResults = true
            self.request = request

            // Audio-thread callback; request appends are thread-safe.
            nonisolated(unsafe) let tapRequest = request
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                tapRequest.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            Self.log.info("🥕 start(work): engine running, creating recognition task…")

            task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
                // Called on SFSpeech's own queue. Extract Sendable values,
                // do cleanup on workQueue, publish state on main.
                let text = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let failed = error != nil
                if let error {
                    Self.log.error("🥕 recognition error: \(error)")
                }
                if isFinal || failed {
                    self?.workQueue.async {
                        self?.stopOnWorkQueue()
                        self?.notifyOnWorkQueue()
                    }
                } else if text != nil {
                    // Child said something — restart the silence countdown.
                    self?.workQueue.async { self?.scheduleSilenceStopOnWorkQueue() }
                }
                Task { @MainActor [weak self] in
                    if let text { self?.transcript = text }
                }
            }
            // Safety net: if the child taps the mic and says nothing at all,
            // no partials ever arrive — end the session after a while.
            scheduleSilenceStopOnWorkQueue(after: 6.0)
            Self.log.info("🥕 start(work): listening (task=\(self.task != nil))")
        } catch {
            Self.log.error("🥕 start(work): failed: \(error)")
            failOnWorkQueue()
        }
    }

    func stopListening() {
        Self.log.info("🥕 stopListening (isListening=\(self.isListening))")
        guard isListening else { return }
        isListening = false
        workQueue.async { [weak self] in
            self?.request?.endAudio()   // let the recognizer finalize
            self?.stopOnWorkQueue()
            self?.notifyOnWorkQueue()
        }
    }

    /// Runs on `workQueue`: after ~2s without a new partial result, treat the
    /// utterance as finished — young children won't find a stop button.
    private nonisolated func scheduleSilenceStopOnWorkQueue(after delay: TimeInterval = 2.0) {
        silenceWork?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.request != nil else { return }
            Self.log.info("🥕 silence auto-stop")
            self.request?.endAudio()
            self.stopOnWorkQueue()
            self.notifyOnWorkQueue()
        }
        silenceWork = item
        workQueue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Runs on `workQueue`.
    private nonisolated func stopOnWorkQueue() {
        Self.log.info("🥕 stop(work): engineRunning=\(self.audioEngine.isRunning)")
        silenceWork?.cancel()
        silenceWork = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        task?.finish()
        task = nil
        request = nil
        restorePlaybackSessionOnWorkQueue()
    }

    /// Runs on `workQueue`: publishes the end of a session exactly once.
    private nonisolated func notifyOnWorkQueue() {
        guard !hasNotified else { return }
        hasNotified = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isListening = false
            self.onListeningFinished?(self.transcript)
        }
    }

    /// Runs on `workQueue`: rolls back a failed start.
    private nonisolated func failOnWorkQueue() {
        stopOnWorkQueue()
        notifyOnWorkQueue()   // empty transcript; the view model ignores it
    }

    /// Runs on `workQueue`: hand the audio session back to the game.
    private nonisolated func restorePlaybackSessionOnWorkQueue() {
        Self.log.info("🥕 restore playback session")
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: .mixWithOthers)
        try? session.setActive(true)
    }
}
