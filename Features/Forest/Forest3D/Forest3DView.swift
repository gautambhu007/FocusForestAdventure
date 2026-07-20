//
//  Forest3DView.swift
//  Focus Forest Adventure
//
//  The walk-around 3D forest experience. First-person camera on the
//  terrain: virtual joystick to move, one-finger drag to look around,
//  pinch to zoom, tap the castle / cottage / treehouse to step inside
//  (furnished rooms!), tap the glowing door to come back out, and
//  double-tap anywhere outdoors to leave the forest.
//
//  Concurrency: SceneKit render callbacks arrive on the render thread,
//  so the coordinator is a plain nonisolated class with
//  nonisolated(unsafe) state (single-writer patterns), matching the
//  project's GCD/AV rules. Scene swaps hop back to the main thread.
//

import SwiftUI
import SceneKit
import SpriteKit

// MARK: - Shared control state (SwiftUI joystick → render loop)

/// Two floats written by the SwiftUI joystick (main thread) and read by
/// the render loop — single-writer, so unchecked is safe here.
final class Forest3DControls: @unchecked Sendable {
    var moveX: Float = 0      // -1…1 strafe
    var moveY: Float = 0      // -1…1 forward/back
}

// MARK: - The SwiftUI experience (SCNView + joystick + hints)

struct Forest3DExperience: View {
    let unlocked: [ForestElement]
    var onExit: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var controls = Forest3DControls()
    @State private var insideName: String?

    var body: some View {
        ZStack {
            Forest3DViewRepresentable(
                unlocked: unlocked,
                night: scheme == .dark,
                controls: controls,
                onExit: onExit,
                onModeChange: { name in insideName = name }
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    hintPill
                    Spacer()
                    Button {
                        onExit()
                    } label: {
                        Label(String(localized: "Leave"), systemImage: "arrowshape.turn.up.backward.fill")
                            .font(ForestTheme.Fonts.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.black.opacity(0.35), in: Capsule())
                    }
                    .accessibilityLabel(String(localized: "Leave the forest"))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                HStack(alignment: .bottom) {
                    JoystickPad(controls: controls)
                        .padding(.leading, 22)
                        .padding(.bottom, 26)
                    Spacer()
                }
            }
        }
    }

    private var hintPill: some View {
        Text(insideName == nil
             ? String(localized: "Joystick to walk • drag to look • pinch to zoom • tap houses to go in")
             : String(localized: "You're inside! Tap the glowing door to go out"))
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.black.opacity(0.35), in: Capsule())
            .allowsHitTesting(false)
    }
}

// MARK: - Virtual joystick

struct JoystickPad: View {
    let controls: Forest3DControls
    @State private var thumb: CGSize = .zero

    private let radius: CGFloat = 55

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.18))
                .overlay(Circle().stroke(.white.opacity(0.45), lineWidth: 2))
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .fill(.white.opacity(0.75))
                .frame(width: 52, height: 52)
                .offset(thumb)
                .shadow(radius: 3)
        }
        .contentShape(Circle().scale(1.6))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    var dx = g.translation.width
                    var dy = g.translation.height
                    let len = sqrt(dx * dx + dy * dy)
                    if len > radius { dx *= radius / len; dy *= radius / len }
                    thumb = CGSize(width: dx, height: dy)
                    controls.moveX = Float(dx / radius)
                    controls.moveY = Float(-dy / radius)
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { thumb = .zero }
                    controls.moveX = 0
                    controls.moveY = 0
                }
        )
        .accessibilityLabel(String(localized: "Walking joystick"))
    }
}

// MARK: - SCNView wrapper

struct Forest3DViewRepresentable: UIViewRepresentable {
    let unlocked: [ForestElement]
    let night: Bool
    let controls: Forest3DControls
    let onExit: () -> Void
    let onModeChange: (String?) -> Void

    func makeCoordinator() -> Forest3DCoordinator {
        Forest3DCoordinator(unlocked: unlocked, night: night,
                            controls: controls, onExit: onExit,
                            onModeChange: onModeChange)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 60
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

// MARK: - Coordinator: camera rig, gestures, per-frame world animation
//
// MainActor for everything UIKit (gestures, SCNView, scene swaps);
// only the render callback is nonisolated and it touches exclusively
// nonisolated(unsafe) state + SceneKit nodes (render-thread mutation is
// SceneKit's documented model).

@MainActor
final class Forest3DCoordinator: NSObject, SCNSceneRendererDelegate {

    private let unlocked: [ForestElement]
    private let night: Bool
    private let controls: Forest3DControls
    private let onExit: () -> Void
    private let onModeChange: (String?) -> Void

    nonisolated(unsafe) private weak var scnView: SCNView?
    nonisolated(unsafe) private var world: Forest3DBuilder.OutdoorWorld?
    nonisolated(unsafe) private var waterMaterial: SCNMaterial?

    // Camera rig for the ACTIVE scene
    nonisolated(unsafe) private var yawNode = SCNNode()
    nonisolated(unsafe) private var pitchNode = SCNNode()
    nonisolated(unsafe) private var cameraNode = SCNNode()
    nonisolated(unsafe) private var yaw: Float = 0
    nonisolated(unsafe) private var pitch: Float = -0.06
    nonisolated(unsafe) private var baseFov: CGFloat = 62
    nonisolated(unsafe) private var interior: InteriorKind?
    nonisolated(unsafe) private var savedOutdoorPosition = SCNVector3(0, 0, 62)
    nonisolated(unsafe) private var savedOutdoorYaw: Float = 0
    nonisolated(unsafe) private var lastTime: TimeInterval = 0
    nonisolated(unsafe) private var transitioning = false

    init(unlocked: [ForestElement], night: Bool, controls: Forest3DControls,
         onExit: @escaping () -> Void, onModeChange: @escaping (String?) -> Void) {
        self.unlocked = unlocked
        self.night = night
        self.controls = controls
        self.onExit = onExit
        self.onModeChange = onModeChange
        super.init()
    }

    // MARK: Setup

    func attach(to view: SCNView) {
        scnView = view
        let built = Forest3DBuilder.buildOutdoor(unlocked: unlocked, night: night)
        world = built
        // Grab the shared brook material for flow animation
        if let brook = built.scene.rootNode.childNode(withName: "brook", recursively: false) {
            waterMaterial = brook.childNodes.first?.geometry?.firstMaterial
        }
        installRig(in: built.scene,
                   position: SCNVector3(0, heightAt(x: 0, z: 62) + 1.75, 62),
                   yaw: .pi)   // spawn looking north toward the castle ridge
        view.scene = built.scene
        view.pointOfView = cameraNode
        view.delegate = self

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.require(toFail: doubleTap)
        view.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)
    }

    private func installRig(in scene: SCNScene, position: SCNVector3, yaw newYaw: Float) {
        yawNode = SCNNode()
        pitchNode = SCNNode()
        cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 500
        camera.fieldOfView = baseFov
        cameraNode.camera = camera
        yawNode.position = position
        yaw = newYaw
        pitch = -0.06
        yawNode.eulerAngles.y = yaw
        pitchNode.eulerAngles.x = pitch
        yawNode.addChildNode(pitchNode)
        pitchNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(yawNode)
    }

    nonisolated private func heightAt(x: Float, z: Float) -> Float {
        Forest3DBuilder.terrainHeight(x: x, z: z)
    }

    // MARK: Gestures (arrive on the main thread)

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: g.view)
        g.setTranslation(.zero, in: g.view)
        yaw -= Float(t.x) * 0.0062
        pitch = max(-0.95, min(0.55, pitch - Float(t.y) * 0.005))
        yawNode.eulerAngles.y = yaw
        pitchNode.eulerAngles.x = pitch
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        guard let camera = cameraNode.camera else { return }
        if g.state == .changed {
            let fov = camera.fieldOfView / g.scale
            camera.fieldOfView = max(32, min(95, fov))
            g.scale = 1
        }
    }

    @objc private func handleDoubleTap() {
        if interior == nil {
            onExit()          // leave the 3D forest entirely
        } else {
            exitInterior()    // inside a building: double-tap also exits it
        }
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        guard let view = scnView, !transitioning else { return }
        let hits = view.hitTest(g.location(in: view), options: [.boundingBoxOnly: true])
        for hit in hits {
            var node: SCNNode? = hit.node
            while let current = node {
                switch current.name {
                case "castle" where interior == nil: enterInterior(.castle); return
                case "cottage" where interior == nil: enterInterior(.cottage); return
                case "treehouse" where interior == nil: enterInterior(.treehouse); return
                case "exitDoor": exitInterior(); return
                default: node = current.parent
                }
            }
        }
    }

    // MARK: Interior transitions

    private func enterInterior(_ kind: InteriorKind) {
        guard let view = scnView else { return }
        transitioning = true
        savedOutdoorPosition = yawNode.position
        savedOutdoorYaw = yaw
        interior = kind
        let room = Forest3DBuilder.buildInterior(kind, night: night)
        installRig(in: room, position: SCNVector3(0, 1.75, 3.8), yaw: .pi)
        view.present(room, with: SKTransition.crossFade(withDuration: 0.7),
                     incomingPointOfView: cameraNode)
        endTransitionSoon()
        onModeChange(kind.rawValue)
    }

    private func exitInterior() {
        guard let view = scnView, let world, interior != nil else { return }
        transitioning = true
        interior = nil
        installRig(in: world.scene,
                   position: savedOutdoorPosition, yaw: savedOutdoorYaw)
        view.present(world.scene, with: SKTransition.crossFade(withDuration: 0.7),
                     incomingPointOfView: cameraNode)
        endTransitionSoon()
        onModeChange(nil)
    }

    /// Debounce taps while a crossfade is running (stays on MainActor).
    private func endTransitionSoon() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            self?.transitioning = false
        }
    }

    // MARK: Per-frame world simulation (render thread)

    nonisolated func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let dt = lastTime == 0 ? 0.016 : min(0.05, time - lastTime)
        lastTime = time

        moveCamera(dt: Float(dt))

        guard interior == nil, let world else { return }
        animateCreatures(world: world, t: time)
        // Brook flow
        waterMaterial?.diffuse.contentsTransform =
            SCNMatrix4Mult(SCNMatrix4MakeScale(6, 1, 1),
                           SCNMatrix4MakeTranslation(Float(time.truncatingRemainder(dividingBy: 60)) * 0.03, 0, 0))
        // Clouds drift in a slow carousel
        world.clouds.eulerAngles.y = Float(time * 0.008)
    }

    nonisolated private func moveCamera(dt: Float) {
        let vx = controls.moveX
        let vy = controls.moveY
        guard vx != 0 || vy != 0 else { return }
        let speed: Float = interior == nil ? 11 : 4.5
        let forward = SCNVector3(-sinf(yaw), 0, -cosf(yaw))
        let right = SCNVector3(cosf(yaw), 0, -sinf(yaw))
        var p = yawNode.position
        p.x += (right.x * vx + forward.x * vy) * speed * dt
        p.z += (right.z * vx + forward.z * vy) * speed * dt
        if interior == nil {
            let limit = Forest3DBuilder.worldHalf - 5
            p.x = max(-limit, min(limit, p.x))
            p.z = max(-limit, min(limit, p.z))
            p.y = heightAt(x: p.x, z: p.z) + 1.75
        } else {
            p.x = max(-6.6, min(6.6, p.x))
            p.z = max(-4.6, min(4.6, p.z))
            p.y = 1.75
        }
        yawNode.position = p
    }

    nonisolated private func animateCreatures(world: Forest3DBuilder.OutdoorWorld, t: TimeInterval) {
        // Foxes lope in loops around their own meadows
        let foxHomes: [(Float, Float, Float)] = [(-16, 30, 13), (28, -6, 16), (-5, -28, 12)]
        for (i, fox) in world.foxes.enumerated() {
            let (cx, cz, r) = foxHomes[i % foxHomes.count]
            let a = Float(t * 0.5) + Float(i) * 2.1
            let x = cx + cosf(a) * r
            let z = cz + sinf(a) * r
            fox.position = SCNVector3(x, heightAt(x: x, z: z), z)
            fox.eulerAngles.y = -a           // face the direction of travel
        }
        // Rabbits hop in little loops that FOLLOW the terrain
        let rabbitHomes: [(Float, Float, Float)] = [(6, 52, 6), (-10, 46, 7), (20, 58, 5), (0, 66, 8)]
        for (i, rabbit) in world.rabbits.enumerated() {
            let (cx, cz, r) = rabbitHomes[i % rabbitHomes.count]
            let a = Float(t * 0.35) + Float(i) * 1.7
            let x = cx + cosf(a) * r
            let z = cz + sinf(a) * r
            let hopPhase = Float((t * 1.7 + Double(i) * 0.4)
                .truncatingRemainder(dividingBy: 1))
            let hop = hopPhase < 0.6 ? 0.8 * sinf(.pi * hopPhase / 0.6) : 0
            rabbit.position = SCNVector3(x, heightAt(x: x, z: z) + hop, z)
            rabbit.eulerAngles.y = -a
            // squash on landing, stretch mid-air
            let squash: Float = hopPhase < 0.6 ? 1.05 : 0.82
            rabbit.scale = SCNVector3(1, squash, 1)
        }
        // Dragon: serpentine flight high above the valley
        for (i, seg) in world.dragonSegments.enumerated() {
            let lag = Double(i) * 0.32
            let ts = t - lag
            let x = Float(60 * sin(2 * .pi * ts / 26))
            let z = Float(-20 + 45 * sin(2 * .pi * ts / 17.3))
            let y = Float(30 + 6 * sin(2 * .pi * ts / 6.1))
            seg.position = SCNVector3(x, y, z)
            if i == 0 {
                // head looks along its flight direction
                let dx = Float(60 * 2 * .pi / 26 * cos(2 * .pi * ts / 26))
                let dz = Float(45 * 2 * .pi / 17.3 * cos(2 * .pi * ts / 17.3))
                seg.eulerAngles.y = atan2f(dx, dz)
            }
        }
        // Butterflies flutter above the flowers
        world.scene.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name, name.hasPrefix("butterfly"),
                  let index = Int(name.dropFirst("butterfly".count)) else { return }
            let s = Double(index) * 9
            let x = Float(30 * sin(t * 0.21 + s) + 12 * sin(t * 0.9 + s))
            let z = Float(28 * cos(t * 0.17 + s) + 30)
            let y = heightAt(x: x, z: z) + 1.4 + Float(0.5 * sin(t * 2.3 + s))
            node.position = SCNVector3(x, y, z)
        }
    }
}
