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

// MARK: - Tile

struct PuzzleTileView: View {
    let tile: PuzzleTile
    var side: CGFloat = 72
    var isSelected: Bool = false
    var isRevealed: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(background)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(borderColor, style: StrokeStyle(lineWidth: tile.isTarget ? 3 : 1,
                                                                     dash: tile.isTarget && !isRevealed ? [6, 4] : []))
                )

            if let glyph = tile.glyph {
                PuzzleGlyphView(glyph: glyph, size: side * 0.55)
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
        .accessibilityLabel(tile.accessibilityLabel)
    }

    private var background: Color {
        if tile.isEmpty && !tile.isTarget { return ForestTheme.Colors.cloudWhite.opacity(0.35) }
        return isSelected
            ? ForestTheme.Colors.sunshine.opacity(0.45)
            : ForestTheme.Colors.cloudWhite
    }

    private var borderColor: Color {
        tile.isTarget ? ForestTheme.Colors.deepGreen.opacity(0.6) : .black.opacity(0.08)
    }
}

// MARK: - Grid

struct PuzzleGridView: View {
    let grid: PuzzleGrid
    /// Non-nil only in `.tapTile` puzzles.
    var onTapTile: ((PuzzleTile) -> Void)?
    var shakingID: UUID?
    var solvedGlyph: PuzzleGlyph?

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

        if let onTapTile {
            Button { onTapTile(tile) } label: {
                PuzzleTileView(tile: filled, side: side, isRevealed: solvedGlyph != nil)
            }
            .buttonStyle(SquishyButtonStyle())
            .gentleShake(trigger: shakingID == tile.id)
        } else {
            PuzzleTileView(tile: filled, side: side, isRevealed: solvedGlyph != nil)
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
            if let glyph = option.glyph {
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
