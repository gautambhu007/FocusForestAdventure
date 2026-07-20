//
//  ProceduralTextures.swift
//  Focus Forest Adventure
//
//  Every surface in the 3D forest is textured, and every texture is
//  painted in code with Core Graphics — grass, bark, leaves, stone,
//  roof shingles, wood planks, plaster, water, carpet, sky. Fully
//  offline, deterministic, and cached.
//

import UIKit

enum ForestTextures {

    nonisolated(unsafe) private static var cache: [String: UIImage] = [:]

    /// Tiny deterministic RNG so textures look identical on every launch.
    private struct Rand {
        var state: UInt64
        init(_ seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double((state >> 33) & 0xFFFFFF) / Double(0xFFFFFF)
        }
        mutating func range(_ a: Double, _ b: Double) -> Double { a + next() * (b - a) }
    }

    private static func make(_ key: String, size: CGFloat = 256,
                             _ draw: (CGContext, CGFloat, inout Rand) -> Void) -> UIImage {
        if let hit = cache[key] { return hit }
        var rng = Rand(UInt64(abs(key.hashValue &* 31)))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            draw(ctx.cgContext, size, &rng)
        }
        cache[key] = image
        return image
    }

    // MARK: Ground & plants

    static var grass: UIImage {
        make("grass") { c, s, rng in
            c.setFillColor(UIColor(red: 0.33, green: 0.58, blue: 0.30, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: s, height: s))
            // mottled patches
            for _ in 0..<90 {
                let g = rng.range(0.48, 0.68)
                c.setFillColor(UIColor(red: g * 0.55, green: g, blue: g * 0.5, alpha: 0.25).cgColor)
                let r = rng.range(8, 30)
                c.fillEllipse(in: CGRect(x: rng.range(-20, Double(s)), y: rng.range(-20, Double(s)),
                                         width: r, height: r * 0.7))
            }
            // blades
            c.setLineCap(.round)
            for _ in 0..<450 {
                let x = rng.range(0, Double(s)); let y = rng.range(0, Double(s))
                let g = rng.range(0.5, 0.8)
                c.setStrokeColor(UIColor(red: g * 0.45, green: g, blue: g * 0.42, alpha: 0.7).cgColor)
                c.setLineWidth(CGFloat(rng.range(0.8, 1.6)))
                c.move(to: CGPoint(x: x, y: y))
                c.addLine(to: CGPoint(x: x + rng.range(-2, 2), y: y - rng.range(3, 8)))
                c.strokePath()
            }
        }
    }

    static var dirtPath: UIImage {
        make("dirt") { c, s, rng in
            c.setFillColor(UIColor(red: 0.58, green: 0.45, blue: 0.31, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: s, height: s))
            for _ in 0..<160 {
                let b = rng.range(0.35, 0.62)
                c.setFillColor(UIColor(red: b, green: b * 0.76, blue: b * 0.52, alpha: 0.5).cgColor)
                let r = rng.range(2, 9)
                c.fillEllipse(in: CGRect(x: rng.range(0, Double(s)), y: rng.range(0, Double(s)),
                                         width: r, height: r * 0.8))
            }
        }
    }

    static var leaves: UIImage {
        make("leaves") { c, s, rng in
            c.setFillColor(UIColor(red: 0.22, green: 0.46, blue: 0.25, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: s, height: s))
            for _ in 0..<240 {
                let g = rng.range(0.40, 0.78)
                c.setFillColor(UIColor(red: g * 0.5, green: g, blue: g * 0.48, alpha: 0.55).cgColor)
                let r = rng.range(6, 18)
                c.fillEllipse(in: CGRect(x: rng.range(-10, Double(s)), y: rng.range(-10, Double(s)),
                                         width: r, height: r))
            }
            // light sparkle
            for _ in 0..<40 {
                c.setFillColor(UIColor(red: 0.72, green: 0.92, blue: 0.62, alpha: 0.35).cgColor)
                let r = rng.range(2, 5)
                c.fillEllipse(in: CGRect(x: rng.range(0, Double(s)), y: rng.range(0, Double(s)),
                                         width: r, height: r))
            }
        }
    }

    static var bark: UIImage {
        make("bark") { c, s, rng in
            c.setFillColor(UIColor(red: 0.45, green: 0.32, blue: 0.20, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: s, height: s))
            for _ in 0..<70 {
                let b = rng.range(0.22, 0.55)
                c.setStrokeColor(UIColor(red: b, green: b * 0.72, blue: b * 0.45, alpha: 0.8).cgColor)
                c.setLineWidth(CGFloat(rng.range(1.5, 5)))
                let x = rng.range(0, Double(s))
                c.move(to: CGPoint(x: x, y: -4))
                c.addCurve(to: CGPoint(x: x + rng.range(-14, 14), y: Double(s) + 4),
                           control1: CGPoint(x: x + rng.range(-10, 10), y: Double(s) * 0.33),
                           control2: CGPoint(x: x + rng.range(-10, 10), y: Double(s) * 0.66))
                c.strokePath()
            }
        }
    }

    // MARK: Buildings

    static var stone: UIImage {
        make("stone") { c, s, rng in
            c.setFillColor(UIColor(red: 0.62, green: 0.60, blue: 0.66, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: s, height: s))
            let rows = 6
            let bh = Double(s) / Double(rows)
            for row in 0..<rows {
                var x = (row % 2 == 0) ? 0.0 : -bh
                while x < Double(s) {
                    let bw = bh * rng.range(1.4, 2.2)
                    let g = rng.range(0.52, 0.70)
                    c.setFillColor(UIColor(red: g, green: g * 0.97, blue: g * 1.05, alpha: 1).cgColor)
                    c.fill(CGRect(x: x + 2, y: Double(row) * bh + 2, width: bw - 4, height: bh - 4))
                    x += bw
                }
            }
            // mortar shading
            c.setStrokeColor(UIColor(red: 0.42, green: 0.40, blue: 0.46, alpha: 0.6).cgColor)
            c.setLineWidth(2)
            for row in 0...rows {
                c.move(to: CGPoint(x: 0, y: Double(row) * bh))
                c.addLine(to: CGPoint(x: Double(s), y: Double(row) * bh))
            }
            c.strokePath()
        }
    }

    static var shingles: UIImage {
        make("shingles") { c, s, rng in
            c.setFillColor(UIColor(red: 0.62, green: 0.30, blue: 0.24, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: s, height: s))
            let rows = 8
            let rh = Double(s) / Double(rows)
            for row in 0..<rows {
                let off = (row % 2 == 0) ? 0.0 : rh
                var x = -rh * 2 + off
                while x < Double(s) + rh {
                    let r = rng.range(0.55, 0.75)
                    c.setFillColor(UIColor(red: r, green: r * 0.52, blue: r * 0.40, alpha: 1).cgColor)
                    c.fillEllipse(in: CGRect(x: x, y: Double(row) * rh, width: rh * 2, height: rh * 1.7))
                    x += rh * 2
                }
            }
        }
    }

    static var planks: UIImage {
        make("planks") { c, s, rng in
            c.setFillColor(UIColor(red: 0.60, green: 0.44, blue: 0.28, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: s, height: s))
            let planks = 6
            let ph = Double(s) / Double(planks)
            for i in 0..<planks {
                let b = rng.range(0.50, 0.68)
                c.setFillColor(UIColor(red: b, green: b * 0.72, blue: b * 0.46, alpha: 1).cgColor)
                c.fill(CGRect(x: 0, y: Double(i) * ph + 1.5, width: Double(s), height: ph - 3))
                // grain
                c.setStrokeColor(UIColor(red: b * 0.7, green: b * 0.5, blue: b * 0.32, alpha: 0.7).cgColor)
                for _ in 0..<5 {
                    c.setLineWidth(CGFloat(rng.range(0.7, 1.4)))
                    let y = Double(i) * ph + rng.range(3, ph - 3)
                    c.move(to: CGPoint(x: 0, y: y))
                    c.addCurve(to: CGPoint(x: Double(s), y: y + rng.range(-3, 3)),
                               control1: CGPoint(x: Double(s) * 0.3, y: y + rng.range(-4, 4)),
                               control2: CGPoint(x: Double(s) * 0.7, y: y + rng.range(-4, 4)))
                    c.strokePath()
                }
            }
        }
    }

    static var plaster: UIImage {
        make("plaster") { c, s, rng in
            c.setFillColor(UIColor(red: 0.95, green: 0.90, blue: 0.80, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: s, height: s))
            for _ in 0..<220 {
                let b = rng.range(0.82, 0.97)
                c.setFillColor(UIColor(red: b, green: b * 0.95, blue: b * 0.85, alpha: 0.5).cgColor)
                let r = rng.range(3, 14)
                c.fillEllipse(in: CGRect(x: rng.range(0, Double(s)), y: rng.range(0, Double(s)),
                                         width: r, height: r))
            }
        }
    }

    static var carpet: UIImage {
        make("carpet") { c, s, rng in
            c.setFillColor(UIColor(red: 0.68, green: 0.18, blue: 0.22, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: s, height: s))
            c.setStrokeColor(UIColor(red: 0.93, green: 0.78, blue: 0.35, alpha: 1).cgColor)
            c.setLineWidth(8)
            c.stroke(CGRect(x: 10, y: 10, width: s - 20, height: s - 20))
            for _ in 0..<120 {
                let b = rng.range(0.5, 0.75)
                c.setFillColor(UIColor(red: b, green: b * 0.3, blue: b * 0.33, alpha: 0.4).cgColor)
                let r = rng.range(2, 6)
                c.fillEllipse(in: CGRect(x: rng.range(0, Double(s)), y: rng.range(0, Double(s)),
                                         width: r, height: r))
            }
        }
    }

    // MARK: Water & sky

    static var water: UIImage {
        make("water") { c, s, rng in
            c.setFillColor(UIColor(red: 0.24, green: 0.52, blue: 0.83, alpha: 1).cgColor)
            c.fill(CGRect(x: 0, y: 0, width: s, height: s))
            for _ in 0..<40 {
                c.setStrokeColor(UIColor(red: 0.72, green: 0.87, blue: 0.98,
                                         alpha: rng.range(0.25, 0.55)).cgColor)
                c.setLineWidth(CGFloat(rng.range(1.2, 2.6)))
                let y = rng.range(0, Double(s))
                let x = rng.range(0, Double(s))
                let len = rng.range(18, 60)
                c.move(to: CGPoint(x: x, y: y))
                c.addQuadCurve(to: CGPoint(x: x + len, y: y),
                               control: CGPoint(x: x + len / 2, y: y + rng.range(-4, 4)))
                c.strokePath()
            }
        }
    }

    static func sky(night: Bool) -> UIImage {
        make(night ? "skyN" : "skyD", size: 512) { c, s, rng in
            let colors = night
                ? [UIColor(red: 0.05, green: 0.08, blue: 0.20, alpha: 1).cgColor,
                   UIColor(red: 0.16, green: 0.23, blue: 0.38, alpha: 1).cgColor]
                : [UIColor(red: 0.38, green: 0.68, blue: 0.94, alpha: 1).cgColor,
                   UIColor(red: 0.84, green: 0.93, blue: 0.90, alpha: 1).cgColor]
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors as CFArray, locations: [0, 1])!
            c.drawLinearGradient(grad, start: .zero,
                                 end: CGPoint(x: 0, y: s), options: [])
            if night {
                for _ in 0..<140 {
                    c.setFillColor(UIColor(white: 1, alpha: rng.range(0.3, 0.9)).cgColor)
                    let r = rng.range(0.8, 2.4)
                    c.fillEllipse(in: CGRect(x: rng.range(0, Double(s)),
                                             y: rng.range(0, Double(s) * 0.7),
                                             width: r, height: r))
                }
            }
        }
    }

    /// Soft round glow for particles (dragon sparkle trail, fireplace).
    static var glow: UIImage {
        make("glow", size: 64) { c, s, _ in
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor(white: 1, alpha: 1).cgColor,
                                           UIColor(white: 1, alpha: 0).cgColor] as CFArray,
                                  locations: [0, 1])!
            c.drawRadialGradient(grad,
                                 startCenter: CGPoint(x: s / 2, y: s / 2), startRadius: 0,
                                 endCenter: CGPoint(x: s / 2, y: s / 2), endRadius: s / 2,
                                 options: [])
        }
    }

    /// Tall meadow grass blades on a transparent background (billboard).
    static var tallGrass: UIImage {
        make("tallgrass", size: 128) { c, s, rng in
            c.setLineCap(.round)
            for _ in 0..<26 {
                let g = rng.range(0.42, 0.75)
                c.setStrokeColor(UIColor(red: g * 0.5, green: g, blue: g * 0.42, alpha: 0.95).cgColor)
                c.setLineWidth(CGFloat(rng.range(2.2, 4.2)))
                let x = rng.range(8, Double(s) - 8)
                let top = rng.range(4, Double(s) * 0.45)
                c.move(to: CGPoint(x: x, y: Double(s)))
                c.addQuadCurve(to: CGPoint(x: x + rng.range(-22, 22), y: top),
                               control: CGPoint(x: x + rng.range(-6, 6), y: Double(s) * 0.55))
                c.strokePath()
            }
        }
    }

    /// A fern frond on a transparent background (billboard).
    static var fern: UIImage {
        make("fern", size: 128) { c, s, rng in
            for stem in 0..<3 {
                let baseX = Double(s) / 2 + Double(stem - 1) * 20
                let lean = rng.range(-14, 14)
                c.setStrokeColor(UIColor(red: 0.18, green: 0.45, blue: 0.22, alpha: 1).cgColor)
                c.setLineWidth(2.4)
                c.move(to: CGPoint(x: baseX, y: Double(s)))
                c.addQuadCurve(to: CGPoint(x: baseX + lean, y: 14),
                               control: CGPoint(x: baseX + lean / 2, y: Double(s) * 0.5))
                c.strokePath()
                for i in 0..<9 {
                    let f = Double(i) / 9
                    let y = Double(s) - f * (Double(s) - 20)
                    let x = baseX + lean * f
                    let len = 20 * (1 - f) + 4
                    let g = rng.range(0.45, 0.7)
                    c.setStrokeColor(UIColor(red: g * 0.45, green: g, blue: g * 0.42, alpha: 0.95).cgColor)
                    c.setLineWidth(3.2)
                    c.move(to: CGPoint(x: x - len, y: y - len * 0.25))
                    c.addLine(to: CGPoint(x: x + len, y: y - len * 0.25))
                    c.strokePath()
                }
            }
        }
    }

    /// A golden five-point star with soft edges (collectible billboard).
    static var goldStar: UIImage {
        make("goldstar", size: 128) { c, s, _ in
            let center = CGPoint(x: s / 2, y: s / 2)
            let path = CGMutablePath()
            for i in 0..<10 {
                let r: CGFloat = i % 2 == 0 ? s * 0.46 : s * 0.20
                let a = CGFloat(i) * .pi / 5 - .pi / 2
                let p = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            c.setShadow(offset: .zero, blur: 10,
                        color: UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 0.9).cgColor)
            c.setFillColor(UIColor(red: 1.0, green: 0.80, blue: 0.25, alpha: 1).cgColor)
            c.addPath(path); c.fillPath()
            c.setShadow(offset: .zero, blur: 0, color: nil)
            c.setFillColor(UIColor(red: 1.0, green: 0.93, blue: 0.6, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: s / 2 - 9, y: s / 2 - 12, width: 18, height: 18))
        }
    }

    /// A butterfly seen from above, wings open (billboard).
    static func butterfly(hue: CGFloat) -> UIImage {
        make("bfly\(Int(hue * 100))", size: 96) { c, s, _ in
            let wing = UIColor(hue: hue, saturation: 0.6, brightness: 0.95, alpha: 0.95)
            let wing2 = UIColor(hue: hue, saturation: 0.4, brightness: 1.0, alpha: 0.9)
            c.setFillColor(wing.cgColor)
            c.fillEllipse(in: CGRect(x: 6, y: 10, width: s * 0.42, height: s * 0.4))
            c.fillEllipse(in: CGRect(x: s - 6 - s * 0.42, y: 10, width: s * 0.42, height: s * 0.4))
            c.setFillColor(wing2.cgColor)
            c.fillEllipse(in: CGRect(x: 14, y: s * 0.52, width: s * 0.3, height: s * 0.3))
            c.fillEllipse(in: CGRect(x: s - 14 - s * 0.3, y: s * 0.52, width: s * 0.3, height: s * 0.3))
            c.setFillColor(UIColor(red: 0.25, green: 0.2, blue: 0.18, alpha: 1).cgColor)
            let body = CGRect(x: s / 2 - 3.5, y: 12, width: 7, height: s - 30)
            c.addPath(CGPath(roundedRect: body, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil))
            c.fillPath()
        }
    }

    /// A scalloped dragon-wing membrane (transparent background).
    static var dragonWing: UIImage {
        make("dragonwing", size: 128) { c, s, _ in
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 6, y: s - 8))
            path.addLine(to: CGPoint(x: s * 0.5, y: 6))
            path.addLine(to: CGPoint(x: s - 6, y: s * 0.3))
            // scalloped bottom edge back to the root
            path.addQuadCurve(to: CGPoint(x: s * 0.62, y: s * 0.62),
                              control: CGPoint(x: s * 0.80, y: s * 0.62))
            path.addQuadCurve(to: CGPoint(x: s * 0.34, y: s * 0.82),
                              control: CGPoint(x: s * 0.46, y: s * 0.86))
            path.addQuadCurve(to: CGPoint(x: 6, y: s - 8),
                              control: CGPoint(x: s * 0.16, y: s * 1.0))
            path.closeSubpath()
            c.setFillColor(UIColor(red: 0.45, green: 0.80, blue: 0.60, alpha: 0.85).cgColor)
            c.addPath(path); c.fillPath()
            // wing fingers
            c.setStrokeColor(UIColor(red: 0.20, green: 0.45, blue: 0.32, alpha: 0.8).cgColor)
            c.setLineWidth(3)
            for target in [CGPoint(x: s * 0.5, y: 8), CGPoint(x: s - 8, y: s * 0.3),
                           CGPoint(x: s * 0.62, y: s * 0.60)] {
                c.move(to: CGPoint(x: 8, y: s - 10))
                c.addLine(to: target)
            }
            c.strokePath()
        }
    }

    /// A five-petal flower billboard (drawn, with transparency).
    static func flower(hue: CGFloat) -> UIImage {
        make("flower\(Int(hue * 100))", size: 64) { c, s, _ in
            let center = CGPoint(x: s / 2, y: s / 2)
            let petal = UIColor(hue: hue, saturation: 0.55, brightness: 0.95, alpha: 1)
            c.setFillColor(petal.cgColor)
            for i in 0..<5 {
                let a = CGFloat(i) * .pi * 2 / 5 - .pi / 2
                let px = center.x + cos(a) * s * 0.22
                let py = center.y + sin(a) * s * 0.22
                c.fillEllipse(in: CGRect(x: px - s * 0.16, y: py - s * 0.16,
                                         width: s * 0.32, height: s * 0.32))
            }
            c.setFillColor(UIColor(red: 1.0, green: 0.83, blue: 0.35, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: center.x - s * 0.13, y: center.y - s * 0.13,
                                     width: s * 0.26, height: s * 0.26))
        }
    }
}
