//
//  Forest3DTreasures.swift
//  Focus Forest Adventure
//
//  Builds the things the child has earned and puts them in the world:
//  furniture inside the cottage, castle and treehouse, staircases and
//  bridges, statues and fountains on the grounds, and animals wandering
//  the forest.
//
//  Nothing here appears until it has been earned by answering questions —
//  walking in and finding your new rocking chair is the whole point.
//

import SceneKit
import UIKit

extension Forest3DBuilder {

    // MARK: Helpers

    private static func tColor(_ c: PlantColor) -> UIColor {
        UIColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
    }

    private static func tMat(_ c: PlantColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = tColor(c)
        m.roughness.contents = 0.75
        return m
    }

    private static func tWood() -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = ForestTextures.planks
        return m
    }

    private static func tGlow(_ c: PlantColor, intensity: CGFloat = 0.9) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = tColor(c)
        m.emission.contents = tColor(c)
        m.emission.intensity = intensity
        return m
    }

    private static func box(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat,
                            _ mat: SCNMaterial, at p: SCNVector3,
                            chamfer: CGFloat = 0.03) -> SCNNode {
        let n = SCNNode(geometry: SCNBox(width: w, height: h, length: d, chamferRadius: chamfer))
        n.geometry?.materials = [mat]
        n.position = p
        return n
    }

    private static func cyl(_ r: CGFloat, _ h: CGFloat, _ mat: SCNMaterial,
                            at p: SCNVector3) -> SCNNode {
        let n = SCNNode(geometry: SCNCylinder(radius: r, height: h))
        n.geometry?.materials = [mat]
        n.position = p
        return n
    }

    private static func sphere(_ r: CGFloat, _ mat: SCNMaterial, at p: SCNVector3) -> SCNNode {
        let n = SCNNode(geometry: SCNSphere(radius: r))
        n.geometry?.materials = [mat]
        n.position = p
        return n
    }

    /// Stand a node on the terrain (the builder's own helper is file-private).
    private static func place(_ node: SCNNode, x: Float, z: Float, sink: Float) {
        node.position = SCNVector3(x, terrainHeight(x: x, z: z) - sink, z)
    }

    // MARK: - One treasure

    /// Build a treasure standing at its own origin, facing +z.
    /// The node is named `treasure.<id>` so tapping it tells the child
    /// what it is.
    static func treasureNode(_ treasure: ForestTreasure) -> SCNNode {
        let root = SCNNode()
        root.name = "treasure.\(treasure.id)"
        let accent = tMat(treasure.accent)
        let wood = tWood()

        switch treasure.form {

        case .chair:
            root.addChildNode(box(0.9, 0.14, 0.9, accent, at: SCNVector3(0, 0.45, 0)))
            root.addChildNode(box(0.9, 1.0, 0.14, accent, at: SCNVector3(0, 0.95, -0.38)))
            for (dx, dz) in [(-0.36, -0.36), (0.36, -0.36), (-0.36, 0.36), (0.36, 0.36)] {
                root.addChildNode(cyl(0.06, 0.45, wood,
                                      at: SCNVector3(Float(dx), 0.22, Float(dz))))
            }
            // Armrests
            for side: Float in [-1, 1] {
                root.addChildNode(box(0.12, 0.10, 0.8, wood,
                                      at: SCNVector3(side * 0.45, 0.72, 0)))
            }

        case .table:
            root.addChildNode(box(1.6, 0.12, 1.0, wood, at: SCNVector3(0, 0.86, 0)))
            for (dx, dz) in [(-0.68, -0.38), (0.68, -0.38), (-0.68, 0.38), (0.68, 0.38)] {
                root.addChildNode(cyl(0.07, 0.86, wood,
                                      at: SCNVector3(Float(dx), 0.43, Float(dz))))
            }
            // Something cheerful on top
            root.addChildNode(sphere(0.14, accent, at: SCNVector3(0, 1.0, 0)))

        case .bed:
            root.addChildNode(box(1.4, 0.30, 2.2, wood, at: SCNVector3(0, 0.30, 0)))
            root.addChildNode(box(1.36, 0.22, 2.0, accent, at: SCNVector3(0, 0.55, 0)))
            root.addChildNode(box(1.1, 0.20, 0.5, tMat(.white), at: SCNVector3(0, 0.70, -0.72)))
            root.addChildNode(box(1.5, 1.1, 0.14, wood, at: SCNVector3(0, 0.85, -1.12)))

        case .chest:
            root.addChildNode(box(1.0, 0.6, 0.7, wood, at: SCNVector3(0, 0.30, 0)))
            let lid = SCNNode(geometry: SCNCylinder(radius: 0.35, height: 1.0))
            lid.geometry?.materials = [wood]
            lid.eulerAngles.z = .pi / 2
            lid.position = SCNVector3(0, 0.60, 0)
            lid.scale = SCNVector3(1, 1, 0.55)
            root.addChildNode(lid)
            // Gold bands and a clasp
            for dz: Float in [-0.24, 0.24] {
                root.addChildNode(box(1.02, 0.62, 0.06, tMat(.gold),
                                      at: SCNVector3(0, 0.31, dz)))
            }
            root.addChildNode(sphere(0.09, tMat(.gold), at: SCNVector3(0, 0.42, 0.36)))
            // A hint of treasure spilling out
            root.addChildNode(sphere(0.10, tGlow(treasure.accent, intensity: 0.5),
                                     at: SCNVector3(0, 0.68, 0.1)))

        case .rug:
            let rug = SCNNode(geometry: SCNCylinder(radius: 1.5, height: 0.05))
            let m = SCNMaterial()
            m.diffuse.contents = ForestTextures.carpet
            m.multiply.contents = tColor(treasure.accent)
            rug.geometry?.materials = [m]
            rug.position = SCNVector3(0, 0.03, 0)
            root.addChildNode(rug)

        case .lamp:
            root.addChildNode(cyl(0.14, 0.08, tMat(.brown), at: SCNVector3(0, 0.04, 0)))
            root.addChildNode(cyl(0.04, 1.1, tMat(.brown), at: SCNVector3(0, 0.6, 0)))
            let shade = SCNNode(geometry: SCNCone(topRadius: 0.18, bottomRadius: 0.34, height: 0.36))
            shade.geometry?.materials = [tGlow(treasure.accent, intensity: 0.6)]
            shade.position = SCNVector3(0, 1.3, 0)
            root.addChildNode(shade)
            let bulb = SCNNode()
            bulb.light = SCNLight()
            bulb.light?.type = .omni
            bulb.light?.intensity = 420
            bulb.light?.color = tColor(.gold)
            bulb.position = SCNVector3(0, 1.2, 0)
            root.addChildNode(bulb)

        case .shelf:
            root.addChildNode(box(1.6, 2.0, 0.10, wood, at: SCNVector3(0, 1.0, -0.2)))
            for side: Float in [-1, 1] {
                root.addChildNode(box(0.10, 2.0, 0.45, wood, at: SCNVector3(side * 0.8, 1.0, 0)))
            }
            for shelf in 0..<3 {
                let y = 0.45 + Float(shelf) * 0.62
                root.addChildNode(box(1.6, 0.08, 0.45, wood, at: SCNVector3(0, y, 0)))
                // Books / pots along each shelf
                for slot in 0..<6 {
                    let item = SCNNode(geometry: SCNBox(width: 0.16, height: 0.34,
                                                        length: 0.26, chamferRadius: 0.02))
                    let hue = CGFloat((shelf * 6 + slot) % 8) / 8
                    item.geometry?.firstMaterial?.diffuse.contents =
                        UIColor(hue: hue, saturation: 0.55, brightness: 0.88, alpha: 1)
                    item.position = SCNVector3(-0.62 + Float(slot) * 0.25, y + 0.21, 0)
                    root.addChildNode(item)
                }
            }

        case .painting:
            root.addChildNode(box(1.3, 1.0, 0.06, tMat(.gold), at: SCNVector3(0, 1.7, 0)))
            root.addChildNode(box(1.12, 0.82, 0.08, accent, at: SCNVector3(0, 1.7, 0.02)))
            // A little painted scene: sky, hill, sun
            root.addChildNode(box(1.12, 0.34, 0.10, tMat(.sky), at: SCNVector3(0, 1.94, 0.03)))
            root.addChildNode(sphere(0.10, tMat(.gold), at: SCNVector3(0.34, 1.98, 0.06)))

        case .banner:
            // A row of hanging pennants on a cord.
            let cord = SCNNode(geometry: SCNCylinder(radius: 0.02, height: 3.2))
            cord.geometry?.materials = [tMat(.brown)]
            cord.eulerAngles.z = .pi / 2
            cord.position = SCNVector3(0, 2.3, 0)
            root.addChildNode(cord)
            for i in 0..<8 {
                let flag = SCNNode(geometry: SCNPyramid(width: 0.3, height: 0.42, length: 0.02))
                let hue = CGFloat(i) / 8
                let m = SCNMaterial()
                m.diffuse.contents = UIColor(hue: hue, saturation: 0.6, brightness: 0.92, alpha: 1)
                m.isDoubleSided = true
                flag.geometry?.materials = [m]
                flag.eulerAngles.z = .pi        // point downward
                flag.position = SCNVector3(-1.4 + Float(i) * 0.4, 2.28, 0)
                root.addChildNode(flag)
            }

        case .staircase:
            // Eight rising steps with a handrail — genuinely climbable-looking.
            let steps = 8
            for i in 0..<steps {
                let y = Float(i) * 0.26 + 0.13
                let z = Float(i) * -0.34
                root.addChildNode(box(1.5, 0.26, 0.34, wood,
                                      at: SCNVector3(0, y, z), chamfer: 0.02))
            }
            for side: Float in [-1, 1] {
                for i in stride(from: 0, to: steps, by: 2) {
                    let y = Float(i) * 0.26 + 0.62
                    let z = Float(i) * -0.34
                    root.addChildNode(cyl(0.04, 0.7, accent,
                                          at: SCNVector3(side * 0.7, y, z)))
                }
                // Sloping handrail
                let rail = SCNNode(geometry: SCNBox(width: 0.08, height: 0.08,
                                                    length: CGFloat(Double(steps) * 0.43),
                                                    chamferRadius: 0.03))
                rail.geometry?.materials = [accent]
                rail.position = SCNVector3(side * 0.7,
                                           Float(steps) * 0.13 + 0.9,
                                           Float(steps) * -0.17)
                rail.eulerAngles.x = atan2(Float(steps) * 0.26, Float(steps) * 0.34)
                root.addChildNode(rail)
            }

        case .bridge:
            // A gently arched deck with side rails.
            let planks = 12
            for i in 0..<planks {
                let f = Float(i) / Float(planks - 1)
                let arch = sinf(f * .pi) * 0.7
                root.addChildNode(box(2.0, 0.12, 0.42, wood,
                                      at: SCNVector3(0, 0.5 + arch, -3.0 + f * 6.0)))
            }
            for side: Float in [-1, 1] {
                for i in stride(from: 0, to: planks, by: 3) {
                    let f = Float(i) / Float(planks - 1)
                    let arch = sinf(f * .pi) * 0.7
                    root.addChildNode(cyl(0.05, 0.8, accent,
                                          at: SCNVector3(side * 0.95, 0.95 + arch, -3.0 + f * 6.0)))
                }
                // Rope handrail follows the arch as a chain of short bars.
                for i in 0..<planks {
                    let f = Float(i) / Float(planks - 1)
                    let arch = sinf(f * .pi) * 0.7
                    root.addChildNode(box(0.06, 0.06, 0.52, accent,
                                          at: SCNVector3(side * 0.95, 1.32 + arch, -3.0 + f * 6.0)))
                }
            }

        case .fountain:
            root.addChildNode(cyl(1.6, 0.4, tMat(.grey), at: SCNVector3(0, 0.2, 0)))
            let water = SCNNode(geometry: SCNCylinder(radius: 1.42, height: 0.1))
            let wm = SCNMaterial()
            wm.diffuse.contents = ForestTextures.water
            wm.transparency = 0.85
            water.geometry?.materials = [wm]
            water.position = SCNVector3(0, 0.42, 0)
            root.addChildNode(water)
            root.addChildNode(cyl(0.22, 1.1, tMat(.grey), at: SCNVector3(0, 0.9, 0)))
            root.addChildNode(cyl(0.7, 0.14, tMat(.grey), at: SCNVector3(0, 1.4, 0)))
            root.addChildNode(sphere(0.24, tGlow(treasure.accent, intensity: 0.5),
                                     at: SCNVector3(0, 1.62, 0)))
            // Falling water: a soft particle spray from the top bowl.
            let spray = SCNParticleSystem()
            spray.particleImage = ForestTextures.glow
            spray.birthRate = 90
            spray.particleLifeSpan = 1.1
            spray.particleSize = 0.10
            spray.particleColor = UIColor(red: 0.7, green: 0.88, blue: 1.0, alpha: 0.75)
            spray.spreadingAngle = 55
            spray.particleVelocity = 1.6
            spray.acceleration = SCNVector3(0, -6, 0)
            let emitter = SCNNode()
            emitter.position = SCNVector3(0, 1.75, 0)
            emitter.addParticleSystem(spray)
            root.addChildNode(emitter)

        case .statue:
            root.addChildNode(box(1.0, 0.3, 1.0, tMat(.grey), at: SCNVector3(0, 0.15, 0)))
            root.addChildNode(box(0.7, 1.0, 0.7, tMat(.grey), at: SCNVector3(0, 0.8, 0)))
            // The figure on the plinth
            root.addChildNode(sphere(0.34, accent, at: SCNVector3(0, 1.6, 0)))
            root.addChildNode(sphere(0.24, accent, at: SCNVector3(0, 2.05, 0)))
            for side: Float in [-1, 1] {
                let ear = SCNNode(geometry: SCNCapsule(capRadius: 0.06, height: 0.42))
                ear.geometry?.materials = [accent]
                ear.position = SCNVector3(side * 0.1, 2.38, 0)
                ear.eulerAngles.z = side * 0.22
                root.addChildNode(ear)
            }

        case .bench:
            root.addChildNode(box(2.0, 0.12, 0.6, wood, at: SCNVector3(0, 0.48, 0)))
            root.addChildNode(box(2.0, 0.6, 0.10, wood, at: SCNVector3(0, 0.82, -0.25)))
            for dx: Float in [-0.8, 0.8] {
                root.addChildNode(box(0.12, 0.48, 0.56, accent,
                                      at: SCNVector3(dx, 0.24, 0)))
            }

        case .swing:
            // Frame
            for side: Float in [-1, 1] {
                for lean: Float in [-1, 1] {
                    let leg = SCNNode(geometry: SCNCylinder(radius: 0.07, height: 2.5))
                    leg.geometry?.materials = [wood]
                    leg.position = SCNVector3(side * 1.1, 1.2, lean * 0.5)
                    leg.eulerAngles.x = -lean * 0.2
                    root.addChildNode(leg)
                }
            }
            let beam = SCNNode(geometry: SCNCylinder(radius: 0.07, height: 2.4))
            beam.geometry?.materials = [wood]
            beam.eulerAngles.z = .pi / 2
            beam.position = SCNVector3(0, 2.4, 0)
            root.addChildNode(beam)
            // The seat, swinging gently for ever
            let swing = SCNNode()
            for dx: Float in [-0.35, 0.35] {
                swing.addChildNode(cyl(0.02, 1.5, tMat(.brown), at: SCNVector3(dx, -0.75, 0)))
            }
            swing.addChildNode(box(0.9, 0.10, 0.36, accent, at: SCNVector3(0, -1.5, 0)))
            swing.position = SCNVector3(0, 2.4, 0)
            let rock = CABasicAnimation(keyPath: "eulerAngles.x")
            rock.fromValue = -0.28; rock.toValue = 0.28
            rock.duration = 2.1; rock.autoreverses = true; rock.repeatCount = .infinity
            rock.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            swing.addAnimation(rock, forKey: "swing")
            root.addChildNode(swing)

        case .planter:
            root.addChildNode(box(1.4, 0.5, 0.5, wood, at: SCNVector3(0, 0.25, 0)))
            root.addChildNode(box(1.3, 0.1, 0.42, tMat(.brown), at: SCNVector3(0, 0.48, 0)))
            // Real catalog plants growing in it.
            let keys = ["mint", "lemongrass", "basil", "tulip", "marigold"]
            for i in 0..<4 {
                let p = plant(kind: keys[i % keys.count])
                p.scale = SCNVector3(0.5, 0.5, 0.5)
                p.position = SCNVector3(-0.45 + Float(i) * 0.3, 0.5, 0)
                root.addChildNode(p)
            }

        case .lantern:
            // A string of glowing lanterns between two posts.
            for side: Float in [-1, 1] {
                root.addChildNode(cyl(0.06, 2.4, wood, at: SCNVector3(side * 1.6, 1.2, 0)))
            }
            for i in 0..<5 {
                let x = -1.3 + Float(i) * 0.65
                let sag = sinf(Float(i) / 4 * .pi) * 0.22
                let body = SCNNode(geometry: SCNSphere(radius: 0.2))
                body.geometry?.materials = [tGlow(treasure.accent, intensity: 0.85)]
                body.scale = SCNVector3(1, 1.25, 1)
                body.position = SCNVector3(x, 2.2 - sag, 0)
                root.addChildNode(body)
                if i == 2 {
                    let glow = SCNNode()
                    glow.light = SCNLight()
                    glow.light?.type = .omni
                    glow.light?.intensity = 360
                    glow.light?.color = tColor(treasure.accent)
                    glow.position = SCNVector3(x, 2.1, 0)
                    root.addChildNode(glow)
                }
            }

        case .birdhouse:
            root.addChildNode(cyl(0.08, 2.2, wood, at: SCNVector3(0, 1.1, 0)))
            for level in 0..<3 {
                let y = 1.6 + Float(level) * 0.62
                root.addChildNode(box(0.6, 0.5, 0.5, accent, at: SCNVector3(0, y, 0)))
                let roof = SCNNode(geometry: SCNPyramid(width: 0.76, height: 0.3, length: 0.66))
                roof.geometry?.materials = [tMat(.crimson)]
                roof.position = SCNVector3(0, y + 0.25, 0)
                root.addChildNode(roof)
                // Doorway
                root.addChildNode(sphere(0.09, tMat(.brown), at: SCNVector3(0, y + 0.05, 0.26)))
            }

        case .animal:
            root.addChildNode(critter(color: treasure.accent, id: treasure.id))
        }

        return root
    }

    /// A friendly generic critter, coloured per species. Bodies differ by
    /// a hash of the id so the hedgehog and the swan don't look alike.
    private static func critter(color: PlantColor, id: String) -> SCNNode {
        let node = SCNNode()
        let fur = tMat(color)
        let bird = id.contains("robin") || id.contains("owl") || id.contains("duck")
            || id.contains("swan") || id.contains("peacock") || id.contains("kingfisher")

        if bird {
            let body = SCNNode(geometry: SCNSphere(radius: 0.3))
            body.geometry?.materials = [fur]
            body.scale = SCNVector3(0.85, 1.0, 1.15)
            body.position = SCNVector3(0, 0.36, 0)
            node.addChildNode(body)
            let head = SCNNode(geometry: SCNSphere(radius: 0.19))
            head.geometry?.materials = [fur]
            head.position = SCNVector3(0, 0.72, 0.14)
            node.addChildNode(head)
            let beak = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.07, height: 0.2))
            beak.geometry?.materials = [tMat(.gold)]
            beak.eulerAngles.x = .pi / 2
            beak.position = SCNVector3(0, 0.70, 0.34)
            node.addChildNode(beak)
            // Tail feathers
            for a: Float in [-0.4, 0, 0.4] {
                let feather = SCNNode(geometry: SCNBox(width: 0.08, height: 0.03,
                                                       length: 0.4, chamferRadius: 0.02))
                feather.geometry?.materials = [fur]
                feather.position = SCNVector3(sinf(a) * 0.1, 0.38, -0.36)
                feather.eulerAngles.y = a
                node.addChildNode(feather)
            }
            for ex: Float in [-0.09, 0.09] {
                node.addChildNode(sphere(0.04, tMat(.white), at: SCNVector3(ex, 0.76, 0.28)))
            }
        } else {
            let body = SCNNode(geometry: SCNCapsule(capRadius: 0.26, height: 0.95))
            body.geometry?.materials = [fur]
            body.eulerAngles.x = .pi / 2
            body.position = SCNVector3(0, 0.42, 0)
            node.addChildNode(body)
            let head = SCNNode(geometry: SCNSphere(radius: 0.22))
            head.geometry?.materials = [fur]
            head.position = SCNVector3(0, 0.62, 0.48)
            node.addChildNode(head)
            let snout = SCNNode(geometry: SCNCone(topRadius: 0.03, bottomRadius: 0.1, height: 0.24))
            snout.geometry?.materials = [tMat(.cream)]
            snout.eulerAngles.x = .pi / 2
            snout.position = SCNVector3(0, 0.58, 0.70)
            node.addChildNode(snout)
            for ex: Float in [-0.11, 0.11] {
                let ear = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.08, height: 0.2))
                ear.geometry?.materials = [fur]
                ear.position = SCNVector3(ex, 0.82, 0.44)
                node.addChildNode(ear)
                node.addChildNode(sphere(0.045, tMat(.brown), at: SCNVector3(ex, 0.66, 0.66)))
            }
            for (i, (lx, lz)) in [(-0.14, 0.3), (0.14, 0.3), (-0.14, -0.3), (0.14, -0.3)].enumerated() {
                let leg = SCNNode(geometry: SCNCylinder(radius: 0.055, height: 0.4))
                leg.geometry?.materials = [fur]
                leg.position = SCNVector3(Float(lx), 0.2, Float(lz))
                leg.pivot = SCNMatrix4MakeTranslation(0, 0.2, 0)
                leg.position.y = 0.4
                let swing = CABasicAnimation(keyPath: "eulerAngles.x")
                swing.fromValue = -0.4; swing.toValue = 0.4
                swing.duration = 0.3; swing.autoreverses = true
                swing.repeatCount = .infinity
                swing.timeOffset = (i % 2 == 0) ? 0 : 0.3
                leg.addAnimation(swing, forKey: "walk")
                node.addChildNode(leg)
            }
            // Hedgehog and badger get spines / stripes for character.
            if id.contains("hedgehog") {
                for i in 0..<14 {
                    let a = Float(i) / 14 * 2 * .pi
                    let spine = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.04, height: 0.24))
                    spine.geometry?.materials = [tMat(.bark)]
                    spine.position = SCNVector3(cosf(a) * 0.16, 0.62, sinf(a) * 0.28 - 0.1)
                    spine.eulerAngles = SCNVector3(-0.5, 0, cosf(a) * 0.4)
                    node.addChildNode(spine)
                }
            } else if id.contains("badger") {
                node.addChildNode(box(0.1, 0.06, 0.44, tMat(.white),
                                      at: SCNVector3(0, 0.74, 0.5)))
            }
        }
        return node
    }

    // MARK: - Placing treasures

    /// Fixed spots on the grounds, so a treasure stays where the child
    /// first found it. The list is walked in earn order.
    private static let groundSpots: [(Float, Float)] = [
        (10, 50), (-12, 48), (22, 46), (-22, 40), (6, 38), (-6, 34),
        (30, 34), (-30, 30), (16, 26), (-16, 22), (38, 20), (-38, 18),
        (2, 18), (24, 8), (-24, 6), (44, 2), (-44, 0), (12, -6),
        (-12, -10), (32, -16), (-32, -20), (0, -26), (20, -32), (-20, -36),
        (46, -30), (-46, -34), (8, -44), (-8, -48), (28, -50), (-28, -54)
    ]

    /// An earned animal and the patch of forest it roams.
    struct Critter {
        let node: SCNNode
        /// Centre of its wander circle.
        let home: SCNVector3
        let radius: Float
    }

    struct GroundTreasures {
        /// Circles the child can't walk through.
        let obstacles: [(Float, Float, Float)]
        let critters: [Critter]
    }

    /// Add every earned outdoor treasure to the world.
    static func placeGroundTreasures(_ treasures: [ForestTreasure],
                                     in root: SCNNode) -> GroundTreasures {
        var obstacles: [(Float, Float, Float)] = []
        var critters: [Critter] = []
        let outdoor = treasures.filter { $0.placement == .grounds }
        var spotIndex = 0
        var animalIndex = 0

        for treasure in outdoor {
            let node = treasureNode(treasure)
            if treasure.form == .animal {
                // Animals roam their own little patch rather than standing
                // on a plinth; the coordinator moves them each frame.
                let homes: [(Float, Float)] = [(-14, 34), (26, 20), (-4, 8),
                                               (36, -6), (-30, -14), (12, -30),
                                               (48, 28), (-46, 12), (18, -46)]
                let (hx, hz) = homes[animalIndex % homes.count]
                let radius = 4.5 + Float(animalIndex % 4) * 2.0
                animalIndex += 1
                node.name = "critter.\(treasure.id)"
                place(node, x: hx, z: hz, sink: 0.05)
                root.addChildNode(node)
                critters.append(Critter(node: node,
                                        home: SCNVector3(hx, 0, hz),
                                        radius: radius))
                continue
            }
            let (x, z) = groundSpots[spotIndex % groundSpots.count]
            spotIndex += 1
            place(node, x: x, z: z, sink: 0.08)
            // Face roughly toward the spawn glade so things look arranged.
            node.eulerAngles.y = atan2(0 - x, 58 - z)
            root.addChildNode(node)
            let radius: Float = switch treasure.form {
            case .fountain: 1.9
            case .bridge, .staircase: 1.4
            case .statue, .swing, .birdhouse: 1.0
            default: 0.9
            }
            obstacles.append((x, z, radius))
        }
        return GroundTreasures(obstacles: obstacles, critters: critters)
    }

    /// Arrange earned furniture inside a room. Slots are laid out around
    /// the walls so nothing lands on the doorway or on the child's head.
    static func placeInteriorTreasures(_ treasures: [ForestTreasure],
                                       kind: InteriorKind,
                                       in root: SCNNode,
                                       roomWidth w: Float, roomDepth d: Float) {
        let placement: TreasurePlacement = switch kind {
        case .castle: .castle
        case .cottage: .cottage
        case .treehouse: .treehouse
        }
        let mine = treasures.filter { $0.placement == placement }

        // Slots hug the walls; the middle stays walkable.
        let slots: [(Float, Float, Float)] = [   // x, z, yaw
            (-w / 2 + 2.0, -d / 2 + 2.0, 0.8),
            (w / 2 - 2.0, -d / 2 + 2.0, -0.8),
            (-w / 2 + 2.0, 0, 1.6),
            (w / 2 - 2.0, 0, -1.6),
            (-w / 2 + 2.4, d / 2 - 2.4, 2.4),
            (w / 2 - 2.4, d / 2 - 2.4, -2.4),
            (0, -d / 2 + 1.6, 0),
            (-w / 4, -d / 2 + 3.4, 0.4),
            (w / 4, -d / 2 + 3.4, -0.4),
            (-w / 3, d / 2 - 3.6, 2.8),
            (w / 3, d / 2 - 3.6, -2.8),
            (0, 0, 0)
        ]

        for (i, treasure) in mine.enumerated() {
            let node = treasureNode(treasure)
            switch treasure.form {
            case .rug:
                // Rugs go on the floor in the middle, never on a wall slot.
                node.position = SCNVector3(0, 0.02, Float(i % 2) * 2.0 - 1.0)
            case .painting:
                // Hang on the back wall, spaced along it.
                let span = w - 4
                let n = max(1, mine.filter { $0.form == .painting }.count)
                let index = mine.filter { $0.form == .painting }
                    .firstIndex(of: treasure) ?? 0
                node.position = SCNVector3(-span / 2 + span * Float(index) / Float(max(1, n - 1)),
                                           0, -d / 2 + 0.4)
            case .banner:
                node.position = SCNVector3(0, 0.6, -d / 2 + 0.8)
            case .lamp, .lantern:
                node.position = SCNVector3(w / 2 - 1.4, 0, Float(i % 3) * 2.2 - 2.2)
            default:
                let (x, z, yaw) = slots[i % slots.count]
                node.position = SCNVector3(x, 0, z)
                node.eulerAngles.y = yaw
            }
            root.addChildNode(node)
        }
    }
}
