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
    var netMode = false       // butterfly net equipped
}

// MARK: - The SwiftUI experience (SCNView + joystick + hints)

struct Forest3DExperience: View {
    let unlocked: [ForestElement]
    var speak: (String) -> Void = { _ in }
    var onExit: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var controls = Forest3DControls()
    @State private var ambience = Forest3DAmbience()
    @State private var insideName: String?
    @State private var starCount = 0
    @State private var pouch = 0
    @State private var netOn = false
    @State private var learnItem: ForestLearnItem?

    var body: some View {
        ZStack {
            Forest3DViewRepresentable(
                unlocked: unlocked,
                night: scheme == .dark,
                controls: controls,
                onExit: onExit,
                onModeChange: { name in
                    insideName = name
                    switch name {
                    case "castle": ambience.setMood(.castle)
                    case "cottage": ambience.setMood(.cottage)
                    case "treehouse": ambience.setMood(.treehouse)
                    default: ambience.setMood(.meadow)
                    }
                },
                onLearn: { item in
                    learnItem = item
                    speak("\(item.name). \(item.fact)")
                },
                onStars: { count in
                    starCount = count
                    speak(String(localized: "You found a golden star!"))
                },
                onPouch: { count, released in
                    pouch = count
                    if released {
                        speak(String(localized: "Fly free, little butterflies!"))
                    }
                }
            )
            .ignoresSafeArea()

            VStack {
                HStack(alignment: .top) {
                    hintPill
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
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
                        counterPill("⭐", starCount)
                        if pouch > 0 { counterPill("🦋", pouch) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                if let item = learnItem {
                    learnCard(item)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                HStack(alignment: .bottom) {
                    JoystickPad(controls: controls)
                        .padding(.leading, 22)
                    Spacer()
                    if insideName == nil {
                        netButton
                            .padding(.trailing, 22)
                    }
                }
                .padding(.bottom, 26)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: learnItem?.name)
        .animation(.easeInOut(duration: 0.2), value: netOn)
        .task(id: learnItem?.name) {
            // Learn cards politely excuse themselves.
            guard learnItem != nil else { return }
            try? await Task.sleep(nanoseconds: 9_000_000_000)
            learnItem = nil
        }
        .onAppear {
            starCount = UserDefaults.standard.array(forKey: "f3d.stars.collected")?.count ?? 0
            ambience.start(mood: .meadow)
        }
        .onDisappear { ambience.stop() }
    }

    private var hintPill: some View {
        Text(hintText)
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.black.opacity(0.35), in: Capsule())
            .allowsHitTesting(false)
    }

    private var hintText: String {
        if insideName != nil {
            return String(localized: "You're inside! Tap the glowing door to go out")
        }
        if netOn {
            return pouch > 0
                ? String(localized: "Tap a garden to set your butterflies free!")
                : String(localized: "Net ready! Tap a butterfly to catch it")
        }
        return String(localized: "Joystick to walk • drag to look • tap plants, fish and houses!")
    }

    private func counterPill(_ emoji: String, _ count: Int) -> some View {
        Text("\(emoji) \(count)")
            .font(.system(.footnote, design: .rounded).weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.black.opacity(0.35), in: Capsule())
    }

    private var netButton: some View {
        Button {
            netOn.toggle()
            controls.netMode = netOn
        } label: {
            Text("🦋")
                .font(.system(size: 30))
                .padding(14)
                .background(netOn ? Color.white.opacity(0.75) : Color.black.opacity(0.35),
                            in: Circle())
                .overlay(Circle().stroke(.white.opacity(netOn ? 1 : 0.4), lineWidth: 2.5))
        }
        .accessibilityLabel(netOn
            ? String(localized: "Put the butterfly net away")
            : String(localized: "Take out the butterfly net"))
    }

    private func learnCard(_ item: ForestLearnItem) -> some View {
        HStack(spacing: 14) {
            Text(item.emoji).font(.system(size: 44))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                Text(item.fact)
                    .font(.system(.subheadline, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .onTapGesture { learnItem = nil }
        .accessibilityElement(children: .combine)
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
    let onLearn: (ForestLearnItem) -> Void
    let onStars: (Int) -> Void
    let onPouch: (Int, Bool) -> Void

    func makeCoordinator() -> Forest3DCoordinator {
        Forest3DCoordinator(unlocked: unlocked, night: night,
                            controls: controls, onExit: onExit,
                            onModeChange: onModeChange, onLearn: onLearn,
                            onStars: onStars, onPouch: onPouch)
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
    private let onLearn: (ForestLearnItem) -> Void
    private let onStars: (Int) -> Void
    private let onPouch: (Int, Bool) -> Void

    nonisolated(unsafe) private weak var scnView: SCNView?
    nonisolated(unsafe) private var world: Forest3DBuilder.OutdoorWorld?

    // Butterfly game state
    private var capturedCount = 0
    /// Butterflies released into gardens: node + garden center they orbit.
    nonisolated(unsafe) private var releasedButterflies: [(SCNNode, SCNVector3)] = []
    nonisolated(unsafe) private var capturedNames: Set<String> = []
    private var bunnyHintIndex = 0

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
         onExit: @escaping () -> Void, onModeChange: @escaping (String?) -> Void,
         onLearn: @escaping (ForestLearnItem) -> Void,
         onStars: @escaping (Int) -> Void,
         onPouch: @escaping (Int, Bool) -> Void) {
        self.unlocked = unlocked
        self.night = night
        self.controls = controls
        self.onExit = onExit
        self.onModeChange = onModeChange
        self.onLearn = onLearn
        self.onStars = onStars
        self.onPouch = onPouch
        super.init()
    }

    // MARK: Setup

    func attach(to view: SCNView) {
        scnView = view
        let built = Forest3DBuilder.buildOutdoor(unlocked: unlocked, night: night)
        world = built
        // Stars found on previous visits stay found.
        let collected = Set((UserDefaults.standard.array(forKey: "f3d.stars.collected") as? [Int]) ?? [])
        for star in built.stars {
            if let name = star.name, let index = Int(name.dropFirst("star.".count)),
               collected.contains(index) {
                star.removeFromParentNode()
            }
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
                if let name = current.name, handleNamedTap(name, node: current) {
                    return
                }
                node = current.parent
            }
        }
    }

    /// Routes a tap on a named node. Returns true when consumed.
    private func handleNamedTap(_ name: String, node: SCNNode) -> Bool {
        switch name {
        case "castle" where interior == nil: enterInterior(.castle); return true
        case "cottage" where interior == nil: enterInterior(.cottage); return true
        case "treehouse" where interior == nil: enterInterior(.treehouse); return true
        case "exitDoor": exitInterior(); return true
        case "bunnyGuide":
            let hints = [
                String(localized: "Walk up the big hill to visit the castle — there are rooms inside!"),
                String(localized: "Golden stars are hiding all over the forest. Can you find them?"),
                String(localized: "Take out your net and catch butterflies, then set them free in a garden!"),
                String(localized: "Tap the flowers and the fish — they all have stories to tell you!")
            ]
            let hint = hints[bunnyHintIndex % hints.count]
            bunnyHintIndex += 1
            onLearn(ForestLearnItem(emoji: "🐰", name: String(localized: "Bunny"), fact: hint))
            return true
        case "garden":
            if capturedCount > 0 {
                releaseButterflies(at: node.position)
            } else {
                onLearn(ForestLearnItem(emoji: "🌷", name: String(localized: "Butterfly Garden"),
                    fact: String(localized: "Catch butterflies with your net, then bring them here to fly free!")))
            }
            return true
        default:
            if name.hasPrefix("star."), let index = Int(name.dropFirst("star.".count)) {
                collectStar(index: index, node: node)
                return true
            }
            if name.hasPrefix("bfly.") {
                guard controls.netMode, !capturedNames.contains(name) else { return false }
                capturedNames.insert(name)
                capturedCount += 1
                node.removeFromParentNode()
                onPouch(capturedCount, false)
                return true
            }
            if name.hasPrefix("learn."),
               let item = Forest3DBuilder.learnItems[String(name.dropFirst("learn.".count))] {
                onLearn(item)
                return true
            }
            return false
        }
    }

    private func collectStar(index: Int, node: SCNNode) {
        node.removeFromParentNode()
        var collected = (UserDefaults.standard.array(forKey: "f3d.stars.collected") as? [Int]) ?? []
        guard !collected.contains(index) else { return }
        collected.append(index)
        UserDefaults.standard.set(collected, forKey: "f3d.stars.collected")
        SyncedScoreStore.set(collected.count, forKey: "forest3d.stars")
        onStars(collected.count)
    }

    private func releaseButterflies(at center: SCNVector3) {
        guard let world else { return }
        let hues: [CGFloat] = [0.08, 0.6, 0.9, 0.16, 0.75]
        for i in 0..<capturedCount {
            let b = SCNNode(geometry: SCNPlane(width: 0.55, height: 0.42))
            let m = SCNMaterial()
            m.diffuse.contents = ForestTextures.butterfly(hue: hues[i % hues.count])
            m.isDoubleSided = true
            m.transparencyMode = .aOne
            b.geometry?.materials = [m]
            b.constraints = [SCNBillboardConstraint()]
            b.position = SCNVector3(center.x, center.y + 1.5, center.z)
            world.scene.rootNode.addChildNode(b)
            releasedButterflies.append((b, center))
        }
        capturedCount = 0
        onPouch(0, true)
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
        // The river actually FLOWS: the texture streams along the ribbon.
        world.riverMaterial?.diffuse.contentsTransform =
            SCNMatrix4MakeTranslation(0, -Float(time.truncatingRemainder(dividingBy: 600)) * 0.12, 0)
        // Clouds drift in a slow carousel
        world.clouds.eulerAngles.y = Float(time * 0.008)
    }

    nonisolated private func moveCamera(dt: Float) {
        let vx = controls.moveX
        let vy = controls.moveY
        guard vx != 0 || vy != 0 else { return }
        let speed: Float = interior == nil ? 7.5 : 3.5   // a calm stroll
        let forward = SCNVector3(-sinf(yaw), 0, -cosf(yaw))
        let right = SCNVector3(cosf(yaw), 0, -sinf(yaw))
        var p = yawNode.position
        p.x += (right.x * vx + forward.x * vy) * speed * dt
        p.z += (right.z * vx + forward.z * vy) * speed * dt
        if let kind = interior {
            p = clampInterior(kind: kind, candidate: p, previous: yawNode.position)
            p.y = 1.75
        } else {
            let limit = Forest3DBuilder.worldHalf - 5
            p.x = max(-limit, min(limit, p.x))
            p.z = max(-limit, min(limit, p.z))
            // Solid world: slide out of tree trunks and building walls.
            if let obstacles = world?.obstacles {
                for (ox, oz, r) in obstacles {
                    let dx = p.x - ox, dz = p.z - oz
                    let distSq = dx * dx + dz * dz
                    let minDist = r + 0.5
                    if distSq < minDist * minDist && distSq > 0.0001 {
                        let dist = sqrtf(distSq)
                        p.x = ox + dx / dist * minDist
                        p.z = oz + dz / dist * minDist
                    }
                }
            }
            p.y = heightAt(x: p.x, z: p.z) + 1.75
        }
        yawNode.position = p
    }

    /// Room bounds. The castle's ground floor is a hall plus two arched
    /// tunnels leading to side rooms; homes are simple rectangles.
    nonisolated private func clampInterior(kind: InteriorKind,
                                           candidate: SCNVector3,
                                           previous: SCNVector3) -> SCNVector3 {
        func allowed(_ x: Float, _ z: Float) -> Bool {
            if kind != .castle {
                return abs(x) <= 6.6 && abs(z) <= 4.6
            }
            if abs(x) <= 7.6 && abs(z) <= 5.6 { return true }            // great hall
            if abs(z) <= 1.4 && abs(x) <= 10.4 { return true }           // tunnels
            if abs(abs(x) - 13.4) <= 2.6 && abs(z) <= 2.6 { return true } // side rooms
            return false
        }
        var p = candidate
        if !allowed(p.x, p.z) {
            // Try sliding along one axis before giving up.
            if allowed(candidate.x, previous.z) {
                p.z = previous.z
            } else if allowed(previous.x, candidate.z) {
                p.x = previous.x
            } else {
                p.x = previous.x; p.z = previous.z
            }
        }
        return p
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
        // Dragon: slow, majestic serpentine flight. Segments overlap into
        // a continuous body and every segment orients along the path.
        let dragonPos: (Double) -> SCNVector3 = { ts in
            SCNVector3(Float(65 * sin(2 * .pi * ts / 34)),
                       Float(28 + 5 * sin(2 * .pi * ts / 8.2)),
                       Float(-15 + 50 * sin(2 * .pi * ts / 23)))
        }
        for (i, seg) in world.dragonSegments.enumerated() {
            let ts = t - Double(i) * 0.14
            let p = dragonPos(ts)
            seg.position = p
            let ahead = dragonPos(ts + 0.12)
            let dx = ahead.x - p.x, dy = ahead.y - p.y, dz = ahead.z - p.z
            let horiz = sqrtf(dx * dx + dz * dz)
            seg.eulerAngles = SCNVector3(-atan2f(dy, max(horiz, 0.001)), atan2f(dx, dz), 0)
        }
        // Fish swim along the river, wiggling their tails
        if !world.riverPath.isEmpty {
            let n = world.riverPath.count
            for (j, f) in world.fish.enumerated() {
                let speed = 0.010 + Double(j % 3) * 0.004
                let s = (t * speed + Double(j) * 0.17).truncatingRemainder(dividingBy: 1)
                let pos = s * Double(n - 1)
                let i0 = min(n - 2, Int(pos))
                let frac = Float(pos - Double(i0))
                let a = world.riverPath[i0], b = world.riverPath[i0 + 1]
                let wiggle = sinf(Float(t) * 6 + Float(j)) * 0.5
                f.position = SCNVector3(a.x + (b.x - a.x) * frac + wiggle,
                                        a.y - 0.32,
                                        a.z + (b.z - a.z) * frac)
                f.eulerAngles.y = atan2f(b.x - a.x, b.z - a.z) + wiggle * 0.4
            }
        }
        // Wild butterflies flutter above the flower meadows
        let homes: [(Float, Float)] = [(-20, 25), (30, 15), (0, 45), (-45, -10),
                                       (55, -25), (20, 70), (-70, 50), (45, 40)]
        for (i, b) in world.butterflies.enumerated() {
            guard b.parent != nil else { continue }   // captured
            let (hx, hz) = homes[i % homes.count]
            let s = Double(i) * 9
            let x = hx + Float(9 * sin(t * 0.26 + s) + 3 * sin(t * 1.1 + s))
            let z = hz + Float(8 * cos(t * 0.21 + s))
            let y = heightAt(x: x, z: z) + 1.3 + Float(0.5 * sin(t * 2.3 + s))
            b.position = SCNVector3(x, y, z)
        }
        // Released butterflies stay near their garden, happy forever
        for (i, (b, home)) in releasedButterflies.enumerated() {
            let s = Double(i) * 5 + 2
            let x = home.x + Float(2.6 * sin(t * 0.5 + s))
            let z = home.z + Float(2.6 * cos(t * 0.38 + s))
            let y = home.y + 1.2 + Float(0.5 * sin(t * 2.0 + s))
            b.position = SCNVector3(x, y, z)
        }
    }
}
