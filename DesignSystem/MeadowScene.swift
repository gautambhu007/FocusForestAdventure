//
//  MeadowScene.swift
//  Focus Forest Adventure
//
//  A hand-drawn meadow for the home screen (and shared sprites for the
//  immersive forest): layered rolling hills with depth shading, a cottage
//  with drifting chimney smoke, a big furry waving bunny, little rabbits
//  hopping along the grass, drawn butterflies and flowers. Pure SwiftUI —
//  no emoji, no assets. Day and night palettes follow the color scheme.
//

import SwiftUI

// MARK: - Shared shapes

/// A simple triangle (roofs, ears, dragon spikes).
struct KidTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// A smooth rolling hill: everything below a gentle sine crest.
struct RollingHill: Shape {
    var baseline: CGFloat   // crest height as a fraction of rect height
    var amplitude: CGFloat  // wave amplitude as a fraction of rect height
    var waves: CGFloat      // full sine periods across the width
    var phase: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        let steps = 72
        for i in 0...steps {
            let f = CGFloat(i) / CGFloat(steps)
            let y = rect.height * (baseline + amplitude * sin((f * waves + phase) * 2 * .pi))
            p.addLine(to: CGPoint(x: rect.minX + f * rect.width, y: y))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - The big waving bunny (home screen mascot)

/// A soft, furry bunny drawn in a 160×200 design space: long ears with
/// pink linings, sparkly eyes, blush, buck teeth, whiskers, a cream belly,
/// big feet with toe pads, fur tufts — and a properly waving paw.
struct CuteBunnyView: View {
    var waving = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wave = false
    @State private var breathe = false

    private static let fur = Color(red: 0.985, green: 0.965, blue: 0.945)
    private static let furShade = Color(red: 0.885, green: 0.845, blue: 0.805)
    private static let furLine = Color(red: 0.78, green: 0.73, blue: 0.69)
    private static let belly = Color(red: 1.0, green: 0.99, blue: 0.965)
    private static let pink = Color(red: 0.975, green: 0.76, blue: 0.79)
    private static let nosePink = Color(red: 0.955, green: 0.61, blue: 0.65)
    private static let eyeBrown = Color(red: 0.28, green: 0.22, blue: 0.19)

    private var furGradient: RadialGradient {
        RadialGradient(colors: [Self.fur, Self.furShade],
                       center: .init(x: 0.42, y: 0.32),
                       startRadius: 4, endRadius: 95)
    }

    var body: some View {
        ZStack {
            // Ears (behind the head), inner pink linings
            ear(at: CGPoint(x: 57, y: 36), degrees: -10, wiggle: false)
            ear(at: CGPoint(x: 103, y: 36), degrees: 10, wiggle: true)

            // Fluffy tail peeking out
            Circle().fill(furGradient)
                .frame(width: 26, height: 26)
                .position(x: 44, y: 152)

            // Body with cream belly, breathing gently
            ZStack {
                Ellipse().fill(furGradient)
                    .frame(width: 100, height: 94)
                Ellipse().fill(Self.belly)
                    .frame(width: 62, height: 66)
                    .offset(y: 9)
                bodyFurTufts
            }
            .scaleEffect(y: breathe ? 1.025 : 0.99, anchor: .bottom)
            .position(x: 80, y: 145)

            // Big feet with pink toe pads
            foot(at: CGPoint(x: 56, y: 186))
            foot(at: CGPoint(x: 104, y: 186))

            // Resting arm
            Ellipse().fill(furGradient)
                .frame(width: 18, height: 34)
                .rotationEffect(.degrees(20))
                .position(x: 52, y: 142)

            // Head
            ZStack {
                Circle().fill(furGradient).frame(width: 88, height: 88)
                headFurTufts
                face
            }
            .position(x: 80, y: 80)

            // Waving arm + paw (rotates from the shoulder)
            ZStack(alignment: .top) {
                Capsule().fill(furGradient).frame(width: 17, height: 46)
                Circle().fill(furGradient)
                    .overlay(Circle().stroke(Self.furShade, lineWidth: 1))
                    .frame(width: 21, height: 21)
                    .offset(y: -12)
            }
            .rotationEffect(.degrees(wave ? -38 : 10), anchor: .bottom)
            .position(x: 123, y: 121)
        }
        .frame(width: 160, height: 200)
        .onAppear {
            guard !reduceMotion else { return }
            if waving {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    wave = true
                }
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .accessibilityLabel(String(localized: "Bunny waving hello"))
    }

    private func ear(at point: CGPoint, degrees: Double, wiggle: Bool) -> some View {
        ZStack {
            Ellipse().fill(furGradient).frame(width: 27, height: 68)
            Ellipse().fill(Self.pink).frame(width: 13, height: 46).offset(y: 4)
        }
        .rotationEffect(.degrees(degrees + (wiggle && wave ? 4 : 0)), anchor: .bottom)
        .position(point)
    }

    private func foot(at point: CGPoint) -> some View {
        ZStack {
            Ellipse().fill(furGradient)
                .overlay(Ellipse().stroke(Self.furShade.opacity(0.6), lineWidth: 1))
                .frame(width: 42, height: 22)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Ellipse().fill(Self.pink).frame(width: 5, height: 7)
                }
            }
            .offset(y: -4)
        }
        .position(point)
    }

    private var face: some View {
        ZStack {
            // Eyes with sparkles
            Circle().fill(Self.eyeBrown).frame(width: 14, height: 14).offset(x: -17, y: -4)
            Circle().fill(Self.eyeBrown).frame(width: 14, height: 14).offset(x: 17, y: -4)
            Circle().fill(.white).frame(width: 5, height: 5).offset(x: -14.5, y: -6.5)
            Circle().fill(.white).frame(width: 5, height: 5).offset(x: 19.5, y: -6.5)
            // Blush
            Circle().fill(Self.pink.opacity(0.55)).frame(width: 16, height: 16).offset(x: -29, y: 12)
            Circle().fill(Self.pink.opacity(0.55)).frame(width: 16, height: 16).offset(x: 29, y: 12)
            // Nose
            RoundedRectangle(cornerRadius: 5).fill(Self.nosePink)
                .frame(width: 13, height: 10).offset(y: 13)
            // Buck teeth
            HStack(spacing: 1) {
                RoundedRectangle(cornerRadius: 2).fill(.white)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Self.furShade, lineWidth: 1))
                    .frame(width: 6, height: 9)
                RoundedRectangle(cornerRadius: 2).fill(.white)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Self.furShade, lineWidth: 1))
                    .frame(width: 6, height: 9)
            }
            .offset(y: 24)
            // Whiskers
            whiskers
        }
    }

    private var whiskers: some View {
        Path { p in
            for (y1, y2) in [(8.0, 2.0), (12.0, 12.0), (16.0, 21.0)] {
                p.move(to: CGPoint(x: 25, y: 44 + y1))
                p.addLine(to: CGPoint(x: 0, y: 44 + y2))
                p.move(to: CGPoint(x: 63, y: 44 + y1))
                p.addLine(to: CGPoint(x: 88, y: 44 + y2))
            }
        }
        .stroke(Self.furLine.opacity(0.8), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        .frame(width: 88, height: 88)
    }

    private var headFurTufts: some View {
        Path { p in
            p.move(to: CGPoint(x: 36, y: 8)); p.addQuadCurve(to: CGPoint(x: 42, y: 0), control: CGPoint(x: 35, y: 2))
            p.move(to: CGPoint(x: 44, y: 6)); p.addQuadCurve(to: CGPoint(x: 49, y: -2), control: CGPoint(x: 43, y: 0))
            p.move(to: CGPoint(x: 52, y: 8)); p.addQuadCurve(to: CGPoint(x: 59, y: 1), control: CGPoint(x: 52, y: 2))
        }
        .stroke(Self.furLine.opacity(0.7), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        .frame(width: 88, height: 88)
    }

    private var bodyFurTufts: some View {
        Path { p in
            p.move(to: CGPoint(x: 8, y: 40)); p.addQuadCurve(to: CGPoint(x: 2, y: 47), control: CGPoint(x: 3, y: 41))
            p.move(to: CGPoint(x: 10, y: 56)); p.addQuadCurve(to: CGPoint(x: 3, y: 62), control: CGPoint(x: 4, y: 56))
            p.move(to: CGPoint(x: 92, y: 40)); p.addQuadCurve(to: CGPoint(x: 98, y: 47), control: CGPoint(x: 97, y: 41))
            p.move(to: CGPoint(x: 90, y: 56)); p.addQuadCurve(to: CGPoint(x: 97, y: 62), control: CGPoint(x: 96, y: 56))
        }
        .stroke(Self.furLine.opacity(0.55), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        .frame(width: 100, height: 94)
    }
}

// MARK: - Little hopping rabbit (side profile)

/// A small side-view rabbit drawn in a 56×40 design space.
struct RabbitProfile: View {
    var tint = Color(red: 0.985, green: 0.965, blue: 0.945)

    private let shade = Color(red: 0.85, green: 0.81, blue: 0.77)

    var body: some View {
        ZStack {
            // Ears leaning back
            Ellipse().fill(tint).overlay(Ellipse().stroke(shade, lineWidth: 0.8))
                .frame(width: 7, height: 20)
                .rotationEffect(.degrees(-32)).position(x: 37, y: 6)
            Ellipse().fill(tint).overlay(Ellipse().stroke(shade, lineWidth: 0.8))
                .frame(width: 7, height: 20)
                .rotationEffect(.degrees(-14)).position(x: 45, y: 5)
            // Tail
            Circle().fill(.white).overlay(Circle().stroke(shade, lineWidth: 0.8))
                .frame(width: 12, height: 12).position(x: 7, y: 24)
            // Body
            Ellipse().fill(tint).overlay(Ellipse().stroke(shade, lineWidth: 0.8))
                .frame(width: 40, height: 26).position(x: 26, y: 26)
            // Back foot
            Ellipse().fill(tint).overlay(Ellipse().stroke(shade, lineWidth: 0.8))
                .frame(width: 16, height: 7).position(x: 16, y: 37)
            // Head
            Circle().fill(tint).overlay(Circle().stroke(shade, lineWidth: 0.8))
                .frame(width: 20, height: 20).position(x: 44, y: 15)
            // Front paw
            Ellipse().fill(tint).overlay(Ellipse().stroke(shade, lineWidth: 0.8))
                .frame(width: 10, height: 6).position(x: 38, y: 36)
            // Eye + nose
            Circle().fill(Color(red: 0.28, green: 0.22, blue: 0.19))
                .frame(width: 3.4, height: 3.4).position(x: 47, y: 13)
            Circle().fill(Color(red: 0.955, green: 0.61, blue: 0.65))
                .frame(width: 2.6, height: 2.6).position(x: 53, y: 16)
        }
        .frame(width: 56, height: 40)
    }
}

/// Rabbits hopping across the meadow with a real hop cycle:
/// crouch (squash) → push off (stretch, nose up) → arc → land (nose down).
struct HoppingRabbits: View {
    /// Vertical center of the ground line, as a fraction of height.
    var groundLine: CGFloat = 0.9
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Config { let speed: Double; let phase: Double; let scale: CGFloat; let tint: Color }
    private let configs: [Config] = [
        Config(speed: 0.052, phase: 0.00, scale: 0.9,
               tint: Color(red: 0.985, green: 0.965, blue: 0.945)),
        Config(speed: 0.040, phase: 0.45, scale: 0.7,
               tint: Color(red: 0.90, green: 0.86, blue: 0.80)),
        Config(speed: 0.061, phase: 0.78, scale: 0.55,
               tint: Color(red: 0.84, green: 0.82, blue: 0.84))
    ]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let baseY = proxy.size.height * groundLine
            if reduceMotion {
                RabbitProfile().scaleEffect(0.8).position(x: w * 0.25, y: baseY)
                RabbitProfile(tint: Color(red: 0.9, green: 0.86, blue: 0.8))
                    .scaleEffect(0.6).position(x: w * 0.7, y: baseY + 6)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 40.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    ForEach(0..<configs.count, id: \.self) { i in
                        let c = configs[i]
                        let travel = (t * c.speed + c.phase)
                            .truncatingRemainder(dividingBy: 1)
                        let x = travel * (w + 140) - 70
                        // Hop cycle: 65% airborne, 35% crouched on the ground.
                        let ph = ((t + c.phase * 7) / 0.62)
                            .truncatingRemainder(dividingBy: 1)
                        let airborne = ph < 0.65
                        let k = airborne ? ph / 0.65 : 0
                        let dy = airborne ? -18 * c.scale * sin(.pi * k) : 0
                        let pitch = airborne ? -14 * cos(.pi * k) : 0
                        RabbitProfile(tint: c.tint)
                            .scaleEffect(x: airborne ? 0.97 : 1.1,
                                         y: airborne ? 1.06 : 0.86,
                                         anchor: .bottom)
                            .rotationEffect(.degrees(pitch))
                            .scaleEffect(c.scale)
                            .position(x: x, y: baseY + dy)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Drawn butterfly (replaces the 🦋 emoji)

/// A butterfly with independently flapping wings wandering inside a region.
struct DrawnButterfly: View {
    var tint: Color = Color(red: 0.96, green: 0.65, blue: 0.14)
    var seed = 0
    var region: CGRect
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            butterflyBody(flap: 0.8)
                .position(x: region.midX, y: region.midY)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate + Double(seed) * 17
                let x = region.midX + CGFloat(sin(t * 0.33) * 0.42 + sin(t * 1.1) * 0.08) * region.width
                let y = region.midY + CGFloat(cos(t * 0.47) * 0.38 + sin(t * 1.7) * 0.06) * region.height
                let flap = 0.35 + 0.65 * abs(sin(t * 9))
                butterflyBody(flap: flap)
                    .rotationEffect(.degrees(sin(t * 2.1) * 14))
                    .position(x: x, y: y)
            }
            .allowsHitTesting(false)
        }
    }

    private func butterflyBody(flap: Double) -> some View {
        ZStack {
            // Left wings (fold toward the body)
            ZStack {
                Ellipse().fill(tint.opacity(0.92)).frame(width: 16, height: 16).offset(x: -7, y: -4)
                Ellipse().fill(tint.opacity(0.65)).frame(width: 12, height: 12).offset(x: -6, y: 6)
            }
            .scaleEffect(x: flap, anchor: .trailing)
            .offset(x: -2)
            // Right wings
            ZStack {
                Ellipse().fill(tint.opacity(0.92)).frame(width: 16, height: 16).offset(x: 7, y: -4)
                Ellipse().fill(tint.opacity(0.65)).frame(width: 12, height: 12).offset(x: 6, y: 6)
            }
            .scaleEffect(x: flap, anchor: .leading)
            .offset(x: 2)
            // Body + antennae
            Capsule().fill(Color(red: 0.28, green: 0.22, blue: 0.19))
                .frame(width: 3.5, height: 18)
            Path { p in
                p.move(to: CGPoint(x: 16, y: 5))
                p.addQuadCurve(to: CGPoint(x: 11, y: 0), control: CGPoint(x: 13, y: 1))
                p.move(to: CGPoint(x: 18, y: 5))
                p.addQuadCurve(to: CGPoint(x: 23, y: 0), control: CGPoint(x: 21, y: 1))
            }
            .stroke(Color(red: 0.28, green: 0.22, blue: 0.19), lineWidth: 1.2)
            .frame(width: 34, height: 26)
        }
        .frame(width: 34, height: 26)
    }
}

// MARK: - Flowers and grass

/// A swaying five-petal flower on a stem, drawn in a 26×44 space.
struct MeadowFlower: View {
    var petal: Color = Color(red: 0.97, green: 0.62, blue: 0.72)
    var sway = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lean = false

    var body: some View {
        ZStack {
            // Stem + leaf
            Capsule().fill(Color(red: 0.35, green: 0.62, blue: 0.36))
                .frame(width: 3, height: 26).position(x: 13, y: 30)
            Ellipse().fill(Color(red: 0.42, green: 0.70, blue: 0.42))
                .frame(width: 10, height: 5)
                .rotationEffect(.degrees(-35)).position(x: 8, y: 32)
            // Petals + center
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Ellipse().fill(petal)
                        .frame(width: 9, height: 14)
                        .offset(y: -7)
                        .rotationEffect(.degrees(Double(i) * 72))
                }
                Circle().fill(Color(red: 1.0, green: 0.83, blue: 0.42))
                    .frame(width: 9, height: 9)
            }
            .position(x: 13, y: 12)
        }
        .frame(width: 26, height: 44)
        .rotationEffect(.degrees(lean ? 4 : -4), anchor: .bottom)
        .onAppear {
            guard sway, !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 2.2 + Double(petal.hashValue % 5) * 0.15)
                .repeatForever(autoreverses: true)
            ) { lean = true }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A tuft of three grass blades, drawn in an 18×16 space.
struct GrassTuft: View {
    var tint = Color(red: 0.30, green: 0.58, blue: 0.33)

    var body: some View {
        Path { p in
            p.move(to: CGPoint(x: 4, y: 16)); p.addQuadCurve(to: CGPoint(x: 1, y: 3), control: CGPoint(x: 1, y: 10))
            p.move(to: CGPoint(x: 9, y: 16)); p.addQuadCurve(to: CGPoint(x: 9, y: 1), control: CGPoint(x: 7, y: 8))
            p.move(to: CGPoint(x: 14, y: 16)); p.addQuadCurve(to: CGPoint(x: 17, y: 4), control: CGPoint(x: 17, y: 10))
        }
        .stroke(tint, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        .frame(width: 18, height: 16)
        .accessibilityHidden(true)
    }
}

// MARK: - Cottage

/// A little cottage with a smoking chimney, drawn in a 110×100 space.
struct CottageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Chimney smoke
            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    ForEach(0..<3, id: \.self) { i in
                        let ph = ((t * 0.35) + Double(i) * 0.33)
                            .truncatingRemainder(dividingBy: 1)
                        Circle()
                            .fill(.white.opacity(0.65 * (1 - ph)))
                            .frame(width: 6 + ph * 12)
                            .position(x: 76 + CGFloat(sin(ph * 5)) * 4,
                                      y: 14 - ph * 22)
                    }
                }
            }
            // Chimney
            Rectangle().fill(Color(red: 0.65, green: 0.32, blue: 0.29))
                .frame(width: 10, height: 24).position(x: 75, y: 28)
            // Roof (two tones for depth)
            KidTriangle().fill(Color(red: 0.69, green: 0.38, blue: 0.31))
                .frame(width: 94, height: 40).position(x: 55, y: 26)
            KidTriangle().fill(Color(red: 0.79, green: 0.48, blue: 0.35))
                .frame(width: 78, height: 33).position(x: 55, y: 30)
            // Walls
            Rectangle().fill(Color(red: 0.965, green: 0.905, blue: 0.81))
                .overlay(Rectangle().stroke(Color(red: 0.85, green: 0.76, blue: 0.63), lineWidth: 1))
                .frame(width: 70, height: 47).position(x: 55, y: 69.5)
            // Door + knob
            UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 0,
                                   bottomTrailingRadius: 0, topTrailingRadius: 8)
                .fill(Color(red: 0.55, green: 0.37, blue: 0.24))
                .frame(width: 17, height: 29).position(x: 66, y: 78.5)
            Circle().fill(Color(red: 0.95, green: 0.82, blue: 0.55))
                .frame(width: 3.2).position(x: 71, y: 80)
            // Window with cross frame
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.75, green: 0.89, blue: 0.95))
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .stroke(Color(red: 0.55, green: 0.37, blue: 0.24), lineWidth: 2))
                .frame(width: 19, height: 17).position(x: 37, y: 66.5)
            Path { p in
                p.move(to: CGPoint(x: 37, y: 58)); p.addLine(to: CGPoint(x: 37, y: 75))
                p.move(to: CGPoint(x: 27.5, y: 66.5)); p.addLine(to: CGPoint(x: 46.5, y: 66.5))
            }
            .stroke(Color(red: 0.55, green: 0.37, blue: 0.24), lineWidth: 1.5)
        }
        .frame(width: 110, height: 100)
        .accessibilityHidden(true)
    }
}

// MARK: - The home meadow background

/// The full home-screen backdrop: sky (sun by day, moon and stars at
/// night), drifting clouds, three hill layers shaded for depth, a cottage,
/// swaying flowers, grass tufts, butterflies, and hopping rabbits.
struct MeadowBackground: View {
    var showRabbits = true
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var night: Bool { scheme == .dark }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                // Sky
                LinearGradient(
                    colors: night
                        ? [Color(red: 0.06, green: 0.10, blue: 0.22),
                           Color(red: 0.15, green: 0.22, blue: 0.36)]
                        : [Color(red: 0.47, green: 0.76, blue: 0.95),
                           Color(red: 0.85, green: 0.94, blue: 0.88)],
                    startPoint: .top, endPoint: .bottom
                )

                if night {
                    StarTwinkleField()
                    MoonView().position(x: w * 0.78, y: h * 0.13)
                } else {
                    SunView().position(x: w * 0.79, y: h * 0.14)
                }

                MeadowCloudLayer(night: night)

                // Far hills — hazy, bluish (atmospheric depth)
                RollingHill(baseline: 0.50, amplitude: 0.045, waves: 1.2, phase: 0.15)
                    .fill(LinearGradient(
                        colors: night
                            ? [Color(red: 0.16, green: 0.26, blue: 0.30),
                               Color(red: 0.11, green: 0.19, blue: 0.24)]
                            : [Color(red: 0.66, green: 0.85, blue: 0.72),
                               Color(red: 0.55, green: 0.76, blue: 0.64)],
                        startPoint: .top, endPoint: .bottom))

                // Mid hills + cottage
                RollingHill(baseline: 0.60, amplitude: 0.055, waves: 0.9, phase: 0.45)
                    .fill(LinearGradient(
                        colors: night
                            ? [Color(red: 0.12, green: 0.24, blue: 0.20),
                               Color(red: 0.08, green: 0.17, blue: 0.14)]
                            : [Color(red: 0.50, green: 0.76, blue: 0.51),
                               Color(red: 0.38, green: 0.65, blue: 0.42)],
                        startPoint: .top, endPoint: .bottom))

                CottageView()
                    .scaleEffect(0.9)
                    .position(x: w * 0.22, y: h * 0.585)

                // Near meadow — richest green
                RollingHill(baseline: 0.735, amplitude: 0.05, waves: 0.8, phase: 0.55)
                    .fill(LinearGradient(
                        colors: night
                            ? [Color(red: 0.10, green: 0.22, blue: 0.15),
                               Color(red: 0.05, green: 0.13, blue: 0.09)]
                            : [Color(red: 0.40, green: 0.72, blue: 0.42),
                               Color(red: 0.24, green: 0.52, blue: 0.30)],
                        startPoint: .top, endPoint: .bottom))

                // Flowers + grass on the near meadow
                MeadowFlower(petal: Color(red: 0.97, green: 0.62, blue: 0.72))
                    .position(x: w * 0.09, y: h * 0.80)
                MeadowFlower(petal: Color(red: 0.99, green: 0.80, blue: 0.40))
                    .scaleEffect(0.85).position(x: w * 0.30, y: h * 0.855)
                MeadowFlower(petal: Color(red: 0.72, green: 0.62, blue: 0.94))
                    .scaleEffect(0.9).position(x: w * 0.68, y: h * 0.83)
                MeadowFlower(petal: Color(red: 0.97, green: 0.62, blue: 0.72))
                    .scaleEffect(0.75).position(x: w * 0.91, y: h * 0.86)
                GrassTuft().position(x: w * 0.18, y: h * 0.88)
                GrassTuft().position(x: w * 0.47, y: h * 0.845)
                GrassTuft().position(x: w * 0.80, y: h * 0.875)

                // Butterflies over the flowers
                DrawnButterfly(seed: 0, region: CGRect(x: w * 0.10, y: h * 0.32,
                                                       width: w * 0.5, height: h * 0.28))
                DrawnButterfly(tint: Color(red: 0.62, green: 0.70, blue: 0.96), seed: 1,
                               region: CGRect(x: w * 0.45, y: h * 0.45,
                                              width: w * 0.45, height: h * 0.25))

                if showRabbits {
                    // Sits in the visible grass band between the bunny and
                    // the bottom cards, so the hopping is never covered.
                    HoppingRabbits(groundLine: 0.685)
                }

                MagicDustView().ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Sky details

struct SunView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1.0, green: 0.90, blue: 0.55).opacity(0.55),
                                              .clear],
                                     center: .center, startRadius: 8, endRadius: 70))
                .frame(width: 140, height: 140)
                .scaleEffect(glow ? 1.12 : 0.95)
            Circle()
                .fill(RadialGradient(colors: [Color(red: 1.0, green: 0.92, blue: 0.62),
                                              Color(red: 1.0, green: 0.78, blue: 0.34)],
                                     center: .init(x: 0.4, y: 0.35),
                                     startRadius: 2, endRadius: 34))
                .frame(width: 58, height: 58)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
        .accessibilityHidden(true)
    }
}

struct MoonView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.98, green: 0.97, blue: 0.88).opacity(0.35),
                                              .clear],
                                     center: .center, startRadius: 6, endRadius: 55))
                .frame(width: 110, height: 110)
            Circle().fill(Color(red: 0.96, green: 0.95, blue: 0.86))
                .frame(width: 46, height: 46)
            Circle().fill(Color(red: 0.88, green: 0.87, blue: 0.78))
                .frame(width: 9).offset(x: -8, y: -6)
            Circle().fill(Color(red: 0.88, green: 0.87, blue: 0.78))
                .frame(width: 6).offset(x: 7, y: 8)
        }
        .accessibilityHidden(true)
    }
}

struct StarTwinkleField: View {
    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 0.25)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ForEach(0..<16, id: \.self) { i in
                    let fx = CGFloat((i * 37 % 100)) / 100
                    let fy = CGFloat((i * 53 % 41)) / 100
                    Circle()
                        .fill(.white.opacity(0.35 + 0.4 * abs(sin(t * 0.9 + Double(i)))))
                        .frame(width: i % 3 == 0 ? 3 : 2)
                        .position(x: fx * proxy.size.width,
                                  y: fy * proxy.size.height)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A soft three-lobed cloud drifting across the sky.
struct MeadowCloudLayer: View {
    var night: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<3, id: \.self) { i in
                SoftCloud()
                    .scaleEffect(0.8 + CGFloat(i) * 0.28)
                    .opacity(night ? 0.22 : 0.9)
                    .offset(
                        x: reduceMotion
                            ? proxy.size.width * 0.30 * CGFloat(i)
                            : (drift ? proxy.size.width + 120 : -160),
                        y: CGFloat(26 + i * 52)
                    )
                    .animation(
                        reduceMotion ? nil :
                            .linear(duration: 40 + Double(i) * 13)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 9),
                        value: drift
                    )
            }
        }
        .onAppear { drift = true }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SoftCloud: View {
    var body: some View {
        ZStack {
            Capsule().fill(.white).frame(width: 92, height: 30).offset(y: 10)
            Circle().fill(.white).frame(width: 38).offset(x: -20, y: -2)
            Circle().fill(.white).frame(width: 48).offset(x: 6, y: -10)
            Circle().fill(.white).frame(width: 30).offset(x: 30, y: 0)
        }
        .frame(width: 100, height: 56)
    }
}
