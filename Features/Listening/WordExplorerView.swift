//
//  WordExplorerView.swift
//  Focus Forest Adventure
//
//  Listening Corner · Word Explorer — a shuffled batch from the ~1000-word
//  ListeningWordBank, shown as a tap-to-hear word wall. "New Words" draws a
//  fresh batch. Pure content browsing: no persistence, no quiz, no scoring —
//  same stateless spirit as the Hindi module lesson pager.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class WordExplorerViewModel {

    private let dependencies: AppDependencies
    private static let batchSize = 48

    private(set) var batch: [String] = []
    private var shown: Set<String> = []

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func onAppear() async {
        shuffleBatch()
        await dependencies.speechService.speak(String(localized: "Tap any word to hear it!"))
    }

    func shuffleBatch() {
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        let newBatch = ListeningWordBank.randomBatch(count: Self.batchSize, excluding: shown)
        batch = newBatch
        shown.formUnion(newBatch)
        // Once we've cycled through most of the bank, let it refill.
        if shown.count > ListeningWordBank.allWords.count - Self.batchSize {
            shown.removeAll()
        }
    }

    func speak(_ word: String) {
        dependencies.hapticsService.playGentleTap()
        Task { await dependencies.speechService.speak(word) }
    }

    func emoji(for word: String) -> String {
        ListeningWordBank.emoji(for: word)
    }
}

struct WordExplorerView: View {
    @State var viewModel: WordExplorerViewModel

    private let columns = [GridItem(.adaptive(minimum: 92, maximum: 140), spacing: 12)]

    var body: some View {
        ZStack {
            ForestSceneBackground(place: .meadow, legibility: 0.2)

            ScrollView {
                VStack(spacing: 16) {
                    Text(String(localized: "📚 Word Explorer"))
                        .font(ForestTheme.Fonts.title)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .padding(.top, 12)
                        .accessibilityAddTraits(.isHeader)

                    BigBouncyButton(
                        title: String(localized: "New Words"),
                        icon: "shuffle",
                        color: ForestTheme.Colors.sunshine
                    ) {
                        viewModel.shuffleBatch()
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.batch, id: \.self) { word in
                            wordCard(word)
                        }
                    }
                }
                .padding(ForestTheme.Metrics.screenPadding)
                .adaptiveContentWidth(900)
            }
        }
        .navigationTitle(String(localized: "Word Explorer"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.onAppear() }
    }

    private func wordCard(_ word: String) -> some View {
        Button {
            viewModel.speak(word)
        } label: {
            VStack(spacing: 4) {
                Text(viewModel.emoji(for: word))
                    .font(.system(size: 30))
                Text(word)
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
            .forestCard(cornerRadius: 16)
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel(String(localized: "Say \(word)"))
    }
}
