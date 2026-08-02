//
//  RhymesAndStoriesViews.swift
//  Focus Forest Adventure
//
//  Nursery rhyme player (line-by-line narration with highlighting) and
//  moral story reader (paged, bilingual, narrated, moral at the end).
//

import SwiftUI

// MARK: - Rhymes

struct RhymesView: View {
    let dependencies: AppDependencies

    @State private var selected: NurseryRhyme?
    @State private var currentLine: Int?
    @State private var playTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            ForestSceneBackground(place: .magicGrove, legibility: 0.2)

            if let rhyme = selected {
                player(rhyme)
            } else {
                rhymeList
            }
        }
        .navigationTitle(String(localized: "बाल गीत · Rhymes"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stopPlayback() }
    }

    private var rhymeList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(RhymeCatalog.rhymes) { rhyme in
                    Button {
                        selected = rhyme
                        play(rhyme)
                    } label: {
                        HStack(spacing: 14) {
                            Text(rhyme.emoji).font(.system(size: 40))
                            Text(rhyme.title)
                                .font(ForestTheme.Fonts.body)
                                .foregroundStyle(ForestTheme.Colors.deepGreen)
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.title)
                                .foregroundStyle(ForestTheme.Colors.leafGreen)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .forestCard(cornerRadius: 20)
                    }
                    .buttonStyle(SquishyButtonStyle())
                }
            }
            .padding(ForestTheme.Metrics.screenPadding)
            .adaptiveContentWidth(600)
        }
    }

    private func player(_ rhyme: NurseryRhyme) -> some View {
        VStack(spacing: 18) {
            Text(rhyme.emoji)
                .font(.system(size: 90))
                .floating(amplitude: 8, period: 1.6)

            Text(rhyme.title)
                .font(ForestTheme.Fonts.title)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                ForEach(rhyme.lines.indices, id: \.self) { index in
                    Text(rhyme.lines[index])
                        .font(ForestTheme.Fonts.heading)
                        .foregroundStyle(currentLine == index
                                         ? ForestTheme.Colors.deepGreen
                                         : ForestTheme.Colors.deepGreen.opacity(0.45))
                        .scaleEffect(currentLine == index ? 1.08 : 1.0)
                        .multilineTextAlignment(.center)
                        .animation(.bouncy(duration: 0.3), value: currentLine)
                }
            }
            .padding(20)
            .forestCard()
            .padding(.horizontal, 24)

            HStack(spacing: 16) {
                Button {
                    play(rhyme)
                } label: {
                    Label(String(localized: "Play again"), systemImage: "play.fill")
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .forestCard(cornerRadius: 16)
                }
                .buttonStyle(SquishyButtonStyle())

                Button {
                    stopPlayback()
                    selected = nil
                } label: {
                    Label(String(localized: "All rhymes"), systemImage: "list.bullet")
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .forestCard(cornerRadius: 16)
                }
                .buttonStyle(SquishyButtonStyle())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rhyme.title). \(rhyme.lines.joined(separator: ". "))")
    }

    private func play(_ rhyme: NurseryRhyme) {
        stopPlayback()
        playTask = Task {
            for index in rhyme.lines.indices {
                guard !Task.isCancelled else { return }
                currentLine = index
                await dependencies.speechService.speak(rhyme.lines[index], language: "hi-IN")
                // Rough per-line pacing; speech itself is fire-and-forget.
                try? await Task.sleep(for: .seconds(2.6))
            }
            currentLine = nil
        }
    }

    private func stopPlayback() {
        playTask?.cancel()
        playTask = nil
        currentLine = nil
        dependencies.speechService.stop()
    }
}

// MARK: - Moral stories

struct MoralStoriesView: View {
    let dependencies: AppDependencies

    @State private var selected: MoralStory?
    @State private var pageIndex = 0

    var body: some View {
        ZStack {
            ForestSceneBackground(place: .dusk, legibility: 0.2)

            if let story = selected {
                reader(story)
            } else {
                storyList
            }
        }
        .navigationTitle(String(localized: "कहानियाँ · Stories"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { dependencies.speechService.stop() }
    }

    private var storyList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(StoryCatalog.stories) { story in
                    Button {
                        pageIndex = 0
                        selected = story
                        narrate(story.pages[0].hindi)
                    } label: {
                        HStack(spacing: 14) {
                            Text(story.emoji).font(.system(size: 40))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(story.titleHindi)
                                    .font(ForestTheme.Fonts.body)
                                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                                Text(story.titleEnglish)
                                    .font(ForestTheme.Fonts.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "book.fill")
                                .font(.title2)
                                .foregroundStyle(ForestTheme.Colors.leafGreen)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .forestCard(cornerRadius: 20)
                    }
                    .buttonStyle(SquishyButtonStyle())
                }
            }
            .padding(ForestTheme.Metrics.screenPadding)
            .adaptiveContentWidth(600)
        }
    }

    private func reader(_ story: MoralStory) -> some View {
        let isMoralPage = pageIndex >= story.pages.count

        return VStack(spacing: 16) {
            Text(story.emoji)
                .font(.system(size: 84))
                .floating(amplitude: 7, period: 2)

            Text(story.titleHindi)
                .font(ForestTheme.Fonts.heading)
                .foregroundStyle(ForestTheme.Colors.deepGreen)

            Group {
                if isMoralPage {
                    VStack(spacing: 10) {
                        Text("🌟 " + String(localized: "सीख"))
                            .font(ForestTheme.Fonts.caption)
                            .foregroundStyle(.secondary)
                        Text(story.moralHindi)
                            .font(ForestTheme.Fonts.heading)
                            .foregroundStyle(ForestTheme.Colors.deepGreen)
                            .multilineTextAlignment(.center)
                        Text(story.moralEnglish)
                            .font(ForestTheme.Fonts.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    VStack(spacing: 12) {
                        Text(story.pages[pageIndex].hindi)
                            .font(ForestTheme.Fonts.heading)
                            .foregroundStyle(ForestTheme.Colors.deepGreen)
                            .multilineTextAlignment(.center)
                        Text(story.pages[pageIndex].english)
                            .font(ForestTheme.Fonts.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 220)
            .forestCard()
            .padding(.horizontal, 24)
            .id(pageIndex)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))

            // Page dots (pages + moral)
            HStack(spacing: 8) {
                ForEach(0...(story.pages.count), id: \.self) { index in
                    Circle()
                        .fill(index == pageIndex ? ForestTheme.Colors.deepGreen : ForestTheme.Colors.mint)
                        .frame(width: 10, height: 10)
                }
            }

            HStack(spacing: 14) {
                pagerButton("chevron.left", enabled: pageIndex > 0) {
                    turnPage(to: pageIndex - 1, in: story)
                }

                BigBouncyButton(
                    title: isMoralPage ? String(localized: "All stories") : String(localized: "Next"),
                    icon: isMoralPage ? "books.vertical.fill" : "chevron.right",
                    color: isMoralPage ? ForestTheme.Colors.leafGreen : ForestTheme.Colors.sunshine
                ) {
                    if isMoralPage {
                        dependencies.speechService.stop()
                        selected = nil
                    } else {
                        turnPage(to: pageIndex + 1, in: story)
                    }
                }

                pagerButton("chevron.right", enabled: !isMoralPage) {
                    turnPage(to: pageIndex + 1, in: story)
                }
            }
            .padding(.horizontal, 24)
        }
        .animation(.smooth(duration: 0.35), value: pageIndex)
    }

    private func pagerButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .frame(width: 48, height: 48)
                .forestCard(cornerRadius: 15)
        }
        .buttonStyle(SquishyButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    private func turnPage(to newIndex: Int, in story: MoralStory) {
        guard newIndex >= 0, newIndex <= story.pages.count else { return }
        pageIndex = newIndex
        dependencies.hapticsService.playGentleTap()
        if newIndex >= story.pages.count {
            narrate("\(String(localized: "सीख")): \(story.moralHindi)")
        } else {
            narrate(story.pages[newIndex].hindi)
        }
    }

    private func narrate(_ text: String) {
        Task {
            await dependencies.speechService.speak(text, language: "hi-IN")
        }
    }
}
