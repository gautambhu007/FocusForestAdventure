//
//  ImmersiveForestScene.swift
//  Focus Forest Adventure
//
//  The child's forest as an explorable, hand-drawn world instead of
//  scattered emoji. Four depth layers (sky → far hills → mid woods →
//  near meadow) pan at different speeds under one finger — classic
//  parallax that reads as 3D. Double-tap zooms INTO the forest
//  (chrome hides, world grows around you); double-tap again hops back
//  out. Foxes patrol the ground, a serpentine dragon rules the sky,
//  the castle watches from a faraway hill, butterflies and flowers
//  everywhere. Everything is drawn and animated in pure SwiftUI.
//

import SwiftUI

struct ImmersiveForestScene: View {
    let unlocked: [ForestElement]
    @Binding var isImmersed: Bool
    /// The Magic Forest opens only once something new has been earned.
    var canImmerse: Bool = true
    /// Called instead of zooming in when the child has no visit to spend.
    var onBlocked: () -> Void = {}

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0 = far left of the world, 1 = far right. Starts centered.
    @State private var panFraction: CGFloat = 0.5
    /// Vertical look-around, only while immersed.
    @State private var panYFraction: CGFloat = 0.5
    @State private var dragStart: (x: CGFloat, y: CGFloat)?

    private var night: Bool { scheme == .dark }
    private func has(_ element: ForestElement) -> Bool { unlocked.contains(element) }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let span = w * 1.6                    // world is 2.6× the screen
            let pan = panFraction * span

            ZStack(alignment: .topLeading) {
                skyLayer(w: w, h: h)
                farLayer(width: w + span * 0.30, h: h)
                    .offset(x: -pan * 0.30)
                midLayer(width: w + span * 0.55, h: h)
                    .offset(x: -pan * 0.55)
                nearLayer(width: w + span, h: h)
                    .offset(x: -pan)
            }
            .frame(width: w, height: h)
            .scaleEffect(isImmersed ? 1.55 : 1.0,
                         anchor: UnitPoint(x: 0.5, y: 0.62))
            .offset(y: isImmersed ? (0.5 - panYFraction) * 170 : 0)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { g in
                        if dragStart == nil { dragStart = (panFraction, panYFraction) }
                        guard let start = dragStart else { return }
                        panFraction = min(1, max(0, start.x - g.translation.width / span))
                        if isImmersed {
                            panYFraction = min(0.85, max(0.15, start.y - g.translation.height / 380))
                        }
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .onTapGesture(count: 2) {
                guard isImmersed || canImmerse else {
                    onBlocked()
                    return
                }
                withAnimation(.spring(response: 0.65, dampingFraction: 0.8)) {
                    isImmersed.toggle()
                    if !isImmersed { panYFraction = 0.5 }
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Sky (static backdrop + flying dragon + rainbow)

    private func skyLayer(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: night
                    ? [Color(red: 0.05, green: 0.09, blue: 0.20),
                       Color(red: 0.14, green: 0.21, blue: 0.34)]
                    : [Color(red: 0.44, green: 0.74, blue: 0.95),
                       Color(red: 0.82, green: 0.93, blue: 0.86)],
                startPoint: .top, endPoint: .bottom
            )

            if night {
                StarTwinkleField()
                MoonView().position(x: w * 0.80, y: h * 0.11)
            } else {
                SunView().position(x: w * 0.81, y: h * 0.12)
            }

            MeadowCloudLayer(night: night)

            if has(.rainbow) {
                RainbowArc()
                    .scaleEffect(w * 0.003)   // design width 300 → 90% of screen
                    .position(x: w * 0.5, y: h * 0.52 - w * 0.11)
                    .opacity(night ? 0.35 : 0.55)
            }

            if has(.dragon) {
                SkyDragon(region: CGRect(x: w * 0.08, y: h * 0.05,
                                         width: w * 0.84, height: h * 0.26))
            }
        }
        .frame(width: w, height: h)
    }

    // MARK: Far hills + castle

    private func farLayer(width: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RollingHill(baseline: 0.50, amplitude: 0.040, waves: 1.8, phase: 0.1)
                .fill(LinearGradient(
                    colors: night
                        ? [Color(red: 0.15, green: 0.25, blue: 0.30),
                           Color(red: 0.10, green: 0.18, blue: 0.23)]
                        : [Color(red: 0.62, green: 0.83, blue: 0.71),
                           Color(red: 0.51, green: 0.74, blue: 0.62)],
                    startPoint: .top, endPoint: .bottom))

            // Distant tree blobs, planted on the hill surface at their x
            ForEach(0..<5, id: \.self) { i in
                let fx = [0.12, 0.30, 0.48, 0.60, 0.90][i]
                let fy = [0.532, 0.464, 0.486, 0.531, 0.456][i]
                Ellipse()
                    .fill((night ? Color(red: 0.10, green: 0.20, blue: 0.18)
                                 : Color(red: 0.40, green: 0.63, blue: 0.50))
                        .opacity(0.85))
                    .frame(width: 46, height: 34)
                    .position(x: width * fx, y: h * fy - 8)
            }

            if has(.castle) {
                CastleSilhouette(night: night)
                    .position(x: width * 0.74, y: h * 0.517 - 49)
            }
        }
        .frame(width: width, height: h, alignment: .topLeading)
    }

    // MARK: Mid woods + treehouse

    private func midLayer(width: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RollingHill(baseline: 0.63, amplitude: 0.050, waves: 1.5, phase: 0.45)
                .fill(LinearGradient(
                    colors: night
                        ? [Color(red: 0.11, green: 0.23, blue: 0.19),
                           Color(red: 0.07, green: 0.16, blue: 0.13)]
                        : [Color(red: 0.47, green: 0.74, blue: 0.49),
                           Color(red: 0.36, green: 0.63, blue: 0.41)],
                    startPoint: .top, endPoint: .bottom))

            if has(.trees) {
                ForEach(0..<4, id: \.self) { i in
                    let fx = [0.10, 0.34, 0.58, 0.86][i]
                    // Hill-surface height at each fx, so trunks stay planted.
                    let fy = [0.601, 0.618, 0.675, 0.580][i]
                    ForestTree(sway: !reduceMotion)
                        .scaleEffect(0.62)
                        .saturation(0.85)
                        .opacity(0.95)
                        .position(x: width * fx, y: h * fy - 35)
                }
            }

            if has(.treehouse) {
                ZStack {
                    ForestTree(sway: false).scaleEffect(0.85)
                    TreehouseView().offset(y: -8)
                }
                .position(x: width * 0.72, y: h * 0.62 - 50)
            }
        }
        .frame(width: width, height: h, alignment: .topLeading)
    }

    // MARK: Near meadow — trees, river, flowers, foxes, butterflies

    private func nearLayer(width: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RollingHill(baseline: 0.76, amplitude: 0.045, waves: 2.0, phase: 0.55)
                .fill(LinearGradient(
                    colors: night
                        ? [Color(red: 0.10, green: 0.22, blue: 0.15),
                           Color(red: 0.05, green: 0.13, blue: 0.09)]
                        : [Color(red: 0.40, green: 0.72, blue: 0.42),
                           Color(red: 0.25, green: 0.53, blue: 0.31)],
                    startPoint: .top, endPoint: .bottom))

            if has(.river) {
                RiverBand(centerY: 0.865, thickness: 30, waves: 2.4)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.36, green: 0.66, blue: 0.92),
                                 Color(red: 0.24, green: 0.50, blue: 0.80)],
                        startPoint: .top, endPoint: .bottom))
                    .opacity(night ? 0.7 : 0.95)
                RiverSparkles(centerY: 0.865, width: width)
            }

            if has(.trees) {
                ForEach(0..<4, id: \.self) { i in
                    let fx = [0.06, 0.38, 0.66, 0.93][i]
                    let s: CGFloat = [1.15, 0.95, 1.25, 1.0][i]
                    // Hill-surface height at each fx, so trunks stay planted.
                    let fy = [0.720, 0.802, 0.728, 0.784][i]
                    ForestTree(sway: !reduceMotion)
                        .scaleEffect(s)
                        .position(x: width * fx, y: h * fy + 8 - 66 * s)
                }
            }

            if has(.flowers) {
                ForEach(0..<7, id: \.self) { i in
                    let fx = [0.10, 0.22, 0.33, 0.50, 0.62, 0.80, 0.90][i]
                    let petals = [Color(red: 0.97, green: 0.62, blue: 0.72),
                                  Color(red: 0.99, green: 0.80, blue: 0.40),
                                  Color(red: 0.72, green: 0.62, blue: 0.94)]
                    MeadowFlower(petal: petals[i % 3], sway: !reduceMotion)
                        .scaleEffect(0.8 + CGFloat(i % 3) * 0.14)
                        .position(x: width * fx, y: h * (0.80 + CGFloat((i * 7) % 5) * 0.014))
                }
            }

            if has(.grass) {
                ForEach(0..<8, id: \.self) { i in
                    let fx = CGFloat(i) / 8 + 0.06
                    GrassTuft(tint: night
                              ? Color(red: 0.16, green: 0.34, blue: 0.22)
                              : Color(red: 0.28, green: 0.55, blue: 0.31))
                        .position(x: width * fx, y: h * (0.83 + CGFloat((i * 5) % 4) * 0.02))
                }
            }

            if has(.animals) {
                RunningFox(patrolMinX: width * 0.08, patrolMaxX: width * 0.42,
                           baseY: h * 0.845, seed: 0)
                RunningFox(patrolMinX: width * 0.55, patrolMaxX: width * 0.90,
                           baseY: h * 0.885, seed: 1)
                    .scaleEffect(0.8)
            }

            if has(.butterflies) {
                DrawnButterfly(seed: 2, region: CGRect(x: width * 0.08, y: h * 0.52,
                                                       width: width * 0.30, height: h * 0.22))
                DrawnButterfly(tint: Color(red: 0.62, green: 0.70, blue: 0.96), seed: 3,
                               region: CGRect(x: width * 0.42, y: h * 0.56,
                                              width: width * 0.28, height: h * 0.20))
                DrawnButterfly(tint: Color(red: 0.94, green: 0.55, blue: 0.72), seed: 4,
                               region: CGRect(x: width * 0.68, y: h * 0.50,
                                              width: width * 0.26, height: h * 0.24))
            }
        }
        .frame(width: width, height: h, alignment: .topLeading)
    }
}

// MARK: - Drawn tree

/// A leafy tree with a three-lobed canopy and gentle sway, 100×140 design.
struct ForestTree: View {
    var sway = true
    @State private var lean = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(LinearGradient(colors: [Color(red: 0.58, green: 0.40, blue: 0.26),
                                              Color(red: 0.45, green: 0.30, blue: 0.19)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 13, height: 48)
                .position(x: 50, y: 112)
            Circle().fill(Color(red: 0.23, green: 0.50, blue: 0.30))
                .frame(width: 48).position(x: 28, y: 74)
            Circle().fill(Color(red: 0.20, green: 0.45, blue: 0.27))
                .frame(width: 48).position(x: 72, y: 74)
            Circle().fill(Color(red: 0.28, green: 0.58, blue: 0.35))
                .frame(width: 68).position(x: 50, y: 55)
            Circle().fill(Color(red: 0.42, green: 0.72, blue: 0.47).opacity(0.8))
                .frame(width: 20).position(x: 38, y: 44)
        }
        .frame(width: 100, height: 140)
        .rotationEffect(.degrees(lean ? 1.3 : -1.3), anchor: .bottom)
        .onAppear {
            guard sway else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                lean = true
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Castle on the faraway hill

/// A misty three-tower castle, 150×130 design, drawn (not 🏰).
struct CastleSilhouette: View {
    var night: Bool

    private var wall: Color { night ? Color(red: 0.30, green: 0.28, blue: 0.44) : Color(red: 0.62, green: 0.58, blue: 0.77) }
    private var wallDark: Color { night ? Color(red: 0.25, green: 0.23, blue: 0.38) : Color(red: 0.54, green: 0.50, blue: 0.71) }
    private var roof: Color { night ? Color(red: 0.20, green: 0.18, blue: 0.33) : Color(red: 0.42, green: 0.37, blue: 0.64) }
    private var windowGlow: Color { Color(red: 0.95, green: 0.82, blue: 0.55) }

    var body: some View {
        ZStack {
            // Towers + keep
            Rectangle().fill(wall).frame(width: 26, height: 80).position(x: 38, y: 82)
            Rectangle().fill(wall).frame(width: 26, height: 80).position(x: 112, y: 82)
            Rectangle().fill(wallDark).frame(width: 40, height: 70).position(x: 75, y: 87)
            // Cone roofs
            KidTriangle().fill(roof).frame(width: 36, height: 32).position(x: 38, y: 28)
            KidTriangle().fill(roof).frame(width: 36, height: 32).position(x: 112, y: 28)
            KidTriangle().fill(roof).frame(width: 50, height: 28).position(x: 75, y: 40)
            // Flags
            flag(x: 38); flag(x: 112)
            // Glowing windows + arched door
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(windowGlow.opacity(night ? 0.95 : 0.8))
                    .frame(width: 8, height: 14)
                    .position(x: [38.0, 75.0, 112.0][i], y: 73)
            }
            UnevenRoundedRectangle(topLeadingRadius: 9, bottomLeadingRadius: 0,
                                   bottomTrailingRadius: 0, topTrailingRadius: 9)
                .fill(roof)
                .frame(width: 18, height: 24).position(x: 75, y: 110)
        }
        .frame(width: 150, height: 130)
        .opacity(0.92)
        .accessibilityHidden(true)
    }

    private func flag(x: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(roof).frame(width: 2, height: 12).position(x: x, y: 8)
            KidTriangle()
                .fill(Color(red: 0.96, green: 0.70, blue: 0.24))
                .frame(width: 10, height: 7)
                .rotationEffect(.degrees(90))
                .position(x: x + 6, y: 5)
        }
    }
}

// MARK: - Treehouse

/// A little house on a platform with a ladder, 90×80 design.
struct TreehouseView: View {
    private let wood = Color(red: 0.62, green: 0.44, blue: 0.28)
    private let woodDark = Color(red: 0.48, green: 0.33, blue: 0.20)

    var body: some View {
        ZStack {
            // Ladder
            Path { p in
                p.move(to: CGPoint(x: 41, y: 48)); p.addLine(to: CGPoint(x: 41, y: 78))
                p.move(to: CGPoint(x: 49, y: 48)); p.addLine(to: CGPoint(x: 49, y: 78))
                for y in stride(from: 54, through: 74, by: 7) {
                    p.move(to: CGPoint(x: 41, y: CGFloat(y)))
                    p.addLine(to: CGPoint(x: 49, y: CGFloat(y)))
                }
            }
            .stroke(woodDark, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            // Platform
            RoundedRectangle(cornerRadius: 3).fill(woodDark)
                .frame(width: 74, height: 8).position(x: 45, y: 46)
            // House
            RoundedRectangle(cornerRadius: 4).fill(wood)
                .frame(width: 46, height: 28).position(x: 45, y: 30)
            KidTriangle().fill(Color(red: 0.72, green: 0.34, blue: 0.28))
                .frame(width: 56, height: 18).position(x: 45, y: 9)
            // Round window
            Circle().fill(Color(red: 0.75, green: 0.89, blue: 0.95))
                .overlay(Circle().stroke(woodDark, lineWidth: 2))
                .frame(width: 13).position(x: 45, y: 29)
        }
        .frame(width: 90, height: 80)
        .accessibilityHidden(true)
    }
}

// MARK: - River

/// A wavy water band across the meadow.
struct RiverBand: Shape {
    var centerY: CGFloat     // fraction of height
    var thickness: CGFloat   // points
    var waves: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let mid = rect.height * centerY
        let steps = 60
        p.move(to: CGPoint(x: rect.minX, y: mid - thickness / 2))
        for i in 0...steps {
            let f = CGFloat(i) / CGFloat(steps)
            let dy = 7 * sin(f * waves * 2 * .pi)
            p.addLine(to: CGPoint(x: rect.minX + f * rect.width,
                                  y: mid - thickness / 2 + dy))
        }
        for i in stride(from: steps, through: 0, by: -1) {
            let f = CGFloat(i) / CGFloat(steps)
            let dy = 7 * sin(f * waves * 2 * .pi + 0.9)
            p.addLine(to: CGPoint(x: rect.minX + f * rect.width,
                                  y: mid + thickness / 2 + dy))
        }
        p.closeSubpath()
        return p
    }
}

/// Little white glints drifting along the river to show flow.
struct RiverSparkles: View {
    var centerY: CGFloat
    var width: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            GeometryReader { proxy in
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    ForEach(0..<5, id: \.self) { i in
                        let f = ((t * 0.05) + Double(i) * 0.2)
                            .truncatingRemainder(dividingBy: 1)
                        Capsule()
                            .fill(.white.opacity(0.55))
                            .frame(width: 16, height: 3)
                            .position(x: CGFloat(f) * width,
                                      y: proxy.size.height * centerY
                                        + CGFloat(sin(f * 15)) * 6)
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Rainbow

struct RainbowArc: View {
    private let bands: [Color] = [
        Color(red: 0.94, green: 0.35, blue: 0.32),
        Color(red: 0.97, green: 0.62, blue: 0.25),
        Color(red: 0.99, green: 0.85, blue: 0.35),
        Color(red: 0.42, green: 0.76, blue: 0.44),
        Color(red: 0.35, green: 0.58, blue: 0.92),
        Color(red: 0.58, green: 0.44, blue: 0.85)
    ]

    var body: some View {
        ZStack {
            ForEach(0..<bands.count, id: \.self) { i in
                Circle()
                    .trim(from: 0.5, to: 1.0)
                    .stroke(bands[i], lineWidth: 9)
                    .frame(width: 280 - CGFloat(i) * 19,
                           height: 280 - CGFloat(i) * 19)
            }
        }
        .frame(width: 300, height: 150, alignment: .top)
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: - Running fox

/// A fox that trots back and forth along the meadow, legs galloping,
/// tail swishing, flipping to face its direction. 84×50 design.
struct RunningFox: View {
    var patrolMinX: CGFloat
    var patrolMaxX: CGFloat
    var baseY: CGFloat
    var seed = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            FoxSprite(legPhase: 0.6, tailPhase: 0)
                .position(x: (patrolMinX + patrolMaxX) / 2, y: baseY)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 40.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate + Double(seed) * 11
                let dist = Double(patrolMaxX - patrolMinX)
                let period = max(2.0, dist / 60.0)
                let s = (t / (2 * period)).truncatingRemainder(dividingBy: 1)
                let goingRight = s < 0.5
                let frac = goingRight ? s * 2 : 2 - s * 2
                let x = patrolMinX + CGFloat(frac) * (patrolMaxX - patrolMinX)
                let legT = t * 9
                FoxSprite(legPhase: legT, tailPhase: t * 6)
                    .scaleEffect(x: goingRight ? 1 : -1)
                    .position(x: x, y: baseY - 3.5 * abs(sin(legT)))
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

struct FoxSprite: View {
    var legPhase: Double
    var tailPhase: Double

    private let orange = Color(red: 0.91, green: 0.46, blue: 0.23)
    private let orangeDark = Color(red: 0.79, green: 0.37, blue: 0.16)
    private let cream = Color(red: 1.0, green: 0.95, blue: 0.89)
    private let dark = Color(red: 0.28, green: 0.22, blue: 0.19)

    var body: some View {
        ZStack {
            // Tail with white tip, swishing
            ZStack {
                Ellipse().fill(orange).frame(width: 34, height: 15)
                    .rotationEffect(.degrees(-25))
                Circle().fill(cream).frame(width: 12)
                    .offset(x: -14, y: -7)
            }
            .rotationEffect(.degrees(sin(tailPhase) * 9), anchor: .trailing)
            .position(x: 14, y: 21)
            // Legs (diagonal gallop pairs)
            leg(x: 28, phase: 0)
            leg(x: 37, phase: .pi)
            leg(x: 50, phase: .pi)
            leg(x: 59, phase: 0)
            // Body + chest
            Ellipse().fill(orange).frame(width: 52, height: 26).position(x: 40, y: 28)
            Ellipse().fill(cream).frame(width: 20, height: 15).position(x: 52, y: 32)
            // Ears
            KidTriangle().fill(orangeDark).frame(width: 12, height: 12).position(x: 54, y: 6)
            KidTriangle().fill(orange).frame(width: 11, height: 11).position(x: 66, y: 5)
            // Head + snout + nose + eye
            Circle().fill(orange).frame(width: 24).position(x: 61, y: 15)
            Ellipse().fill(cream).frame(width: 17, height: 9).position(x: 72, y: 20)
            Circle().fill(dark).frame(width: 4.5).position(x: 79, y: 20)
            Circle().fill(dark).frame(width: 4.5).position(x: 63, y: 12)
        }
        .frame(width: 84, height: 50)
    }

    private func leg(x: CGFloat, phase: Double) -> some View {
        Capsule().fill(orangeDark)
            .frame(width: 5.5, height: 15)
            .rotationEffect(.degrees(sin(legPhase + phase) * 26), anchor: .top)
            .position(x: x, y: 40)
    }
}

// MARK: - Sky dragon

/// A serpentine dragon that undulates across the sky: a chain of body
/// segments with golden spine spikes follows the head, wings flap, and
/// every few seconds it puffs a little (harmless) fire.
struct SkyDragon: View {
    var region: CGRect
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let gold = Color(red: 0.96, green: 0.70, blue: 0.24)
    private let dark = Color(red: 0.20, green: 0.30, blue: 0.22)

    private func segColor(_ i: Int) -> Color {
        let f = Double(i) / 8
        return Color(red: 0.23 + 0.07 * f,
                     green: 0.63 + 0.06 * f,
                     blue: 0.38 + 0.24 * f)
    }

    private func flightPos(_ t: Double) -> CGPoint {
        CGPoint(x: region.midX + 0.44 * region.width * CGFloat(sin(2 * .pi * t / 16)),
                y: region.midY + 0.40 * region.height * CGFloat(sin(2 * .pi * t / 5.3)))
    }

    var body: some View {
        if reduceMotion {
            dragonBody(t: 2.8, animate: false)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                dragonBody(t: timeline.date.timeIntervalSinceReferenceDate, animate: true)
            }
            .allowsHitTesting(false)
        }
    }

    private func dragonBody(t: Double, animate: Bool) -> some View {
        let head = flightPos(t)
        let dir: CGFloat = cos(2 * .pi * t / 16) >= 0 ? 1 : -1
        let firePhase = animate ? t.truncatingRemainder(dividingBy: 8) : 5.0
        let flap = animate ? 0.55 + 0.45 * abs(sin(t * 7)) : 0.8

        return ZStack {
            // Body segments, tail-first so the head overlaps
            ForEach((1...8).reversed(), id: \.self) { i in
                let p = flightPos(t - Double(i) * 0.20)
                let r = 15 - CGFloat(i) * 1.3
                ZStack {
                    Circle().fill(segColor(i)).frame(width: r * 2)
                    if i < 6 {
                        KidTriangle().fill(gold.opacity(0.9))
                            .frame(width: 7, height: 7)
                            .offset(y: -r - 2)
                    }
                }
                .position(p)
            }

            // Wings on the shoulder segment
            let shoulder = flightPos(t - 0.20)
            Ellipse().fill(Color(red: 0.50, green: 0.85, blue: 0.65).opacity(0.75))
                .frame(width: 18, height: 30)
                .scaleEffect(y: flap, anchor: .bottom)
                .rotationEffect(.degrees(-24))
                .position(x: shoulder.x - 8, y: shoulder.y - 20)
            Ellipse().fill(Color(red: 0.50, green: 0.85, blue: 0.65).opacity(0.6))
                .frame(width: 18, height: 30)
                .scaleEffect(y: flap, anchor: .bottom)
                .rotationEffect(.degrees(24))
                .position(x: shoulder.x + 8, y: shoulder.y - 20)

            // Fire puff
            if firePhase < 0.9 {
                let k = firePhase / 0.9
                Circle().fill(Color(red: 0.98, green: 0.55, blue: 0.20).opacity(1 - k))
                    .frame(width: 10 + k * 16)
                    .position(x: head.x + dir * (26 + CGFloat(k) * 18), y: head.y + 4)
                Circle().fill(Color(red: 1.0, green: 0.82, blue: 0.35).opacity(0.9 * (1 - k)))
                    .frame(width: 6 + k * 10)
                    .position(x: head.x + dir * (32 + CGFloat(k) * 22), y: head.y + 2)
            }

            // Head: snout, eye, horns
            Circle().fill(segColor(0)).frame(width: 30).position(head)
            Ellipse().fill(Color(red: 0.55, green: 0.86, blue: 0.66))
                .frame(width: 16, height: 11)
                .position(x: head.x + dir * 11, y: head.y + 4)
            Capsule().fill(gold).frame(width: 4, height: 12)
                .rotationEffect(.degrees(Double(-14 * dir)))
                .position(x: head.x - dir * 5, y: head.y - 16)
            Capsule().fill(gold).frame(width: 4, height: 12)
                .rotationEffect(.degrees(Double(10 * dir)))
                .position(x: head.x + dir * 3, y: head.y - 17)
            Circle().fill(.white).frame(width: 8)
                .position(x: head.x + dir * 4, y: head.y - 5)
            Circle().fill(dark).frame(width: 4.5)
                .position(x: head.x + dir * 5, y: head.y - 5)
        }
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Friendly Dragon flying around your forest"))
    }
}
