//
//  Forest3DExtras.swift
//  Focus Forest Adventure
//
//  The living layer of the 3D forest: tappable learn-about plants and
//  fish, tall grass, gardens for releasing butterflies, collectible
//  stars, the 3D bunny guide, a continuous flowing river with fish,
//  and the rebuilt (more real) dragon.
//

import SceneKit
import UIKit

// MARK: - Learning content (tap a plant/fish → card + voice)

struct ForestLearnItem {
    let emoji: String
    let name: String
    let fact: String
}

extension Forest3DBuilder {

    /// Keyed by node name: "learn.<key>". Every plant species in the
    /// catalog is tappable, plus the fish that swim in the river.
    static let learnItems: [String: ForestLearnItem] = {
        var items: [String: ForestLearnItem] = [
            "goldfish": ForestLearnItem(emoji: "🐠", name: String(localized: "Goldfish"),
                fact: String(localized: "Fish breathe underwater with special slits called gills.")),
            "trout": ForestLearnItem(emoji: "🐟", name: String(localized: "Trout"),
                fact: String(localized: "Trout love cold, clean rivers and can leap right out of the water!")),
            "catfish": ForestLearnItem(emoji: "🐡", name: String(localized: "Catfish"),
                fact: String(localized: "Catfish have whiskers like a cat — they use them to feel for food in the mud."))
        ]
        for species in PlantCatalog.all {
            items[species.key] = ForestLearnItem(emoji: species.emoji,
                                                 name: species.name,
                                                 fact: species.fact)
        }
        return items
    }()

    // MARK: - Plants

    private static func billboard(_ image: UIImage, width: CGFloat, height: CGFloat) -> SCNNode {
        // Two crossed planes: reads as a bush from every direction.
        let node = SCNNode()
        for angle in [0, Float.pi / 2] {
            let plane = SCNNode(geometry: SCNPlane(width: width, height: height))
            let m = SCNMaterial()
            m.diffuse.contents = image
            m.isDoubleSided = true
            m.transparencyMode = .aOne
            plane.geometry?.materials = [m]
            plane.eulerAngles.y = angle
            plane.position = SCNVector3(0, Float(height / 2), 0)
            node.addChildNode(plane)
        }
        return node
    }

    private static func uiColor(_ c: PlantColor) -> UIColor {
        UIColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
    }

    private static func solid(_ c: PlantColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = uiColor(c)
        m.roughness.contents = 0.85
        return m
    }

    /// Local textured material (the builder's own helper is file-private).
    private static func textured(_ image: UIImage) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = image
        return m
    }

    /// Flower centres and other golden trim. Computed rather than stored:
    /// `SCNMaterial` isn't `Sendable`, so a shared static would be a strict-
    /// concurrency error.
    private static var sharedGold: SCNMaterial { solid(PlantColor(0.98, 0.80, 0.28)) }

    /// A double-sided copy of a material, for flat leaves and petals.
    private static func flat(_ c: PlantColor) -> SCNMaterial {
        let m = solid(c)
        m.isDoubleSided = true
        return m
    }

    /// A flat leaf blade or petal. Takes a shared material so a whole
    /// plant can be flattened into a couple of draw calls.
    private static func facingPlane(width: CGFloat, height: CGFloat,
                                    mat: SCNMaterial) -> SCNNode {
        let node = SCNNode(geometry: SCNPlane(width: width, height: height))
        node.geometry?.materials = [mat]
        return node
    }

    /// Five petals around a golden centre — used by every `.bloom` species
    /// so the flower takes the species' own color exactly.
    private static func flowerHead(radius: Float, mat petalMat: SCNMaterial) -> SCNNode {
        let head = SCNNode()
        for i in 0..<5 {
            let a = Float(i) / 5 * 2 * .pi
            let petal = SCNNode(geometry: SCNSphere(radius: CGFloat(radius * 0.52)))
            petal.geometry?.materials = [petalMat]
            petal.scale = SCNVector3(1, 0.35, 1.25)
            petal.position = SCNVector3(cosf(a) * radius * 0.62, 0, sinf(a) * radius * 0.62)
            petal.eulerAngles.y = -a
            head.addChildNode(petal)
        }
        let centre = SCNNode(geometry: SCNSphere(radius: CGFloat(radius * 0.34)))
        centre.geometry?.materials = [sharedGold]
        centre.scale = SCNVector3(1, 0.6, 1)
        head.addChildNode(centre)
        return head
    }

    /// Deterministic per-species jitter, so a species looks the same
    /// every launch but each individual differs a little.
    private struct Wobble {
        var s: UInt64
        init(_ seed: Int) { s = UInt64(bitPattern: Int64(seed &* 2654435761 &+ 12345)) | 1 }
        mutating func next() -> Float {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return Float((s >> 33) & 0xFFFF) / Float(0xFFFF)
        }
        mutating func range(_ a: Float, _ b: Float) -> Float { a + next() * (b - a) }
    }

    /// Grow one plant from the catalog. `kind` is the species key; the
    /// form archetype decides the geometry, the species supplies height
    /// and colors. Unknown keys fall back to a grass tuft.
    static func plant(kind: String) -> SCNNode {
        let root = SCNNode()
        root.name = "learn.\(kind)"
        guard let species = PlantCatalog.plant(kind) else {
            root.addChildNode(billboard(ForestTextures.tallGrass, width: 1.3, height: 1.0))
            return root
        }

        let h = species.height
        let accent = species.accent
        let foliage = species.foliage
        var rng = Wobble(abs(kind.hashValue))

        // Shared per-plant materials: every form below draws from these, so
        // one plant is a couple of draw calls rather than one per petal.
        let foliageMat = solid(foliage)
        let accentMat = solid(accent)
        let foliageFlat = flat(foliage)
        let accentFlat = flat(accent)
        let barkMat = textured(ForestTextures.bark)
        let whiteMat = solid(PlantColor(0.97, 0.97, 0.94))

        switch species.form {

        case .tuft:
            // Blades fanning out of the ground, tinted to the species.
            let blades = billboard(ForestTextures.tallGrass,
                                   width: CGFloat(h * 1.15), height: CGFloat(h))
            for child in blades.childNodes {
                child.geometry?.firstMaterial?.multiply.contents = uiColor(foliage)
            }
            root.addChildNode(blades)
            // A few taller blades in the accent color break up the silhouette.
            for _ in 0..<3 {
                let blade = facingPlane(width: CGFloat(h * 0.10),
                                        height: CGFloat(h * rng.range(0.8, 1.25)),
                                        mat: accentFlat)
                blade.position = SCNVector3(rng.range(-0.18, 0.18),
                                            h * 0.55,
                                            rng.range(-0.18, 0.18))
                blade.eulerAngles.z = rng.range(-0.25, 0.25)
                root.addChildNode(blade)
            }

        case .cane:
            // Segmented stalks with a knuckle between each section.
            let stalks = 3
            for i in 0..<stalks {
                let a = Float(i) / Float(stalks) * 2 * .pi
                let x = cosf(a) * 0.16, z = sinf(a) * 0.16
                let segments = 5
                let segH = h / Float(segments)
                for s in 0..<segments {
                    let seg = SCNNode(geometry: SCNCylinder(radius: CGFloat(h * 0.032),
                                                            height: CGFloat(segH * 0.9)))
                    seg.geometry?.materials = [foliageMat]
                    seg.position = SCNVector3(x, segH * (Float(s) + 0.5), z)
                    root.addChildNode(seg)
                    let knuckle = SCNNode(geometry: SCNSphere(radius: CGFloat(h * 0.038)))
                    knuckle.geometry?.materials = [accentMat]
                    knuckle.position = SCNVector3(x, segH * Float(s + 1), z)
                    root.addChildNode(knuckle)
                }
                // Long leaves peeling off the top third.
                for l in 0..<3 {
                    let leaf = facingPlane(width: CGFloat(h * 0.10),
                                           height: CGFloat(h * 0.34), mat: foliageFlat)
                    leaf.position = SCNVector3(x, h * (0.62 + Float(l) * 0.12), z)
                    leaf.eulerAngles = SCNVector3(0, rng.range(0, 6.28), rng.range(-0.7, 0.7))
                    root.addChildNode(leaf)
                }
            }

        case .reed:
            // Slim stalks, each topped with a seed head.
            for i in 0..<5 {
                let x = rng.range(-0.14, 0.14), z = rng.range(-0.14, 0.14)
                let sh = h * rng.range(0.8, 1.0)
                let stem = SCNNode(geometry: SCNCylinder(radius: CGFloat(h * 0.018),
                                                         height: CGFloat(sh)))
                stem.geometry?.materials = [foliageMat]
                stem.position = SCNVector3(x, sh / 2, z)
                stem.eulerAngles.z = rng.range(-0.08, 0.08)
                root.addChildNode(stem)
                let head = SCNNode(geometry: SCNCapsule(capRadius: CGFloat(h * 0.05),
                                                        height: CGFloat(h * 0.26)))
                head.geometry?.materials = [accentMat]
                head.position = SCNVector3(x, sh + h * 0.09, z)
                root.addChildNode(head)
                _ = i
            }

        case .bloom:
            let stemH = h * 0.82
            let stem = SCNNode(geometry: SCNCylinder(radius: CGFloat(h * 0.028),
                                                     height: CGFloat(stemH)))
            stem.geometry?.materials = [foliageMat]
            stem.position = SCNVector3(0, stemH / 2, 0)
            root.addChildNode(stem)
            for side: Float in [-1, 1] {
                let leaf = facingPlane(width: CGFloat(h * 0.26), height: CGFloat(h * 0.12),
                                       mat: foliageFlat)
                leaf.position = SCNVector3(side * h * 0.12, stemH * 0.42, 0)
                leaf.eulerAngles.z = side * 0.5
                root.addChildNode(leaf)
            }
            let head = flowerHead(radius: h * 0.26, mat: accentFlat)
            head.position = SCNVector3(0, stemH + h * 0.06, 0)
            root.addChildNode(head)

        case .spike:
            // Several stems carrying tapering flower spires.
            for i in 0..<3 {
                let dx = (Float(i) - 1) * h * 0.13
                let sh = h * rng.range(0.75, 1.0)
                let stem = SCNNode(geometry: SCNCylinder(radius: CGFloat(h * 0.022),
                                                         height: CGFloat(sh * 0.7)))
                stem.geometry?.materials = [foliageMat]
                stem.position = SCNVector3(dx, sh * 0.35, dx * 0.4)
                root.addChildNode(stem)
                // Bells getting smaller toward the tip.
                for b in 0..<5 {
                    let f = Float(b) / 4
                    let bell = SCNNode(geometry: SCNSphere(radius: CGFloat(h * 0.06 * (1 - f * 0.55))))
                    bell.geometry?.materials = [accentMat]
                    bell.scale = SCNVector3(1, 1.3, 1)
                    bell.position = SCNVector3(dx, sh * (0.66 + f * 0.30), dx * 0.4)
                    root.addChildNode(bell)
                }
            }

        case .bush:
            // Two or three overlapping leafy puffs.
            for i in 0..<3 {
                let r = h * (0.42 - Float(i) * 0.06)
                let puff = SCNNode(geometry: SCNSphere(radius: CGFloat(r)))
                puff.geometry?.materials = [foliageMat]
                puff.scale = SCNVector3(1, 0.82, 1)
                puff.position = SCNVector3(rng.range(-0.22, 0.22) * h,
                                           h * (0.42 + Float(i) * 0.14),
                                           rng.range(-0.22, 0.22) * h)
                root.addChildNode(puff)
            }
            // Blossoms dotted over the surface.
            for _ in 0..<7 {
                let a = rng.range(0, 6.28)
                let e = rng.range(0.2, 0.95)
                let bloom = SCNNode(geometry: SCNSphere(radius: CGFloat(h * 0.055)))
                bloom.geometry?.materials = [accentMat]
                bloom.position = SCNVector3(cosf(a) * h * 0.36,
                                            h * (0.35 + e * 0.55),
                                            sinf(a) * h * 0.36)
                root.addChildNode(bloom)
            }

        case .berryBush:
            for i in 0..<2 {
                let puff = SCNNode(geometry: SCNSphere(radius: CGFloat(h * 0.44)))
                puff.geometry?.materials = [foliageMat]
                puff.scale = SCNVector3(1, 0.78, 1)
                puff.position = SCNVector3(rng.range(-0.2, 0.2) * h,
                                           h * (0.44 + Float(i) * 0.2),
                                           rng.range(-0.2, 0.2) * h)
                root.addChildNode(puff)
            }
            // Berries hang in little clusters of three.
            for _ in 0..<6 {
                let a = rng.range(0, 6.28)
                let e = rng.range(0.25, 0.85)
                let cx = cosf(a) * h * 0.40, cz = sinf(a) * h * 0.40
                for b in 0..<3 {
                    let berry = SCNNode(geometry: SCNSphere(radius: CGFloat(h * 0.055)))
                    berry.geometry?.materials = [accentMat]
                    berry.position = SCNVector3(cx + Float(b - 1) * h * 0.06,
                                                h * (0.30 + e * 0.55) - Float(b) * h * 0.03,
                                                cz)
                    root.addChildNode(berry)
                }
            }

        case .fruitTree:
            let trunkH = h * 0.45
            let trunk = SCNNode(geometry: SCNCylinder(radius: CGFloat(h * 0.055),
                                                      height: CGFloat(trunkH)))
            trunk.geometry?.materials = [barkMat]
            trunk.position = SCNVector3(0, trunkH / 2, 0)
            root.addChildNode(trunk)
            let canopyMat = foliageMat
            let puffs: [(Float, Float, Float, Float)] = [
                (0.34, 0, 0.80, 0), (0.24, -0.22, 0.66, 0.10),
                (0.24, 0.22, 0.68, -0.08), (0.20, 0.04, 0.98, 0.06)
            ]
            for (r, dx, dy, dz) in puffs {
                let puff = SCNNode(geometry: SCNSphere(radius: CGFloat(h * r)))
                puff.geometry?.materials = [canopyMat]
                puff.scale = SCNVector3(1, 0.86, 1)
                puff.position = SCNVector3(h * dx, h * dy, h * dz)
                root.addChildNode(puff)
            }
            // Fruit hanging under the canopy.
            for _ in 0..<8 {
                let a = rng.range(0, 6.28)
                let rad = rng.range(0.18, 0.36) * h
                let fruit = SCNNode(geometry: SCNSphere(radius: CGFloat(h * 0.055)))
                fruit.geometry?.materials = [accentMat]
                fruit.position = SCNVector3(cosf(a) * rad,
                                            h * rng.range(0.62, 0.86),
                                            sinf(a) * rad)
                root.addChildNode(fruit)
            }

        case .mushroom:
            let stalkH = h * 0.62
            let stalk = SCNNode(geometry: SCNCylinder(radius: CGFloat(h * 0.16),
                                                      height: CGFloat(stalkH)))
            stalk.geometry?.materials = [foliageMat]
            stalk.position = SCNVector3(0, stalkH / 2, 0)
            root.addChildNode(stalk)
            let cap = SCNNode(geometry: SCNSphere(radius: CGFloat(h * 0.46)))
            cap.geometry?.materials = [accentMat]
            cap.scale = SCNVector3(1, 0.55, 1)
            cap.position = SCNVector3(0, stalkH + h * 0.06, 0)
            root.addChildNode(cap)
            for _ in 0..<4 {
                let a = rng.range(0, 6.28)
                let dot = SCNNode(geometry: SCNSphere(radius: CGFloat(h * 0.07)))
                dot.geometry?.materials = [whiteMat]
                dot.position = SCNVector3(cosf(a) * h * 0.26,
                                          stalkH + h * 0.19,
                                          sinf(a) * h * 0.26)
                root.addChildNode(dot)
            }

        case .groundCover:
            // A low spreading mat of leaves with flowers or fruit peeping out.
            for _ in 0..<9 {
                let a = rng.range(0, 6.28)
                let rad = rng.range(0, 0.45)
                let leaf = SCNNode(geometry: SCNSphere(radius: CGFloat(max(0.06, h * 0.9))))
                leaf.geometry?.materials = [foliageMat]
                leaf.scale = SCNVector3(1.4, 0.28, 1.4)
                leaf.position = SCNVector3(cosf(a) * rad, h * 0.4, sinf(a) * rad)
                root.addChildNode(leaf)
            }
            for _ in 0..<4 {
                let a = rng.range(0, 6.28)
                let dot = SCNNode(geometry: SCNSphere(radius: CGFloat(max(0.04, h * 0.42))))
                dot.geometry?.materials = [accentMat]
                dot.position = SCNVector3(cosf(a) * 0.3, h * 0.85, sinf(a) * 0.3)
                root.addChildNode(dot)
            }

        case .vine:
            // A wavy climbing stem with leaves and flowers along it.
            let steps = 9
            for i in 0..<steps {
                let f = Float(i) / Float(steps - 1)
                let y = f * h
                let x = sinf(f * 5.4) * h * 0.10
                let z = cosf(f * 4.1) * h * 0.08
                let seg = SCNNode(geometry: SCNSphere(radius: CGFloat(h * 0.032)))
                seg.geometry?.materials = [foliageMat]
                seg.position = SCNVector3(x, y, z)
                root.addChildNode(seg)
                if i % 2 == 0 {
                    let leaf = facingPlane(width: CGFloat(h * 0.20), height: CGFloat(h * 0.16),
                                           mat: foliageFlat)
                    leaf.position = SCNVector3(x + h * 0.11, y, z)
                    leaf.eulerAngles.z = rng.range(-0.4, 0.4)
                    root.addChildNode(leaf)
                }
                if i % 3 == 1 {
                    let bloom = SCNNode(geometry: SCNSphere(radius: CGFloat(h * 0.055)))
                    bloom.geometry?.materials = [accentMat]
                    bloom.position = SCNVector3(x - h * 0.09, y, z + h * 0.04)
                    root.addChildNode(bloom)
                }
            }

        case .succulent:
            // Thick upright pads radiating from the base.
            for i in 0..<6 {
                let a = Float(i) / 6 * 2 * .pi
                let pad = SCNNode(geometry: SCNSphere(radius: CGFloat(h * 0.30)))
                pad.geometry?.materials = [foliageMat]
                pad.scale = SCNVector3(0.42, 1.5, 0.9)
                pad.position = SCNVector3(cosf(a) * h * 0.18, h * 0.45, sinf(a) * h * 0.18)
                pad.eulerAngles = SCNVector3(cosf(a) * 0.35, -a, sinf(a) * 0.35)
                root.addChildNode(pad)
            }
            let crown = SCNNode(geometry: SCNSphere(radius: CGFloat(h * 0.12)))
            crown.geometry?.materials = [accentMat]
            crown.position = SCNVector3(0, h * 0.92, 0)
            root.addChildNode(crown)

        case .palm:
            let trunkH = h * 0.72
            let trunk = SCNNode(geometry: SCNCylinder(radius: CGFloat(h * 0.05),
                                                      height: CGFloat(trunkH)))
            trunk.geometry?.materials = [barkMat]
            trunk.position = SCNVector3(0, trunkH / 2, 0)
            root.addChildNode(trunk)
            // Arching fronds around the crown.
            for i in 0..<7 {
                let a = Float(i) / 7 * 2 * .pi
                let frond = facingPlane(width: CGFloat(h * 0.20), height: CGFloat(h * 0.52),
                                        mat: foliageFlat)
                frond.pivot = SCNMatrix4MakeTranslation(0, Float(h * 0.26), 0)
                frond.position = SCNVector3(cosf(a) * h * 0.06, trunkH, sinf(a) * h * 0.06)
                frond.eulerAngles = SCNVector3(cosf(a) * 0.9, -a, sinf(a) * 0.9)
                root.addChildNode(frond)
            }
            // Fruit bunched under the crown.
            for i in 0..<5 {
                let a = Float(i) / 5 * 2 * .pi
                let fruit = SCNNode(geometry: SCNSphere(radius: CGFloat(h * 0.055)))
                fruit.geometry?.materials = [accentMat]
                fruit.position = SCNVector3(cosf(a) * h * 0.10, trunkH - h * 0.06, sinf(a) * h * 0.10)
                root.addChildNode(fruit)
            }

        case .rootVeg:
            // The root shoulder peeking out of the soil, leaves on top.
            let rootNode = SCNNode(geometry: SCNCone(topRadius: CGFloat(h * 0.22),
                                                     bottomRadius: 0,
                                                     height: CGFloat(h * 0.5)))
            rootNode.geometry?.materials = [accentMat]
            rootNode.position = SCNVector3(0, h * 0.12, 0)
            rootNode.eulerAngles.x = .pi        // point the tip down into the soil
            root.addChildNode(rootNode)
            for i in 0..<5 {
                let a = Float(i) / 5 * 2 * .pi
                let leaf = facingPlane(width: CGFloat(h * 0.18), height: CGFloat(h * 0.62),
                                       mat: foliageFlat)
                leaf.pivot = SCNMatrix4MakeTranslation(0, Float(h * 0.31), 0)
                leaf.position = SCNVector3(cosf(a) * h * 0.06, h * 0.34, sinf(a) * h * 0.06)
                leaf.eulerAngles = SCNVector3(cosf(a) * 0.4, -a, sinf(a) * 0.4)
                root.addChildNode(leaf)
            }
        }

        return root
    }

    // MARK: - Garden (release captured butterflies here)

    static func garden() -> SCNNode {
        let root = SCNNode()
        root.name = "garden"
        let plankMat = SCNMaterial()
        plankMat.diffuse.contents = ForestTextures.planks
        // Fence ring
        let radius: Float = 4.2
        for i in 0..<12 {
            let a = Float(i) / 12 * 2 * .pi
            let post = SCNNode(geometry: SCNCylinder(radius: 0.07, height: 0.9))
            post.geometry?.materials = [plankMat]
            post.position = SCNVector3(cosf(a) * radius, 0.45, sinf(a) * radius)
            root.addChildNode(post)
            let rail = SCNNode(geometry: SCNBox(width: 2.3, height: 0.09, length: 0.09, chamferRadius: 0.02))
            rail.geometry?.materials = [plankMat]
            let mid = a + .pi / 12
            rail.position = SCNVector3(cosf(mid) * radius, 0.7, sinf(mid) * radius)
            rail.eulerAngles.y = -mid + .pi / 2
            root.addChildNode(rail)
        }
        // Rose arch entrance
        let arch = SCNNode(geometry: SCNTorus(ringRadius: 1.1, pipeRadius: 0.09))
        arch.geometry?.materials = [plankMat]
        arch.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        arch.position = SCNVector3(0, 1.1, radius)
        root.addChildNode(arch)
        for f: Float in [0.25, 0.5, 0.75] {
            let rose = SCNNode(geometry: SCNSphere(radius: 0.1))
            rose.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.95, green: 0.4, blue: 0.55, alpha: 1)
            let a = Float.pi * f
            rose.position = SCNVector3(cosf(a) * 1.1, 1.1 + sinf(a) * 1.1 - 1.1 + 1.1, radius)
            rose.position.y = 1.1 + sinf(a) * 1.1
            root.addChildNode(rose)
        }
        // Flower bed inside
        for i in 0..<8 {
            let a = Float(i) / 8 * 2 * .pi
            let f = plant(kind: ["tulip", "daisy", "lavender"][i % 3])
            f.name = nil   // garden flowers are decoration, not tap targets
            f.position = SCNVector3(cosf(a) * 2.0, 0, sinf(a) * 2.0)
            root.addChildNode(f)
        }
        return root
    }

    // MARK: - Collectible star

    static func collectibleStar(index: Int) -> SCNNode {
        let root = SCNNode()
        root.name = "star.\(index)"
        let plane = SCNNode(geometry: SCNPlane(width: 0.9, height: 0.9))
        let m = SCNMaterial()
        m.diffuse.contents = ForestTextures.goldStar
        m.emission.contents = ForestTextures.goldStar
        m.emission.intensity = 0.7
        m.isDoubleSided = true
        m.transparencyMode = .aOne
        plane.geometry?.materials = [m]
        root.addChildNode(plane)
        root.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 3.5)))
        let bob = CABasicAnimation(keyPath: "position.y")
        bob.fromValue = 0.0
        bob.toValue = 0.3
        bob.duration = 1.4; bob.autoreverses = true; bob.repeatCount = .infinity
        plane.addAnimation(bob, forKey: "bob")
        return root
    }

    // MARK: - Bunny guide (the mascot, in 3D, waving)

    static func bunnyGuide() -> SCNNode {
        let root = SCNNode()
        root.name = "bunnyGuide"
        let fur = SCNMaterial()
        fur.diffuse.contents = UIColor(red: 0.985, green: 0.965, blue: 0.945, alpha: 1)
        let pink = SCNMaterial()
        pink.diffuse.contents = UIColor(red: 0.975, green: 0.72, blue: 0.76, alpha: 1)

        let body = SCNNode(geometry: SCNSphere(radius: 0.55))
        body.geometry?.materials = [fur]
        body.scale = SCNVector3(1, 1.15, 0.9)
        body.position = SCNVector3(0, 0.62, 0)
        root.addChildNode(body)
        let head = SCNNode(geometry: SCNSphere(radius: 0.42))
        head.geometry?.materials = [fur]
        head.position = SCNVector3(0, 1.55, 0)
        root.addChildNode(head)
        for ex: Float in [-0.18, 0.18] {
            let ear = SCNNode(geometry: SCNCapsule(capRadius: 0.11, height: 0.85))
            ear.geometry?.materials = [fur]
            ear.position = SCNVector3(ex, 2.25, 0)
            ear.eulerAngles.z = -ex * 0.6
            root.addChildNode(ear)
            let inner = SCNNode(geometry: SCNCapsule(capRadius: 0.05, height: 0.5))
            inner.geometry?.materials = [pink]
            inner.position = SCNVector3(ex, 2.25, 0.08)
            inner.eulerAngles.z = -ex * 0.6
            root.addChildNode(inner)
        }
        for ex: Float in [-0.17, 0.17] {
            let eye = SCNNode(geometry: SCNSphere(radius: 0.06))
            eye.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.28, green: 0.22, blue: 0.19, alpha: 1)
            eye.position = SCNVector3(ex, 1.62, 0.38)
            root.addChildNode(eye)
        }
        let nose = SCNNode(geometry: SCNSphere(radius: 0.06))
        nose.geometry?.materials = [pink]
        nose.position = SCNVector3(0, 1.5, 0.42)
        root.addChildNode(nose)
        for ex: Float in [-0.35, 0.35] {
            let foot = SCNNode(geometry: SCNCapsule(capRadius: 0.13, height: 0.5))
            foot.geometry?.materials = [fur]
            foot.eulerAngles.x = .pi / 2
            foot.position = SCNVector3(ex, 0.13, 0.15)
            root.addChildNode(foot)
        }
        // Waving arm
        let arm = SCNNode(geometry: SCNCapsule(capRadius: 0.09, height: 0.55))
        arm.geometry?.materials = [fur]
        arm.pivot = SCNMatrix4MakeTranslation(0, -0.27, 0)
        arm.position = SCNVector3(0.52, 1.05, 0)
        let wave = CABasicAnimation(keyPath: "eulerAngles.z")
        wave.fromValue = -2.4; wave.toValue = -1.4
        wave.duration = 0.5; wave.autoreverses = true; wave.repeatCount = .infinity
        arm.addAnimation(wave, forKey: "wave")
        arm.eulerAngles.z = -1.9
        root.addChildNode(arm)
        let restArm = SCNNode(geometry: SCNCapsule(capRadius: 0.09, height: 0.5))
        restArm.geometry?.materials = [fur]
        restArm.position = SCNVector3(-0.5, 0.85, 0.1)
        restArm.eulerAngles.z = 0.5
        root.addChildNode(restArm)
        return root
    }

    // MARK: - Continuous river + fish

    struct RiverBuild {
        let node: SCNNode
        let material: SCNMaterial
        /// Sampled centerline points (for fish to swim along).
        let path: [SCNVector3]
    }

    static func riverPathPoint(z: Float) -> SCNVector3 {
        let x = 34 * sinf(z * 0.028) + 26
        // Smooth the height so the water doesn't stair-step over bumps.
        var y: Float = 0
        for dz: Float in [-4, 0, 4] {
            y += terrainHeight(x: x, z: z + dz)
        }
        return SCNVector3(x, y / 3 + 0.15, z)
    }

    static func riverRibbon() -> RiverBuild {
        var pathPoints: [SCNVector3] = []
        var vertices: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [Int32] = []
        let halfW: Float = 3.0
        let z0: Float = -worldHalf + 4
        let z1: Float = worldHalf - 4
        let steps = 110
        for i in 0...steps {
            let z = z0 + (z1 - z0) * Float(i) / Float(steps)
            let c = riverPathPoint(z: z)
            pathPoints.append(c)
            // Perpendicular to the path in the xz-plane
            let slope = 34 * 0.028 * cosf(z * 0.028)     // dx/dz
            let len = sqrtf(slope * slope + 1)
            let nx = 1 / len, nz = -slope / len
            vertices.append(SCNVector3(c.x - nx * halfW, c.y, c.z - nz * halfW))
            vertices.append(SCNVector3(c.x + nx * halfW, c.y, c.z + nz * halfW))
            let v = Double(i) / 6.0
            uvs.append(CGPoint(x: 0, y: v))
            uvs.append(CGPoint(x: 1, y: v))
            if i > 0 {
                let a = Int32((i - 1) * 2)
                indices.append(contentsOf: [a, a + 1, a + 2, a + 2, a + 1, a + 3])
            }
        }
        let normals = [SCNVector3](repeating: SCNVector3(0, 1, 0), count: vertices.count)
        let geo = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices),
                      SCNGeometrySource(normals: normals),
                      SCNGeometrySource(textureCoordinates: uvs)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        let m = SCNMaterial()
        m.diffuse.contents = ForestTextures.water
        m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
        m.transparency = 0.88
        m.isDoubleSided = true
        geo.materials = [m]
        let node = SCNNode(geometry: geo)
        node.name = "river"
        return RiverBuild(node: node, material: m, path: pathPoints)
    }

    static func fish(kind: String) -> SCNNode {
        let root = SCNNode()
        root.name = "learn.\(kind)"
        let color: UIColor
        switch kind {
        case "goldfish": color = UIColor(red: 0.98, green: 0.55, blue: 0.20, alpha: 1)
        case "trout": color = UIColor(red: 0.55, green: 0.70, blue: 0.75, alpha: 1)
        default: color = UIColor(red: 0.55, green: 0.48, blue: 0.42, alpha: 1)
        }
        let m = SCNMaterial()
        m.diffuse.contents = color
        let body = SCNNode(geometry: SCNSphere(radius: 0.28))
        body.geometry?.materials = [m]
        body.scale = SCNVector3(0.7, 0.8, 1.6)
        root.addChildNode(body)
        let tail = SCNNode(geometry: SCNCone(topRadius: 0.02, bottomRadius: 0.2, height: 0.35))
        tail.geometry?.materials = [m]
        tail.eulerAngles.x = -.pi / 2
        tail.position = SCNVector3(0, 0, -0.55)
        tail.name = "tail"
        root.addChildNode(tail)
        let fin = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.12, height: 0.22))
        fin.geometry?.materials = [m]
        fin.position = SCNVector3(0, 0.28, 0)
        root.addChildNode(fin)
        for ex: Float in [-0.14, 0.14] {
            let eye = SCNNode(geometry: SCNSphere(radius: 0.05))
            eye.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            eye.position = SCNVector3(ex, 0.08, 0.32)
            root.addChildNode(eye)
            let pupil = SCNNode(geometry: SCNSphere(radius: 0.025))
            pupil.geometry?.firstMaterial?.diffuse.contents = UIColor.black
            pupil.position = SCNVector3(ex * 1.1, 0.08, 0.36)
            root.addChildNode(pupil)
        }
        return root
    }

    // MARK: - The rebuilt dragon (overlapping tapered body, real wings)

    static func dragonV2() -> (root: SCNNode, segments: [SCNNode]) {
        let root = SCNNode()
        root.name = "dragon"
        var segments: [SCNNode] = []
        let count = 16
        for i in 0..<count {
            let f = Float(i) / Float(count - 1)
            // Neck thickens into the chest then tapers to a tail tip.
            let r = 0.42 + 0.55 * sinf(.pi * powf(f, 0.8)) * (1 - f * 0.35) + (i == 0 ? 0.25 : 0)
            let seg = SCNNode(geometry: SCNSphere(radius: CGFloat(r)))
            let m = SCNMaterial()
            m.diffuse.contents = UIColor(red: 0.22 + 0.08 * CGFloat(f),
                                         green: 0.60 + 0.08 * CGFloat(f),
                                         blue: 0.38 + 0.20 * CGFloat(f), alpha: 1)
            m.roughness.contents = 0.6
            seg.geometry?.materials = [m]
            // Dorsal ridge all the way down the spine
            if i > 0 && i < count - 1 {
                let spike = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: CGFloat(r) * 0.22,
                                                      height: CGFloat(r) * 0.7))
                spike.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.96, green: 0.70, blue: 0.24, alpha: 1)
                spike.position = SCNVector3(0, r * 0.95, 0)
                seg.addChildNode(spike)
            }
            if i == 0 {
                seg.scale = SCNVector3(0.9, 0.85, 1.25)   // head: longer than wide
                let snout = SCNNode(geometry: SCNSphere(radius: 0.32))
                snout.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.50, green: 0.82, blue: 0.60, alpha: 1)
                snout.scale = SCNVector3(0.85, 0.6, 1.2)
                snout.position = SCNVector3(0, -0.12, 0.62)
                seg.addChildNode(snout)
                for ex: Float in [-0.24, 0.24] {
                    let eye = SCNNode(geometry: SCNSphere(radius: 0.12))
                    eye.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.85, blue: 0.35, alpha: 1)
                    eye.geometry?.firstMaterial?.emission.contents = UIColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1)
                    eye.geometry?.firstMaterial?.emission.intensity = 0.4
                    eye.position = SCNVector3(ex, 0.24, 0.42)
                    seg.addChildNode(eye)
                    let pupil = SCNNode(geometry: SCNSphere(radius: 0.055))
                    pupil.geometry?.firstMaterial?.diffuse.contents = UIColor.black
                    pupil.position = SCNVector3(ex * 1.05, 0.24, 0.52)
                    seg.addChildNode(pupil)
                    let horn = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.09, height: 0.55))
                    horn.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.94, green: 0.90, blue: 0.78, alpha: 1)
                    horn.position = SCNVector3(ex * 1.3, 0.55, -0.15)
                    horn.eulerAngles = SCNVector3(-0.5, 0, -ex)
                    seg.addChildNode(horn)
                }
                for ex: Float in [-0.10, 0.10] {
                    let nostril = SCNNode(geometry: SCNSphere(radius: 0.035))
                    nostril.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.15, green: 0.35, blue: 0.25, alpha: 1)
                    nostril.position = SCNVector3(ex, -0.02, 1.0)
                    seg.addChildNode(nostril)
                }
            }
            if i == 3 {
                // Big membrane wings at the shoulders
                for side: Float in [-1, 1] {
                    let wing = SCNNode(geometry: SCNPlane(width: 3.4, height: 2.4))
                    let m = SCNMaterial()
                    m.diffuse.contents = ForestTextures.dragonWing
                    m.isDoubleSided = true
                    m.transparencyMode = .aOne
                    wing.geometry?.materials = [m]
                    wing.pivot = SCNMatrix4MakeTranslation(-1.7 * side, -1.0, 0)
                    wing.position = SCNVector3(side * 0.4, 0.5, 0)
                    if side > 0 { wing.eulerAngles.y = .pi }   // mirror
                    let flap = CABasicAnimation(keyPath: "eulerAngles.z")
                    flap.fromValue = -0.85 * side
                    flap.toValue = 0.35 * side
                    flap.duration = 0.8
                    flap.autoreverses = true
                    flap.repeatCount = .infinity
                    flap.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    wing.addAnimation(flap, forKey: "flap")
                    seg.addChildNode(wing)
                }
            }
            root.addChildNode(seg)
            segments.append(seg)
        }
        // Tail fin
        let fin = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.3, height: 0.6))
        fin.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.96, green: 0.70, blue: 0.24, alpha: 1)
        fin.eulerAngles.x = .pi / 2
        segments[count - 1].addChildNode(fin)
        // Soft sparkle trail from the tail
        let sparkle = SCNParticleSystem()
        sparkle.particleImage = ForestTextures.glow
        sparkle.birthRate = 8
        sparkle.particleLifeSpan = 1.4
        sparkle.particleSize = 0.3
        sparkle.particleColor = UIColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 0.7)
        sparkle.particleVelocity = 0.3
        segments[count - 1].addParticleSystem(sparkle)
        return (root, segments)
    }
}
