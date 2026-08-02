//
//  ListeningHubView.swift
//  Focus Forest Adventure
//
//  Listening Corner — 5 subsections: the 2 existing mission-based games
//  (forced to a specific type instead of the adventure grid's semi-random
//  pick) plus 3 new browse-and-listen tools. Reached from its own Home
//  button, independent of "Choose Your Adventure".
//

import SwiftUI
import Observation

@Observable
@MainActor
final class ListeningHubViewModel {

    private let dependencies: AppDependencies
    private(set) var isStarting = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func onAppear() async {
        await dependencies.speechService.speak(String(localized: "Let's listen and learn!"))
    }

    /// Animal Sounds / Repeat the Pattern tiles: same mission engine as the
    /// adventure grid, just forced to one specific type.
    func startListeningMission(forced type: MissionType) async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)

        do {
            let child = try dependencies.childRepository.activeChild()
            let plan = try dependencies.startMissionUseCase.execute(
                adventure: .listening,
                child: child,
                difficultyEngine: dependencies.difficultyEngine,
                preference: dependencies.appState.settings.preferredDifficulty,
                duration: 240,
                age: dependencies.appState.settings.childAge,
                forcedMissionType: type
            )
            await dependencies.speechService.speak(BunnyPhrase.missionStart.text)
            dependencies.appState.navigationPath.append(.mission(plan))
        } catch {
            assertionFailure("Listening mission start failed: \(error)")
        }
    }

    func letterSoundsTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        dependencies.appState.navigationPath.append(.hindiModule("englishAlphabet"))
    }

    func myWordsTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        dependencies.appState.navigationPath.append(.listeningMyWords)
    }

    func wordExplorerTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        dependencies.appState.navigationPath.append(.wordExplorer)
    }
}

struct ListeningHubView: View {
    @State var viewModel: ListeningHubViewModel

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 14)]

    var body: some View {
        ZStack {
            ForestSceneBackground(place: .glade, legibility: 0.2)

            ScrollView {
                VStack(spacing: 16) {
                    Text(String(localized: "👂 Listening Corner"))
                        .font(ForestTheme.Fonts.title)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .padding(.top, 12)
                        .accessibilityAddTraits(.isHeader)

                    LazyVGrid(columns: columns, spacing: 14) {
                        tile(emoji: "🦁", title: String(localized: "Animal Sounds")) {
                            Task { await viewModel.startListeningMission(forced: .guessAnimalSound) }
                        }
                        tile(emoji: "🥁", title: String(localized: "Repeat the Pattern")) {
                            Task { await viewModel.startListeningMission(forced: .repeatPattern) }
                        }
                        tile(emoji: "🔤", title: String(localized: "Letter Sounds")) {
                            viewModel.letterSoundsTapped()
                        }
                        tile(emoji: "✍️", title: String(localized: "My Words")) {
                            viewModel.myWordsTapped()
                        }
                        tile(emoji: "📚", title: String(localized: "Word Explorer")) {
                            viewModel.wordExplorerTapped()
                        }
                    }
                }
                .padding(ForestTheme.Metrics.screenPadding)
                .adaptiveContentWidth(900)
            }
        }
        .navigationTitle(String(localized: "Listening Corner"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.onAppear() }
    }

    private func tile(emoji: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emoji).font(.system(size: 44))
                Text(title)
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .forestCard(cornerRadius: 22)
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel(title)
    }
}
