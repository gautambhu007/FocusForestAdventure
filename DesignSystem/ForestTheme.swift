//
//  ForestTheme.swift
//  Focus Forest Adventure
//
//  Design tokens: pastel palette, rounded typography, gradients.
//  Color-blind-safe alternates are provided for game-critical colors.
//

import SwiftUI

enum ForestTheme {

    // MARK: Colors

    enum Colors {
        static let deepGreen   = Color(red: 0.13, green: 0.42, blue: 0.30)
        static let leafGreen   = Color(red: 0.55, green: 0.80, blue: 0.55)
        static let mint        = Color(red: 0.78, green: 0.93, blue: 0.82)
        static let sunshine    = Color(red: 1.00, green: 0.80, blue: 0.35)
        static let peach       = Color(red: 1.00, green: 0.72, blue: 0.58)
        static let bubblegum   = Color(red: 0.98, green: 0.62, blue: 0.75)
        static let skyBlue     = Color(red: 0.62, green: 0.84, blue: 0.98)
        static let lavender    = Color(red: 0.78, green: 0.72, blue: 0.95)
        static let cloudWhite  = Color(red: 0.98, green: 0.98, blue: 0.96)
        static let soil        = Color(red: 0.55, green: 0.42, blue: 0.30)

        /// Game colors with color-blind-safe variants (distinct luminance + shape pairing).
        static func gameColor(_ name: GameColor, colorBlindMode: Bool) -> Color {
            switch (name, colorBlindMode) {
            case (.red, false):    return Color(red: 0.95, green: 0.45, blue: 0.42)
            case (.red, true):     return Color(red: 0.80, green: 0.25, blue: 0.20)
            case (.blue, _):       return skyBlue
            case (.green, false):  return leafGreen
            case (.green, true):   return Color(red: 0.00, green: 0.62, blue: 0.45)   // teal-green
            case (.yellow, _):     return sunshine
            case (.purple, _):     return lavender
            case (.pink, _):       return bubblegum
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
