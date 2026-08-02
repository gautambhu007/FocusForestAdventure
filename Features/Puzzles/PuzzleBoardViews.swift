//
//  PuzzleBoardViews.swift
//  Focus Forest Adventure
//
//  The one renderer every puzzle kind shares: a legend (optional), a grid of
//  tiles, and a row of answer chips. Adding a generator recipe never needs a
//  new view — that's the whole point of `PuzzleKind` being data.
//

import SwiftUI

// MARK: - Glyph

struct PuzzleGlyphView: View {
    let glyph: PuzzleGlyph
    var size: CGFloat = 44
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch glyph.motif {
            case .shape(let symbol):
                Image(systemName: symbol.systemImage)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(
                        ForestTheme.Colors.gameColor(
                            glyph.color,
                            colorBlindMode: appState.settings.isColorBlindModeEnabled
                        )
                    )
                    // Pale colors (white, yellow) need an edge to stay visible
                    // on a light card — color is never the only signal.
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
            case .picture(let emoji, _):
                // Story pictures carry their own color; they're never tinted.
                Text(emoji)
                    .font(.system(size: size * 0.86))
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(glyph.rotation))
        .accessibilityLabel(glyph.accessibilityLabel)
    }
}

// MARK: - Pipe

/// Arms reaching from the middle of a cell to whichever sides the pipe opens
/// onto. Drawn rather than glyphed, so a turn animates instead of popping.
struct PipeShape: Shape {
    let connections: PipeConnections

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let middle = CGPoint(x: rect.midX, y: rect.midY)
        for side in PipeConnections.all where connections.contains(side) {
            path.move(to: middle)
            switch side {
            case .north: path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            case .south: path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            case .east:  path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            case .west:  path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            default: break
            }
        }
        return path
    }
}

struct PipeTileView: View {
    let connections: PipeConnections
    var side: CGFloat = 72
    /// Water has reached this pipe.
    var isFlowing: Bool = false

    var body: some View {
        ZStack {
            PipeShape(connections: connections)
                .stroke(color, style: StrokeStyle(lineWidth: side * 0.2,
                                                  lineCap: .round, lineJoin: .round))
            // A hub dot keeps corners from looking like two loose arms.
            Circle()
                .fill(color)
                .frame(width: side * 0.26, height: side * 0.26)
        }
        .frame(width: side, height: side)
        .animation(.bouncy(duration: 0.25), value: connections)
        .accessibilityHidden(true)
    }

    private var color: Color {
        isFlowing ? ForestTheme.Colors.skyBlue : ForestTheme.Colors.deepGreen.opacity(0.35)
    }
}

// MARK: - Block

/// A little grid of filled and empty squares — the answer chips for
/// block-rotation puzzles.
struct PuzzlePatternView: View {
    let pattern: PuzzlePattern
    var cellSide: CGFloat = 18
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<pattern.rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<pattern.columns, id: \.self) { column in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(pattern.isFilled(row: row, column: column) ? fill : empty)
                            .frame(width: cellSide, height: cellSide)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pattern.accessibilityLabel)
    }

    private var fill: Color {
        ForestTheme.Colors.gameColor(
            pattern.color,
            colorBlindMode: appState.settings.isColorBlindModeEnabled
        )
    }

    private var empty: Color { ForestTheme.Colors.deepGreen.opacity(0.1) }
}

// MARK: - Tile

struct PuzzleTileView: View {
    let tile: PuzzleTile
    var side: CGFloat = 72
    var isSelected: Bool = false
    var isRevealed: Bool = false
    /// Memory puzzles: the board has been covered and this tile's contents
    /// are now hidden.
    var isCovered: Bool = false
    /// Hidden-object puzzles: this one has already been found.
    var isFound: Bool = false
    /// Maze puzzles: this cell is part of the route walked so far.
    var isOnPath: Bool = false
    /// Maze puzzles: the child is standing here.
    var isCurrentStep: Bool = false
    /// Assembly puzzles: the right piece has been dropped in here.
    var isFilledSlot: Bool = false
    /// Pipe puzzles: the water has reached this tile.
    var isFlowing: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(background)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(borderColor, style: StrokeStyle(lineWidth: strokeWidth,
                                                                     dash: showsQuestionMark ? [6, 4] : []))
                )

            if let pipe = tile.pipe {
                ZStack {
                    PipeTileView(connections: pipe, side: side, isFlowing: isFlowing)
                    // The tap and the far end are labelled so it's obvious
                    // which way the water is meant to travel.
                    switch tile.role {
                    case .start: endMarker("🚰")
                    case .goal: endMarker(isFlowing ? "🌊" : "🪣")
                    default: EmptyView()
                    }
                }
            } else if tile.role == .slot {
                // A slot shows the shape it wants as a faint silhouette, then
                // the real thing once the piece lands.
                if let glyph = tile.glyph {
                    PuzzleGlyphView(glyph: glyph, size: side * 0.55)
                        .opacity(isFilledSlot ? 1 : 0.22)
                        .grayscale(isFilledSlot ? 0 : 1)
                }
            } else if tile.role != .plain || isOnPath {
                mazeContent
            } else if isCovered {
                // The lid. Marked cells stay marked so the child knows which
                // one the question is about.
                Text(tile.isTarget ? "?" : "🔒")
                    .font(.system(size: side * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(tile.isTarget ? 0.55 : 0.35))
            } else if let glyph = tile.glyph {
                PuzzleGlyphView(glyph: glyph, size: side * 0.55)
                    .opacity(isFound ? 0.45 : 1)
                    .overlay(alignment: .topTrailing) {
                        if isFound {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: side * 0.26))
                                .foregroundStyle(ForestTheme.Colors.leafGreen)
                        }
                    }
            } else if let text = tile.text {
                Text(text)
                    .font(.system(size: side * 0.44, weight: .heavy, design: .rounded))
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
            } else if tile.isTarget {
                Text("?")
                    .font(.system(size: side * 0.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.5))
            }
        }
        .frame(width: side, height: side)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// The tap / bucket badge on a pipe run's two ends.
    private func endMarker(_ emoji: String) -> some View {
        Text(emoji)
            .font(.system(size: side * 0.34))
            .padding(3)
            .background(ForestTheme.Colors.cloudWhite.opacity(0.9), in: Circle())
    }

    /// Maze cells: the danger, the goal, the key, and a footprint trail
    /// behind the child so the route so far is always visible.
    @ViewBuilder
    private var mazeContent: some View {
        switch tile.role {
        case .hazard:
            if let glyph = tile.glyph {
                PuzzleGlyphView(glyph: glyph, size: side * 0.5)
            } else {
                Text("🚫").font(.system(size: side * 0.45))
            }
        case .goal:
            Text(isOnPath ? "🎉" : "🏆").font(.system(size: side * 0.5))
        case .key:
            Text(isOnPath ? "✅" : "🔑").font(.system(size: side * 0.5))
        case .start:
            Text(isCurrentStep ? "🧒" : "🏁").font(.system(size: side * 0.5))
        case .plain:
            if isCurrentStep {
                Text("🧒").font(.system(size: side * 0.5))
            } else if isOnPath {
                Text("•")
                    .font(.system(size: side * 0.6, weight: .black, design: .rounded))
                    .foregroundStyle(ForestTheme.Colors.leafGreen)
            }
        case .slot:
            // Slots are drawn by the assembly branch above, never here.
            EmptyView()
        }
    }

    private var strokeWidth: CGFloat {
        if isCurrentStep { return 4 }
        if tile.role == .slot { return isFilledSlot ? 2 : 3 }
        return tile.isTarget ? 3 : 1
    }

    private var showsQuestionMark: Bool {
        if tile.role == .slot { return !isFilledSlot }
        return tile.isTarget && !isRevealed && !isFound && tile.role == .plain
    }

    private var accessibilityLabel: String {
        if let pipe = tile.pipe {
            let place = switch tile.role {
            case .start: String(localized: "the tap")
            case .goal: String(localized: "the bucket")
            default: String(localized: "pipe")
            }
            let flow = isFlowing
                ? String(localized: "water flowing")
                : String(localized: "no water yet")
            return "\(place), \(pipe.localizedName), \(flow)"
        }
        if isCovered {
            return tile.isTarget
                ? String(localized: "covered, the cell in question")
                : String(localized: "covered")
        }
        if tile.role == .slot {
            let wanted = tile.glyph?.accessibilityLabel ?? String(localized: "a piece")
            return isFilledSlot
                ? String(localized: "\(wanted), placed")
                : String(localized: "empty space for \(wanted)")
        }
        if isCurrentStep { return String(localized: "\(tile.accessibilityLabel), you are here") }
        if isOnPath { return String(localized: "\(tile.accessibilityLabel), already walked") }
        if isFound { return String(localized: "\(tile.accessibilityLabel), found") }
        return tile.accessibilityLabel
    }

    private var background: Color {
        if tile.role == .slot {
            return isFilledSlot
                ? ForestTheme.Colors.leafGreen.opacity(0.3)
                : ForestTheme.Colors.cloudWhite.opacity(0.6)
        }
        if tile.role == .hazard { return ForestTheme.Colors.peach.opacity(0.45) }
        if isCurrentStep { return ForestTheme.Colors.sunshine.opacity(0.55) }
        if isOnPath { return ForestTheme.Colors.leafGreen.opacity(0.3) }
        if isFound { return ForestTheme.Colors.leafGreen.opacity(0.25) }
        if isCovered { return ForestTheme.Colors.lavender.opacity(0.35) }
        if tile.isEmpty && !tile.isTarget { return ForestTheme.Colors.cloudWhite.opacity(0.35) }
        return isSelected
            ? ForestTheme.Colors.sunshine.opacity(0.45)
            : ForestTheme.Colors.cloudWhite
    }

    private var borderColor: Color {
        if isCurrentStep { return ForestTheme.Colors.deepGreen.opacity(0.8) }
        return tile.isTarget ? ForestTheme.Colors.deepGreen.opacity(0.6) : .black.opacity(0.08)
    }
}

// MARK: - Grid

struct PuzzleGridView: View {
    let grid: PuzzleGrid
    /// Non-nil in the tap-the-board puzzles (`.tapTile`, `.tapMany`).
    var onTapTile: ((PuzzleTile) -> Void)?
    var shakingID: UUID?
    var solvedGlyph: PuzzleGlyph?
    /// Memory puzzles: the peek is over and the board is face down.
    var isCovered: Bool = false
    /// Hidden-object puzzles: tiles already found.
    var foundIDs: Set<UUID> = []
    /// Maze puzzles: the route walked so far, in order.
    var path: [UUID] = []
    /// Assembly puzzles: slots that already hold their piece.
    var filledSlotIDs: Set<UUID> = []
    /// Pipe puzzles: tiles the water has reached.
    var floodedIDs: Set<UUID> = []

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 10
            let available = proxy.size.width - spacing * CGFloat(grid.columns - 1)
            let side = min(max(available / CGFloat(max(grid.columns, 1)), 36), 88)

            VStack(spacing: spacing) {
                ForEach(0..<grid.rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<grid.columns, id: \.self) { column in
                            if let tile = grid.tile(row: row, column: column) {
                                tileView(tile, side: side)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: boardHeight)
    }

    /// Keeps the board from pushing the answer chips off screen on small phones.
    private var boardHeight: CGFloat {
        CGFloat(grid.rows) * 88 + CGFloat(max(0, grid.rows - 1)) * 10
    }

    @ViewBuilder
    private func tileView(_ tile: PuzzleTile, side: CGFloat) -> some View {
        // The solved answer drops into the target tile so the child sees the
        // completed pattern before moving on.
        let filled = (tile.isTarget && solvedGlyph != nil)
            ? PuzzleTile(id: tile.id, glyph: solvedGlyph, isTarget: true)
            : tile
        // Once the answer is revealed the cover comes off, so the child sees
        // what was hiding there.
        let covered = isCovered && solvedGlyph == nil

        if let onTapTile {
            Button { onTapTile(tile) } label: {
                PuzzleTileView(tile: filled, side: side,
                               isRevealed: solvedGlyph != nil,
                               isCovered: covered,
                               isFound: foundIDs.contains(tile.id))
            }
            .buttonStyle(SquishyButtonStyle())
            .gentleShake(trigger: shakingID == tile.id)
        } else {
            PuzzleTileView(tile: filled, side: side,
                           isRevealed: solvedGlyph != nil,
                           isCovered: covered,
                           isFound: foundIDs.contains(tile.id),
                           isOnPath: path.contains(tile.id),
                           isCurrentStep: path.last == tile.id,
                           isFilledSlot: filledSlotIDs.contains(tile.id),
                           isFlowing: floodedIDs.contains(tile.id))
                .gentleShake(trigger: shakingID == tile.id)
        }
    }
}

// MARK: - Legend

struct PuzzleLegendView: View {
    let entries: [PuzzleLegendEntry]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(entries) { entry in
                HStack(spacing: 10) {
                    ForEach(Array(entry.inputs.enumerated()), id: \.offset) { _, glyph in
                        PuzzleGlyphView(glyph: glyph, size: 26)
                    }
                    Text("=")
                        .font(ForestTheme.Fonts.body)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                    PuzzleGlyphView(glyph: entry.result, size: 26)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(ForestTheme.Colors.cloudWhite.opacity(0.85))
                .clipShape(Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(entry.accessibilityLabel)
            }
        }
    }
}

// MARK: - Options

struct PuzzleOptionsView: View {
    let options: [PuzzleOption]
    let onTap: (PuzzleOption) -> Void
    var shakingID: UUID?
    var isLocked: Bool

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 96, maximum: 160), spacing: 14)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(options) { option in
                Button { onTap(option) } label: {
                    optionLabel(option)
                }
                .buttonStyle(SquishyButtonStyle())
                .disabled(isLocked)
                .gentleShake(trigger: shakingID == option.id)
                .accessibilityLabel(option.accessibilityLabel)
            }
        }
    }

    @ViewBuilder
    private func optionLabel(_ option: PuzzleOption) -> some View {
        Group {
            if let pattern = option.pattern {
                PuzzlePatternView(pattern: pattern, cellSide: 18)
            } else if let glyph = option.glyph {
                PuzzleGlyphView(glyph: glyph, size: 52)
            } else {
                Text(option.text ?? "")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: ForestTheme.Metrics.minChildTapTarget + 24)
        .background(ForestTheme.Colors.cloudWhite)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
    }
}
