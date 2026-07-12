//
//  StoryViews.swift
//  Focus Forest Adventure
//
//  Phase 2.1 story reader and history surfaces.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class StoryHistoryViewModel {
    private let dependencies: AppDependencies

    private(set) var stories: [StoryRecord] = []
    private(set) var isLoading = true

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func load() async {
        defer { isLoading = false }
        do {
            let child = try dependencies.childRepository.activeChild()
            stories = try dependencies.storyService.storyHistory(for: child)
        } catch {
            stories = []
        }
    }
}

struct StoryView: View {
    let story: StoryRecord
    let dependencies: AppDependencies
    let onFinished: () -> Void

    var body: some View {
        StoryReader(story: story, dependencies: dependencies, onFinished: onFinished)
    }
}

struct StoryReader: View {
    let story: StoryRecord
    let dependencies: AppDependencies
    let onFinished: () -> Void

    @State private var pageIndex = 0

    private var pages: [String] {
        story.pages.isEmpty
            ? [String(localized: "Bunny found a tiny story seed. It will bloom after the next adventure!")]
            : story.pages
    }

    private var isLastPage: Bool { pageIndex >= pages.count - 1 }

    var body: some View {
        ZStack {
            ForestTheme.Gradients.magic.ignoresSafeArea()
            MagicDustView().ignoresSafeArea()

            VStack(spacing: 18) {
                header

                Spacer(minLength: 0)

                pageCard
                    .id(pageIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                pageDots

                controls
            }
            .padding(ForestTheme.Metrics.screenPadding)
            .adaptiveContentWidth(760)
        }
        .animation(.smooth(duration: 0.35), value: pageIndex)
        .toolbar(.hidden, for: .navigationBar)
        .task { await narrateCurrentPage() }
        .onDisappear { dependencies.storyNarrator.stop() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(String(localized: "Bunny's Story"))
                .font(ForestTheme.Fonts.caption)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
            Text(story.title)
                .font(ForestTheme.Fonts.title)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(16)
        .forestCard()
    }

    private var pageCard: some View {
        VStack(spacing: 18) {
            LottieView(animation: .bunnyThinking, loopMode: .loop)
                .frame(width: 120, height: 120)

            Text(pages[pageIndex])
                .font(ForestTheme.Fonts.body)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            Label(
                String(localized: "Offline story"),
                systemImage: story.isOfflineGenerated ? "wifi.slash" : "sparkles"
            )
            .font(ForestTheme.Fonts.caption)
            .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 360)
        .forestCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Story page \(pageIndex + 1) of \(pages.count). \(pages[pageIndex])"))
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Circle()
                    .fill(index == pageIndex ? ForestTheme.Colors.deepGreen : ForestTheme.Colors.mint)
                    .frame(width: 10, height: 10)
            }
        }
        .accessibilityLabel(String(localized: "Page \(pageIndex + 1) of \(pages.count)"))
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                movePage(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .frame(width: 58, height: 58)
                    .forestCard(cornerRadius: 18)
            }
            .buttonStyle(SquishyButtonStyle())
            .disabled(pageIndex == 0)
            .opacity(pageIndex == 0 ? 0.4 : 1)
            .accessibilityLabel(String(localized: "Previous page"))

            BigBouncyButton(
                title: isLastPage ? String(localized: "Wiggle Time!") : String(localized: "Next"),
                icon: isLastPage ? "figure.dance" : "chevron.right",
                color: isLastPage ? ForestTheme.Colors.leafGreen : ForestTheme.Colors.sunshine
            ) {
                if isLastPage {
                    dependencies.storyNarrator.stop()
                    onFinished()
                } else {
                    movePage(by: 1)
                }
            }
        }
    }

    private func movePage(by delta: Int) {
        let next = (pageIndex + delta).clamped(to: 0...(pages.count - 1))
        guard next != pageIndex else { return }
        dependencies.hapticsService.playGentleTap()
        pageIndex = next
        Task { await narrateCurrentPage() }
    }

    private func narrateCurrentPage() async {
        await dependencies.storyNarrator.narrate(pages[pageIndex])
    }
}

struct StoryHistory: View {
    @State var viewModel: StoryHistoryViewModel

    var body: some View {
        List {
            if viewModel.stories.isEmpty && !viewModel.isLoading {
                ContentUnavailableView(
                    String(localized: "No stories yet"),
                    systemImage: "book.closed",
                    description: Text(String(localized: "Finish a mission and Bunny will save the first forest story here."))
                )
            }

            ForEach(viewModel.stories, id: \.persistentModelID) { story in
                VStack(alignment: .leading, spacing: 6) {
                    Text(story.title)
                        .font(ForestTheme.Fonts.body)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                    Text(story.createdAt, style: .date)
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "\(story.pages.count) pages · Level \(story.forestLevel) forest"))
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .navigationTitle(String(localized: "Story History"))
        .task { await viewModel.load() }
    }
}
