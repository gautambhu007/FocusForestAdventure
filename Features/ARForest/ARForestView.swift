//
//  ARForestView.swift
//  Focus Forest Adventure
//
//  Phase 2.5 AR Forest screen: device gate, ARView container, child-sized
//  HUD (plant picker, stars, save/load), and a friendly non-AR fallback.
//

import SwiftUI
import RealityKit

struct ARForestView: View {
    let dependencies: AppDependencies
    @State private var session = ARForestSession()

    var body: some View {
        Group {
            if ARForestSession.isSupported {
                arContent
            } else {
                unsupportedFallback
            }
        }
        .navigationTitle(String(localized: "AR Forest"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: AR

    private var arContent: some View {
        ZStack {
            ARForestContainer(session: session)
                .ignoresSafeArea()

            VStack {
                statusBanner
                Spacer()
                controls
            }
            .padding()
        }
        .onDisappear { session.detach() }
    }

    private var statusBanner: some View {
        Text(session.statusMessage)
            .font(ForestTheme.Fonts.caption)
            .foregroundStyle(ForestTheme.Colors.deepGreen)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .forestCard(cornerRadius: 14)
            .accessibilityLabel(session.statusMessage)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                plantButton(kind: .tree, title: String(localized: "Tree"), emoji: "🌳")
                plantButton(kind: .flower, title: String(localized: "Flower"), emoji: "🌸")
                plantButton(kind: .animal, title: String(localized: "Friend"), emoji: "🦊")

                Spacer()

                Text("⭐ \(session.state.starsCollected)")
                    .font(ForestTheme.Fonts.body)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .forestCard(cornerRadius: 14)
                    .accessibilityLabel(String(localized: "\(session.state.starsCollected) stars collected"))
            }

            HStack(spacing: 10) {
                Button {
                    session.saveWorld()
                } label: {
                    Label(String(localized: "Save forest"), systemImage: "square.and.arrow.down")
                        .font(ForestTheme.Fonts.caption)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .forestCard(cornerRadius: 14)
                }
                .buttonStyle(SquishyButtonStyle())

                if session.hasSavedWorld {
                    Button {
                        session.loadWorld()
                    } label: {
                        Label(String(localized: "Load forest"), systemImage: "arrow.counterclockwise")
                            .font(ForestTheme.Fonts.caption)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .forestCard(cornerRadius: 14)
                    }
                    .buttonStyle(SquishyButtonStyle())
                }
                Spacer()
            }
        }
    }

    private func plantButton(kind: ARForestSceneState.PlantKind, title: String, emoji: String) -> some View {
        Button {
            session.plantKind = kind
        } label: {
            Text("\(emoji) \(title)")
                .font(ForestTheme.Fonts.caption)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .forestCard(cornerRadius: 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(session.plantKind == kind
                                ? ForestTheme.Colors.leafGreen : .clear, lineWidth: 3)
                )
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(session.plantKind == kind ? .isSelected : [])
    }

    // MARK: Fallback (unsupported devices)

    private var unsupportedFallback: some View {
        ZStack {
            ForestTheme.Gradients.morningSky.ignoresSafeArea()
            VStack(spacing: 16) {
                LottieView(animation: .treeGrow, loopMode: .loop)
                    .frame(width: 160, height: 160)
                Text(String(localized: "This device can't show the magic AR forest, but your real forest is always growing!"))
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                BigBouncyButton(
                    title: String(localized: "Visit my forest"),
                    icon: "tree.fill",
                    color: ForestTheme.Colors.leafGreen
                ) {
                    dependencies.appState.navigationPath.removeAll()
                    dependencies.appState.navigationPath.append(.forest)
                }
            }
        }
    }
}

// MARK: - ARView bridge

private struct ARForestContainer: UIViewRepresentable {
    let session: ARForestSession

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        session.attach(to: arView)
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)
        context.coordinator.session = session
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator: NSObject {
        var session: ARForestSession?

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            session?.handleTap(at: recognizer.location(in: recognizer.view))
        }
    }
}
