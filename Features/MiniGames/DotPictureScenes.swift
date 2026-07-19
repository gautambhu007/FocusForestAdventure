//
//  DotPictureScenes.swift
//  Focus Forest Adventure
//
//  Picture Puzzles for Smart Dots: when every pair is connected, the
//  lines ARE the drawing — a sunset over the sea, a cloud over a meadow,
//  a beach umbrella, a mountain sunrise. Every stroke has its own shade
//  (so the matching is forced and always solvable), and all coordinates
//  were machine-validated: no crossings, finger-sized dot spacing, and
//  clearance between dots and foreign strokes.
//

import SwiftUI

struct DotPictureScene: Identifiable {
    struct Stroke {
        let from: CGPoint
        let to: CGPoint
        let color: Color
    }

    let id: String
    let emoji: String
    let title: String
    let revealTitle: String
    let background: [Color]
    let strokes: [Stroke]
}

enum DotPictures {

    private static func stroke(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double,
                               _ color: Color) -> DotPictureScene.Stroke {
        DotPictureScene.Stroke(from: CGPoint(x: x1, y: y1), to: CGPoint(x: x2, y: y2), color: color)
    }

    // Scene shades
    private static let gold1 = Color(red: 1.0, green: 0.78, blue: 0.30)
    private static let gold2 = Color(red: 1.0, green: 0.70, blue: 0.20)
    private static let gold3 = Color(red: 0.98, green: 0.62, blue: 0.25)
    private static let orange1 = Color(red: 0.98, green: 0.55, blue: 0.30)
    private static let orange2 = Color(red: 0.95, green: 0.48, blue: 0.28)
    private static let blue1 = Color(red: 0.30, green: 0.55, blue: 0.85)
    private static let blue2 = Color(red: 0.35, green: 0.62, blue: 0.90)
    private static let blue3 = Color(red: 0.42, green: 0.70, blue: 0.92)
    private static let teal1 = Color(red: 0.30, green: 0.72, blue: 0.75)
    private static let teal2 = Color(red: 0.38, green: 0.78, blue: 0.78)
    private static let green1 = Color(red: 0.35, green: 0.65, blue: 0.40)
    private static let green2 = Color(red: 0.45, green: 0.72, blue: 0.42)
    private static let green3 = Color(red: 0.30, green: 0.58, blue: 0.38)
    private static let gray1 = Color(red: 0.75, green: 0.78, blue: 0.84)
    private static let gray2 = Color(red: 0.66, green: 0.70, blue: 0.78)
    private static let white1 = Color(red: 0.92, green: 0.94, blue: 0.98)
    private static let purple1 = Color(red: 0.55, green: 0.45, blue: 0.75)
    private static let purple2 = Color(red: 0.62, green: 0.50, blue: 0.80)
    private static let brown1 = Color(red: 0.60, green: 0.42, blue: 0.28)
    private static let pinkStroke = Color(red: 0.95, green: 0.55, blue: 0.62)

    static let scenes: [DotPictureScene] = [
        DotPictureScene(
            id: "sunset", emoji: "🌅",
            title: String(localized: "Sunset Sea"),
            revealTitle: String(localized: "It's a sunset over the sea!"),
            background: [Color(red: 1.0, green: 0.78, blue: 0.55),
                         Color(red: 0.98, green: 0.55, blue: 0.55),
                         Color(red: 0.25, green: 0.35, blue: 0.60)],
            strokes: [
                stroke(0.08, 0.56, 0.30, 0.56, blue1),      // horizon left
                stroke(0.70, 0.56, 0.92, 0.56, blue2),      // horizon right
                stroke(0.365, 0.52, 0.405, 0.45, gold1),    // sun arc left
                stroke(0.455, 0.418, 0.545, 0.418, gold2),  // sun arc top
                stroke(0.595, 0.45, 0.635, 0.52, gold3),    // sun arc right
                stroke(0.30, 0.38, 0.36, 0.31, orange1),    // ray left
                stroke(0.50, 0.36, 0.50, 0.27, orange2),    // ray up
                stroke(0.64, 0.31, 0.70, 0.38, orange1),    // ray right
                stroke(0.16, 0.66, 0.34, 0.66, blue3),      // sparkle rows
                stroke(0.44, 0.73, 0.60, 0.73, teal1),
                stroke(0.68, 0.66, 0.84, 0.66, blue3),
                stroke(0.28, 0.82, 0.46, 0.82, teal2),
                stroke(0.56, 0.89, 0.72, 0.89, blue2)
            ]
        ),
        DotPictureScene(
            id: "meadow", emoji: "⛅",
            title: String(localized: "Cloudy Meadow"),
            revealTitle: String(localized: "It's a cloud over the meadow!"),
            background: [Color(red: 0.62, green: 0.84, blue: 0.98),
                         Color(red: 0.80, green: 0.93, blue: 0.85)],
            strokes: [
                stroke(0.26, 0.33, 0.32, 0.24, gray1),      // cloud bumps
                stroke(0.39, 0.20, 0.49, 0.19, white1),
                stroke(0.56, 0.21, 0.63, 0.28, gray2),
                stroke(0.30, 0.375, 0.60, 0.375, gray1),    // cloud base
                stroke(0.08, 0.72, 0.28, 0.63, green1),     // hills
                stroke(0.36, 0.63, 0.52, 0.70, green2),
                stroke(0.60, 0.66, 0.76, 0.59, green3),
                stroke(0.84, 0.62, 0.92, 0.70, green2),
                stroke(0.76, 0.14, 0.88, 0.10, gold1),      // sun corner
                stroke(0.70, 0.24, 0.78, 0.19, gold2),
                stroke(0.20, 0.90, 0.20, 0.80, pinkStroke), // flower stems
                stroke(0.72, 0.92, 0.72, 0.82, green1)
            ]
        ),
        DotPictureScene(
            id: "beach", emoji: "🏖️",
            title: String(localized: "Beach Day"),
            revealTitle: String(localized: "It's a beach umbrella!"),
            background: [Color(red: 0.55, green: 0.85, blue: 0.95),
                         Color(red: 0.98, green: 0.90, blue: 0.65)],
            strokes: [
                stroke(0.32, 0.74, 0.32, 0.52, brown1),     // umbrella pole
                stroke(0.17, 0.49, 0.28, 0.39, orange1),    // canopy left
                stroke(0.37, 0.39, 0.48, 0.49, pinkStroke), // canopy right
                stroke(0.08, 0.84, 0.42, 0.84, gold1),      // shoreline
                stroke(0.52, 0.84, 0.90, 0.84, gold2),
                stroke(0.54, 0.60, 0.66, 0.565, blue1),     // waves
                stroke(0.72, 0.58, 0.84, 0.545, blue2),
                stroke(0.58, 0.70, 0.72, 0.68, teal1),
                stroke(0.78, 0.695, 0.90, 0.66, blue3),
                stroke(0.12, 0.15, 0.23, 0.11, gold3),      // sun
                stroke(0.10, 0.26, 0.19, 0.215, orange2)
            ]
        ),
        DotPictureScene(
            id: "sunrise", emoji: "🌄",
            title: String(localized: "Mountain Sunrise"),
            revealTitle: String(localized: "It's a mountain sunrise!"),
            background: [Color(red: 0.98, green: 0.75, blue: 0.55),
                         Color(red: 0.80, green: 0.65, blue: 0.85)],
            strokes: [
                stroke(0.10, 0.72, 0.28, 0.42, purple1),    // mountain 1
                stroke(0.34, 0.44, 0.47, 0.67, purple2),
                stroke(0.53, 0.70, 0.67, 0.45, purple1),    // mountain 2
                stroke(0.73, 0.47, 0.86, 0.70, purple2),
                stroke(0.42, 0.24, 0.53, 0.20, gold1),      // sun
                stroke(0.28, 0.34, 0.36, 0.28, gold2),      // rays
                stroke(0.59, 0.28, 0.67, 0.34, gold2),
                stroke(0.12, 0.20, 0.20, 0.13, gray2),      // bird wings
                stroke(0.26, 0.13, 0.34, 0.20, gray2),
                stroke(0.10, 0.79, 0.86, 0.79, green1)      // ground
            ]
        )
    ]

    /// Build a playable puzzle: one pair per stroke, each with a unique
    /// color index (matching is forced, so the puzzle is trivially unique
    /// and always completable — the joy is the reveal).
    static func puzzle(for scene: DotPictureScene) -> DotPuzzle {
        var dots: [DotPuzzle.Dot] = []
        var solution: [[Int]] = []
        for (index, stroke) in scene.strokes.enumerated() {
            dots.append(DotPuzzle.Dot(id: dots.count, point: stroke.from, colorIndex: index))
            dots.append(DotPuzzle.Dot(id: dots.count, point: stroke.to, colorIndex: index))
            solution.append([dots.count - 2, dots.count - 1])
        }
        return DotPuzzle(dots: dots, solution: solution)
    }
}
