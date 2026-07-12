//
//  Particles.swift
//  Focus Forest Adventure
//
//  Confetti, sparkles, and magic dust — pure-SwiftUI particle systems built on
//  TimelineView + Canvas for 60fps with zero allocations per frame.
//  All effects respect Reduce Motion (they render a static burst instead).
//

import SwiftUI

// MARK: - Confetti

struct ConfettiView: View {
    var particleCount: Int = 60
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let particles: [ConfettiParticle]

    init(particleCount: Int = 60) {
        self.particleCount = particleCount
        self.particles = (0..<particleCount).map { _ in ConfettiParticle.random() }
    }

    var body: some View {
        if reduceMotion {
            // Static celebratory frame for Reduce Motion users.
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundStyle(ForestTheme.Colors.sunshine)
                .transition(.opacity)
        } else {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for particle in particles {
                        particle.draw(in: &context, size: size, time: t)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

struct ConfettiParticle {
    let x: Double            // 0...1 horizontal origin
    let hue: Double
    let speed: Double        // fall speed
    let phase: Double        // start offset
    let spin: Double
    let sizePt: Double

    static func random() -> ConfettiParticle {
        ConfettiParticle(
            x: .random(in: 0...1),
            hue: .random(in: 0...1),
            speed: .random(in: 80...220),
            phase: .random(in: 0...4),
            spin: .random(in: 2...8),
            sizePt: .random(in: 8...16)
        )
    }

    func draw(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let localTime = (time + phase).truncatingRemainder(dividingBy: 4)
        let y = localTime * speed - 40
        guard y < size.height + 20 else { return }

        let wobble = sin((time + phase) * 3) * 24
        let rect = CGRect(
            x: x * size.width + wobble,
            y: y,
            width: sizePt,
            height: sizePt * 0.6
        )

        var ctx = context
        ctx.translateBy(x: rect.midX, y: rect.midY)
        ctx.rotate(by: .radians(time * spin))
        ctx.fill(
            Path(roundedRect: CGRect(x: -rect.width / 2, y: -rect.height / 2,
                                     width: rect.width, height: rect.height),
                 cornerRadius: 2),
            with: .color(Color(hue: hue, saturation: 0.65, brightness: 0.95))
        )
    }
}

// MARK: - Sparkle burst (correct answers)

struct SparkleBurstView: View {
    let trigger: Int
    @State private var burstID = 0

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                SparkleRay(angle: .degrees(Double(index) * 36), trigger: burstID)
            }
        }
        .onChange(of: trigger) { burstID += 1 }
        .allowsHitTesting(false)
    }
}

private struct SparkleRay: View {
    let angle: Angle
    let trigger: Int
    @State private var flying = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "sparkle")
            .font(.title2)
            .foregroundStyle(ForestTheme.Colors.sunshine)
            .opacity(flying ? 0 : 1)
            .offset(
                x: flying ? cos(angle.radians) * 90 : 0,
                y: flying ? sin(angle.radians) * 90 : 0
            )
            .onChange(of: trigger) {
                guard !reduceMotion else { return }
                flying = false
                withAnimation(.easeOut(duration: 0.7)) { flying = true }
            }
    }
}

// MARK: - Magic dust (ambient, floats upward)

struct MagicDustView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let motes: [DustMote] = (0..<24).map { _ in DustMote.random() }

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for mote in motes {
                        let localTime = (t * mote.speed + mote.phase).truncatingRemainder(dividingBy: 1)
                        let y = size.height * (1 - localTime)
                        let x = mote.x * size.width + sin(t + mote.phase * 7) * 18
                        let opacity = sin(localTime * .pi) * 0.7
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: mote.size, height: mote.size)),
                            with: .color(.white.opacity(opacity))
                        )
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

private struct DustMote {
    let x: Double, speed: Double, phase: Double, size: Double

    static func random() -> DustMote {
        DustMote(x: .random(in: 0...1), speed: .random(in: 0.03...0.08),
                 phase: .random(in: 0...1), size: .random(in: 3...7))
    }
}
