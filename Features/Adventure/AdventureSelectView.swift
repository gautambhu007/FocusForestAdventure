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
    /// Age 6: Numbers first asks which addition section to play.
    var isChoosingAdditionSection = false

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

        // Age 6: Numbers has four graded addition sections — ask first.
        if adventure == .numbers && dependencies.appState.settings.childAge >= 6 {
            dependencies.hapticsService.playGentleTap()
            isChoosingAdditionSection = true
            await dependencies.speechService.speak(String(localized: "How brave are we feeling today?"))
            return
        }
        await start(adventure, additionSection: nil)
    }

    /// Called from the addition section sheet.
    func selectAdditionSection(_ section: AdditionSection) async {
        isChoosingAdditionSection = false
        await start(.numbers, additionSection: section)
    }

    /// Smart Dots IQ puzzle.
    func dotConnectTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        dependencies.appState.navigationPath.append(.dotConnect)
    }

    /// Hindi alphabet explorer (browse & listen — not a mission).
    func hindiAlphabetTapped() {
        dependencies.hapticsService.playGentleTap()
        dependencies.soundEngine.play(.tapPop)
        dependencies.appState.navigationPath.append(.hindiAlphabet)
    }

    private func start(_ adventure: AdventureKind, additionSection: AdditionSection?) async {
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
                age: dependencies.appState.settings.childAge,
                additionSection: additionSection
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

                        // Smart Dots IQ puzzle
                        Button {
                            viewModel.dotConnectTapped()
                        } label: {
                            VStack(spacing: 8) {
                                Text("🧠")
                                    .font(.system(size: 38))
                                Text(String(localized: "Smart Dots"))
                                    .font(ForestTheme.Fonts.body)
                                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                            }
                            .frame(maxWidth: .infinity, minHeight: 150)
                            .background(ForestTheme.Colors.lavender.opacity(0.35))
                            .forestCard()
                        }
                        .buttonStyle(SquishyButtonStyle())
                        .accessibilityLabel(String(localized: "Smart Dots puzzle"))
                        .accessibilityHint(String(localized: "Connect matching colors without crossing lines"))

                        // Hindi alphabet explorer
                        Button {
                            viewModel.hindiAlphabetTapped()
                        } label: {
                            VStack(spacing: 8) {
                                Text("क ख ग")
                                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                                Text(String(localized: "Hindi Letters"))
                                    .font(ForestTheme.Fonts.body)
                                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                            }
                            .frame(maxWidth: .infinity, minHeight: 150)
                            .background(ForestTheme.Colors.peach.opacity(0.35))
                            .forestCard()
                        }
                        .buttonStyle(SquishyButtonStyle())
                        .accessibilityLabel(String(localized: "Hindi alphabet"))
                        .accessibilityHint(String(localized: "Learn Hindi letters with pictures and sounds"))
                    }
                }
                .padding(ForestTheme.Metrics.screenPadding)
                .adaptiveContentWidth(900)   // roomy grid, centered on iPad
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.onAppear() }
        .sheet(isPresented: Binding(
            get: { viewModel.isChoosingAdditionSection },
            set: { viewModel.isChoosingAdditionSection = $0 }
        )) {
            additionSectionSheet
                .presentationDetents([.medium, .large])
        }
    }

    /// Age 6: pick one of the four graded addition sections.
    private var additionSectionSheet: some View {
        ZStack {
            ForestTheme.Gradients.morningSky.ignoresSafeArea()
            VStack(spacing: 14) {
                Text(String(localized: "Pick your challenge!"))
                    .font(ForestTheme.Fonts.heading)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .padding(.top, 20)
                    .accessibilityAddTraits(.isHeader)

                ForEach(AdditionSection.allCases) { section in
                    Button {
                        Task { await viewModel.selectAdditionSection(section) }
                    } label: {
                        HStack(spacing: 12) {
                            Text(section.stars)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(section.localizedTitle)
                                    .font(ForestTheme.Fonts.body)
                                Text(section.localizedDescription)
                                    .font(ForestTheme.Fonts.caption)
                                    .opacity(0.75)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .forestCard(cornerRadius: 20)
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .accessibilityLabel(String(localized: "\(section.localizedTitle) addition"))
                }
                Spacer()
            }
            .padding(.horizontal, ForestTheme.Metrics.screenPadding)
            .adaptiveContentWidth(600)
        }
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
