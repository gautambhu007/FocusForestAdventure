//
//  ForestTheme.swift
//  Focus Forest Adventure
//
//  Design tokens: pastel palette, rounded typography, gradients.
//  Color-blind-safe alternates are provided for game-critical colors.
//

import SwiftUI
import UIKit

enum ForestTheme {

    // MARK: Colors

    enum Colors {
        /// Dynamic color: pastel daytime palette in light mode, a calm
        /// "forest at night" palette in dark mode. Centralizing adaptivity
        /// here means every screen inherits night mode automatically.
        private static func adaptive(
            light: (Double, Double, Double),
            dark: (Double, Double, Double)
        ) -> Color {
            Color(UIColor { traits in
                let (r, g, b) = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(red: r, green: g, blue: b, alpha: 1)
            })
        }

        /// Primary text/ink: deep green by day, soft mint by night.
        static let deepGreen   = adaptive(light: (0.13, 0.42, 0.30), dark: (0.72, 0.92, 0.80))
        static let leafGreen   = adaptive(light: (0.55, 0.80, 0.55), dark: (0.42, 0.68, 0.46))
        /// Large surface tint: pale mint by day, deep moss by night.
        static let mint        = adaptive(light: (0.78, 0.93, 0.82), dark: (0.13, 0.24, 0.18))
        static let sunshine    = adaptive(light: (1.00, 0.80, 0.35), dark: (0.95, 0.72, 0.30))
        static let peach       = adaptive(light: (1.00, 0.72, 0.58), dark: (0.62, 0.40, 0.34))
        static let bubblegum   = adaptive(light: (0.98, 0.62, 0.75), dark: (0.60, 0.34, 0.45))
        /// Sky: daylight blue by day, dusk navy by night (gradients inherit).
        static let skyBlue     = adaptive(light: (0.62, 0.84, 0.98), dark: (0.15, 0.22, 0.36))
        static let lavender    = adaptive(light: (0.78, 0.72, 0.95), dark: (0.36, 0.32, 0.52))
        /// Card surface: warm white by day, dark green-gray by night.
        static let cloudWhite  = adaptive(light: (0.98, 0.98, 0.96), dark: (0.15, 0.19, 0.17))
        static let soil        = Color(red: 0.55, green: 0.42, blue: 0.30)
        /// Card edge highlight (forestCard border).
        static let cardStroke  = adaptive(light: (1.0, 1.0, 1.0), dark: (0.35, 0.45, 0.40))

        /// Game colors with color-blind-safe variants (distinct luminance + shape pairing).
        /// Deliberately FIXED (non-adaptive): these teach color names, so
        /// "blue" must look blue in night mode too.
        static func gameColor(_ name: GameColor, colorBlindMode: Bool) -> Color {
            switch (name, colorBlindMode) {
            case (.red, false):    return Color(red: 0.95, green: 0.45, blue: 0.42)
            case (.red, true):     return Color(red: 0.80, green: 0.25, blue: 0.20)
            case (.blue, _):       return Color(red: 0.62, green: 0.84, blue: 0.98)
            case (.green, false):  return Color(red: 0.55, green: 0.80, blue: 0.55)
            case (.green, true):   return Color(red: 0.00, green: 0.62, blue: 0.45)   // teal-green
            case (.yellow, _):     return Color(red: 1.00, green: 0.80, blue: 0.35)
            case (.purple, _):     return Color(red: 0.78, green: 0.72, blue: 0.95)
            case (.pink, _):       return Color(red: 0.98, green: 0.62, blue: 0.75)
            case (.orange, _):     return Color(red: 1.00, green: 0.60, blue: 0.20)
            case (.brown, _):      return Color(red: 0.58, green: 0.42, blue: 0.25)
            case (.black, _):      return Color(red: 0.16, green: 0.16, blue: 0.18)
            case (.white, _):      return Color(red: 0.98, green: 0.98, blue: 0.96)
            }
        }
    }

    enum GameColor: String, CaseIterable, Codable, Sendable {
        case red, blue, green, yellow, purple, pink, orange, brown, black, white

        /// Every game color is paired with a symbol so color is never the only signal.
        var accessibilitySymbol: String {
            switch self {
            case .red: "heart.fill"
            case .blue: "drop.fill"
            case .green: "leaf.fill"
            case .yellow: "sun.max.fill"
            case .purple: "moon.stars.fill"
            case .pink: "star.fill"
            case .orange: "carrot.fill"
            case .brown: "pawprint.fill"
            case .black: "moon.fill"
            case .white: "snowflake"
            }
        }

        var localizedName: String {
            switch self {
            case .red: String(localized: "Red")
            case .blue: String(localized: "Blue")
            case .green: String(localized: "Green")
            case .yellow: String(localized: "Yellow")
            case .purple: String(localized: "Purple")
            case .pink: String(localized: "Pink")
            case .orange: String(localized: "Orange")
            case .brown: String(localized: "Brown")
            case .black: String(localized: "Black")
            case .white: String(localized: "White")
            }
        }

        /// Foreground that stays readable on top of this color
        /// (white symbols vanish on white/yellow cards).
        var contrastingForeground: Color {
            switch self {
            case .white, .yellow: Color.black.opacity(0.65)
            default: .white
            }
        }
    }

    // MARK: Gradients

    enum Gradients {
        static let morningSky = LinearGradient(
            colors: [Colors.skyBlue.opacity(0.8), Colors.mint, Colors.cloudWhite],
            startPoint: .top, endPoint: .bottom
        )
        static let meadow = LinearGradient(
            colors: [Colors.leafGreen, Colors.mint],
            startPoint: .top, endPoint: .bottom
        )
        static let sunset = LinearGradient(
            colors: [Colors.peach, Colors.bubblegum.opacity(0.7), Colors.lavender.opacity(0.6)],
            startPoint: .top, endPoint: .bottom
        )
        static let magic = LinearGradient(
            colors: [Colors.lavender, Colors.skyBlue, Colors.mint],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: Typography
    // SF Rounded everywhere; sizes are generous for small hands & early readers.
    // All fonts scale with Dynamic Type via relativeTo.

    enum Fonts {
        static let hero    = Font.system(size: 40, weight: .heavy, design: .rounded)
        static let title   = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let heading = Font.system(.title2, design: .rounded).weight(.bold)
        static let body    = Font.system(.title3, design: .rounded).weight(.semibold)
        static let caption = Font.system(.body, design: .rounded).weight(.medium)
        static let giant   = Font.system(size: 88, weight: .heavy, design: .rounded)
    }

    // MARK: Metrics

    enum Metrics {
        /// Minimum tap target for children (HIG minimum is 44pt; we use 64pt for ages 4–6).
        static let minChildTapTarget: CGFloat = 64
        static let cardCornerRadius: CGFloat = 28
        static let screenPadding: CGFloat = 20
    }
}
