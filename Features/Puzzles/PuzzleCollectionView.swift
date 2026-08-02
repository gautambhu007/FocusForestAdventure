//
//  PuzzleCollectionView.swift
//  Focus Forest Adventure
//
//  The treasure room: what a child's gems are for. Owned things are bright,
//  affordable things say their price, and things that need a crystal say
//  which one — nothing is ever hidden, because a visible goal is the point.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class PuzzleCollectionViewModel {

    private let dependencies: AppDependencies
    private(set) var snapshot = PuzzleProgressSnapshot()
    /// Set briefly after a purchase so the view can celebrate it.
    private(set) var justBought: Collectible?
    /// Set briefly when a mural is finished.
    private(set) var finishedMural: WorldMural?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var gems: Int { snapshot.gems }
    var pieces: Int { snapshot.pieces }
    var owned: Set<String> { snapshot.owned }
    var companionID: String { snapshot.companionID }

    var ownedCount: Int { snapshot.owned.count }
    var totalCount: Int { CollectibleCatalog.all.count }

    func onAppear() async {
        refresh()
        await dependencies.speechService.speak(String(localized: "Look at everything you've collected!"))
    }

    func refresh() {
        do {
            let child = try dependencies.childRepository.activeChild()
            snapshot = try dependencies.puzzleRepository.snapshot(for: child)
        } catch {
            assertionFailure("Collection load failed: \(error)")
        }
    }

    func items(_ kind: CollectibleKind) -> [Collectible] {
        CollectibleCatalog.items(of: kind)
    }

    // MARK: Murals

    /// Only worlds the child has actually visited — an untouched world's
    /// mural would just be nine blanks and a spoiler.
    var muralWorlds: [PuzzleWorld] {
        PuzzleWorld.allCases.filter {
            snapshot.completed($0) > 0 || snapshot.muralPlaced($0) > 0
        }
    }

    func mural(_ world: PuzzleWorld) -> WorldMural { MuralCatalog.mural(for: world) }
    func placed(_ world: PuzzleWorld) -> Int { snapshot.muralPlaced(world) }

    func canPlacePiece(in world: PuzzleWorld) -> Bool {
        pieces > 0 && placed(world) < WorldMural.tileCount
    }

    func placePieceTapped(in world: PuzzleWorld) async {
        guard canPlacePiece(in: world) else {
            if pieces == 0 {
                dependencies.soundEngine.play(.gentleTryAgain)
                await dependencies.speechService.speak(
                    String(localized: "Play a level to earn another puzzle piece!")
                )
            }
            return
        }
        do {
            let child = try dependencies.childRepository.activeChild()
            let placement = try dependencies.puzzleRepository.placeMuralPiece(in: world, for: child)
            guard placement.placed else { return }
            dependencies.hapticsService.playSuccess()
            dependencies.soundEngine.play(placement.completedNow ? .chestOpen : .tapPop)
            refresh()

            if placement.completedNow {
                finishedMural = mural(world)
                await dependencies.speechService.speak(
                    String(localized: "You finished the picture! \(placement.bonusGems) gems!")
                )
                try? await Task.sleep(for: .seconds(2))
                finishedMural = nil
            }
        } catch {
            assertionFailure("Mural placement failed: \(error)")
        }
    }

    func isOwned(_ item: Collectible) -> Bool { owned.contains(item.id) }
    func isAvailable(_ item: Collectible) -> Bool { item.isAvailable(crystals: snapshot.crystals) }
    func canAfford(_ item: Collectible) -> Bool { gems >= item.price }

    /// Why this item can't be bought yet, in a child's terms.
    func status(_ item: Collectible) -> String {
        if isOwned(item) { return String(localized: "Yours!") }
        guard isAvailable(item) else {
            let crystal = item.requiresCrystal?.crystal
            return String(localized: "Needs \(crystal?.localizedName ?? "a crystal")")
        }
        return "💎 \(item.price)"
    }

    func tapped(_ item: Collectible) async {
        do {
            let child = try dependencies.childRepository.activeChild()

            if isOwned(item) {
                // Owning a friend means you can bring them along.
                guard item.kind == .companion else { return }
                try dependencies.puzzleRepository.setCompanion(item.id, for: child)
                dependencies.hapticsService.playGentleTap()
                dependencies.soundEngine.play(.tapPop)
                refresh()
                await dependencies.speechService.speak(
                    String(localized: "\(item.name) is coming with you!")
                )
                return
            }

            guard isAvailable(item) else {
                dependencies.soundEngine.play(.gentleTryAgain)
                await dependencies.speechService.speak(status(item))
                return
            }
            guard canAfford(item) else {
                dependencies.soundEngine.play(.gentleTryAgain)
                await dependencies.speechService.speak(
                    String(localized: "\(item.price - gems) more gems and it's yours!")
                )
                return
            }

            let bought = try dependencies.puzzleRepository.purchase(item, for: child)
            guard bought else { return }
            dependencies.hapticsService.playSuccess()
            dependencies.soundEngine.play(.chestOpen)
            refresh()
            justBought = item
            await dependencies.speechService.speak(String(localized: "You got the \(item.name)!"))
            try? await Task.sleep(for: .seconds(1.6))
            justBought = nil
        } catch {
            assertionFailure("Collection action failed: \(error)")
        }
    }
}

struct PuzzleCollectionView: View {
    @State var viewModel: PuzzleCollectionViewModel

    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 12)]

    var body: some View {
        ZStack {
            ForestSceneBackground(place: .blossom, legibility: 0.2)

            ScrollView {
                VStack(spacing: 18) {
                    header
                    muralSection

                    ForEach(CollectibleKind.allCases, id: \.self) { kind in
                        section(kind)
                    }
                }
                .padding(ForestTheme.Metrics.screenPadding)
                .adaptiveContentWidth(900)
            }

            if let bought = viewModel.justBought {
                celebration(bought)
            }
            if let mural = viewModel.finishedMural {
                muralCelebration(mural)
            }
        }
        .navigationTitle(String(localized: "My Collection"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.onAppear() }
        .onAppear { viewModel.refresh() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                Label("\(viewModel.gems)", systemImage: "diamond.fill")
                    .foregroundStyle(ForestTheme.Colors.skyBlue)
                Label("\(viewModel.pieces)", systemImage: "puzzlepiece.fill")
                    .foregroundStyle(ForestTheme.Colors.leafGreen)
            }
            .font(ForestTheme.Fonts.body)

            Text(String(localized: "\(viewModel.ownedCount) of \(viewModel.totalCount) collected"))
                .font(ForestTheme.Fonts.caption)
                .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.8))
                .monospacedDigit()
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .forestCard(cornerRadius: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(localized: "\(viewModel.gems) gems. \(viewModel.ownedCount) of \(viewModel.totalCount) collected.")
        )
    }

    // MARK: Murals

    @ViewBuilder
    private var muralSection: some View {
        if !viewModel.muralWorlds.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "🧩 My Pictures"))
                    .font(ForestTheme.Fonts.heading)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .accessibilityAddTraits(.isHeader)

                Text(String(localized: "Every puzzle piece you place uncovers a little more."))
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.7))

                ForEach(viewModel.muralWorlds, id: \.self) { world in
                    muralCard(world)
                }
            }
        }
    }

    private func muralCard(_ world: PuzzleWorld) -> some View {
        let mural = viewModel.mural(world)
        let placed = viewModel.placed(world)
        let complete = mural.isComplete(placed)

        return HStack(spacing: 14) {
            muralGrid(mural, placed: placed)

            VStack(alignment: .leading, spacing: 6) {
                Text(mural.title)
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .lineLimit(2)
                Text("\(world.emoji) \(world.shortTitle)")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.7))

                if complete {
                    Label(String(localized: "Finished!"), systemImage: "checkmark.seal.fill")
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.leafGreen)
                } else {
                    Text("\(placed)/\(WorldMural.tileCount)")
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.8))
                        .monospacedDigit()
                    Button {
                        Task { await viewModel.placePieceTapped(in: world) }
                    } label: {
                        Label(String(localized: "Place a piece"), systemImage: "puzzlepiece.fill")
                            .font(ForestTheme.Fonts.caption)
                            .foregroundStyle(ForestTheme.Colors.deepGreen)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(ForestTheme.Colors.mint.opacity(0.7))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .disabled(!viewModel.canPlacePiece(in: world))
                    .opacity(viewModel.canPlacePiece(in: world) ? 1 : 0.5)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .forestCard(cornerRadius: 20)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            complete
                ? String(localized: "\(mural.title), finished")
                : String(localized: "\(mural.title), \(placed) of \(WorldMural.tileCount) pieces placed")
        )
    }

    private func muralGrid(_ mural: WorldMural, placed: Int) -> some View {
        let revealed = mural.revealed(placed)
        return VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { column in
                        let tile = revealed[row * 3 + column]
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(tile == nil
                                      ? ForestTheme.Colors.deepGreen.opacity(0.12)
                                      : ForestTheme.Colors.cloudWhite)
                            if let tile {
                                Text(tile).font(.system(size: 20))
                            }
                        }
                        .frame(width: 30, height: 30)
                    }
                }
            }
        }
        .padding(6)
        .background(ForestTheme.Colors.cloudWhite.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }

    private func muralCelebration(_ mural: WorldMural) -> some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 14) {
                muralGrid(mural, placed: WorldMural.tileCount)
                    .scaleEffect(1.6)
                    .padding(.bottom, 16)
                Text(mural.title)
                    .font(ForestTheme.Fonts.heading)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                Text(String(localized: "💎 \(mural.completionBonus) gems!"))
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.9))
            }
            .padding(30)
            .forestCard(cornerRadius: 26)
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    private func section(_ kind: CollectibleKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(kind.emoji) \(kind.localizedTitle)")
                .font(ForestTheme.Fonts.heading)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.items(kind)) { item in
                    itemCard(item)
                }
            }
        }
    }

    private func itemCard(_ item: Collectible) -> some View {
        let owned = viewModel.isOwned(item)
        let available = viewModel.isAvailable(item)
        let isCompanion = item.id == viewModel.companionID

        return Button {
            Task { await viewModel.tapped(item) }
        } label: {
            VStack(spacing: 6) {
                Text(item.emoji)
                    .font(.system(size: 38))
                    .opacity(owned ? 1 : (available ? 0.75 : 0.3))
                    .saturation(owned ? 1 : (available ? 0.7 : 0))
                Text(item.name)
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(viewModel.status(item))
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(statusColor(owned: owned, available: available, item: item))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .padding(.vertical, 8)
            .forestCard(cornerRadius: 18)
            .overlay(alignment: .topTrailing) {
                if isCompanion {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ForestTheme.Colors.bubblegum)
                        .padding(8)
                }
            }
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel(accessibilityLabel(item, owned: owned, isCompanion: isCompanion))
    }

    private func statusColor(owned: Bool, available: Bool, item: Collectible) -> Color {
        if owned { return ForestTheme.Colors.leafGreen }
        if !available { return ForestTheme.Colors.deepGreen.opacity(0.5) }
        return viewModel.canAfford(item)
            ? ForestTheme.Colors.deepGreen
            : ForestTheme.Colors.deepGreen.opacity(0.55)
    }

    private func accessibilityLabel(_ item: Collectible, owned: Bool, isCompanion: Bool) -> String {
        if isCompanion { return String(localized: "\(item.name), your friend right now") }
        if owned {
            return item.kind == .companion
                ? String(localized: "\(item.name), yours. Tap to bring along.")
                : String(localized: "\(item.name), yours")
        }
        return String(localized: "\(item.name). \(viewModel.status(item))")
    }

    private func celebration(_ item: Collectible) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(item.emoji)
                    .font(.system(size: 90))
                    .floating(amplitude: 8, period: 1.8)
                Text(String(localized: "\(item.name) is yours!"))
                    .font(ForestTheme.Fonts.heading)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
            }
            .padding(28)
            .forestCard(cornerRadius: 26)
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }
}
