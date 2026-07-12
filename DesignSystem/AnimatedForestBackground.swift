//
//  AnimatedForestBackground.swift
//  Focus Forest Adventure
//
//  The living forest backdrop: sky gradient, swaying trees, flying birds,
//  butterflies, and drifting clouds. Density scales with forest level.
//

import SwiftUI

struct AnimatedForestBackground: View {
    enum Density { case light, medium, lush }
    var density: Density = .medium

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForestTheme.Gradients.morningSky.ignoresSafeArea()

            // Drifting clouds
            CloudLayer()

            // Swaying trees along the bottom
            TreeLine(treeCount: treeCount)
                .frame(maxHeight: .infinity, alignment: .bottom)

            // Birds
            if density != .light {
                FlyingBird(delay: 0).allowsHitTesting(false)
                FlyingBird(delay: 6).allowsHitTesting(false)
            }

            // Butterflies
            ForEach(0..<butterflyCount, id: \.self) { index in
                ButterflySprite(seed: index)
            }

            MagicDustView().ignoresSafeArea()
        }
        .accessibilityHidden(true) // decorative
    }

    private var treeCount: Int {
        switch density { case .light: 3; case .medium: 5; case .lush: 8 }
    }

    private var butterflyCount: Int {
        switch density { case .light: 1; case .medium: 2; case .lush: 4 }
    }
}

// MARK: - Trees

private struct TreeLine: View {
    let treeCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sway = false

    var body: some View {
        HStack(alignment: .bottom, spacing: -12) {
            ForEach(0..<treeCount, id: \.self) { index in
                Image(systemName: "tree.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: CGFloat(80 + (index * 37) % 70))
                    .foregroundStyle(
                        ForestTheme.Colors.deepGreen
                            .opacity(0.35 + Double(index % 3) * 0.2)
                    )
                    .rotationEffect(.degrees(reduceMotion ? 0 : (sway ? 1.5 : -1.5)),
                                    anchor: .bottom)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                sway = true
            }
        }
    }
}

// MARK: - Clouds

private struct CloudLayer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "cloud.fill")
                    .font(.system(size: 60 + CGFloat(index) * 18))
                    .foregroundStyle(.white.opacity(0.7))
                    .offset(
                        x: reduceMotion
                            ? proxy.size.width * 0.3 * CGFloat(index)
                            : (drift ? proxy.size.width + 100 : -140),
                        y: CGFloat(30 + index * 55)
                    )
                    .animation(
                        reduceMotion ? nil :
                            .linear(duration: 34 + Double(index) * 11)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 8),
                        value: drift
                    )
            }
        }
        .onAppear { drift = true }
    }
}

// MARK: - Bird

private struct FlyingBird: View {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fly = false

    var body: some View {
        GeometryReader { proxy in
            Image(systemName: "bird.fill")
                .font(.title)
                .foregroundStyle(ForestTheme.Colors.peach)
                .offset(
                    x: fly ? proxy.size.width + 60 : -60,
                    y: proxy.size.height * 0.22 + (fly ? -30 : 10)
                )
                .animation(
                    reduceMotion ? nil :
                        .easeInOut(duration: 12).repeatForever(autoreverses: false).delay(delay),
                    value: fly
                )
        }
        .onAppear { if !reduceMotion { fly = true } }
    }
}

// MARK: - Butterfly

struct ButterflySprite: View {
    let seed: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate + Double(seed) * 13
                Text("🦋")
                    .font(.title2)
                    .position(
                        x: 100 + CGFloat(sin(t * 0.4) * 120 + cos(t * 0.9) * 40) + CGFloat(seed * 60),
                        y: 220 + CGFloat(cos(t * 0.5) * 90 + sin(t * 1.3) * 25)
                    )
                    .rotationEffect(.degrees(sin(t * 2) * 12))
            }
            .allowsHitTesting(false)
        }
    }
}
