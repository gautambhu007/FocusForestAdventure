//
//  ARForestSession.swift
//  Focus Forest Adventure
//
//  Phase 2.5 AR Forest: RealityKit session state — planting, watering,
//  star collecting, and world persistence.
//
//  Persistence strategy: ARWorldMap (for relocalization) + a JSON sidecar
//  describing what was planted where. On load we feed ARKit the world map
//  and re-create entities from the sidecar — no ARSessionDelegate needed,
//  which keeps Swift 6 concurrency simple (everything stays on @MainActor;
//  ARKit's completion handlers are hopped explicitly).
//
//  Entities are procedural (cylinders/spheres/cones) — no bundled 3D assets.
//

import Foundation
import Observation
import ARKit
import RealityKit

// MARK: - Pure scene state (unit-testable, ARKit-free)

struct ARForestSceneState: Codable, Equatable, Sendable {
    enum PlantKind: String, Codable, Sendable { case tree, flower, animal }

    struct Planted: Codable, Equatable, Sendable {
        var kind: PlantKind
        var transform: [Float]   // 16 floats, column-major 4x4
        var growth: Int = 0      // watering count, caps at 3
    }

    var planted: [Planted] = []
    var starsCollected: Int = 0

    var treeCount: Int { planted.filter { $0.kind == .tree }.count }
    var flowerCount: Int { planted.filter { $0.kind == .flower }.count }

    mutating func plant(_ kind: PlantKind, transform: simd_float4x4) {
        planted.append(Planted(kind: kind, transform: transform.flattened))
    }

    /// Returns the new growth stage (max 3), or nil for an invalid index.
    mutating func water(at index: Int) -> Int? {
        guard planted.indices.contains(index) else { return nil }
        planted[index].growth = min(3, planted[index].growth + 1)
        return planted[index].growth
    }
}

extension simd_float4x4 {
    var flattened: [Float] {
        [columns.0, columns.1, columns.2, columns.3].flatMap { [$0.x, $0.y, $0.z, $0.w] }
    }

    init?(flattened values: [Float]) {
        guard values.count == 16 else { return nil }
        self.init(
            SIMD4(values[0], values[1], values[2], values[3]),
            SIMD4(values[4], values[5], values[6], values[7]),
            SIMD4(values[8], values[9], values[10], values[11]),
            SIMD4(values[12], values[13], values[14], values[15])
        )
    }
}

// MARK: - Session

@Observable
@MainActor
final class ARForestSession {

    static var isSupported: Bool { ARWorldTrackingConfiguration.isSupported }

    private(set) var state = ARForestSceneState()
    private(set) var statusMessage = String(localized: "Point at the floor, then tap to plant!")
    private(set) var hasSavedWorld = false
    var plantKind: ARForestSceneState.PlantKind = .tree

    private weak var arView: ARView?
    /// Index into `state.planted` keyed by entity identity.
    private var plantedEntities: [Entity: Int] = [:]
    private var starEntities: Set<Entity> = []
    private var starTimer: Task<Void, Never>?

    private var saveDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
    private var worldMapURL: URL { saveDirectory.appendingPathComponent("arforest.worldmap") }
    private var sceneURL: URL { saveDirectory.appendingPathComponent("arforest.scene.json") }

    // MARK: Lifecycle

    func attach(to arView: ARView) {
        self.arView = arView
        hasSavedWorld = FileManager.default.fileExists(atPath: worldMapURL.path)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.run(configuration)

        startStarRain()
    }

    func detach() {
        starTimer?.cancel()
        starTimer = nil
        arView?.session.pause()
    }

    // MARK: Interaction

    func handleTap(at point: CGPoint) {
        guard let arView else { return }

        // 1. Tapping an existing entity: collect stars, water plants.
        if let entity = arView.entity(at: point) {
            let root = topLevelEntity(of: entity)
            if starEntities.contains(root) {
                collectStar(root)
                return
            }
            if let index = plantedEntities[root] {
                water(root, index: index)
                return
            }
        }

        // 2. Otherwise: plant on the nearest horizontal plane.
        guard let hit = arView.raycast(from: point, allowing: .estimatedPlane,
                                       alignment: .horizontal).first else {
            statusMessage = String(localized: "Aim at the floor and try again!")
            return
        }
        plant(at: hit.worldTransform)
    }

    private func plant(at transform: simd_float4x4) {
        guard let arView else { return }
        let kind = plantKind
        state.plant(kind, transform: transform)

        let anchor = AnchorEntity(world: transform)
        let entity = Self.makeEntity(kind: kind, growth: 0)
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)
        plantedEntities[entity] = state.planted.count - 1

        entity.scale = .init(repeating: 0.01)
        var grown = entity.transform
        grown.scale = .one
        entity.move(to: grown, relativeTo: entity.parent, duration: 0.5, timingFunction: .easeOut)

        statusMessage = switch kind {
        case .tree: String(localized: "A tree! Tap it to water it 💧")
        case .flower: String(localized: "A flower! Tap it to water it 💧")
        case .animal: String(localized: "A forest friend! Tap to feed it 🥕")
        }
    }

    private func water(_ entity: Entity, index: Int) {
        guard let stage = state.water(at: index) else { return }
        // Each watering grows the plant a little (caps at 3 stages).
        var target = entity.transform
        target.scale = .init(repeating: 1.0 + Float(stage) * 0.25)
        entity.move(to: target, relativeTo: entity.parent, duration: 0.4, timingFunction: .easeInOut)
        statusMessage = stage >= 3
            ? String(localized: "Fully grown! Beautiful! 🌟")
            : String(localized: "Growing! Water it again soon 💧")
    }

    private func collectStar(_ entity: Entity) {
        starEntities.remove(entity)
        entity.parent?.removeFromParent()
        state.starsCollected += 1
        statusMessage = String(localized: "Star collected! ⭐ \(state.starsCollected) so far!")
    }

    /// Every ~8s a star appears near the child at reachable height.
    private func startStarRain() {
        starTimer?.cancel()
        starTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                guard let self, !Task.isCancelled else { return }
                self.spawnStar()
            }
        }
    }

    private func spawnStar() {
        guard let arView, starEntities.count < 3 else { return }
        let x = Float.random(in: -0.8...0.8)
        let z = Float.random(in: -0.8...(-0.3))
        let anchor = AnchorEntity(world: [x, Float.random(in: 0.1...0.6), z])
        let star = Self.makeStarEntity()
        anchor.addChild(star)
        arView.scene.addAnchor(anchor)
        starEntities.insert(star)
    }

    // MARK: Persistence

    func saveWorld() {
        guard let arView else { return }
        statusMessage = String(localized: "Saving your forest…")
        let sceneData = try? JSONEncoder().encode(state)

        arView.session.getCurrentWorldMap { [weak self] worldMap, error in
            // Completion arrives on an ARKit queue: extract Sendable Data
            // first, then hop home.
            let mapData: Data? = worldMap.flatMap {
                try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
            }
            let failure = error != nil
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let mapData, let sceneData {
                    try? mapData.write(to: self.worldMapURL, options: .atomic)
                    try? sceneData.write(to: self.sceneURL, options: .atomic)
                    self.hasSavedWorld = true
                    self.statusMessage = String(localized: "Forest saved! 🌳")
                } else {
                    self.statusMessage = failure
                        ? String(localized: "Look around a bit more, then try saving again!")
                        : String(localized: "Couldn't save this time — try again!")
                }
            }
        }
    }

    func loadWorld() {
        guard let arView,
              let mapData = try? Data(contentsOf: worldMapURL),
              let worldMap = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: ARWorldMap.self, from: mapData
              ),
              let sceneData = try? Data(contentsOf: sceneURL),
              let savedState = try? JSONDecoder().decode(ARForestSceneState.self, from: sceneData)
        else {
            statusMessage = String(localized: "No saved forest yet — plant one and tap Save!")
            return
        }

        // Restart tracking against the saved map, then rebuild the plants.
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        configuration.initialWorldMap = worldMap
        arView.scene.anchors.removeAll()
        plantedEntities.removeAll()
        starEntities.removeAll()
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        state = savedState
        for (index, plantedItem) in savedState.planted.enumerated() {
            guard let transform = simd_float4x4(flattened: plantedItem.transform) else { continue }
            let anchor = AnchorEntity(world: transform)
            let entity = Self.makeEntity(kind: plantedItem.kind, growth: plantedItem.growth)
            anchor.addChild(entity)
            arView.scene.addAnchor(anchor)
            plantedEntities[entity] = index
        }
        statusMessage = String(localized: "Welcome back to your forest! Move your iPad around slowly so it can find its place.")
    }

    // MARK: Procedural entities

    private func topLevelEntity(of entity: Entity) -> Entity {
        var current = entity
        while let parent = current.parent, !(parent is AnchorEntity) {
            current = parent
        }
        return current
    }

    private static func makeEntity(kind: ARForestSceneState.PlantKind, growth: Int) -> ModelEntity {
        let root: ModelEntity
        switch kind {
        case .tree:
            let trunk = ModelEntity(
                mesh: .generateCylinder(height: 0.12, radius: 0.015),
                materials: [SimpleMaterial(color: .brown, isMetallic: false)]
            )
            let foliage = ModelEntity(
                mesh: .generateSphere(radius: 0.06),
                materials: [SimpleMaterial(color: .systemGreen, isMetallic: false)]
            )
            foliage.position = [0, 0.10, 0]
            trunk.addChild(foliage)
            trunk.position = [0, 0.06, 0]
            root = trunk
        case .flower:
            let stem = ModelEntity(
                mesh: .generateCylinder(height: 0.06, radius: 0.004),
                materials: [SimpleMaterial(color: .systemGreen, isMetallic: false)]
            )
            let bloom = ModelEntity(
                mesh: .generateSphere(radius: 0.02),
                materials: [SimpleMaterial(color: .systemPink, isMetallic: false)]
            )
            bloom.position = [0, 0.04, 0]
            stem.addChild(bloom)
            stem.position = [0, 0.03, 0]
            root = stem
        case .animal:
            // A little fox: body + head spheres, two cone ears, sphere tail.
            let fur = SimpleMaterial(color: .systemOrange, isMetallic: false)
            let body = ModelEntity(mesh: .generateSphere(radius: 0.035), materials: [fur])
            let head = ModelEntity(mesh: .generateSphere(radius: 0.024), materials: [fur])
            head.position = [0, 0.038, 0.02]
            let earLeft = ModelEntity(mesh: .generateCone(height: 0.02, radius: 0.008), materials: [fur])
            earLeft.position = [-0.012, 0.024, 0]
            let earRight = ModelEntity(mesh: .generateCone(height: 0.02, radius: 0.008), materials: [fur])
            earRight.position = [0.012, 0.024, 0]
            head.addChild(earLeft)
            head.addChild(earRight)
            let tail = ModelEntity(
                mesh: .generateSphere(radius: 0.015),
                materials: [SimpleMaterial(color: .white, isMetallic: false)]
            )
            tail.position = [0, 0.01, -0.04]
            body.addChild(head)
            body.addChild(tail)
            body.position = [0, 0.035, 0]
            root = body
        }
        root.scale = .init(repeating: 1.0 + Float(growth) * 0.25)
        root.generateCollisionShapes(recursive: true)
        return root
    }

    private static func makeStarEntity() -> ModelEntity {
        let star = ModelEntity(
            mesh: .generateSphere(radius: 0.025),
            materials: [SimpleMaterial(color: .systemYellow, isMetallic: true)]
        )
        star.generateCollisionShapes(recursive: true)
        return star
    }
}
