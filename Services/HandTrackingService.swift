//
//  HandTrackingService.swift
//  Focus Forest Adventure
//
//  Phase 2.6: front-camera hand tracking via Vision.
//
//  Privacy rules:
//  - Frames are processed in memory and immediately discarded — never
//    stored, never leave the device.
//  - Tracking runs only inside a gesture mini-game, started by an explicit
//    tap, and stops the moment the game ends.
//
//  Concurrency: same rule as VoiceManager — ALL AVFoundation/Vision work on
//  a plain serial GCD queue, only observable state on @MainActor.
//

import Foundation
import Observation
import AVFoundation
import Vision
import CoreGraphics
import os

@MainActor
protocol HandTrackingServiceProtocol: AnyObject {
    var isAvailable: Bool { get }
    var isTracking: Bool { get }
    /// Latest classified gesture.
    var gesture: HandGesture { get }
    /// Normalized index-fingertip position (mirrored for the front camera,
    /// origin top-left) — the game cursor. Nil when no hand is visible.
    var pointerPosition: CGPoint? { get }
    /// Increments each time a wave (repeated left-right swings) is detected.
    var waveCount: Int { get }
    func requestPermission() async -> Bool
    func startTracking()
    func stopTracking()
}

@Observable
@MainActor
final class HandTrackingService: NSObject, HandTrackingServiceProtocol {

    private nonisolated static let log = Logger(subsystem: "com.focusforest.adventure", category: "hands")

    // MARK: Observable state (main actor)

    private(set) var isTracking = false
    private(set) var gesture: HandGesture = .none
    private(set) var pointerPosition: CGPoint?
    private(set) var waveCount = 0

    var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    // MARK: Capture machinery (workQueue only)

    private nonisolated let workQueue = DispatchQueue(label: "com.focusforest.hands", qos: .userInitiated)
    nonisolated(unsafe) private var captureSession: AVCaptureSession?
    nonisolated(unsafe) private let engine = GestureEngine()
    nonisolated(unsafe) private var waveDetector = WaveDetector()
    /// Vision is throttled — every frame is wasteful at 60fps.
    nonisolated(unsafe) private var lastAnalysis = Date.distantPast

    func requestPermission() async -> Bool {
        guard Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") is String else {
            Self.log.error("🥕 hands: camera usage key missing — refusing")
            return false
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                self.workQueue.async {
                    AVCaptureDevice.requestAccess(for: .video) { granted in
                        continuation.resume(returning: granted)
                    }
                }
            }
        @unknown default: return false
        }
    }

    func startTracking() {
        guard !isTracking, isAvailable else { return }
        isTracking = true
        workQueue.async { [weak self] in
            self?.startOnWorkQueue()
        }
    }

    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        gesture = .none
        pointerPosition = nil
        workQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            self?.captureSession = nil
        }
    }

    // MARK: Work queue

    private nonisolated func startOnWorkQueue() {
        guard captureSession == nil,
              let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera)
        else {
            Self.log.error("🥕 hands: no front camera / input failed")
            Task { @MainActor [weak self] in self?.isTracking = false }
            return
        }

        let session = AVCaptureSession()
        session.sessionPreset = .vga640x480   // plenty for hand pose, cheap on battery
        guard session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: workQueue)
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        captureSession = session
        session.startRunning()
        Self.log.debug("🥕 hands: tracking started")
    }

    private nonisolated func analyze(_ pixelBuffer: CVPixelBuffer) {
        // ~12 fps analysis cadence.
        guard Date().timeIntervalSince(lastAnalysis) > 0.08 else { return }
        lastAnalysis = Date()

        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])

        guard let observation = request.results?.first else {
            Task { @MainActor [weak self] in
                self?.gesture = .none
                self?.pointerPosition = nil
            }
            return
        }

        func point(_ joint: VNHumanHandPoseObservation.JointName) -> CGPoint? {
            guard let recognized = try? observation.recognizedPoint(joint),
                  recognized.confidence > 0.3 else { return nil }
            // Vision: origin bottom-left. Convert to top-left UI space and
            // mirror X for the front camera so movement feels natural.
            return CGPoint(x: 1.0 - recognized.location.x, y: 1.0 - recognized.location.y)
        }

        let landmarks = HandLandmarks(
            wrist: point(.wrist),
            thumbTip: point(.thumbTip),
            indexTip: point(.indexTip),
            middleTip: point(.middleTip),
            ringTip: point(.ringTip),
            littleTip: point(.littleTip)
        )
        let classified = engine.classify(landmarks)
        let pointer = landmarks.indexTip

        // Wave detection: wrist swings over time. Reset after a hit so one
        // enthusiastic wave counts once, not ten times.
        var waved = false
        if let wrist = landmarks.wrist {
            waved = waveDetector.add(wristX: wrist.x, at: Date().timeIntervalSinceReferenceDate)
            if waved { waveDetector = WaveDetector() }
        }

        Task { @MainActor [weak self] in
            guard let self, self.isTracking else { return }
            self.gesture = classified
            self.pointerPosition = pointer
            if waved { self.waveCount += 1 }
        }
    }
}

extension HandTrackingService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        analyze(pixelBuffer)
    }
}
