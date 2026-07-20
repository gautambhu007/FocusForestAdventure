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

    /// Keyed by node name: "learn.<key>"
    static let learnItems: [String: ForestLearnItem] = [
        "sunflower": ForestLearnItem(emoji: "🌻", name: String(localized: "Sunflower"),
            fact: String(localized: "Sunflowers turn their faces to follow the sun across the sky!")),
        "tulip": ForestLearnItem(emoji: "🌷", name: String(localized: "Tulip"),
            fact: String(localized: "Tulips close their petals at night to keep warm.")),
        "daisy": ForestLearnItem(emoji: "🌼", name: String(localized: "Daisy"),
            fact: String(localized: "A daisy is really many tiny flowers packed together in one!")),
        "lavender": ForestLearnItem(emoji: "💜", name: String(localized: "Lavender"),
            fact: String(localized: "Lavender smells so nice that bees and butterflies love it.")),
        "mushroom": ForestLearnItem(emoji: "🍄", name: String(localized: "Mushroom"),
            fact: String(localized: "Mushrooms are not plants — they are fungi, and they help old leaves turn back into soil.")),
        "fern": ForestLearnItem(emoji: "🌿", name: String(localized: "Fern"),
            fact: String(localized: "Ferns are older than dinosaurs — they have no flowers at all!")),
        "berry": ForestLearnItem(emoji: "🫐", name: String(localized: "Berry Bush"),
            fact: String(localized: "Birds eat berries and spread the seeds so new bushes can grow.")),
        "tallgrass": ForestLearnItem(emoji: "🌾", name: String(localized: "Tall Grass"),
            fact: String(localized: "Tall grass is a cozy hiding home for rabbits and crickets.")),
        "goldfish": ForestLearnItem(emoji: "🐠", name: String(localized: "Goldfish"),
            fact: String(localized: "Fish breathe underwater with special slits called gills.")),
        "trout": ForestLearnItem(emoji: "🐟", name: String(localized: "Trout"),
            fact: String(localized: "Trout love cold, clean rivers and can leap right out of the water!")),
        "catfish": ForestLearnItem(emoji: "🐡", name: String(localized: "Catfish"),
            fact: String(localized: "Catfish have whiskers like a cat — they use them to feel for food in the mud."))
    ]

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

    static func plant(kind: String) -> SCNNode {
        let root = SCNNode()
        root.name = "learn.\(kind)"
        switch kind {
        case "sunflower":
            let stem = SCNNode(geometry: SCNCylinder(radius: 0.05, height: 1.6))
            stem.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.30, green: 0.55, blue: 0.28, alpha: 1)
            stem.position = SCNVector3(0, 0.8, 0)
            root.addChildNode(stem)
            let head = SCNNode(geometry: SCNPlane(width: 0.9, height: 0.9))
            let m = SCNMaterial()
            m.diffuse.contents = ForestTextures.flower(hue: 0.13)
            m.isDoubleSided = true; m.transparencyMode = .aOne
            head.geometry?.materials = [m]
            head.position = SCNVector3(0, 1.65, 0)
            head.constraints = [SCNBillboardConstraint()]
            root.addChildNode(head)
        case "tulip":
            let stem = SCNNode(geometry: SCNCylinder(radius: 0.035, height: 0.8))
            stem.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.32, green: 0.58, blue: 0.30, alpha: 1)
            stem.position = SCNVector3(0, 0.4, 0)
            root.addChildNode(stem)
            let cup = SCNNode(geometry: SCNSphere(radius: 0.16))
            cup.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.92, green: 0.30, blue: 0.45, alpha: 1)
            cup.scale = SCNVector3(1, 1.35, 1)
            cup.position = SCNVector3(0, 0.92, 0)
            root.addChildNode(cup)
        case "daisy":
            let stem = SCNNode(geometry: SCNCylinder(radius: 0.03, height: 0.6))
            stem.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.35, green: 0.62, blue: 0.36, alpha: 1)
            stem.position = SCNVector3(0, 0.3, 0)
            root.addChildNode(stem)
            let head = SCNNode(geometry: SCNPlane(width: 0.5, height: 0.5))
            let m = SCNMaterial()
            m.diffuse.contents = ForestTextures.flower(hue: 0.55)
            m.isDoubleSided = true; m.transparencyMode = .aOne
            head.geometry?.materials = [m]
            head.position = SCNVector3(0, 0.62, 0)
            head.constraints = [SCNBillboardConstraint()]
            root.addChildNode(head)
        case "lavender":
            for dx in [-0.12, 0, 0.12] {
                let stem = SCNNode(geometry: SCNCylinder(radius: 0.025, height: 0.9))
                stem.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.35, green: 0.58, blue: 0.38, alpha: 1)
                stem.position = SCNVector3(Float(dx), 0.45, Float(dx) * 0.5)
                root.addChildNode(stem)
                let bud = SCNNode(geometry: SCNCapsule(capRadius: 0.06, height: 0.3))
                bud.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.62, green: 0.48, blue: 0.85, alpha: 1)
                bud.position = SCNVector3(Float(dx), 1.0, Float(dx) * 0.5)
                root.addChildNode(bud)
            }
        case "mushroom":
            let stalk = SCNNode(geometry: SCNCylinder(radius: 0.09, height: 0.34))
            stalk.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.95, green: 0.92, blue: 0.84, alpha: 1)
            stalk.position = SCNVector3(0, 0.17, 0)
            root.addChildNode(stalk)
            let cap = SCNNode(geometry: SCNSphere(radius: 0.26))
            cap.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.85, green: 0.28, blue: 0.24, alpha: 1)
            cap.scale = SCNVector3(1, 0.55, 1)
            cap.position = SCNVector3(0, 0.38, 0)
            root.addChildNode(cap)
            for (sx, sz) in [(-0.1, 0.08), (0.12, -0.05), (0.0, 0.14)] {
                let dot = SCNNode(geometry: SCNSphere(radius: 0.045))
                dot.geometry?.firstMaterial?.diffuse.contents = UIColor.white
                dot.position = SCNVector3(Float(sx), 0.5, Float(sz))
                root.addChildNode(dot)
            }
        case "fern":
            root.addChildNode(billboard(ForestTextures.fern, width: 1.1, height: 1.1))
        case "berry":
            let bush = SCNNode(geometry: SCNSphere(radius: 0.5))
            bush.geometry?.firstMaterial?.diffuse.contents = ForestTextures.leaves
            bush.scale = SCNVector3(1, 0.75, 1)
            bush.position = SCNVector3(0, 0.4, 0)
            root.addChildNode(bush)
            var s: UInt64 = 7
            for _ in 0..<8 {
                s = s &* 6364136223846793005 &+ 1
                let a = Float((s >> 33) & 1023) / 1023 * 2 * .pi
                s = s &* 6364136223846793005 &+ 1
                let e = Float((s >> 33) & 1023) / 1023
                let berry = SCNNode(geometry: SCNSphere(radius: 0.06))
                berry.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.30, green: 0.35, blue: 0.75, alpha: 1)
                berry.position = SCNVector3(cosf(a) * 0.42, 0.35 + e * 0.35, sinf(a) * 0.42)
                root.addChildNode(berry)
            }
        default: // tallgrass
            root.addChildNode(billboard(ForestTextures.tallGrass, width: 1.3, height: 1.0))
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
