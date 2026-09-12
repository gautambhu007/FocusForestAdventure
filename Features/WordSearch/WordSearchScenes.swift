//
//  WordSearchScenes.swift
//  Focus Forest Adventure
//
//  Painted scenes for the Word Hunt themes the forest cannot stand in —
//  an ocean, a farm, a city, a railway. Painted the way
//  `ForestSceneBackground` paints the forest: one seeded `Canvas`, sky to
//  ground in layers, so a sheet looks the same every time it opens and
//  costs one rasterised layer. The puzzle panel covers the middle of the
//  page, so the detail lives in the margins (brief §12: frame the puzzle,
//  don't compete with it).
//
//  These are placeholders in the same sense the forest is: a painted
//  `WS_ENV_nn` image set replaces any of them without a code change.
//

import SwiftUI

/// One family per theme the forest cannot paint.
enum WordSearchSceneFamily: String, CaseIterable, Sendable {
    case ocean, farm, prehistoric, city, beach, winter
    case tropical, savanna, arctic, robot, construction, railway
}

extension WordSearchPalette {
    /// The painted family for a palette with no forest place.
    var paintedScene: WordSearchSceneFamily? {
        switch self {
        case .ocean: .ocean
        case .farm: .farm
        case .prehistoric: .prehistoric
        case .city: .city
        case .beach: .beach
        case .winter: .winter
        case .tropical: .tropical
        case .savanna: .savanna
        case .arctic: .arctic
        case .robot: .robot
        case .construction: .construction
        case .railway: .railway
        case .meadow, .enchanted, .jungle, .mountain, .rescue, .river,
             .autumn, .harvest, .space, .cave, .fantasy, .celebration: nil
        }
    }
}

struct WordSearchPaintedScene: View {
    let family: WordSearchSceneFamily
    /// The sheet number: two sheets in one family get different layouts.
    var seed: Int = 0
    var legibility: Double = 0.18

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            Canvas(rendersAsynchronously: false) { context, size in
                var painter = ScenePainter(ctx: context, size: size,
                                           rng: SceneRNG(UInt64(seed) &* 31 &+ 17))
                painter.paint(family)
            }
            .drawingGroup()

            if legibility > 0 {
                Rectangle()
                    .fill((scheme == .dark ? Color.black : Color.white)
                        .opacity(reduceTransparency ? legibility + 0.2 : legibility))
                    .blendMode(scheme == .dark ? .normal : .softLight)
            }
            if scheme == .dark {
                Color.black.opacity(0.35)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Painter

private struct SceneRNG {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed | 1 }
    mutating func unit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 33) & 0xFFFFFF) / Double(0xFFFFFF)
    }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + unit() * (b - a) }
}

private func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }

private struct ScenePainter {
    var ctx: GraphicsContext
    let size: CGSize
    var rng: SceneRNG
    var w: CGFloat { size.width }
    var h: CGFloat { size.height }

    mutating func paint(_ family: WordSearchSceneFamily) {
        guard w > 1, h > 1 else { return }
        switch family {
        case .ocean: ocean()
        case .farm: farm()
        case .prehistoric: prehistoric()
        case .city: city()
        case .beach: beach()
        case .winter: winter()
        case .tropical: tropical()
        case .savanna: savanna()
        case .arctic: arctic()
        case .robot: robot()
        case .construction: construction()
        case .railway: railway()
        }
    }

    // MARK: Shared strokes

    mutating func sky(_ top: Color, _ bottom: Color, to y: CGFloat? = nil) {
        let bottomY = y ?? h
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: bottomY + 2)),
                 with: .linearGradient(Gradient(colors: [top, bottom]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: bottomY)))
    }

    mutating func sun(at p: CGPoint, radius: CGFloat, _ color: Color, glow: Double = 0.5) {
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - radius * 3, y: p.y - radius * 3, width: radius * 6, height: radius * 6)),
                 with: .radialGradient(Gradient(colors: [color.opacity(glow), color.opacity(0)]),
                                       center: p, startRadius: radius * 0.5, endRadius: radius * 3))
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)),
                 with: .color(color))
    }

    /// A rolling band from `baseline` down to the bottom edge.
    mutating func hills(baseline: CGFloat, amplitude: CGFloat, waves: Double, phase: Double, _ color: Color) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h))
        let steps = 48
        for i in 0...steps {
            let f = Double(i) / Double(steps)
            let y = baseline + sin(f * waves * .pi * 2 + phase) * amplitude
            path.addLine(to: CGPoint(x: f * w, y: y))
        }
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        ctx.fill(path, with: .color(color))
    }

    mutating func ground(from y: CGFloat, _ top: Color, _ bottom: Color) {
        ctx.fill(Path(CGRect(x: 0, y: y, width: w, height: h - y)),
                 with: .linearGradient(Gradient(colors: [top, bottom]),
                                       startPoint: CGPoint(x: 0, y: y), endPoint: CGPoint(x: 0, y: h)))
    }

    mutating func dots(count: Int, in rect: CGRect, radius: ClosedRange<Double>, _ color: Color, alpha: ClosedRange<Double> = 0.5...0.9) {
        for _ in 0..<count {
            let r = rng.range(radius.lowerBound, radius.upperBound)
            let x = rng.range(rect.minX, rect.maxX), y = rng.range(rect.minY, rect.maxY)
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                     with: .color(color.opacity(rng.range(alpha.lowerBound, alpha.upperBound))))
        }
    }

    mutating func cloud(at p: CGPoint, scale s: CGFloat, _ color: Color) {
        for (dx, dy, r) in [(0.0, 0.0, 1.0), (0.9, 0.15, 0.75), (-0.85, 0.2, 0.7), (0.3, -0.35, 0.8)] {
            let radius = 22 * s * r
            ctx.fill(Path(ellipseIn: CGRect(x: p.x + dx * 22 * s - radius, y: p.y + dy * 22 * s - radius,
                                            width: radius * 2, height: radius * 2)), with: .color(color))
        }
    }

    mutating func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ color: Color, corner: CGFloat = 0) {
        let r = CGRect(x: x, y: y, width: width, height: height)
        ctx.fill(corner > 0 ? Path(roundedRect: r, cornerRadius: corner) : Path(r), with: .color(color))
    }

    mutating func circle(_ cx: CGFloat, _ cy: CGFloat, _ radius: CGFloat, _ color: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)), with: .color(color))
    }

    mutating func triangle(_ a: CGPoint, _ b: CGPoint, _ cpt: CGPoint, _ color: Color) {
        var p = Path(); p.move(to: a); p.addLine(to: b); p.addLine(to: cpt); p.closeSubpath()
        ctx.fill(p, with: .color(color))
    }

    /// Wavy horizontal lines — water, wind, sand ripples.
    mutating func ripples(from y: CGFloat, count: Int, spacing: CGFloat, _ color: Color, width: CGFloat = 2) {
        for i in 0..<count {
            let yy = y + CGFloat(i) * spacing
            var p = Path()
            p.move(to: CGPoint(x: 0, y: yy))
            for step in 1...24 {
                let x = w * CGFloat(step) / 24
                p.addLine(to: CGPoint(x: x, y: yy + sin(Double(step) * 0.9 + Double(i)) * 4))
            }
            ctx.stroke(p, with: .color(color), lineWidth: width)
        }
    }

    // MARK: Families

    mutating func ocean() {
        // Under the water: light above, deep below, sand at the bottom.
        sky(c(0.55, 0.85, 0.95), c(0.15, 0.45, 0.75))
        for i in 0..<5 {
            let x = w * (0.1 + CGFloat(i) * 0.2)
            var beam = Path()
            beam.move(to: CGPoint(x: x, y: 0)); beam.addLine(to: CGPoint(x: x + 40, y: 0))
            beam.addLine(to: CGPoint(x: x + 110, y: h * 0.7)); beam.addLine(to: CGPoint(x: x + 20, y: h * 0.7))
            beam.closeSubpath()
            ctx.fill(beam, with: .linearGradient(Gradient(colors: [.white.opacity(0.18), .white.opacity(0)]),
                                                 startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.6)))
        }
        hills(baseline: h * 0.86, amplitude: 10, waves: 1.5, phase: 0.4, c(0.93, 0.85, 0.62))
        // Seaweed and coral along the bottom edges.
        for i in 0..<12 {
            let x = i < 6 ? rng.range(0, w * 0.22) : rng.range(w * 0.78, w)
            let tall = rng.range(50, 130)
            let green = i % 3 == 0 ? c(0.95, 0.45, 0.55) : c(0.25, 0.65, 0.45)
            var p = Path()
            p.move(to: CGPoint(x: x, y: h))
            p.addQuadCurve(to: CGPoint(x: x + 8, y: h - tall), control: CGPoint(x: x - 22, y: h - tall * 0.5))
            p.addQuadCurve(to: CGPoint(x: x + 14, y: h), control: CGPoint(x: x + 30, y: h - tall * 0.5))
            ctx.fill(p, with: .color(green))
        }
        dots(count: 34, in: CGRect(x: 0, y: h * 0.1, width: w, height: h * 0.75), radius: 3...9, .white, alpha: 0.25...0.6)
        // A couple of small fish at the top edge.
        for i in 0..<3 {
            let x = rng.range(w * 0.1, w * 0.9), y = h * (0.05 + CGFloat(i) * 0.035)
            let body = [c(1.0, 0.62, 0.25), c(0.95, 0.4, 0.5), c(0.4, 0.75, 0.95)][i]
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 34, height: 18)), with: .color(body))
            triangle(CGPoint(x: x + 2, y: y + 9), CGPoint(x: x - 12, y: y - 2), CGPoint(x: x - 12, y: y + 20), body)
        }
    }

    mutating func farm() {
        sky(c(0.55, 0.80, 0.97), c(0.88, 0.94, 0.90), to: h * 0.55)
        sun(at: CGPoint(x: w * 0.8, y: h * 0.12), radius: 30, c(1.0, 0.88, 0.45))
        cloud(at: CGPoint(x: w * 0.2, y: h * 0.1), scale: 1.1, .white.opacity(0.9))
        cloud(at: CGPoint(x: w * 0.55, y: h * 0.06), scale: 0.8, .white.opacity(0.85))
        hills(baseline: h * 0.5, amplitude: h * 0.03, waves: 1.2, phase: 0.2, c(0.62, 0.82, 0.45))
        hills(baseline: h * 0.56, amplitude: h * 0.025, waves: 0.9, phase: 2.1, c(0.48, 0.74, 0.36))
        ground(from: h * 0.6, c(0.55, 0.78, 0.40), c(0.36, 0.62, 0.30))
        // A red barn peeking in from the left, a fence along the bottom.
        rect(-20, h * 0.42, w * 0.22, h * 0.16, c(0.82, 0.28, 0.24))
        triangle(CGPoint(x: -30, y: h * 0.42), CGPoint(x: w * 0.21, y: h * 0.42), CGPoint(x: w * 0.09, y: h * 0.33), c(0.55, 0.2, 0.18))
        rect(w * 0.06, h * 0.49, w * 0.06, h * 0.09, c(0.45, 0.16, 0.14), corner: 3)
        for i in 0..<14 {
            let x = CGFloat(i) * (w / 13)
            rect(x, h * 0.9, 8, h * 0.08, c(0.78, 0.62, 0.42), corner: 2)
        }
        rect(0, h * 0.92, w, 5, c(0.78, 0.62, 0.42)); rect(0, h * 0.955, w, 5, c(0.78, 0.62, 0.42))
        // Crop rows on the right.
        for i in 0..<5 {
            let y = h * (0.66 + CGFloat(i) * 0.045)
            ripples(from: y, count: 1, spacing: 0, c(0.30, 0.55, 0.26), width: 6)
        }
    }

    mutating func prehistoric() {
        sky(c(0.98, 0.78, 0.55), c(0.99, 0.92, 0.75), to: h * 0.55)
        sun(at: CGPoint(x: w * 0.25, y: h * 0.14), radius: 34, c(1.0, 0.72, 0.35), glow: 0.6)
        // A smoking volcano on the right, tree-ferns on the left.
        triangle(CGPoint(x: w * 0.62, y: h * 0.58), CGPoint(x: w * 1.1, y: h * 0.58), CGPoint(x: w * 0.88, y: h * 0.2), c(0.5, 0.36, 0.34))
        triangle(CGPoint(x: w * 0.83, y: h * 0.28), CGPoint(x: w * 0.93, y: h * 0.28), CGPoint(x: w * 0.88, y: h * 0.2), c(0.95, 0.45, 0.25))
        for i in 0..<4 {
            circle(w * 0.9 + CGFloat(i) * 14, h * 0.17 - CGFloat(i) * 26, 16 + CGFloat(i) * 4, c(0.75, 0.72, 0.72).opacity(0.7))
        }
        hills(baseline: h * 0.56, amplitude: h * 0.03, waves: 1.4, phase: 1.0, c(0.62, 0.72, 0.42))
        ground(from: h * 0.62, c(0.56, 0.68, 0.36), c(0.40, 0.52, 0.28))
        for i in 0..<3 {
            let x = w * 0.04 + CGFloat(i) * 40, top = h * (0.28 + CGFloat(i) * 0.06)
            rect(x, top, 10, h * 0.4, c(0.45, 0.35, 0.25), corner: 4)
            for k in 0..<6 {
                let angle = Double(k) * .pi / 3
                let ex = x + 5 + CGFloat(cos(angle)) * 55, ey = top + CGFloat(sin(angle)) * 30
                var frond = Path(); frond.move(to: CGPoint(x: x + 5, y: top)); frond.addLine(to: CGPoint(x: ex, y: ey))
                ctx.stroke(frond, with: .color(c(0.25, 0.55, 0.3)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        }
        for _ in 0..<6 {
            let x = rng.range(0, w), y = rng.range(h * 0.7, h * 0.97)
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 34, height: 26)), with: .color(c(0.9, 0.86, 0.75)))
        }
    }

    mutating func city() {
        sky(c(0.62, 0.82, 0.98), c(0.90, 0.95, 1.0), to: h * 0.62)
        sun(at: CGPoint(x: w * 0.18, y: h * 0.1), radius: 26, c(1.0, 0.9, 0.55))
        // Skyline: pale far blocks, then bolder near ones on both edges.
        var x: CGFloat = -10
        while x < w {
            let bw = rng.range(40, 80), bh = rng.range(h * 0.12, h * 0.28)
            rect(x, h * 0.62 - bh, bw, bh, c(0.72, 0.80, 0.90))
            x += bw + 6
        }
        for (bx, bw, bh, color) in [(-10.0, w * 0.18, h * 0.42, c(0.95, 0.72, 0.45)), (w * 0.84, w * 0.2, h * 0.36, c(0.55, 0.72, 0.88))] {
            rect(bx, h * 0.62 - bh, bw, bh, color, corner: 4)
            for row in 0..<Int(bh / 32) {
                for col in 0..<Int(bw / 30) {
                    rect(bx + 10 + CGFloat(col) * 30, h * 0.62 - bh + 12 + CGFloat(row) * 32, 14, 18, c(1.0, 0.97, 0.75), corner: 2)
                }
            }
        }
        ground(from: h * 0.62, c(0.55, 0.58, 0.62), c(0.38, 0.40, 0.45))
        rect(0, h * 0.8, w, 4, .white.opacity(0.8))
        var dash: CGFloat = 0
        while dash < w { rect(dash, h * 0.9, 30, 5, c(1.0, 0.85, 0.3)); dash += 60 }
        rect(w * 0.06, h * 0.64, 6, h * 0.14, c(0.3, 0.3, 0.32))
        rect(w * 0.035, h * 0.6, 34, 12, c(0.95, 0.35, 0.3), corner: 6)
    }

    mutating func beach() {
        sky(c(0.48, 0.78, 0.98), c(0.85, 0.94, 1.0), to: h * 0.5)
        sun(at: CGPoint(x: w * 0.78, y: h * 0.12), radius: 34, c(1.0, 0.88, 0.4), glow: 0.6)
        cloud(at: CGPoint(x: w * 0.25, y: h * 0.12), scale: 1.0, .white)
        ctx.fill(Path(CGRect(x: 0, y: h * 0.48, width: w, height: h * 0.2)),
                 with: .linearGradient(Gradient(colors: [c(0.30, 0.70, 0.90), c(0.45, 0.82, 0.92)]),
                                       startPoint: CGPoint(x: 0, y: h * 0.48), endPoint: CGPoint(x: 0, y: h * 0.68)))
        ripples(from: h * 0.52, count: 4, spacing: h * 0.035, .white.opacity(0.7))
        hills(baseline: h * 0.68, amplitude: 8, waves: 1.0, phase: 0.3, c(0.98, 0.90, 0.68))
        ground(from: h * 0.72, c(0.98, 0.90, 0.68), c(0.92, 0.80, 0.55))
        // A striped umbrella on the left, a sandcastle and shells at the bottom.
        rect(w * 0.1, h * 0.42, 5, h * 0.3, c(0.6, 0.45, 0.3))
        for i in 0..<6 {
            let a0 = .pi + Double(i) * .pi / 6, a1 = a0 + .pi / 6
            var p = Path(); p.move(to: CGPoint(x: w * 0.1 + 2, y: h * 0.44))
            p.addArc(center: CGPoint(x: w * 0.1 + 2, y: h * 0.44), radius: 70, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
            p.closeSubpath()
            ctx.fill(p, with: .color(i % 2 == 0 ? c(0.95, 0.35, 0.35) : .white))
        }
        rect(w * 0.8, h * 0.82, 60, 50, c(0.90, 0.75, 0.48), corner: 4)
        for i in 0..<3 { rect(w * 0.8 + CGFloat(i) * 22, h * 0.78, 14, 10, c(0.90, 0.75, 0.48)) }
        dots(count: 8, in: CGRect(x: 0, y: h * 0.86, width: w, height: h * 0.12), radius: 4...8, c(0.98, 0.7, 0.7), alpha: 0.7...1)
    }

    mutating func winter() {
        sky(c(0.72, 0.82, 0.94), c(0.92, 0.95, 0.98), to: h * 0.55)
        hills(baseline: h * 0.52, amplitude: h * 0.04, waves: 1.1, phase: 0.5, c(0.86, 0.91, 0.96))
        hills(baseline: h * 0.58, amplitude: h * 0.03, waves: 0.8, phase: 2.4, .white)
        ground(from: h * 0.64, .white, c(0.86, 0.90, 0.95))
        // Snowy pines at both edges.
        for (x, s) in [(w * 0.06, 1.0), (w * 0.16, 0.7), (w * 0.9, 1.1), (w * 0.8, 0.65)] {
            let base = h * 0.66, height = h * 0.3 * s
            for tier in 0..<3 {
                let ty = base - height * CGFloat(tier) / 3, half = 42 * s * (1 - CGFloat(tier) * 0.22)
                triangle(CGPoint(x: x - half, y: ty), CGPoint(x: x + half, y: ty), CGPoint(x: x, y: ty - height * 0.45), c(0.25, 0.48, 0.42))
                triangle(CGPoint(x: x - half * 0.6, y: ty - height * 0.18), CGPoint(x: x + half * 0.6, y: ty - height * 0.18), CGPoint(x: x, y: ty - height * 0.45), .white.opacity(0.9))
            }
            rect(x - 6, base - 4, 12, 18, c(0.45, 0.32, 0.25))
        }
        // A snowman at the bottom.
        circle(w * 0.5, h * 0.95, 28, .white); circle(w * 0.5, h * 0.88, 20, .white)
        circle(w * 0.5 - 6, h * 0.87, 2.5, .black); circle(w * 0.5 + 6, h * 0.87, 2.5, .black)
        triangle(CGPoint(x: w * 0.5, y: h * 0.885), CGPoint(x: w * 0.5, y: h * 0.895), CGPoint(x: w * 0.5 + 14, y: h * 0.892), c(1.0, 0.55, 0.2))
        dots(count: 60, in: CGRect(x: 0, y: 0, width: w, height: h), radius: 2...4.5, .white, alpha: 0.6...1)
    }

    mutating func tropical() {
        sky(c(0.40, 0.76, 0.98), c(0.88, 0.95, 0.98), to: h * 0.55)
        sun(at: CGPoint(x: w * 0.72, y: h * 0.1), radius: 30, c(1.0, 0.86, 0.4), glow: 0.6)
        ctx.fill(Path(CGRect(x: 0, y: h * 0.5, width: w, height: h * 0.16)), with: .color(c(0.30, 0.78, 0.85)))
        ripples(from: h * 0.53, count: 3, spacing: h * 0.04, .white.opacity(0.6))
        hills(baseline: h * 0.66, amplitude: 10, waves: 1.0, phase: 1.0, c(0.98, 0.90, 0.66))
        ground(from: h * 0.7, c(0.98, 0.90, 0.66), c(0.55, 0.75, 0.40))
        // Palms leaning in from both top corners.
        for (x, dir) in [(w * 0.08, 1.0), (w * 0.92, -1.0)] {
            var trunk = Path(); trunk.move(to: CGPoint(x: x, y: h * 0.7))
            trunk.addQuadCurve(to: CGPoint(x: x + dir * 40, y: h * 0.18), control: CGPoint(x: x - dir * 30, y: h * 0.45))
            ctx.stroke(trunk, with: .color(c(0.55, 0.40, 0.28)), style: StrokeStyle(lineWidth: 12, lineCap: .round))
            for k in 0..<6 {
                let angle = -Double.pi / 2 + (Double(k) - 2.5) * 0.55
                var frond = Path(); frond.move(to: CGPoint(x: x + dir * 40, y: h * 0.18))
                frond.addQuadCurve(to: CGPoint(x: x + dir * 40 + CGFloat(cos(angle)) * 90, y: h * 0.18 + CGFloat(sin(angle)) * 60 + 40),
                                   control: CGPoint(x: x + dir * 40 + CGFloat(cos(angle)) * 70, y: h * 0.18 + CGFloat(sin(angle)) * 60))
                ctx.stroke(frond, with: .color(c(0.20, 0.62, 0.32)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            }
            circle(x + dir * 44, h * 0.21, 8, c(0.45, 0.3, 0.2)); circle(x + dir * 32, h * 0.22, 8, c(0.45, 0.3, 0.2))
        }
        dots(count: 6, in: CGRect(x: 0, y: h * 0.75, width: w, height: h * 0.22), radius: 6...12, c(0.95, 0.4, 0.55), alpha: 0.8...1)
    }

    mutating func savanna() {
        sky(c(0.98, 0.72, 0.42), c(1.0, 0.92, 0.70), to: h * 0.58)
        sun(at: CGPoint(x: w * 0.5, y: h * 0.2), radius: 46, c(1.0, 0.6, 0.3), glow: 0.5)
        hills(baseline: h * 0.58, amplitude: h * 0.02, waves: 1.6, phase: 0.8, c(0.86, 0.70, 0.42))
        ground(from: h * 0.62, c(0.88, 0.74, 0.44), c(0.72, 0.56, 0.32))
        // Acacia silhouettes: a flat crown on a thin trunk, at both edges.
        for (x, s) in [(w * 0.12, 1.0), (w * 0.86, 0.8)] {
            rect(x - 5, h * 0.4, 10, h * 0.22 * s + 20, c(0.36, 0.26, 0.18))
            ctx.fill(Path(ellipseIn: CGRect(x: x - 80 * s, y: h * 0.36, width: 160 * s, height: 44 * s)), with: .color(c(0.32, 0.42, 0.22)))
            ctx.fill(Path(ellipseIn: CGRect(x: x - 50 * s, y: h * 0.32, width: 100 * s, height: 30 * s)), with: .color(c(0.38, 0.5, 0.26)))
        }
        for _ in 0..<40 {
            let x = rng.range(0, w), y = rng.range(h * 0.66, h)
            var blade = Path(); blade.move(to: CGPoint(x: x, y: y)); blade.addLine(to: CGPoint(x: x + rng.range(-6, 6), y: y - rng.range(12, 30)))
            ctx.stroke(blade, with: .color(c(0.62, 0.52, 0.28)), lineWidth: 2)
        }
    }

    mutating func arctic() {
        sky(c(0.12, 0.22, 0.45), c(0.55, 0.78, 0.92), to: h * 0.5)
        // Northern lights: soft slanted ribbons.
        for i in 0..<3 {
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: -20, y: h * (0.08 + CGFloat(i) * 0.08)))
            ribbon.addCurve(to: CGPoint(x: w + 20, y: h * (0.14 + CGFloat(i) * 0.08)),
                            control1: CGPoint(x: w * 0.3, y: h * (0.02 + CGFloat(i) * 0.08)),
                            control2: CGPoint(x: w * 0.7, y: h * (0.22 + CGFloat(i) * 0.08)))
            ctx.stroke(ribbon, with: .color([c(0.45, 0.95, 0.75), c(0.55, 0.75, 1.0), c(0.85, 0.6, 0.95)][i].opacity(0.45)), lineWidth: 26)
        }
        dots(count: 30, in: CGRect(x: 0, y: 0, width: w, height: h * 0.4), radius: 1...2.5, .white, alpha: 0.4...0.9)
        ctx.fill(Path(CGRect(x: 0, y: h * 0.5, width: w, height: h * 0.5)), with: .color(c(0.35, 0.62, 0.85)))
        // Ice floes and an iceberg on the right.
        triangle(CGPoint(x: w * 0.7, y: h * 0.52), CGPoint(x: w * 1.05, y: h * 0.52), CGPoint(x: w * 0.86, y: h * 0.3), c(0.88, 0.95, 1.0))
        triangle(CGPoint(x: w * 0.78, y: h * 0.52), CGPoint(x: w * 0.98, y: h * 0.52), CGPoint(x: w * 0.86, y: h * 0.3), c(0.72, 0.86, 0.96))
        for _ in 0..<7 {
            let x = rng.range(-30, w), y = rng.range(h * 0.56, h * 0.98), fw = rng.range(60, 140)
            ctx.fill(Path(roundedRect: CGRect(x: x, y: y, width: fw, height: 20), cornerRadius: 10), with: .color(.white.opacity(0.92)))
        }
    }

    mutating func robot() {
        sky(c(0.45, 0.52, 0.72), c(0.82, 0.86, 0.94), to: h * 0.6)
        // A circuit pattern in the sky, gears at the corners.
        for _ in 0..<14 {
            let x = rng.range(0, w), y = rng.range(0, h * 0.55), len = rng.range(40, 120)
            let horizontal = rng.unit() > 0.5
            var trace = Path(); trace.move(to: CGPoint(x: x, y: y))
            trace.addLine(to: CGPoint(x: horizontal ? x + len : x, y: horizontal ? y : y + len))
            ctx.stroke(trace, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            circle(x, y, 4, c(0.6, 0.95, 0.9).opacity(0.8))
        }
        for (cx, cy, r) in [(w * 0.08, h * 0.08, 46.0), (w * 0.94, h * 0.9, 60.0), (w * 0.1, h * 0.94, 34.0)] {
            for k in 0..<8 {
                let a = Double(k) * .pi / 4
                rect(cx + CGFloat(cos(a)) * r - 8, cy + CGFloat(sin(a)) * r - 8, 16, 16, c(0.55, 0.60, 0.70), corner: 3)
            }
            circle(cx, cy, r * 0.85, c(0.62, 0.67, 0.78)); circle(cx, cy, r * 0.35, c(0.45, 0.52, 0.72))
        }
        ground(from: h * 0.6, c(0.58, 0.62, 0.72), c(0.40, 0.44, 0.55))
        for i in 0..<Int(w / 40) { rect(CGFloat(i) * 40, h * 0.6, 1, h * 0.4, .white.opacity(0.12)) }
        for i in 0..<8 { rect(0, h * 0.6 + CGFloat(i) * h * 0.05, w, 1, .white.opacity(0.12)) }
    }

    mutating func construction() {
        sky(c(0.55, 0.80, 0.98), c(0.92, 0.95, 0.98), to: h * 0.6)
        sun(at: CGPoint(x: w * 0.2, y: h * 0.1), radius: 26, c(1.0, 0.9, 0.5))
        // A crane arm across the top right, a half-built wall at the bottom.
        rect(w * 0.86, h * 0.05, 12, h * 0.6, c(0.98, 0.72, 0.2))
        rect(w * 0.45, h * 0.09, w * 0.55, 10, c(0.98, 0.72, 0.2))
        for i in 0..<6 {
            let x = w * 0.47 + CGFloat(i) * w * 0.07
            var brace = Path(); brace.move(to: CGPoint(x: x, y: h * 0.09)); brace.addLine(to: CGPoint(x: x + w * 0.035, y: h * 0.09 + 10))
            ctx.stroke(brace, with: .color(c(0.98, 0.72, 0.2)), lineWidth: 3)
        }
        rect(w * 0.55, h * 0.1, 2, h * 0.16, c(0.3, 0.3, 0.3))
        rect(w * 0.53, h * 0.26, 18, 16, c(0.3, 0.3, 0.3), corner: 3)
        ground(from: h * 0.6, c(0.80, 0.70, 0.52), c(0.62, 0.52, 0.36))
        for row in 0..<3 {
            for col in 0..<5 {
                let offset = row % 2 == 0 ? 0.0 : 22.0
                rect(w * 0.02 + CGFloat(col) * 46 + offset, h * 0.9 - CGFloat(row) * 20, 42, 18, c(0.82, 0.38, 0.28), corner: 2)
            }
        }
        for i in 0..<3 {
            let x = w * 0.72 + CGFloat(i) * 44
            triangle(CGPoint(x: x, y: h * 0.98), CGPoint(x: x + 34, y: h * 0.98), CGPoint(x: x + 17, y: h * 0.88), c(1.0, 0.55, 0.15))
            rect(x + 8, h * 0.93, 18, 4, .white)
        }
    }

    mutating func railway() {
        sky(c(0.62, 0.84, 0.97), c(0.92, 0.96, 0.98), to: h * 0.55)
        cloud(at: CGPoint(x: w * 0.3, y: h * 0.09), scale: 1.0, .white)
        cloud(at: CGPoint(x: w * 0.78, y: h * 0.15), scale: 0.7, .white.opacity(0.9))
        hills(baseline: h * 0.5, amplitude: h * 0.04, waves: 1.0, phase: 0.6, c(0.60, 0.80, 0.52))
        hills(baseline: h * 0.57, amplitude: h * 0.03, waves: 1.3, phase: 2.0, c(0.46, 0.70, 0.40))
        ground(from: h * 0.62, c(0.52, 0.74, 0.42), c(0.38, 0.60, 0.32))
        // Track curving in from the bottom-left, a signal at the right.
        var ballast = Path()
        ballast.move(to: CGPoint(x: -20, y: h)); ballast.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.62), control: CGPoint(x: w * 0.1, y: h * 0.7))
        ballast.addLine(to: CGPoint(x: w * 0.62, y: h * 0.62)); ballast.addQuadCurve(to: CGPoint(x: w * 0.2, y: h), control: CGPoint(x: w * 0.2, y: h * 0.72))
        ballast.closeSubpath()
        ctx.fill(ballast, with: .color(c(0.72, 0.66, 0.56)))
        for i in 0..<14 {
            let t = CGFloat(i) / 14
            let x = -20 + (w * 0.58 + 20) * t, y = h - (h * 0.38) * t * t
            let sleeper = CGRect(x: x, y: y, width: 40 - t * 20, height: 6)
            ctx.fill(Path(roundedRect: sleeper, cornerRadius: 2), with: .color(c(0.45, 0.32, 0.22)))
        }
        for offset in [4.0, 30.0] {
            var rail = Path(); rail.move(to: CGPoint(x: -20 + offset, y: h))
            rail.addQuadCurve(to: CGPoint(x: w * 0.55 + offset * 0.5, y: h * 0.62), control: CGPoint(x: w * 0.1 + offset, y: h * 0.7))
            ctx.stroke(rail, with: .color(c(0.5, 0.5, 0.52)), lineWidth: 3)
        }
        rect(w * 0.9, h * 0.62, 6, h * 0.3, c(0.3, 0.3, 0.32))
        rect(w * 0.87, h * 0.58, 22, 44, c(0.2, 0.2, 0.22), corner: 6)
        circle(w * 0.9 + 4, h * 0.62 + 10, 7, c(0.2, 0.85, 0.35)); circle(w * 0.9 + 4, h * 0.62 + 28, 7, c(0.9, 0.25, 0.2).opacity(0.4))
    }
}
