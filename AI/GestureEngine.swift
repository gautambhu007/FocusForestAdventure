//
//  GestureEngine.swift
//  Focus Forest Adventure
//
//  Phase 2.6: pure hand-gesture classification. Vision supplies normalized
//  landmarks; this engine turns them into game gestures. No Vision imports —
//  fully unit-testable with synthetic points.
//

import Foundation
import CoreGraphics

/// Normalized (0…1) hand landmarks. Any point Vision couldn't see is nil.
struct HandLandmarks: Sendable, Equatable {
    var wrist: CGPoint?
    var thumbTip: CGPoint?
    var indexTip: CGPoint?
    var middleTip: CGPoint?
    var ringTip: CGPoint?
    var littleTip: CGPoint?
}

enum HandGesture: String, Sendable, Equatable {
    case pinch      // thumb + index together → "collect"
    case point      // index out, rest curled → "choose"
    case grab       // fist → "hold"
    case openPalm   // all fingers out → "hello" / release
    case none
}

struct GestureEngine: Sendable {

    /// Distances are in normalized image space.
    struct Thresholds: Sendable {
        var pinchDistance: CGFloat = 0.06
        var curledDistance: CGFloat = 0.18    // fingertip close to wrist = curled
        var extendedDistance: CGFloat = 0.26  // fingertip far from wrist = extended
    }

    var thresholds = Thresholds()

    func classify(_ hand: HandLandmarks) -> HandGesture {
        guard let wrist = hand.wrist else { return .none }

        // Pinch wins outright — it's the primary game action.
        if let thumb = hand.thumbTip, let index = hand.indexTip,
           distance(thumb, index) < thresholds.pinchDistance {
            return .pinch
        }

        let fingers = [hand.indexTip, hand.middleTip, hand.ringTip, hand.littleTip]
        let seen = fingers.compactMap { $0 }
        guard seen.count >= 3 else { return .none }   // too little data — no guess

        let extended = seen.filter { distance($0, wrist) > thresholds.extendedDistance }.count
        let curled = seen.filter { distance($0, wrist) < thresholds.curledDistance }.count

        if extended >= 3 { return .openPalm }
        if curled >= 3 {
            // Index out while the rest are curled = point; all curled = grab.
            if let index = hand.indexTip,
               distance(index, wrist) > thresholds.extendedDistance {
                return .point
            }
            return .grab
        }
        return .none
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

/// Wave = the wrist swinging left/right repeatedly within a short window.
/// Feed wrist X positions over time; `isWaving` flips true on 3 direction
/// changes inside 1.5s. Pure state machine — testable without a camera.
struct WaveDetector: Sendable {
    private var lastX: CGFloat?
    private var lastDirection: CGFloat = 0
    private var directionChanges: [TimeInterval] = []

    private let minSwing: CGFloat = 0.03
    private let window: TimeInterval = 1.5

    mutating func add(wristX: CGFloat, at time: TimeInterval) -> Bool {
        defer { lastX = wristX }
        guard let lastX else { return false }

        let delta = wristX - lastX
        guard abs(delta) > minSwing else { return isWaving(at: time) }

        let direction: CGFloat = delta > 0 ? 1 : -1
        if lastDirection != 0, direction != lastDirection {
            directionChanges.append(time)
        }
        lastDirection = direction
        return isWaving(at: time)
    }

    private mutating func isWaving(at time: TimeInterval) -> Bool {
        directionChanges.removeAll { time - $0 > window }
        return directionChanges.count >= 3
    }
}
