//
//  View+Forest.swift
//  Focus Forest Adventure
//
//  Small, reusable view modifiers used across the app.
//

import SwiftUI

extension View {

    /// Tiny bounce on every tap — the whole app should feel squishy and alive.
    func tapBounce(scale: CGFloat = 0.92) -> some View {
        modifier(TapBounceModifier(pressedScale: scale))
    }

    /// Rounded glass card treatment used for all cards in the app.
    func forestCard(cornerRadius: CGFloat = 28) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            // Two layers: a solid tint to guarantee contrast against the
            // painted forest behind, then the material for depth. Thin
            // material alone let tree trunks and leaves show through
            // enough to muddy small text.
            .background(ForestTheme.Colors.cloudWhite.opacity(0.72), in: shape)
            .background(.regularMaterial, in: shape)
            .overlay(
                shape.strokeBorder(ForestTheme.Colors.cardStroke.opacity(0.65), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
    }

    /// Gentle floating (used for butterflies, clouds, chest). Respects Reduce Motion.
    func floating(amplitude: CGFloat = 8, period: Double = 2.4) -> some View {
        modifier(FloatingModifier(amplitude: amplitude, period: period))
    }

    /// A soft, friendly "not quite" shake. Never harsh — small offsets, slow spring.
    func gentleShake(trigger: Bool) -> some View {
        modifier(GentleShakeModifier(trigger: trigger))
    }

    /// Keeps interactive content at a comfortable width on iPad (centered),
    /// while staying full-width on iPhone. Backgrounds still fill the screen.
    func adaptiveContentWidth(_ maxWidth: CGFloat = 760) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Modifiers

private struct TapBounceModifier: ViewModifier {
    let pressedScale: CGFloat
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? pressedScale : 1)
            .animation(.bouncy(duration: 0.3), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

private struct FloatingModifier: ViewModifier {
    let amplitude: CGFloat
    let period: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: reduceMotion ? 0 : (up ? -amplitude : amplitude))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: period).repeatForever(autoreverses: true)) {
                    up = true
                }
            }
    }
}

private struct GentleShakeModifier: ViewModifier {
    let trigger: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(x: trigger && !reduceMotion ? 6 : 0)
            .animation(
                trigger ? .spring(response: 0.15, dampingFraction: 0.25) : .default,
                value: trigger
            )
    }
}

// MARK: - Date helpers

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}
