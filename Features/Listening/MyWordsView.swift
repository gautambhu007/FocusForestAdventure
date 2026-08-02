//
//  MyWordsView.swift
//  Focus Forest Adventure
//
//  Listening Corner · My Words — a parent/child types in any word, it's
//  saved, and every saved word is a tappable chip that speaks itself aloud
//  via the shared SpeechService.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class MyWordsViewModel {

    private let dependencies: AppDependencies
    private var child: ChildProfile?

    private(set) var words: [CustomWord] = []
    var draftText: String = ""

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func onAppear() async {
        do {
            let child = try dependencies.childRepository.activeChild()
            self.child = child
            words = try dependencies.customWordRepository.words(for: child)
        } catch {
            assertionFailure("My Words load failed: \(error)")
        }
        await dependencies.speechService.speak(String(localized: "Type a word and I'll say it for you!"))
    }

    /// Kid-safe, lightweight input guard: trim, cap length, letters/spaces only.
    func addWord() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 24,
              trimmed.allSatisfy({ $0.isLetter || $0.isWhitespace }),
              let child else { return }
        do {
            try dependencies.customWordRepository.add(trimmed, for: child)
            words = try dependencies.customWordRepository.words(for: child)
            draftText = ""
            dependencies.hapticsService.playSuccess()
        } catch {
            assertionFailure("Add custom word failed: \(error)")
        }
    }

    func delete(_ word: CustomWord) {
        do {
            try dependencies.customWordRepository.delete(word)
            words.removeAll { $0.persistentModelID == word.persistentModelID }
        } catch {
            assertionFailure("Delete custom word failed: \(error)")
        }
    }

    func speak(_ word: CustomWord) {
        dependencies.hapticsService.playGentleTap()
        Task { await dependencies.speechService.speak(word.text) }
    }
}

struct MyWordsView: View {
    @State var viewModel: MyWordsViewModel
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        ZStack {
            ForestSceneBackground(place: .meadow, legibility: 0.2)

            ScrollView {
                VStack(spacing: 18) {
                    Text(String(localized: "✍️ My Words"))
                        .font(ForestTheme.Fonts.title)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .padding(.top, 12)
                        .accessibilityAddTraits(.isHeader)

                    HStack(spacing: 10) {
                        TextField(String(localized: "Type a word..."), text: $viewModel.draftText)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($isFieldFocused)
                            .submitLabel(.done)
                            .onSubmit { viewModel.addWord() }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .forestCard(cornerRadius: 16)

                        Button {
                            viewModel.addWord()
                            isFieldFocused = false
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(ForestTheme.Colors.leafGreen)
                        }
                        .accessibilityLabel(String(localized: "Add word"))
                    }

                    if viewModel.words.isEmpty {
                        Text(String(localized: "No words yet — add your first one above!"))
                            .font(ForestTheme.Fonts.caption)
                            .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.8))
                            .padding(.top, 20)
                    } else {
                        FlowLayout(spacing: 12) {
                            ForEach(viewModel.words, id: \.persistentModelID) { word in
                                wordChip(word)
                            }
                        }
                    }
                }
                .padding(ForestTheme.Metrics.screenPadding)
                .adaptiveContentWidth(700)
            }
        }
        .navigationTitle(String(localized: "My Words"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.onAppear() }
    }

    private func wordChip(_ word: CustomWord) -> some View {
        HStack(spacing: 6) {
            Button {
                viewModel.speak(word)
            } label: {
                Text(word.text)
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
            }
            .buttonStyle(SquishyButtonStyle())
            .accessibilityLabel(String(localized: "Say \(word.text)"))

            Button {
                viewModel.delete(word)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(String(localized: "Delete \(word.text)"))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .forestCard(cornerRadius: 20)
    }
}
