//
//  AdventureSelectView.swift
//  Focus Forest Adventure
//
//  "Choose Adventure" — a grid of pastel cards, ordered by the
//  LearningRecommendationEngine so the best-fit adventure comes first.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class AdventureSelectViewModel {

    private let dependencies: AppDependencies

    private(set) var orderedAdventures: [AdventureKind] = AdventureKind.allCases
    private(set) var todayPlan: LearningRecommendationEngine.TodayPlan?
    private(set) var isStarting = false

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func onAppear() async {
        do {
            let child = try dependencies.childRepository.activeChild()
            let plan = try dependencies.fetchTodayPlanUseCase.execute(
                child: child,
                preference: dependencies.appState.settings.preferredDifficulty
            )
            todayPlan = plan
            orderedAdventures = plan.recommendedAdventures
        } catch {
            orderedAdventures = AdventureKind.allCases
        }
        await dependencies.speechService.speak(String(localized: "Which adventure shall we pick?"))
    }

    func select(_ adventure: AdventureKind) async {
        guard !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)

        do {
            let child = try dependencies.childRepository.activeChild()
            let plan = try dependencies.startMissionUseCase.execute(
                adventure: adventure,
                child: child,
                difficultyEngine: dependencies.difficultyEngine,
                preference: dependencies.appState.settings.preferredDifficulty,
                duration: todayPlan?.missionDuration ?? 240,
                age: dependencies.appState.settings.childAge
            )
            await dependencies.speechService.speak(BunnyPhrase.missionStart.text)
            dependencies.appState.navigationPath.append(.mission(plan))
        } catch {
            assertionFailure("Mission start failed: \(error)")
        }
    }
}

struct AdventureSelectView: View {
    @State var viewModel: AdventureSelectViewModel

    /// Adaptive columns: 2 across on iPhone, 3–4 across on iPad.
    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 260), spacing: 16)]

    var body: some View {
        ZStack {
            ForestTheme.Gradients.magic.ignoresSafeArea()
            MagicDustView().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text(String(localized: "Choose Your Adventure!"))
                        .font(ForestTheme.Fonts.title)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .padding(.top, 12)
                        .accessibilityAddTraits(.isHeader)

                    if let first = viewModel.orderedAdventures.first {
                        recommendedBanner(first)
                    }

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.orderedAdventures, id: \.self) { adventure in
                            AdventureCard(adventure: adventure) {
                                Task { await viewModel.select(adventure) }
                            }
                        }
                    }
                }
                .padding(ForestTheme.Metrics.screenPadding)
                .adaptiveContentWidth(900)   // roomy grid, centered on iPad
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.onAppear() }
    }

    private func recommendedBanner(_ adventure: AdventureKind) -> some View {
        HStack(spacing: 10) {
            Text("🐰")
                .font(.title)
            Text(String(localized: "Bunny thinks you'll love \(adventure.localizedTitle) today!"))
                .font(ForestTheme.Fonts.caption)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .forestCard(cornerRadius: 20)
    }
}
