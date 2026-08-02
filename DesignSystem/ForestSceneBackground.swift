//
//  ForestSceneBackground.swift
//  Focus Forest Adventure
//
//  Every screen in the app stands somewhere in the forest. This file
//  paints those places: layered tree lines, a leaf-covered floor,
//  overhanging canopy, light shafts and drifting leaves — never a flat
//  gradient.
//
//  The whole scene is drawn in a single `Canvas` from a seeded RNG, so a
//  screen looks identical every time it opens and costs one rasterised
//  layer rather than hundreds of SwiftUI views. Only the drifting leaves
//  animate, in a second lightweight Canvas.
//

import SwiftUI

// MARK: - Places in the forest

/// Where a screen stands. Each place has its own palette, tree density
/// and mood, so screens feel like different clearings in one world.
enum ForestPlace: String, CaseIterable, Sendable {
    /// Open sunny meadow at the forest edge — bright, lots of sky.
    case meadow
    /// Deep among the trunks — dense, green, dim, framed by canopy.
    case deepWoods
    /// A sunlit clearing with god-rays through the leaves.
    case glade
    /// Beside the brook — cool blues and mossy banks.
    case riverbank
    /// Cherry and mulberry in full blossom — pinks and creams.
    case blossom
    /// Late afternoon on the ridge — amber and long shadows.
    case dusk
    /// The forest by moonlight — deep blues, fireflies.
    case night
    /// Under the biggest tree, where the magic lives — violets and glow.
    case magicGrove
}

// MARK: - Palette

private struct ScenePalette {
    var skyTop: Color
    var skyBottom: Color
    var far: Color
    var mid: Color
    var near: Color
    var canopy: Color
    var groundTop: Color
    var groundBottom: Color
    var accent: Color
    var lightBeam: Color
    var beamStrength: Double
    var trunkCount: Int
    var hasSun: Bool

    static func of(_ place: ForestPlace, night dark: Bool) -> ScenePalette {
        func c(_ r: Double, _ g: Double, _ b: Double) -> Color {
            Color(red: r, green: g, blue: b)
        }
        // Night mode reuses the daytime composition with a moonlit palette,
        // so every screen dims together rather than one by one.
        if dark {
            let base = ScenePalette(
                skyTop: c(0.05, 0.08, 0.19), skyBottom: c(0.12, 0.19, 0.32),
                far: c(0.10, 0.17, 0.24), mid: c(0.08, 0.15, 0.19),
                near: c(0.05, 0.11, 0.13), canopy: c(0.04, 0.10, 0.11),
                groundTop: c(0.09, 0.18, 0.14), groundBottom: c(0.04, 0.10, 0.08),
                accent: c(0.55, 0.62, 0.85), lightBeam: c(0.68, 0.76, 1.0),
                beamStrength: 0.05, trunkCount: 3, hasSun: false
            )
            switch place {
            case .magicGrove:
                var p = base
                p.accent = c(0.72, 0.60, 0.95); p.beamStrength = 0.10
                p.lightBeam = c(0.80, 0.70, 1.0)
                return p
            case .blossom:
                var p = base
                p.accent = c(0.85, 0.65, 0.78)
                return p
            case .meadow, .glade:
                var p = base
                p.trunkCount = 2; p.beamStrength = 0.07
                return p
            default:
                return base
            }
        }

        switch place {
        case .meadow:
            return ScenePalette(
                skyTop: c(0.44, 0.74, 0.95), skyBottom: c(0.83, 0.93, 0.89),
                far: c(0.62, 0.82, 0.70), mid: c(0.42, 0.70, 0.48),
                near: c(0.25, 0.53, 0.32), canopy: c(0.22, 0.48, 0.28),
                groundTop: c(0.44, 0.73, 0.44), groundBottom: c(0.24, 0.51, 0.29),
                accent: c(0.99, 0.80, 0.40), lightBeam: c(1.0, 0.95, 0.72),
                beamStrength: 0.10, trunkCount: 2, hasSun: true
            )
        case .deepWoods:
            return ScenePalette(
                skyTop: c(0.58, 0.78, 0.72), skyBottom: c(0.78, 0.87, 0.74),
                far: c(0.42, 0.62, 0.48), mid: c(0.26, 0.48, 0.32),
                near: c(0.15, 0.34, 0.21), canopy: c(0.11, 0.28, 0.17),
                groundTop: c(0.33, 0.46, 0.26), groundBottom: c(0.19, 0.30, 0.16),
                accent: c(0.86, 0.62, 0.26), lightBeam: c(0.92, 0.96, 0.70),
                beamStrength: 0.13, trunkCount: 4, hasSun: false
            )
        case .glade:
            return ScenePalette(
                skyTop: c(0.66, 0.87, 0.93), skyBottom: c(0.92, 0.96, 0.82),
                far: c(0.58, 0.79, 0.58), mid: c(0.38, 0.66, 0.42),
                near: c(0.23, 0.50, 0.29), canopy: c(0.20, 0.45, 0.26),
                groundTop: c(0.52, 0.75, 0.42), groundBottom: c(0.28, 0.53, 0.30),
                accent: c(1.0, 0.86, 0.42), lightBeam: c(1.0, 0.97, 0.70),
                beamStrength: 0.26, trunkCount: 3, hasSun: true
            )
        case .riverbank:
            return ScenePalette(
                skyTop: c(0.52, 0.78, 0.93), skyBottom: c(0.80, 0.92, 0.94),
                far: c(0.50, 0.74, 0.70), mid: c(0.32, 0.60, 0.52),
                near: c(0.18, 0.42, 0.36), canopy: c(0.16, 0.38, 0.33),
                groundTop: c(0.36, 0.63, 0.55), groundBottom: c(0.20, 0.42, 0.42),
                accent: c(0.68, 0.88, 0.95), lightBeam: c(0.86, 0.96, 1.0),
                beamStrength: 0.12, trunkCount: 3, hasSun: false
            )
        case .blossom:
            return ScenePalette(
                skyTop: c(0.72, 0.85, 0.96), skyBottom: c(0.98, 0.91, 0.90),
                far: c(0.86, 0.74, 0.80), mid: c(0.74, 0.56, 0.66),
                near: c(0.44, 0.42, 0.44), canopy: c(0.94, 0.72, 0.80),
                groundTop: c(0.62, 0.76, 0.52), groundBottom: c(0.36, 0.56, 0.36),
                accent: c(0.99, 0.76, 0.84), lightBeam: c(1.0, 0.92, 0.94),
                beamStrength: 0.14, trunkCount: 3, hasSun: true
            )
        case .dusk:
            return ScenePalette(
                skyTop: c(0.42, 0.48, 0.76), skyBottom: c(0.99, 0.74, 0.55),
                far: c(0.52, 0.44, 0.52), mid: c(0.36, 0.31, 0.40),
                near: c(0.21, 0.19, 0.27), canopy: c(0.18, 0.16, 0.24),
                groundTop: c(0.44, 0.42, 0.34), groundBottom: c(0.24, 0.23, 0.22),
                accent: c(0.99, 0.70, 0.38), lightBeam: c(1.0, 0.82, 0.52),
                beamStrength: 0.20, trunkCount: 4, hasSun: true
            )
        case .night:
            return ScenePalette(
                skyTop: c(0.05, 0.08, 0.22), skyBottom: c(0.16, 0.24, 0.40),
                far: c(0.13, 0.21, 0.28), mid: c(0.09, 0.16, 0.22),
                near: c(0.05, 0.11, 0.15), canopy: c(0.04, 0.09, 0.13),
                groundTop: c(0.10, 0.20, 0.16), groundBottom: c(0.05, 0.12, 0.10),
                accent: c(0.70, 0.78, 0.98), lightBeam: c(0.76, 0.84, 1.0),
                beamStrength: 0.07, trunkCount: 3, hasSun: false
            )
        case .magicGrove:
            return ScenePalette(
                skyTop: c(0.60, 0.62, 0.92), skyBottom: c(0.86, 0.84, 0.97),
                far: c(0.58, 0.62, 0.82), mid: c(0.42, 0.48, 0.68),
                near: c(0.26, 0.34, 0.50), canopy: c(0.30, 0.32, 0.56),
                groundTop: c(0.44, 0.62, 0.52), groundBottom: c(0.26, 0.40, 0.40),
                accent: c(0.82, 0.72, 0.99), lightBeam: c(0.92, 0.86, 1.0),
                beamStrength: 0.22, trunkCount: 3, hasSun: false
            )
        }
    }
}

// MARK: - Seeded RNG (identical scene on every redraw)

private struct SceneRandom {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed | 1 }
    mutating func unit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 33) & 0xFFFFFF) / Double(0xFFFFFF)
    }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + unit() * (b - a) }
    mutating func int(_ n: Int) -> Int { Int(unit() * Double(n)) % max(1, n) }
}

// MARK: - The background

/// A painted forest scene. Drop it at the bottom of any screen's `ZStack`
/// in place of a gradient.
struct ForestSceneBackground: View {
    var place: ForestPlace = .meadow
    /// Softens the scene behind content so text stays readable. Screens
    /// with dense cards can drop this to 0.
    var legibility: Double = 0.16

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var palette: ScenePalette {
        ScenePalette.of(place, night: scheme == .dark)
    }

    var body: some View {
        ZStack {
            Canvas(rendersAsynchronously: false) { context, size in
                paint(&context, size: size, palette: palette,
                      seed: UInt64(abs(place.rawValue.hashValue)) &+ 7)
            }
            .drawingGroup()

            if !reduceMotion {
                DriftingLeaves(tint: palette.accent, place: place)
            }

            // A soft veil so cards and text always win against the art.
            if legibility > 0 {
                Rectangle()
                    .fill(
                        (scheme == .dark ? Color.black : Color.white)
                            .opacity(reduceTransparency ? legibility + 0.2 : legibility)
                    )
                    .blendMode(scheme == .dark ? .normal : .softLight)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // MARK: Painting

    private func paint(_ ctx: inout GraphicsContext, size: CGSize,
                       palette p: ScenePalette, seed: UInt64) {
        let w = size.width, h = size.height
        guard w > 1, h > 1 else { return }
        var rng = SceneRandom(seed)

        // Horizon: where the tree line meets the ground.
        let horizon = h * 0.52

        // 1. Sky
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: horizon + 2)),
            with: .linearGradient(Gradient(colors: [p.skyTop, p.skyBottom]),
                                  startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon))
        )

        // 2. Sun or moon glow behind the trees
        if p.hasSun {
            let sun = CGPoint(x: w * 0.74, y: h * 0.16)
            ctx.fill(
                Path(ellipseIn: CGRect(x: sun.x - 110, y: sun.y - 110, width: 220, height: 220)),
                with: .radialGradient(
                    Gradient(colors: [p.lightBeam.opacity(0.55), p.lightBeam.opacity(0)]),
                    center: sun, startRadius: 6, endRadius: 110)
            )
            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 28, y: sun.y - 28, width: 56, height: 56)),
                     with: .color(p.lightBeam.opacity(0.9)))
        } else if scheme == .dark || place == .night {
            let moon = CGPoint(x: w * 0.78, y: h * 0.14)
            ctx.fill(
                Path(ellipseIn: CGRect(x: moon.x - 80, y: moon.y - 80, width: 160, height: 160)),
                with: .radialGradient(
                    Gradient(colors: [p.lightBeam.opacity(0.35), p.lightBeam.opacity(0)]),
                    center: moon, startRadius: 4, endRadius: 80)
            )
            ctx.fill(Path(ellipseIn: CGRect(x: moon.x - 22, y: moon.y - 22, width: 44, height: 44)),
                     with: .color(p.lightBeam.opacity(0.92)))
            // Stars
            for _ in 0..<26 {
                let sx = rng.range(0, w), sy = rng.range(0, h * 0.42)
                let r = rng.range(0.8, 2.0)
                ctx.fill(Path(ellipseIn: CGRect(x: sx, y: sy, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(rng.range(0.25, 0.7))))
            }
        }

        // 3. Three receding tree lines. Far ones are small, pale and
        //    densely packed; near ones are big and dark.
        treeLine(&ctx, rng: &rng, width: w, baseline: horizon - h * 0.03,
                 count: 26, minH: h * 0.10, maxH: h * 0.17, color: p.far, blossom: nil)
        treeLine(&ctx, rng: &rng, width: w, baseline: horizon + h * 0.01,
                 count: 17, minH: h * 0.16, maxH: h * 0.26, color: p.mid,
                 blossom: place == .blossom ? p.accent : nil)
        treeLine(&ctx, rng: &rng, width: w, baseline: horizon + h * 0.06,
                 count: 11, minH: h * 0.22, maxH: h * 0.36, color: p.near,
                 blossom: place == .blossom ? p.accent : nil)

        // 4. Ground
        var ground = Path()
        ground.move(to: CGPoint(x: 0, y: h))
        ground.addLine(to: CGPoint(x: 0, y: horizon + h * 0.05))
        // A gently undulating ground edge so it never looks like a band.
        let steps = 40
        for i in 0...steps {
            let f = Double(i) / Double(steps)
            let y = horizon + h * 0.05 + sin(f * 3.1 + 0.6) * h * 0.022
            ground.addLine(to: CGPoint(x: f * w, y: y))
        }
        ground.addLine(to: CGPoint(x: w, y: h))
        ground.closeSubpath()
        ctx.fill(ground, with: .linearGradient(
            Gradient(colors: [p.groundTop, p.groundBottom]),
            startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)))

        // 5. The leaf carpet — fallen leaves over the whole floor.
        paintLeafLitter(&ctx, rng: &rng, width: w, height: h,
                        from: horizon + h * 0.04, palette: p)

        // 6. Undergrowth: grass tufts, flowers and toadstools on the floor.
        paintUndergrowth(&ctx, rng: &rng, width: w, height: h,
                         from: horizon + h * 0.07, palette: p)

        // 7. Big framing trunks at the edges — this is what makes the
        //    screen feel like it is INSIDE the forest, not looking at it.
        paintForegroundTrunks(&ctx, rng: &rng, width: w, height: h, palette: p)

        // 8. Overhanging canopy along the top edge.
        paintCanopy(&ctx, rng: &rng, width: w, height: h, palette: p)

        // 9. Light shafts slanting through the leaves.
        if p.beamStrength > 0.01 {
            for i in 0..<4 {
                let x = w * (0.14 + Double(i) * 0.24)
                var beam = Path()
                beam.move(to: CGPoint(x: x, y: 0))
                beam.addLine(to: CGPoint(x: x + w * 0.10, y: 0))
                beam.addLine(to: CGPoint(x: x + w * 0.30, y: h))
                beam.addLine(to: CGPoint(x: x + w * 0.13, y: h))
                beam.closeSubpath()
                ctx.fill(beam, with: .linearGradient(
                    Gradient(colors: [p.lightBeam.opacity(p.beamStrength),
                                      p.lightBeam.opacity(0)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.9)))
            }
        }
    }

    /// One row of trees standing on `baseline`.
    private func treeLine(_ ctx: inout GraphicsContext, rng: inout SceneRandom,
                          width: CGFloat, baseline: CGFloat, count: Int,
                          minH: CGFloat, maxH: CGFloat, color: Color,
                          blossom: Color?) {
        let spacing = width / CGFloat(count - 1)
        for i in 0..<count {
            let x = CGFloat(i) * spacing + CGFloat(rng.range(-12, 12))
            let treeH = CGFloat(rng.range(Double(minH), Double(maxH)))
            let treeW = treeH * CGFloat(rng.range(0.42, 0.68))
            let crown = blossom ?? color
            // Trunk
            let trunkW = treeW * 0.13
            ctx.fill(
                Path(CGRect(x: x - trunkW / 2, y: baseline - treeH * 0.34,
                            width: trunkW, height: treeH * 0.36)),
                with: .color(color.opacity(0.9))
            )
            // Canopy: three overlapping blobs, or a conifer cone.
            if rng.unit() < 0.34 {
                var cone = Path()
                cone.move(to: CGPoint(x: x, y: baseline - treeH))
                cone.addLine(to: CGPoint(x: x + treeW / 2, y: baseline - treeH * 0.22))
                cone.addLine(to: CGPoint(x: x - treeW / 2, y: baseline - treeH * 0.22))
                cone.closeSubpath()
                ctx.fill(cone, with: .color(crown))
            } else {
                for (dx, dy, r) in [(0.0, 0.72, 0.52), (-0.30, 0.56, 0.40), (0.30, 0.58, 0.40)] {
                    let rr = treeW * CGFloat(r)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x + treeW * CGFloat(dx) - rr,
                                               y: baseline - treeH * CGFloat(dy) - rr,
                                               width: rr * 2, height: rr * 2)),
                        with: .color(crown)
                    )
                }
            }
        }
    }

    /// Fallen leaves covering the whole floor, thicker toward the bottom.
    private func paintLeafLitter(_ ctx: inout GraphicsContext, rng: inout SceneRandom,
                                 width w: CGFloat, height h: CGFloat,
                                 from top: CGFloat, palette p: ScenePalette) {
        let litterColors: [Color] = [
            Color(red: 0.84, green: 0.62, blue: 0.24),
            Color(red: 0.76, green: 0.44, blue: 0.20),
            Color(red: 0.60, green: 0.30, blue: 0.16),
            Color(red: 0.44, green: 0.30, blue: 0.18),
            Color(red: 0.38, green: 0.55, blue: 0.26)
        ]
        let span = h - top
        guard span > 0 else { return }
        for _ in 0..<300 {
            // Bias toward the foreground: leaves are bigger and denser near us.
            let f = pow(rng.unit(), 0.7)
            let y = top + span * f
            let x = rng.range(0, w)
            let scale = 0.35 + f * 1.0
            let lw = rng.range(7, 15) * scale
            let lh = lw * rng.range(0.40, 0.62)
            let angle = rng.range(0, .pi * 2)
            let color = litterColors[rng.int(litterColors.count)]
                .opacity(scheme == .dark ? 0.42 : rng.range(0.55, 0.9))

            var leaf = Path()
            leaf.move(to: CGPoint(x: -lw / 2, y: 0))
            leaf.addQuadCurve(to: CGPoint(x: lw / 2, y: 0), control: CGPoint(x: 0, y: lh))
            leaf.addQuadCurve(to: CGPoint(x: -lw / 2, y: 0), control: CGPoint(x: 0, y: -lh))
            leaf.closeSubpath()

            let placed = leaf
                .applying(CGAffineTransform(rotationAngle: angle))
                .applying(CGAffineTransform(translationX: x, y: y))
            ctx.fill(placed, with: .color(color))
        }
    }

    /// Grass tufts, flowers and toadstools poking through the leaves.
    private func paintUndergrowth(_ ctx: inout GraphicsContext, rng: inout SceneRandom,
                                  width w: CGFloat, height h: CGFloat,
                                  from top: CGFloat, palette p: ScenePalette) {
        let span = h - top
        guard span > 0 else { return }
        // Grass
        for _ in 0..<70 {
            let f = pow(rng.unit(), 0.8)
            let y = top + span * f
            let x = rng.range(0, w)
            let bladeH = rng.range(6, 20) * (0.4 + f)
            var blades = Path()
            for b in -1...1 {
                blades.move(to: CGPoint(x: x + Double(b) * 3.5, y: y))
                blades.addQuadCurve(
                    to: CGPoint(x: x + Double(b) * 7, y: y - bladeH),
                    control: CGPoint(x: x + Double(b) * 4, y: y - bladeH * 0.6))
            }
            ctx.stroke(blades, with: .color(p.groundTop.opacity(0.85)),
                       style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
        // Flowers
        for _ in 0..<26 {
            let f = pow(rng.unit(), 0.8)
            let y = top + span * f
            let x = rng.range(0, w)
            let r = rng.range(2.0, 4.4) * (0.5 + f)
            for i in 0..<5 {
                let a = Double(i) / 5 * .pi * 2
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x + cos(a) * r - r * 0.6,
                                           y: y + sin(a) * r - r * 0.6,
                                           width: r * 1.2, height: r * 1.2)),
                    with: .color(p.accent.opacity(0.9))
                )
            }
            ctx.fill(Path(ellipseIn: CGRect(x: x - r * 0.5, y: y - r * 0.5,
                                            width: r, height: r)),
                     with: .color(Color(red: 1, green: 0.85, blue: 0.4)))
        }
        // Toadstools
        for _ in 0..<7 {
            let f = pow(rng.unit(), 0.8)
            let y = top + span * f
            let x = rng.range(0, w)
            let s = rng.range(3.0, 6.0) * (0.6 + f)
            ctx.fill(Path(CGRect(x: x - s * 0.18, y: y - s, width: s * 0.36, height: s)),
                     with: .color(Color(red: 0.95, green: 0.92, blue: 0.84).opacity(0.9)))
            ctx.fill(Path(ellipseIn: CGRect(x: x - s * 0.7, y: y - s * 1.45,
                                            width: s * 1.4, height: s * 0.9)),
                     with: .color(Color(red: 0.84, green: 0.28, blue: 0.24).opacity(0.92)))
        }
    }

    /// Tall trunks running the full height at the screen edges.
    private func paintForegroundTrunks(_ ctx: inout GraphicsContext, rng: inout SceneRandom,
                                       width w: CGFloat, height h: CGFloat,
                                       palette p: ScenePalette) {
        // Positions hug the edges so the middle of the screen stays clear
        // for content.
        let spots: [CGFloat] = [-0.02, 1.02, 0.16, 0.86, 0.42]
        for i in 0..<min(p.trunkCount, spots.count) {
            let x = w * spots[i]
            let tw = w * CGFloat(rng.range(0.055, 0.10))
            var trunk = Path()
            trunk.move(to: CGPoint(x: x - tw / 2, y: h))
            trunk.addCurve(
                to: CGPoint(x: x - tw * 0.38, y: -h * 0.05),
                control1: CGPoint(x: x - tw * 0.62, y: h * 0.6),
                control2: CGPoint(x: x - tw * 0.30, y: h * 0.3))
            trunk.addLine(to: CGPoint(x: x + tw * 0.38, y: -h * 0.05))
            trunk.addCurve(
                to: CGPoint(x: x + tw / 2, y: h),
                control1: CGPoint(x: x + tw * 0.30, y: h * 0.3),
                control2: CGPoint(x: x + tw * 0.62, y: h * 0.6))
            trunk.closeSubpath()

            let bark = p.canopy.opacity(0.92)
            ctx.fill(trunk, with: .linearGradient(
                Gradient(colors: [bark.opacity(0.75), bark]),
                startPoint: CGPoint(x: x - tw, y: 0), endPoint: CGPoint(x: x + tw, y: 0)))

            // Bark grooves
            for g in 0..<3 {
                var groove = Path()
                let gx = x - tw * 0.28 + tw * 0.28 * CGFloat(g)
                groove.move(to: CGPoint(x: gx, y: h))
                groove.addQuadCurve(to: CGPoint(x: gx + CGFloat(rng.range(-6, 6)), y: 0),
                                    control: CGPoint(x: gx + CGFloat(rng.range(-10, 10)), y: h * 0.5))
                ctx.stroke(groove, with: .color(.black.opacity(0.12)), lineWidth: 1.6)
            }
            // A mossy root flare at the base
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - tw * 0.9, y: h - 26,
                                       width: tw * 1.8, height: 34)),
                with: .color(p.groundBottom.opacity(0.7))
            )
        }
    }

    /// Leaves hanging into the frame from the top edge.
    private func paintCanopy(_ ctx: inout GraphicsContext, rng: inout SceneRandom,
                             width w: CGFloat, height h: CGFloat,
                             palette p: ScenePalette) {
        let clusters = 14
        for i in 0..<clusters {
            let x = w * CGFloat(i) / CGFloat(clusters - 1) + CGFloat(rng.range(-18, 18))
            let drop = CGFloat(rng.range(Double(h) * 0.04, Double(h) * 0.15))
            let r = CGFloat(rng.range(28, 62))
            // Two tones so the canopy reads as layered, not a flat band.
            let shade = i % 2 == 0 ? p.canopy : p.canopy.opacity(0.82)
            for (dx, dy, rs) in [(0.0, 0.0, 1.0), (-0.55, -0.28, 0.78), (0.58, -0.24, 0.74)] {
                let rr = r * CGFloat(rs)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x + r * CGFloat(dx) - rr,
                                           y: drop + r * CGFloat(dy) - rr,
                                           width: rr * 2, height: rr * 2)),
                    with: .color(shade)
                )
            }
            // A few dangling leaves under the cluster.
            if rng.unit() < 0.6 {
                let lx = x + CGFloat(rng.range(-20, 20))
                let ly = drop + r * 0.7
                var leaf = Path()
                leaf.move(to: CGPoint(x: lx, y: ly))
                leaf.addQuadCurve(to: CGPoint(x: lx, y: ly + 22),
                                  control: CGPoint(x: lx + 11, y: ly + 10))
                leaf.addQuadCurve(to: CGPoint(x: lx, y: ly),
                                  control: CGPoint(x: lx - 11, y: ly + 10))
                ctx.fill(leaf, with: .color(shade))
            }
        }
        // Fill the very top edge so no sky shows above the canopy.
        ctx.fill(Path(CGRect(x: 0, y: -1, width: w, height: h * 0.045)),
                 with: .color(p.canopy))
    }
}

// MARK: - Drifting leaves

/// A handful of leaves tumbling slowly down the screen. Drawn in one
/// animated Canvas; skipped entirely when Reduce Motion is on.
private struct DriftingLeaves: View {
    var tint: Color
    var place: ForestPlace

    private var count: Int {
        switch place {
        case .blossom: 16      // petals falling
        case .night, .magicGrove: 8
        default: 11
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<count {
                    let s = Double(i) * 7.3
                    let fall = (t * (0.035 + Double(i % 4) * 0.012) + Double(i) * 0.17)
                        .truncatingRemainder(dividingBy: 1)
                    let y = fall * (size.height + 80) - 40
                    let x = (size.width * (Double(i) / Double(count)))
                        + sin(t * 0.5 + s) * 34
                        + sin(t * 1.3 + s) * 8
                    let spin = t * 1.4 + s
                    let lw = 9.0 + Double(i % 3) * 3
                    let lh = lw * 0.5

                    var leaf = Path()
                    leaf.move(to: CGPoint(x: -lw / 2, y: 0))
                    leaf.addQuadCurve(to: CGPoint(x: lw / 2, y: 0), control: CGPoint(x: 0, y: lh))
                    leaf.addQuadCurve(to: CGPoint(x: -lw / 2, y: 0), control: CGPoint(x: 0, y: -lh))
                    leaf.closeSubpath()

                    let placed = leaf
                        .applying(CGAffineTransform(scaleX: 1, y: cos(spin)))
                        .applying(CGAffineTransform(rotationAngle: spin * 0.4))
                        .applying(CGAffineTransform(translationX: x, y: y))
                    ctx.fill(placed, with: .color(tint.opacity(0.55)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Convenience

extension View {
    /// Stand this screen somewhere in the forest.
    func forestScene(_ place: ForestPlace, legibility: Double = 0.16) -> some View {
        background(ForestSceneBackground(place: place, legibility: legibility))
    }
}
