//
//  Forest3DBuilder.swift
//  Focus Forest Adventure
//
//  Builds the real-3D forest world in SceneKit: a rolling terrain mesh
//  the child walks on, textured trees, a castle on the far hill, a
//  cottage, a treehouse, a winding brook, rainbow, flowers — plus three
//  furnished interiors (castle hall, cottage room, treehouse nook) you
//  can step into by tapping the building. All geometry is procedural
//  and all textures come from ForestTextures.
//

import SceneKit
import UIKit

enum InteriorKind: String {
    case castle, cottage, treehouse
}

enum Forest3DBuilder {

    // MARK: Terrain

    static let worldHalf: Float = 120

    /// Height of the ground at any point — gentle rolling hills, with a
    /// tall ridge to the north where the castle watches over the valley.
    static func terrainHeight(x: Float, z: Float) -> Float {
        var h: Float = 0
        h += 2.1 * sinf(0.030 * x) * cosf(0.024 * z)
        h += 3.2 * sinf(0.013 * (x + 40)) * cosf(0.011 * (z - 30))
        h += 1.0 * sinf(0.05 * x + 1.3) * sinf(0.043 * z)
        // Castle ridge to the north (negative z)
        let ridge = max(0, (-z - 55) / 55)
        h += 10 * ridge * ridge
        return h
    }

    static func terrainNode() -> SCNNode {
        let n = 72
        let step = (worldHalf * 2) / Float(n)
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [Int32] = []
        for row in 0...n {
            for col in 0...n {
                let x = -worldHalf + Float(col) * step
                let z = -worldHalf + Float(row) * step
                let y = terrainHeight(x: x, z: z)
                vertices.append(SCNVector3(x, y, z))
                // Normal by central difference
                let e: Float = 0.8
                let dx = terrainHeight(x: x + e, z: z) - terrainHeight(x: x - e, z: z)
                let dz = terrainHeight(x: x, z: z + e) - terrainHeight(x: x, z: z - e)
                var nx = -dx / (2 * e), nz = -dz / (2 * e)
                let len = sqrtf(nx * nx + 1 + nz * nz)
                nx /= len; nz /= len
                normals.append(SCNVector3(nx, 1 / len, nz))
                uvs.append(CGPoint(x: Double(col) / 3.0, y: Double(row) / 3.0))
            }
        }
        for row in 0..<n {
            for col in 0..<n {
                let a = Int32(row * (n + 1) + col)
                let b = a + 1
                let c = a + Int32(n + 1)
                let d = c + 1
                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }
        let geo = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices),
                      SCNGeometrySource(normals: normals),
                      SCNGeometrySource(textureCoordinates: uvs)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        let mat = SCNMaterial()
        // Leaf-strewn woodland floor, not bare grass — the ground is
        // covered everywhere before a single 3D leaf is placed on top.
        mat.diffuse.contents = ForestTextures.forestFloor
        mat.diffuse.wrapS = .repeat; mat.diffuse.wrapT = .repeat
        mat.roughness.contents = 0.95
        geo.materials = [mat]
        let node = SCNNode(geometry: geo)
        node.name = "terrain"
        return node
    }

    // MARK: Leaf litter

    /// Thousands of fallen leaves lying flat on the ground across the
    /// WHOLE world — every corner, not just clearings. They are baked
    /// into one mesh sharing one material, so the cost is a single draw
    /// call no matter how many leaves there are. Each leaf's four corners
    /// sit on the terrain, so the carpet follows every slope.
    static func leafLitter(count: Int, seed: UInt64 = 424242,
                           scale: Float = 1) -> SCNNode {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [Int32] = []
        vertices.reserveCapacity(count * 4)

        var state = seed | 1
        func rnd() -> Float {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Float((state >> 33) & 0xFFFF) / Float(0xFFFF)
        }

        let reach = worldHalf - 2
        for i in 0..<count {
            let cx = (rnd() * 2 - 1) * reach
            let cz = (rnd() * 2 - 1) * reach
            let size = (0.16 + rnd() * 0.22) * scale
            let angle = rnd() * 2 * .pi
            let lift = 0.02 + rnd() * 0.05

            // Half-extents rotated in the ground plane.
            let ca = cosf(angle) * size, sa = sinf(angle) * size
            let corners: [(Float, Float)] = [
                (-ca + sa, -sa - ca), (ca + sa, sa - ca),
                (-ca - sa, -sa + ca), (ca - sa, sa + ca)
            ]
            // Atlas cell (2×2) — four leaf colors mixed evenly.
            let cell = Int(rnd() * 4) % 4
            let u0 = CGFloat(cell % 2) * 0.5
            let v0 = CGFloat(cell / 2) * 0.5
            let cellUVs: [CGPoint] = [
                CGPoint(x: u0, y: v0 + 0.5), CGPoint(x: u0 + 0.5, y: v0 + 0.5),
                CGPoint(x: u0, y: v0), CGPoint(x: u0 + 0.5, y: v0)
            ]

            let base = Int32(i * 4)
            for (c, (dx, dz)) in corners.enumerated() {
                let x = cx + dx, z = cz + dz
                vertices.append(SCNVector3(x, terrainHeight(x: x, z: z) + lift, z))
                normals.append(SCNVector3(0, 1, 0))
                uvs.append(cellUVs[c])
            }
            indices.append(contentsOf: [base, base + 2, base + 1,
                                        base + 1, base + 2, base + 3])
        }

        let geo = SCNGeometry(
            sources: [SCNGeometrySource(vertices: vertices),
                      SCNGeometrySource(normals: normals),
                      SCNGeometrySource(textureCoordinates: uvs)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )
        let m = SCNMaterial()
        m.diffuse.contents = ForestTextures.leafAtlas
        m.isDoubleSided = true
        m.transparencyMode = .aOne
        m.writesToDepthBuffer = false   // flat on the ground; never z-fights
        m.roughness.contents = 1.0
        geo.materials = [m]

        let node = SCNNode(geometry: geo)
        node.name = "leafLitter"
        node.castsShadow = false
        return node
    }

    /// Drifts of deeper leaves that pile up under the trees and in hollows.
    /// Same single-mesh trick, larger and darker, laid over the base litter.
    static func leafDrifts(count: Int) -> SCNNode {
        let node = leafLitter(count: count, seed: 987_654_321, scale: 1.7)
        node.name = "leafDrifts"
        node.geometry?.firstMaterial?.multiply.contents =
            UIColor(red: 0.74, green: 0.62, blue: 0.46, alpha: 1)
        return node
    }

    // MARK: Small helpers

    private static func material(_ image: UIImage, tileX: CGFloat = 1, tileY: CGFloat = 1) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = image
        if tileX != 1 || tileY != 1 {
            m.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(tileX), Float(tileY), 1)
            m.diffuse.wrapS = .repeat; m.diffuse.wrapT = .repeat
        }
        return m
    }

    private static func colored(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        return m
    }

    private static func place(_ node: SCNNode, x: Float, z: Float, sink: Float = 0.1) {
        node.position = SCNVector3(x, terrainHeight(x: x, z: z) - sink, z)
    }

    // MARK: Trees

    static func tree(scale: Float = 1) -> SCNNode {
        let root = SCNNode()
        root.name = "tree"
        let trunk = SCNNode(geometry: SCNCylinder(radius: 0.35, height: 3.4))
        trunk.geometry?.materials = [material(ForestTextures.bark)]
        trunk.position = SCNVector3(0, 1.7, 0)
        root.addChildNode(trunk)
        let leafMat = material(ForestTextures.leaves)
        let sizes: [(Float, Float, Float, Float)] = [   // (radius, x, y, z)
            (1.9, 0, 4.4, 0), (1.3, -1.1, 3.6, 0.4), (1.3, 1.1, 3.7, -0.3), (1.1, 0.2, 5.4, 0.3)
        ]
        for (r, x, y, z) in sizes {
            let puff = SCNNode(geometry: SCNSphere(radius: CGFloat(r)))
            puff.geometry?.materials = [leafMat]
            puff.position = SCNVector3(x, y, z)
            puff.scale = SCNVector3(1, 0.85, 1)
            root.addChildNode(puff)
        }
        root.scale = SCNVector3(scale, scale, scale)
        // gentle sway
        let sway = CABasicAnimation(keyPath: "eulerAngles.z")
        sway.fromValue = -0.02; sway.toValue = 0.02
        sway.duration = 2.6 + Double(scale); sway.autoreverses = true
        sway.repeatCount = .infinity
        root.addAnimation(sway, forKey: "sway")
        return root
    }

    // MARK: Cottage (tap to go inside)

    static func cottage() -> SCNNode {
        let root = SCNNode()
        root.name = "cottage"
        let walls = SCNNode(geometry: SCNBox(width: 5.2, height: 3.0, length: 4.2, chamferRadius: 0.05))
        walls.geometry?.materials = [material(ForestTextures.plaster)]
        walls.position = SCNVector3(0, 1.5, 0)
        root.addChildNode(walls)
        let roof = SCNNode(geometry: SCNPyramid(width: 6.2, height: 2.4, length: 5.2))
        roof.geometry?.materials = [material(ForestTextures.shingles)]
        roof.position = SCNVector3(0, 3.0, 0)
        root.addChildNode(roof)
        let chimney = SCNNode(geometry: SCNBox(width: 0.6, height: 1.6, length: 0.6, chamferRadius: 0.03))
        chimney.geometry?.materials = [material(ForestTextures.stone)]
        chimney.position = SCNVector3(1.6, 4.2, 0.8)
        root.addChildNode(chimney)
        let door = SCNNode(geometry: SCNBox(width: 1.0, height: 1.9, length: 0.1, chamferRadius: 0.04))
        door.geometry?.materials = [material(ForestTextures.planks)]
        door.position = SCNVector3(0, 0.95, 2.12)
        door.name = "cottage"
        root.addChildNode(door)
        for dx in [-1.6, 1.6] {
            let window = SCNNode(geometry: SCNBox(width: 0.9, height: 0.9, length: 0.08, chamferRadius: 0.02))
            let m = colored(UIColor(red: 0.75, green: 0.89, blue: 0.95, alpha: 1))
            m.emission.contents = UIColor(red: 0.95, green: 0.85, blue: 0.55, alpha: 1)
            m.emission.intensity = 0.25
            window.geometry?.materials = [m]
            window.position = SCNVector3(Float(dx), 1.7, 2.12)
            root.addChildNode(window)
        }
        return root
    }

    // MARK: Castle (tap to go inside)

    static func castle() -> SCNNode {
        let root = SCNNode()
        root.name = "castle"
        let stoneMat = material(ForestTextures.stone, tileX: 2, tileY: 2)
        let roofMat = colored(UIColor(red: 0.42, green: 0.37, blue: 0.64, alpha: 1))

        let keep = SCNNode(geometry: SCNBox(width: 8, height: 7, length: 6, chamferRadius: 0.1))
        keep.geometry?.materials = [stoneMat]
        keep.position = SCNVector3(0, 3.5, 0)
        root.addChildNode(keep)

        for (tx, tz) in [(-4.6, 2.6), (4.6, 2.6), (-4.6, -2.6), (4.6, -2.6)] {
            let tower = SCNNode(geometry: SCNCylinder(radius: 1.5, height: 10))
            tower.geometry?.materials = [stoneMat]
            tower.position = SCNVector3(Float(tx), 5, Float(tz))
            root.addChildNode(tower)
            let cone = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 1.9, height: 2.6))
            cone.geometry?.materials = [roofMat]
            cone.position = SCNVector3(Float(tx), 11.3, Float(tz))
            root.addChildNode(cone)
            let pole = SCNNode(geometry: SCNCylinder(radius: 0.05, height: 1.2))
            pole.geometry?.materials = [roofMat]
            pole.position = SCNVector3(Float(tx), 13.2, Float(tz))
            root.addChildNode(pole)
            let flag = SCNNode(geometry: SCNPlane(width: 0.9, height: 0.5))
            flag.geometry?.materials = [colored(UIColor(red: 0.96, green: 0.70, blue: 0.24, alpha: 1))]
            flag.geometry?.firstMaterial?.isDoubleSided = true
            flag.position = SCNVector3(Float(tx) + 0.5, 13.5, Float(tz))
            root.addChildNode(flag)
        }
        // Glowing windows
        for wx in [-2.2, 0, 2.2] {
            let w = SCNNode(geometry: SCNBox(width: 0.8, height: 1.4, length: 0.1, chamferRadius: 0.05))
            let m = colored(UIColor(red: 0.98, green: 0.86, blue: 0.55, alpha: 1))
            m.emission.contents = UIColor(red: 0.98, green: 0.84, blue: 0.45, alpha: 1)
            m.emission.intensity = 0.8
            w.geometry?.materials = [m]
            w.position = SCNVector3(Float(wx), 4.6, 3.06)
            root.addChildNode(w)
        }
        // Arched door
        let door = SCNNode(geometry: SCNBox(width: 1.8, height: 2.6, length: 0.15, chamferRadius: 0.1))
        door.geometry?.materials = [material(ForestTextures.planks)]
        door.position = SCNVector3(0, 1.3, 3.06)
        door.name = "castle"
        root.addChildNode(door)
        return root
    }

    // MARK: Treehouse (tap to go inside)

    static func treehouseTree() -> SCNNode {
        let root = SCNNode()
        root.name = "treehouse"
        let trunk = SCNNode(geometry: SCNCylinder(radius: 0.8, height: 6.5))
        trunk.geometry?.materials = [material(ForestTextures.bark)]
        trunk.position = SCNVector3(0, 3.25, 0)
        root.addChildNode(trunk)
        let leafMat = material(ForestTextures.leaves)
        for (r, x, y, z): (Float, Float, Float, Float) in
            [(2.6, 0, 8.0, 0), (1.8, -1.8, 7.0, 0.6), (1.8, 1.8, 7.2, -0.5)] {
            let puff = SCNNode(geometry: SCNSphere(radius: CGFloat(r)))
            puff.geometry?.materials = [leafMat]
            puff.position = SCNVector3(x, y, z)
            root.addChildNode(puff)
        }
        let plankMat = material(ForestTextures.planks)
        let platform = SCNNode(geometry: SCNBox(width: 4.6, height: 0.3, length: 4.6, chamferRadius: 0.05))
        platform.geometry?.materials = [plankMat]
        platform.position = SCNVector3(0, 4.4, 0)
        root.addChildNode(platform)
        let house = SCNNode(geometry: SCNBox(width: 3.2, height: 2.2, length: 3.0, chamferRadius: 0.06))
        house.geometry?.materials = [plankMat]
        house.position = SCNVector3(0, 5.6, 0)
        house.name = "treehouse"
        root.addChildNode(house)
        let roof = SCNNode(geometry: SCNPyramid(width: 3.9, height: 1.4, length: 3.7))
        roof.geometry?.materials = [material(ForestTextures.shingles)]
        roof.position = SCNVector3(0, 6.7, 0)
        root.addChildNode(roof)
        // Ladder
        for i in 0..<6 {
            let rung = SCNNode(geometry: SCNCylinder(radius: 0.05, height: 0.7))
            rung.geometry?.materials = [plankMat]
            rung.eulerAngles.z = .pi / 2
            rung.position = SCNVector3(0, 0.6 + Float(i) * 0.7, 1.05)
            root.addChildNode(rung)
        }
        return root
    }

    // MARK: Brook, rainbow, flowers, clouds, sun

    static func brook() -> SCNNode {
        let root = SCNNode()
        let waterMat = material(ForestTextures.water, tileX: 6, tileY: 1)
        waterMat.transparency = 0.85
        let segments = 26
        for i in 0..<segments {
            let z0 = -worldHalf + Float(i) * (worldHalf * 2 / Float(segments))
            let z1 = z0 + worldHalf * 2 / Float(segments)
            let zm = (z0 + z1) / 2
            let x = 34 * sinf(zm * 0.028) + 26
            let plane = SCNNode(geometry: SCNPlane(width: 5.5, height: CGFloat(z1 - z0) * 1.15))
            plane.geometry?.materials = [waterMat]
            plane.eulerAngles.x = -.pi / 2
            plane.position = SCNVector3(x, terrainHeight(x: x, z: zm) + 0.12, zm)
            root.addChildNode(plane)
        }
        root.name = "brook"
        return root
    }

    static func rainbow() -> SCNNode {
        let root = SCNNode()
        let colors: [UIColor] = [
            UIColor(red: 0.94, green: 0.35, blue: 0.32, alpha: 0.8),
            UIColor(red: 0.97, green: 0.62, blue: 0.25, alpha: 0.8),
            UIColor(red: 0.99, green: 0.85, blue: 0.35, alpha: 0.8),
            UIColor(red: 0.42, green: 0.76, blue: 0.44, alpha: 0.8),
            UIColor(red: 0.35, green: 0.58, blue: 0.92, alpha: 0.8),
            UIColor(red: 0.58, green: 0.44, blue: 0.85, alpha: 0.8)
        ]
        for (i, color) in colors.enumerated() {
            let torus = SCNNode(geometry: SCNTorus(ringRadius: CGFloat(34 - i), pipeRadius: 0.45))
            let m = colored(color)
            m.emission.contents = color
            m.emission.intensity = 0.4
            m.transparency = 0.75
            torus.geometry?.materials = [m]
            torus.eulerAngles.x = .pi / 2   // stand the ring upright
            root.addChildNode(torus)
        }
        // Lower half hides under the terrain
        root.position = SCNVector3(-55, 0, -35)
        root.eulerAngles.y = 0.5
        return root
    }

    static func flowerField(count: Int, seed: Int) -> SCNNode {
        let root = SCNNode()
        var state = UInt64(seed * 7919 + 13)
        func rnd() -> Float {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Float((state >> 33) & 0xFFFF) / Float(0xFFFF)
        }
        let hues: [CGFloat] = [0.95, 0.12, 0.75, 0.55]
        for i in 0..<count {
            let x = (rnd() * 2 - 1) * (worldHalf - 15)
            let z = (rnd() * 2 - 1) * (worldHalf - 15)
            if z < -50 { continue }   // keep the castle ridge clear
            let stem = SCNNode(geometry: SCNCylinder(radius: 0.04, height: 0.55))
            stem.geometry?.materials = [colored(UIColor(red: 0.35, green: 0.62, blue: 0.36, alpha: 1))]
            let head = SCNNode(geometry: SCNPlane(width: 0.55, height: 0.55))
            let m = material(ForestTextures.flower(hue: hues[i % hues.count]))
            m.isDoubleSided = true
            head.geometry?.materials = [m]
            head.position = SCNVector3(0, 0.42, 0)
            head.constraints = [SCNBillboardConstraint()]
            stem.addChildNode(head)
            place(stem, x: x, z: z, sink: -0.22)
            root.addChildNode(stem)
        }
        return root
    }

    static func clouds() -> SCNNode {
        let root = SCNNode()
        let m = colored(.white)
        m.transparency = 0.9
        for i in 0..<7 {
            let cloud = SCNNode()
            for j in 0..<3 {
                let puff = SCNNode(geometry: SCNSphere(radius: CGFloat(2.2 - Double(j) * 0.4)))
                puff.geometry?.materials = [m]
                puff.position = SCNVector3(Float(j) * 2.4 - 2.4, Float(j % 2) * 0.5, 0)
                puff.scale = SCNVector3(1, 0.55, 0.8)
                cloud.addChildNode(puff)
            }
            let angle = Float(i) / 7 * 2 * .pi
            cloud.position = SCNVector3(cosf(angle) * 70, 34 + Float(i % 3) * 4, sinf(angle) * 70)
            cloud.name = "cloud"
            root.addChildNode(cloud)
        }
        return root
    }

    // MARK: Creatures (animated per-frame by the coordinator)

    static func fox() -> SCNNode {
        let root = SCNNode()
        root.name = "fox"
        let orange = colored(UIColor(red: 0.91, green: 0.46, blue: 0.23, alpha: 1))
        let darkOrange = colored(UIColor(red: 0.79, green: 0.37, blue: 0.16, alpha: 1))
        let cream = colored(UIColor(red: 1.0, green: 0.95, blue: 0.89, alpha: 1))

        let body = SCNNode(geometry: SCNCapsule(capRadius: 0.32, height: 1.5))
        body.geometry?.materials = [orange]
        body.eulerAngles.x = .pi / 2
        body.position = SCNVector3(0, 0.62, 0)
        root.addChildNode(body)

        let head = SCNNode(geometry: SCNSphere(radius: 0.30))
        head.geometry?.materials = [orange]
        head.position = SCNVector3(0, 0.95, 0.75)
        root.addChildNode(head)
        let snout = SCNNode(geometry: SCNCone(topRadius: 0.02, bottomRadius: 0.14, height: 0.4))
        snout.geometry?.materials = [cream]
        snout.eulerAngles.x = .pi / 2
        snout.position = SCNVector3(0, 0.88, 1.05)
        root.addChildNode(snout)
        for ex in [-0.14, 0.14] {
            let ear = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.1, height: 0.28))
            ear.geometry?.materials = [darkOrange]
            ear.position = SCNVector3(Float(ex), 1.25, 0.70)
            root.addChildNode(ear)
        }
        let tail = SCNNode(geometry: SCNCone(topRadius: 0.05, bottomRadius: 0.20, height: 0.9))
        tail.geometry?.materials = [orange]
        tail.eulerAngles.x = -1.2
        tail.position = SCNVector3(0, 0.75, -0.85)
        tail.name = "tail"
        root.addChildNode(tail)
        let tip = SCNNode(geometry: SCNSphere(radius: 0.13))
        tip.geometry?.materials = [cream]
        tip.position = SCNVector3(0, 0.42, 0)
        tail.addChildNode(tip)

        for (i, (lx, lz)) in [(-0.18, 0.45), (0.18, 0.45), (-0.18, -0.45), (0.18, -0.45)].enumerated() {
            let leg = SCNNode(geometry: SCNCylinder(radius: 0.07, height: 0.55))
            leg.geometry?.materials = [darkOrange]
            leg.position = SCNVector3(Float(lx), 0.28, Float(lz))
            leg.pivot = SCNMatrix4MakeTranslation(0, 0.27, 0)
            leg.position.y = 0.55
            let swing = CABasicAnimation(keyPath: "eulerAngles.x")
            swing.fromValue = -0.55; swing.toValue = 0.55
            swing.duration = 0.22; swing.autoreverses = true
            swing.repeatCount = .infinity
            swing.timeOffset = (i % 2 == 0) ? 0 : 0.22
            leg.addAnimation(swing, forKey: "swing")
            root.addChildNode(leg)
        }
        return root
    }

    static func rabbit() -> SCNNode {
        let root = SCNNode()
        root.name = "rabbit"
        let fur = colored(UIColor(red: 0.985, green: 0.965, blue: 0.945, alpha: 1))
        let body = SCNNode(geometry: SCNCapsule(capRadius: 0.22, height: 0.75))
        body.geometry?.materials = [fur]
        body.eulerAngles.x = .pi / 2.3
        body.position = SCNVector3(0, 0.34, 0)
        root.addChildNode(body)
        let head = SCNNode(geometry: SCNSphere(radius: 0.19))
        head.geometry?.materials = [fur]
        head.position = SCNVector3(0, 0.62, 0.34)
        root.addChildNode(head)
        for ex in [-0.08, 0.08] {
            let ear = SCNNode(geometry: SCNCapsule(capRadius: 0.045, height: 0.4))
            ear.geometry?.materials = [fur]
            ear.eulerAngles.x = -0.35
            ear.position = SCNVector3(Float(ex), 0.9, 0.26)
            root.addChildNode(ear)
        }
        let tail = SCNNode(geometry: SCNSphere(radius: 0.10))
        tail.geometry?.materials = [fur]
        tail.position = SCNVector3(0, 0.32, -0.42)
        root.addChildNode(tail)
        return root
    }

    /// The dragon: head + tapering body segments, repositioned every
    /// frame along a serpentine sky path by the coordinator.
    static func dragon() -> (root: SCNNode, segments: [SCNNode]) {
        let root = SCNNode()
        root.name = "dragon"
        var segments: [SCNNode] = []
        for i in 0..<9 {
            let r = 0.85 - Float(i) * 0.07
            let seg = SCNNode(geometry: SCNSphere(radius: CGFloat(r)))
            let f = CGFloat(i) / 8
            let m = colored(UIColor(red: 0.23 + 0.07 * f, green: 0.63 + 0.06 * f,
                                    blue: 0.38 + 0.24 * f, alpha: 1))
            seg.geometry?.materials = [m]
            if i < 6 {
                let spike = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.12, height: 0.35))
                spike.geometry?.materials = [colored(UIColor(red: 0.96, green: 0.70, blue: 0.24, alpha: 1))]
                spike.position = SCNVector3(0, r + 0.12, 0)
                seg.addChildNode(spike)
            }
            if i == 0 {
                // eyes + horns + snout on the head
                for ex in [-0.3, 0.3] {
                    let eye = SCNNode(geometry: SCNSphere(radius: 0.14))
                    eye.geometry?.materials = [colored(.white)]
                    eye.position = SCNVector3(Float(ex), 0.35, 0.65)
                    seg.addChildNode(eye)
                    let pupil = SCNNode(geometry: SCNSphere(radius: 0.07))
                    pupil.geometry?.materials = [colored(UIColor(red: 0.2, green: 0.25, blue: 0.2, alpha: 1))]
                    pupil.position = SCNVector3(0, 0, 0.1)
                    eye.addChildNode(pupil)
                    let horn = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.09, height: 0.45))
                    horn.geometry?.materials = [colored(UIColor(red: 0.96, green: 0.70, blue: 0.24, alpha: 1))]
                    horn.position = SCNVector3(Float(ex) * 0.8, 0.85, 0.1)
                    seg.addChildNode(horn)
                }
                let snout = SCNNode(geometry: SCNSphere(radius: 0.35))
                snout.geometry?.materials = [colored(UIColor(red: 0.55, green: 0.86, blue: 0.66, alpha: 1))]
                snout.position = SCNVector3(0, -0.05, 0.75)
                snout.scale = SCNVector3(1, 0.7, 1.1)
                seg.addChildNode(snout)
            }
            if i == 1 {
                // flapping wings
                for side: Float in [-1, 1] {
                    let wing = SCNNode(geometry: SCNPlane(width: 1.8, height: 1.1))
                    let m = colored(UIColor(red: 0.50, green: 0.85, blue: 0.65, alpha: 1))
                    m.transparency = 0.8; m.isDoubleSided = true
                    wing.geometry?.materials = [m]
                    wing.pivot = SCNMatrix4MakeTranslation(-0.9 * side, 0, 0)
                    wing.position = SCNVector3(side * 0.5, 0.5, 0)
                    let flap = CABasicAnimation(keyPath: "eulerAngles.z")
                    flap.fromValue = -0.7 * side; flap.toValue = 0.5 * side
                    flap.duration = 0.35; flap.autoreverses = true
                    flap.repeatCount = .infinity
                    wing.addAnimation(flap, forKey: "flap")
                    seg.addChildNode(wing)
                }
            }
            root.addChildNode(seg)
            segments.append(seg)
        }
        // sparkle trail
        let sparkle = SCNParticleSystem()
        sparkle.particleImage = ForestTextures.glow
        sparkle.birthRate = 12
        sparkle.particleLifeSpan = 1.2
        sparkle.particleSize = 0.35
        sparkle.particleColor = UIColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 0.8)
        sparkle.spreadingAngle = 40
        sparkle.particleVelocity = 0.4
        segments[8].addParticleSystem(sparkle)
        return (root, segments)
    }

    // MARK: Lights & sky

    static func addLighting(to scene: SCNScene, night: Bool) {
        scene.background.contents = ForestTextures.sky(night: night)
        scene.fogStartDistance = 70
        scene.fogEndDistance = 260
        scene.fogColor = night
            ? UIColor(red: 0.16, green: 0.23, blue: 0.38, alpha: 1)
            : UIColor(red: 0.84, green: 0.93, blue: 0.90, alpha: 1)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = night ? 300 : 1000
        sun.light?.color = night ? UIColor(red: 0.75, green: 0.8, blue: 1, alpha: 1) : UIColor.white
        sun.light?.castsShadow = true
        sun.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        sun.light?.shadowColor = UIColor(white: 0, alpha: 0.35)
        sun.eulerAngles = SCNVector3(-1.0, 0.6, 0)
        scene.rootNode.addChildNode(sun)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = night ? 220 : 420
        ambient.light?.color = night
            ? UIColor(red: 0.55, green: 0.6, blue: 0.85, alpha: 1) : UIColor.white
        scene.rootNode.addChildNode(ambient)

        // Visible sun / moon disc
        let disc = SCNNode(geometry: SCNSphere(radius: 5))
        let m = SCNMaterial()
        m.diffuse.contents = night
            ? UIColor(red: 0.96, green: 0.95, blue: 0.86, alpha: 1)
            : UIColor(red: 1.0, green: 0.88, blue: 0.5, alpha: 1)
        m.emission.contents = m.diffuse.contents
        m.emission.intensity = 1
        disc.geometry?.materials = [m]
        disc.position = SCNVector3(80, 70, -110)
        scene.rootNode.addChildNode(disc)
    }

    // MARK: - The outdoor world

    struct OutdoorWorld {
        let scene: SCNScene
        let dragonSegments: [SCNNode]
        let foxes: [SCNNode]
        let rabbits: [SCNNode]
        let clouds: SCNNode
        /// (x, z, radius) circles the camera can't walk through.
        let obstacles: [(Float, Float, Float)]
        /// River centerline samples for the fish to swim along.
        let riverPath: [SCNVector3]
        let riverMaterial: SCNMaterial?
        let fish: [SCNNode]
        let stars: [SCNNode]
        let butterflies: [SCNNode]
        let gardens: [SCNNode]
        /// Earned animals, roamed each frame by the coordinator.
        let critters: [Critter]
    }

    static func buildOutdoor(unlocked: [ForestElement],
                             treasures: [ForestTreasure] = [],
                             night: Bool) -> OutdoorWorld {
        let scene = SCNScene()
        let root = scene.rootNode
        func has(_ e: ForestElement) -> Bool { unlocked.contains(e) }

        root.addChildNode(terrainNode())
        addLighting(to: scene, night: night)

        // Trees — a young forest even at level 1, lush when unlocked
        var state: UInt64 = 99
        func rnd() -> Float {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Float((state >> 33) & 0xFFFF) / Float(0xFFFF)
        }
        var obstacles: [(Float, Float, Float)] = []
        let treeCount = has(.trees) ? 34 : 10
        for _ in 0..<treeCount {
            let x = (rnd() * 2 - 1) * (worldHalf - 12)
            let z = (rnd() * 2 - 1) * (worldHalf - 12)
            // keep the spawn glade, brook line, and castle courtyard clear
            if abs(x) < 10 && abs(z - 55) < 14 { continue }
            if abs(x - (34 * sinf(z * 0.028) + 26)) < 6 { continue }
            if z < -60 { continue }
            let scale = 0.8 + rnd() * 0.9
            let t = tree(scale: scale)
            place(t, x: x, z: z, sink: 0.2)
            root.addChildNode(t)
            obstacles.append((x, z, 0.7 * scale))
        }

        // The forest floor: leaves everywhere, then deeper drifts on top.
        root.addChildNode(leafLitter(count: 4200))
        root.addChildNode(leafDrifts(count: 900))

        // The living carpet. Every species in the catalog is planted —
        // the understory (herbs, flowers, ferns, berries, mushrooms) is
        // scattered thickly, the big fruit trees and palms more sparsely
        // so the world stays walkable.
        func clearOfPaths(_ x: Float, _ z: Float, margin: Float) -> Bool {
            if abs(x) < 6 && abs(z - 58) < 8 { return false }              // spawn glade
            if abs(x - (34 * sinf(z * 0.028) + 26)) < margin { return false } // brook
            if z < -62 { return false }                                     // castle ridge
            return true
        }

        let understory = PlantCatalog.understory
        // Roughly a dozen of every small species, so the child meets the
        // whole catalog by wandering rather than by luck.
        let perSpecies = has(.flowers) ? 12 : 6
        for (index, species) in understory.enumerated() {
            for _ in 0..<perSpecies {
                let x = (rnd() * 2 - 1) * (worldHalf - 8)
                let z = (rnd() * 2 - 1) * (worldHalf - 8)
                guard clearOfPaths(x, z, margin: 5) else { continue }
                let p = plant(kind: species.key)
                let s = 0.85 + rnd() * 0.4
                p.scale = SCNVector3(s, s, s)
                p.eulerAngles.y = rnd() * 2 * .pi
                place(p, x: x, z: z, sink: 0.06)
                root.addChildNode(p)
            }
            _ = index
        }

        // Orchard species: fewer, larger, and solid to walk around.
        for species in PlantCatalog.canopy {
            let copies = has(.trees) ? 3 : 2
            for _ in 0..<copies {
                let x = (rnd() * 2 - 1) * (worldHalf - 14)
                let z = (rnd() * 2 - 1) * (worldHalf - 14)
                guard clearOfPaths(x, z, margin: 7) else { continue }
                if abs(x) < 12 && abs(z - 55) < 16 { continue }   // keep the glade open
                let p = plant(kind: species.key)
                let s = 0.9 + rnd() * 0.5
                p.scale = SCNVector3(s, s, s)
                p.eulerAngles.y = rnd() * 2 * .pi
                place(p, x: x, z: z, sink: 0.15)
                root.addChildNode(p)
                obstacles.append((x, z, 0.5 * s))
            }
        }

        var riverPath: [SCNVector3] = []
        var riverMaterial: SCNMaterial?
        var fishNodes: [SCNNode] = []
        if has(.river) {
            let river = riverRibbon()
            root.addChildNode(river.node)
            riverPath = river.path
            riverMaterial = river.material
            let kinds = ["goldfish", "trout", "catfish"]
            for i in 0..<6 {
                let f = fish(kind: kinds[i % 3])
                root.addChildNode(f)
                fishNodes.append(f)
            }
        }
        if has(.rainbow) { root.addChildNode(rainbow()) }
        let cloudsNode = clouds()
        root.addChildNode(cloudsNode)

        // Buildings
        let home = cottage()
        place(home, x: 16, z: 42, sink: 0.25)
        root.addChildNode(home)
        obstacles.append((16, 42, 3.8))

        if has(.castle) {
            let fort = castle()
            place(fort, x: 0, z: -88, sink: 0.4)
            root.addChildNode(fort)
            obstacles.append((0, -88, 6.5))
        }

        if has(.treehouse) {
            let th = treehouseTree()
            place(th, x: -34, z: 8, sink: 0.3)
            root.addChildNode(th)
            obstacles.append((-34, 8, 1.6))
        }

        // Butterfly gardens (release captured butterflies here)
        var gardens: [SCNNode] = []
        for (gx, gz) in [(-14.0, 62.0), (48.0, 20.0)] {
            let g = garden()
            place(g, x: Float(gx), z: Float(gz), sink: 0.1)
            root.addChildNode(g)
            gardens.append(g)
        }

        // Collectible stars hidden around the world
        var stars: [SCNNode] = []
        let starSpots: [(Float, Float)] = [(-22, 22), (42, -12), (-62, -38), (72, 62),
                                           (-92, 32), (20, 34), (-36, 2), (6, -78)]
        for (i, spot) in starSpots.enumerated() {
            let s = collectibleStar(index: i)
            s.position = SCNVector3(spot.0,
                                    terrainHeight(x: spot.0, z: spot.1) + 1.3,
                                    spot.1)
            root.addChildNode(s)
            stars.append(s)
        }

        // The bunny guide waits near the spawn glade
        let bunny = bunnyGuide()
        place(bunny, x: -4, z: 56, sink: 0.1)
        bunny.eulerAngles.y = .pi * 0.85   // faces the child at spawn
        root.addChildNode(bunny)
        obstacles.append((-4, 56, 1.0))

        // Creatures
        var foxes: [SCNNode] = []
        if has(.animals) {
            for _ in 0..<3 {
                let f = fox()
                root.addChildNode(f)
                foxes.append(f)
            }
        }
        var rabbits: [SCNNode] = []
        for _ in 0..<4 {
            let r = rabbit()
            root.addChildNode(r)
            rabbits.append(r)
        }

        var dragonSegments: [SCNNode] = []
        if has(.dragon) {
            let d = dragonV2()
            root.addChildNode(d.root)
            dragonSegments = d.segments
        }

        var butterflies: [SCNNode] = []
        if has(.butterflies) {
            let hues: [CGFloat] = [0.08, 0.6, 0.9, 0.16]
            for i in 0..<8 {
                let b = SCNNode(geometry: SCNPlane(width: 0.55, height: 0.42))
                let m = material(ForestTextures.butterfly(hue: hues[i % hues.count]))
                m.isDoubleSided = true
                m.transparencyMode = .aOne
                b.geometry?.materials = [m]
                b.name = "bfly.\(i)"
                b.constraints = [SCNBillboardConstraint()]
                root.addChildNode(b)
                butterflies.append(b)
            }
        }

        // Everything the child has earned, standing where they left it.
        let earned = placeGroundTreasures(treasures, in: root)
        obstacles.append(contentsOf: earned.obstacles)

        return OutdoorWorld(scene: scene, dragonSegments: dragonSegments,
                            foxes: foxes, rabbits: rabbits, clouds: cloudsNode,
                            obstacles: obstacles, riverPath: riverPath,
                            riverMaterial: riverMaterial, fish: fishNodes,
                            stars: stars, butterflies: butterflies,
                            gardens: gardens, critters: earned.critters)
    }

    // MARK: - Interiors

    /// A furnished room the child can walk around in. Tap the glowing
    /// door (named "exitDoor") to go back outside.
    static func buildInterior(_ kind: InteriorKind,
                              treasures: [ForestTreasure] = [],
                              night: Bool) -> SCNScene {
        let scene = SCNScene()
        let root = scene.rootNode
        scene.background.contents = ForestTextures.sky(night: night)

        let w: CGFloat = 16, d: CGFloat = 12
        // The castle hall soars four stories; homes are cozy.
        let h: CGFloat = kind == .castle ? 15.5 : (kind == .treehouse ? 4.6 : 5.2)
        let wallMat: SCNMaterial
        let floorMat: SCNMaterial
        let ceilingMat: SCNMaterial
        switch kind {
        case .castle:
            wallMat = material(ForestTextures.stone, tileX: 3, tileY: 4)
            floorMat = material(ForestTextures.stone, tileX: 4, tileY: 3)
            ceilingMat = material(ForestTextures.stone, tileX: 4, tileY: 3)
        case .cottage:
            wallMat = material(ForestTextures.plaster, tileX: 2, tileY: 1)
            floorMat = material(ForestTextures.planks, tileX: 3, tileY: 2)
            ceilingMat = material(ForestTextures.planks, tileX: 3, tileY: 2)
        case .treehouse:
            wallMat = material(ForestTextures.planks, tileX: 3, tileY: 1.5)
            floorMat = material(ForestTextures.planks, tileX: 3, tileY: 2)
            ceilingMat = material(ForestTextures.planks, tileX: 3, tileY: 2)
        }

        let floor = SCNNode(geometry: SCNBox(width: w, height: 0.3, length: d, chamferRadius: 0))
        floor.geometry?.materials = [floorMat]
        floor.position = SCNVector3(0, -0.15, 0)
        root.addChildNode(floor)

        // Walls (front wall has the doorway gap)
        let backWall = SCNNode(geometry: SCNBox(width: w, height: h, length: 0.3, chamferRadius: 0))
        backWall.geometry?.materials = [wallMat]
        backWall.position = SCNVector3(0, Float(h) / 2, Float(-d / 2))
        root.addChildNode(backWall)
        for side: Float in [-1, 1] {
            if kind == .castle {
                // Side walls with archway openings into the tunnel wings
                for zSign: Float in [-1, 1] {
                    let seg = SCNNode(geometry: SCNBox(width: 0.3, height: h,
                                                       length: (d - 3.2) / 2, chamferRadius: 0))
                    seg.geometry?.materials = [wallMat]
                    seg.position = SCNVector3(side * Float(w / 2), Float(h) / 2,
                                              zSign * Float(d / 4 + 0.8))
                    root.addChildNode(seg)
                }
                let above = SCNNode(geometry: SCNBox(width: 0.3, height: h - 3.2,
                                                     length: 3.2, chamferRadius: 0))
                above.geometry?.materials = [wallMat]
                above.position = SCNVector3(side * Float(w / 2),
                                            Float(h) - Float(h - 3.2) / 2, 0)
                root.addChildNode(above)
            } else {
                let wall = SCNNode(geometry: SCNBox(width: 0.3, height: h, length: d, chamferRadius: 0))
                wall.geometry?.materials = [wallMat]
                wall.position = SCNVector3(side * Float(w / 2), Float(h) / 2, 0)
                root.addChildNode(wall)
            }
        }
        for side: Float in [-1, 1] {
            let front = SCNNode(geometry: SCNBox(width: (w - 2.4) / 2, height: h, length: 0.3, chamferRadius: 0))
            front.geometry?.materials = [wallMat]
            front.position = SCNVector3(side * Float(w / 4 + 0.6), Float(h) / 2, Float(d / 2))
            root.addChildNode(front)
        }
        let lintel = SCNNode(geometry: SCNBox(width: 2.4, height: h - 3.0, length: 0.3, chamferRadius: 0))
        lintel.geometry?.materials = [wallMat]
        lintel.position = SCNVector3(0, Float(h) - Float(h - 3.0) / 2, Float(d / 2))
        root.addChildNode(lintel)

        // A proper roof over every room
        let ceiling = SCNNode(geometry: SCNBox(width: w, height: 0.3, length: d, chamferRadius: 0))
        ceiling.geometry?.materials = [ceilingMat]
        ceiling.position = SCNVector3(0, Float(h) + 0.15, 0)
        root.addChildNode(ceiling)

        if kind == .castle {
            castleGrandHall(root: root, w: Float(w), d: Float(d), h: Float(h),
                            wallMat: wallMat, floorMat: floorMat)
        }

        // Glowing exit door in the doorway
        let exitDoor = SCNNode(geometry: SCNBox(width: 2.2, height: 2.9, length: 0.15, chamferRadius: 0.08))
        let doorMat = material(ForestTextures.planks)
        doorMat.emission.contents = UIColor(red: 0.5, green: 0.9, blue: 0.6, alpha: 1)
        doorMat.emission.intensity = 0.35
        exitDoor.geometry?.materials = [doorMat]
        exitDoor.position = SCNVector3(0, 1.45, Float(d / 2))
        exitDoor.name = "exitDoor"
        root.addChildNode(exitDoor)

        // Warm room light + soft ambient
        let lamp = SCNNode()
        lamp.light = SCNLight()
        lamp.light?.type = .omni
        lamp.light?.intensity = 700
        lamp.light?.color = UIColor(red: 1.0, green: 0.9, blue: 0.75, alpha: 1)
        lamp.position = SCNVector3(0, Float(h) - 1, 0)
        root.addChildNode(lamp)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 260
        root.addChildNode(ambient)

        furnish(kind, root: root, roomWidth: Float(w), roomDepth: Float(d))
        // Earned furniture goes in on top of the room's built-in fittings.
        placeInteriorTreasures(treasures, kind: kind, in: root,
                               roomWidth: Float(w), roomDepth: Float(d))
        return scene
    }

    /// The castle atrium: four stories of balconies rising to a
    /// chandelier, plus arched tunnels through the side walls into an
    /// armory (right) and a library (left).
    private static func castleGrandHall(root: SCNNode, w: Float, d: Float, h: Float,
                                        wallMat: SCNMaterial, floorMat: SCNMaterial) {
        let gold = colored(UIColor(red: 0.93, green: 0.78, blue: 0.35, alpha: 1))
        let plankMat = material(ForestTextures.planks)

        // Three balcony stories above the ground floor
        for story in 1...3 {
            let y = Float(story) * 3.8
            for side: Float in [-1, 1] {
                let ledge = SCNNode(geometry: SCNBox(width: 2.0, height: 0.25,
                                                     length: CGFloat(d) - 1, chamferRadius: 0.03))
                ledge.geometry?.materials = [floorMat]
                ledge.position = SCNVector3(side * (w / 2 - 1.15), y, 0)
                root.addChildNode(ledge)
                for i in 0..<7 {
                    let post = SCNNode(geometry: SCNCylinder(radius: 0.05, height: 0.8))
                    post.geometry?.materials = [gold]
                    post.position = SCNVector3(side * (w / 2 - 2.1), y + 0.5,
                                               -d / 2 + 1 + Float(i) * (d - 2) / 6)
                    root.addChildNode(post)
                }
                let rail = SCNNode(geometry: SCNBox(width: 0.09, height: 0.09,
                                                    length: CGFloat(d) - 1, chamferRadius: 0.02))
                rail.geometry?.materials = [gold]
                rail.position = SCNVector3(side * (w / 2 - 2.1), y + 0.9, 0)
                root.addChildNode(rail)
            }
            // Glowing story windows on the back wall
            for wx: Float in [-3, 0, 3] {
                let win = SCNNode(geometry: SCNBox(width: 0.9, height: 1.6, length: 0.1, chamferRadius: 0.05))
                let m = colored(UIColor(red: 0.98, green: 0.86, blue: 0.55, alpha: 1))
                m.emission.contents = UIColor(red: 0.98, green: 0.84, blue: 0.45, alpha: 1)
                m.emission.intensity = 0.7
                win.geometry?.materials = [m]
                win.position = SCNVector3(wx, Float(story) * 3.8 + 1.6, -d / 2 + 0.2)
                root.addChildNode(win)
            }
        }

        // Chandelier under the roof
        let ring = SCNNode(geometry: SCNTorus(ringRadius: 1.6, pipeRadius: 0.09))
        ring.geometry?.materials = [gold]
        ring.position = SCNVector3(0, h - 2.2, 0)
        root.addChildNode(ring)
        let chain = SCNNode(geometry: SCNCylinder(radius: 0.04, height: 2.0))
        chain.geometry?.materials = [gold]
        chain.position = SCNVector3(0, h - 1.1, 0)
        root.addChildNode(chain)
        for i in 0..<6 {
            let a = Float(i) / 6 * 2 * .pi
            let candle = SCNNode(geometry: SCNCylinder(radius: 0.06, height: 0.3))
            candle.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            candle.position = SCNVector3(cosf(a) * 1.6, h - 2.0, sinf(a) * 1.6)
            root.addChildNode(candle)
            let flame = SCNNode(geometry: SCNSphere(radius: 0.08))
            let fm = colored(UIColor(red: 1.0, green: 0.75, blue: 0.3, alpha: 1))
            fm.emission.contents = fm.diffuse.contents
            fm.emission.intensity = 1
            flame.geometry?.materials = [fm]
            flame.position = SCNVector3(cosf(a) * 1.6, h - 1.8, sinf(a) * 1.6)
            root.addChildNode(flame)
        }
        let chandelierLight = SCNNode()
        chandelierLight.light = SCNLight()
        chandelierLight.light?.type = .omni
        chandelierLight.light?.intensity = 500
        chandelierLight.light?.color = UIColor(red: 1.0, green: 0.85, blue: 0.6, alpha: 1)
        chandelierLight.position = SCNVector3(0, h - 2.5, 0)
        root.addChildNode(chandelierLight)

        // Tunnel wings + side rooms
        for side: Float in [-1, 1] {
            let tx = side * (w / 2 + 1.2)     // tunnel center
            let rx = side * (w / 2 + 5.4)     // room center
            // Tunnel floor/ceiling/walls (x: w/2 … w/2+2.4, z: ±1.6)
            let tFloor = SCNNode(geometry: SCNBox(width: 2.4, height: 0.3, length: 3.2, chamferRadius: 0))
            tFloor.geometry?.materials = [floorMat]
            tFloor.position = SCNVector3(tx, -0.15, 0)
            root.addChildNode(tFloor)
            let tCeil = SCNNode(geometry: SCNBox(width: 2.4, height: 0.3, length: 3.2, chamferRadius: 0))
            tCeil.geometry?.materials = [wallMat]
            tCeil.position = SCNVector3(tx, 3.2, 0)
            root.addChildNode(tCeil)
            for zSign: Float in [-1, 1] {
                let tWall = SCNNode(geometry: SCNBox(width: 2.4, height: 3.2, length: 0.3, chamferRadius: 0))
                tWall.geometry?.materials = [wallMat]
                tWall.position = SCNVector3(tx, 1.6, zSign * 1.6)
                root.addChildNode(tWall)
            }
            // Archway crown at the hall-side entry
            let arch = SCNNode(geometry: SCNTorus(ringRadius: 1.5, pipeRadius: 0.14))
            arch.geometry?.materials = [gold]
            arch.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            arch.position = SCNVector3(side * (w / 2), 3.0, 0)
            root.addChildNode(arch)
            // Torch in the tunnel
            let flame = SCNNode(geometry: SCNSphere(radius: 0.12))
            let fm = colored(UIColor(red: 1.0, green: 0.62, blue: 0.2, alpha: 1))
            fm.emission.contents = fm.diffuse.contents
            fm.emission.intensity = 1
            flame.geometry?.materials = [fm]
            flame.position = SCNVector3(tx, 2.4, 1.35)
            let torchLight = SCNLight()
            torchLight.type = .omni; torchLight.intensity = 260
            torchLight.color = UIColor(red: 1.0, green: 0.7, blue: 0.35, alpha: 1)
            flame.light = torchLight
            root.addChildNode(flame)

            // Side room shell: 6×6, height 4
            let rFloor = SCNNode(geometry: SCNBox(width: 6, height: 0.3, length: 6, chamferRadius: 0))
            rFloor.geometry?.materials = [floorMat]
            rFloor.position = SCNVector3(rx, -0.15, 0)
            root.addChildNode(rFloor)
            let rCeil = SCNNode(geometry: SCNBox(width: 6, height: 0.3, length: 6, chamferRadius: 0))
            rCeil.geometry?.materials = [wallMat]
            rCeil.position = SCNVector3(rx, 4.0, 0)
            root.addChildNode(rCeil)
            let outer = SCNNode(geometry: SCNBox(width: 0.3, height: 4, length: 6, chamferRadius: 0))
            outer.geometry?.materials = [wallMat]
            outer.position = SCNVector3(rx + side * 3, 2, 0)
            root.addChildNode(outer)
            for zSign: Float in [-1, 1] {
                let rWall = SCNNode(geometry: SCNBox(width: 6, height: 4, length: 0.3, chamferRadius: 0))
                rWall.geometry?.materials = [wallMat]
                rWall.position = SCNVector3(rx, 2, zSign * 3)
                root.addChildNode(rWall)
            }
            // Inner wall segments beside the tunnel mouth
            for zSign: Float in [-1, 1] {
                let seg = SCNNode(geometry: SCNBox(width: 0.3, height: 4, length: 1.4, chamferRadius: 0))
                seg.geometry?.materials = [wallMat]
                seg.position = SCNVector3(rx - side * 3, 2, zSign * 2.3)
                root.addChildNode(seg)
            }
            let roomLamp = SCNNode()
            roomLamp.light = SCNLight()
            roomLamp.light?.type = .omni
            roomLamp.light?.intensity = 320
            roomLamp.light?.color = UIColor(red: 1.0, green: 0.88, blue: 0.7, alpha: 1)
            roomLamp.position = SCNVector3(rx, 3.4, 0)
            root.addChildNode(roomLamp)

            if side > 0 {
                // ARMORY: shields on the wall + crossed swords
                for sz: Float in [-1.4, 1.4] {
                    let shield = SCNNode(geometry: SCNSphere(radius: 0.55))
                    let sm = colored(UIColor(red: 0.55, green: 0.35, blue: 0.25, alpha: 1))
                    shield.geometry?.materials = [sm]
                    shield.scale = SCNVector3(1, 1.2, 0.25)
                    shield.position = SCNVector3(rx + side * 2.7, 2.2, sz)
                    root.addChildNode(shield)
                    let boss = SCNNode(geometry: SCNSphere(radius: 0.16))
                    boss.geometry?.materials = [gold]
                    boss.position = SCNVector3(rx + side * 2.5, 2.2, sz)
                    root.addChildNode(boss)
                }
                for angle: Float in [-0.6, 0.6] {
                    let blade = SCNNode(geometry: SCNBox(width: 0.12, height: 1.8, length: 0.04, chamferRadius: 0.02))
                    blade.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.8, alpha: 1)
                    blade.position = SCNVector3(rx, 2.1, -2.8)
                    blade.eulerAngles.z = angle
                    root.addChildNode(blade)
                    let hilt = SCNNode(geometry: SCNBox(width: 0.5, height: 0.1, length: 0.08, chamferRadius: 0.02))
                    hilt.geometry?.materials = [gold]
                    hilt.position = SCNVector3(rx - sinf(angle) * 0.6, 2.1 - cosf(angle) * 0.6, -2.8)
                    hilt.eulerAngles.z = angle
                    root.addChildNode(hilt)
                }
            } else {
                // LIBRARY: two bookshelves full of rainbow books + reading rug
                for sz: Float in [-1.6, 1.6] {
                    let shelf = SCNNode(geometry: SCNBox(width: 0.5, height: 2.6, length: 2.4, chamferRadius: 0.03))
                    shelf.geometry?.materials = [plankMat]
                    shelf.position = SCNVector3(rx + side * 2.6, 1.3, sz)
                    root.addChildNode(shelf)
                    for row in 0..<3 {
                        for slot in 0..<6 {
                            let book = SCNNode(geometry: SCNBox(width: 0.3, height: 0.5,
                                                                length: 0.22, chamferRadius: 0.01))
                            let hue = CGFloat((row * 6 + slot) % 8) / 8
                            book.geometry?.firstMaterial?.diffuse.contents =
                                UIColor(hue: hue, saturation: 0.6, brightness: 0.85, alpha: 1)
                            book.position = SCNVector3(rx + side * 2.35,
                                                       0.6 + Float(row) * 0.8,
                                                       sz - 1.0 + Float(slot) * 0.38)
                            root.addChildNode(book)
                        }
                    }
                }
                let rug = SCNNode(geometry: SCNCylinder(radius: 1.2, height: 0.05))
                rug.geometry?.materials = [material(ForestTextures.carpet)]
                rug.position = SCNVector3(rx, 0.05, 0)
                root.addChildNode(rug)
            }
        }
    }

    private static func furnish(_ kind: InteriorKind, root: SCNNode,
                                roomWidth w: Float, roomDepth d: Float) {
        switch kind {
        case .castle:
            // Red carpet to the throne
            let carpet = SCNNode(geometry: SCNBox(width: 2.6, height: 0.06, length: CGFloat(d) - 2, chamferRadius: 0.02))
            carpet.geometry?.materials = [material(ForestTextures.carpet, tileX: 1, tileY: 3)]
            carpet.position = SCNVector3(0, 0.05, 0.5)
            root.addChildNode(carpet)
            // Throne
            let seat = SCNNode(geometry: SCNBox(width: 1.6, height: 0.7, length: 1.2, chamferRadius: 0.06))
            let gold = colored(UIColor(red: 0.93, green: 0.78, blue: 0.35, alpha: 1))
            seat.geometry?.materials = [gold]
            seat.position = SCNVector3(0, 0.35, -d / 2 + 1.4)
            root.addChildNode(seat)
            let back = SCNNode(geometry: SCNBox(width: 1.6, height: 2.4, length: 0.25, chamferRadius: 0.08))
            back.geometry?.materials = [gold]
            back.position = SCNVector3(0, 1.55, -d / 2 + 0.85)
            root.addChildNode(back)
            // Torches with flickering flames
            for tx: Float in [-w / 2 + 1, w / 2 - 1] {
                let post = SCNNode(geometry: SCNCylinder(radius: 0.07, height: 1.1))
                post.geometry?.materials = [material(ForestTextures.planks)]
                post.position = SCNVector3(tx, 2.2, -d / 2 + 0.6)
                root.addChildNode(post)
                let flame = SCNNode(geometry: SCNSphere(radius: 0.18))
                let fm = colored(UIColor(red: 1.0, green: 0.62, blue: 0.2, alpha: 1))
                fm.emission.contents = UIColor(red: 1.0, green: 0.6, blue: 0.15, alpha: 1)
                fm.emission.intensity = 1
                flame.geometry?.materials = [fm]
                flame.position = SCNVector3(tx, 2.9, -d / 2 + 0.6)
                let fire = SCNLight()
                fire.type = .omni; fire.intensity = 350
                fire.color = UIColor(red: 1.0, green: 0.7, blue: 0.35, alpha: 1)
                flame.light = fire
                let flicker = CABasicAnimation(keyPath: "light.intensity")
                flicker.fromValue = 250; flicker.toValue = 420
                flicker.duration = 0.35; flicker.autoreverses = true
                flicker.repeatCount = .infinity
                flame.addAnimation(flicker, forKey: "flicker")
                root.addChildNode(flame)
            }
            // Banners
            for bx: Float in [-3.5, 3.5] {
                let banner = SCNNode(geometry: SCNPlane(width: 1.1, height: 2.2))
                let bm = colored(UIColor(red: 0.68, green: 0.18, blue: 0.22, alpha: 1))
                bm.isDoubleSided = true
                banner.geometry?.materials = [bm]
                banner.position = SCNVector3(bx, 3.2, -d / 2 + 0.35)
                root.addChildNode(banner)
            }

        case .cottage:
            // Bed
            let bed = SCNNode(geometry: SCNBox(width: 1.6, height: 0.5, length: 2.4, chamferRadius: 0.08))
            bed.geometry?.materials = [colored(UIColor(red: 0.55, green: 0.65, blue: 0.9, alpha: 1))]
            bed.position = SCNVector3(-w / 2 + 1.6, 0.25, -d / 2 + 1.8)
            root.addChildNode(bed)
            let pillow = SCNNode(geometry: SCNBox(width: 1.2, height: 0.25, length: 0.6, chamferRadius: 0.1))
            pillow.geometry?.materials = [colored(.white)]
            pillow.position = SCNVector3(-w / 2 + 1.6, 0.6, -d / 2 + 1.0)
            root.addChildNode(pillow)
            // Table + stools
            let tableTop = SCNNode(geometry: SCNCylinder(radius: 1.0, height: 0.12))
            tableTop.geometry?.materials = [material(ForestTextures.planks)]
            tableTop.position = SCNVector3(2, 0.85, 0)
            root.addChildNode(tableTop)
            let tableLeg = SCNNode(geometry: SCNCylinder(radius: 0.1, height: 0.85))
            tableLeg.geometry?.materials = [material(ForestTextures.planks)]
            tableLeg.position = SCNVector3(2, 0.42, 0)
            root.addChildNode(tableLeg)
            for (sx, sz): (Float, Float) in [(0.6, 0.9), (3.4, -0.7)] {
                let stool = SCNNode(geometry: SCNCylinder(radius: 0.35, height: 0.5))
                stool.geometry?.materials = [material(ForestTextures.planks)]
                stool.position = SCNVector3(sx, 0.25, sz)
                root.addChildNode(stool)
            }
            // Fireplace with a warm glow
            let hearth = SCNNode(geometry: SCNBox(width: 2.0, height: 1.8, length: 0.7, chamferRadius: 0.05))
            hearth.geometry?.materials = [material(ForestTextures.stone)]
            hearth.position = SCNVector3(w / 2 - 1.2, 0.9, -d / 2 + 0.7)
            root.addChildNode(hearth)
            let ember = SCNNode(geometry: SCNSphere(radius: 0.25))
            let em = colored(UIColor(red: 1.0, green: 0.55, blue: 0.15, alpha: 1))
            em.emission.contents = UIColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1)
            em.emission.intensity = 1
            ember.geometry?.materials = [em]
            ember.position = SCNVector3(w / 2 - 1.2, 0.4, -d / 2 + 1.1)
            let glow = SCNLight()
            glow.type = .omni; glow.intensity = 300
            glow.color = UIColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 1)
            ember.light = glow
            root.addChildNode(ember)
            // Rug
            let rug = SCNNode(geometry: SCNCylinder(radius: 1.5, height: 0.04))
            rug.geometry?.materials = [material(ForestTextures.carpet)]
            rug.position = SCNVector3(0, 0.04, 1.5)
            root.addChildNode(rug)

        case .treehouse:
            // Cushions
            for (cx, cz, hue): (Float, Float, CGFloat) in [(-2, -1, 0.95), (0, -2.5, 0.55), (2, -1, 0.12)] {
                let cushion = SCNNode(geometry: SCNCylinder(radius: 0.6, height: 0.35))
                cushion.geometry?.materials = [colored(UIColor(hue: hue, saturation: 0.5, brightness: 0.9, alpha: 1))]
                cushion.position = SCNVector3(cx, 0.18, cz)
                root.addChildNode(cushion)
            }
            // Bookshelf
            let shelf = SCNNode(geometry: SCNBox(width: 2.2, height: 2.0, length: 0.4, chamferRadius: 0.04))
            shelf.geometry?.materials = [material(ForestTextures.planks)]
            shelf.position = SCNVector3(-w / 2 + 1.3, 1.0, -d / 2 + 0.5)
            root.addChildNode(shelf)
            for i in 0..<6 {
                let book = SCNNode(geometry: SCNBox(width: 0.22, height: 0.5, length: 0.15, chamferRadius: 0.01))
                book.geometry?.materials = [colored(UIColor(hue: CGFloat(i) / 6, saturation: 0.6, brightness: 0.85, alpha: 1))]
                book.position = SCNVector3(-w / 2 + 0.7 + Float(i) * 0.26, 1.55, -d / 2 + 0.5)
                root.addChildNode(book)
            }
            // Lantern
            let lantern = SCNNode(geometry: SCNSphere(radius: 0.22))
            let lm = colored(UIColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 1))
            lm.emission.contents = lm.diffuse.contents
            lm.emission.intensity = 0.9
            lantern.geometry?.materials = [lm]
            lantern.position = SCNVector3(0, 2.6, 0)
            root.addChildNode(lantern)
            // Round window with a view
            let window = SCNNode(geometry: SCNCylinder(radius: 0.8, height: 0.1))
            let wm = SCNMaterial()
            wm.diffuse.contents = ForestTextures.sky(night: false)
            wm.emission.contents = ForestTextures.sky(night: false)
            wm.emission.intensity = 0.4
            window.geometry?.materials = [wm]
            window.eulerAngles.x = .pi / 2
            window.position = SCNVector3(0, 2.6, -d / 2 + 0.16)
            root.addChildNode(window)
        }
    }
}
