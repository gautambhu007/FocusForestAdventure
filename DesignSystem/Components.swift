//
//  Components.swift
//  Focus Forest Adventure
//
//  Reusable design-system components: buttons, cards, progress, speech bubbles.
//

import SwiftUI

// MARK: - BigBouncyButton
// The primary interactive element. Huge tap target, bouncy press, voice-over ready.

struct BigBouncyButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = ForestTheme.Colors.leafGreen
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.title2.weight(.bold))
                }
                Text(title)
                    .font(ForestTheme.Fonts.heading)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 36)
            .frame(minHeight: ForestTheme.Metrics.minChildTapTarget)
            .background(
                Capsule()
                    .fill(color.gradient)
                    .shadow(color: color.opacity(0.5), radius: 10, y: 6)
            )
            .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 2))
        }
        .buttonStyle(SquishyButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

struct SquishyButtonStyle: ButtonStyle {
    var reduceMotion = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.9 : 1)
            .animation(.bouncy(duration: 0.3), value: configuration.isPressed)
    }
}

// MARK: - AdventureCard
// Rounded pastel card used on the adventure-select screen.

struct AdventureCard: View {
    let adventure: AdventureKind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Text(adventure.emoji)
                    .font(.system(size: 56))
                    .floating(amplitude: 4, period: 2.0)
                Text(adventure.localizedTitle)
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(adventure.tint.opacity(0.35))
            .forestCard()
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel(String(localized: "\(adventure.localizedTitle) adventure"))
        .accessibilityHint(String(localized: "Starts a \(adventure.localizedTitle) mission"))
    }
}

// MARK: - ForestProgressBar
// A vine that grows and blooms as the child progresses. No numbers for the child.

struct ForestProgressBar: View {
    /// 0...1
    let progress: Double
    var label: String = String(localized: "Today's adventure")

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(ForestTheme.Fonts.caption)
                .foregroundStyle(ForestTheme.Colors.deepGreen)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ForestTheme.Colors.mint.opacity(0.6))

                    Capsule()
                        .fill(ForestTheme.Gradients.meadow)
                        .frame(width: max(24, proxy.size.width * progress))
                        .animation(.bouncy(duration: 0.8), value: progress)

                    Text("🌱")
                        .font(.title3)
                        .offset(x: max(0, proxy.size.width * progress - 26))
                        .animation(.bouncy(duration: 0.8), value: progress)
                }
            }
            .frame(height: 26)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(String(localized: "\(Int(progress * 100)) percent complete"))
    }
}

// MARK: - SpeechBubble

struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(ForestTheme.Fonts.body)
            .foregroundStyle(ForestTheme.Colors.deepGreen)
            .multilineTextAlignment(.center)
            .padding(20)
            .forestCard(cornerRadius: 24)
            .padding(.horizontal, 32)
    }
}

// MARK: - StarCounter

struct StarCounter: View {
    let count: Int
    @State private var pop = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .foregroundStyle(ForestTheme.Colors.sunshine)
                .scaleEffect(pop ? 1.4 : 1)
            Text("\(count)")
                .font(ForestTheme.Fonts.body)
                .contentTransition(.numericText())
                .foregroundStyle(ForestTheme.Colors.deepGreen)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .forestCard(cornerRadius: 20)
        .onChange(of: count) {
            withAnimation(.bouncy(duration: 0.35)) { pop = true }
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.bouncy) { pop = false }
            }
        }
        .accessibilityLabel(String(localized: "\(count) stars collected"))
    }
}
