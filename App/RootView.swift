//
//  RootView.swift
//  Focus Forest Adventure
//
//  Splash → animated forest intro → Home. Owns the root NavigationStack.
//

import SwiftUI

struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppState.self) private var appState

    @State private var phase: LaunchPhase = .splash

    enum LaunchPhase { case splash, intro, ready }

    var body: some View {
        @Bindable var appState = appState

        NavigationStack(path: $appState.navigationPath) {
            ZStack {
                switch phase {
                case .splash:
                    SplashView()
                        .transition(.opacity)
                case .intro:
                    ForestIntroView {
                        withAnimation(.smooth(duration: 0.6)) { phase = .ready }
                    }
                    .transition(.opacity)
                case .ready:
                    HomeView(viewModel: HomeViewModel(dependencies: dependencies))
                        .transition(.opacity.combined(with: .scale(scale: 1.05)))
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
            // Parent-set daily play limit: gentle full-screen rest overlay.
            // Parent surfaces stay reachable so the limit can be adjusted.
            .overlay {
                if isRestTime {
                    restOverlay
                }
            }
        }
        .task {
            // Splash for 1.6s, then the bunny welcome intro.
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.smooth(duration: 0.6)) { phase = .intro }
        }
    }

    /// Limit reached and not inside a parent surface.
    private var isRestTime: Bool {
        _ = appState.usageTick   // re-evaluate on every meter tick
        let limit = appState.settings.dailyLimitMinutes
        guard limit > 0 else { return false }
        let inParentArea = appState.navigationPath.contains { route in
            route == .parentGate || route == .parentDashboard || route == .settings
        }
        return !inParentArea && DailyUsage.todayMinutes() >= limit
    }

    private var restOverlay: some View {
        ZStack {
            ForestSceneBackground(place: .night, legibility: 0.22)
            VStack(spacing: 18) {
                Text("😴🐰")
                    .font(.system(size: 80))
                    .floating(amplitude: 6, period: 2.4)
                Text(String(localized: "The forest is sleeping!"))
                    .font(ForestTheme.Fonts.title)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                Text(String(localized: "Wonderful playing today! Time to rest — Bunny will be here tomorrow. 🌙"))
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Button {
                    appState.navigationPath.append(.parentGate)
                } label: {
                    Text(String(localized: "Parents"))
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .forestCard(cornerRadius: 16)
                }
                .buttonStyle(SquishyButtonStyle())
            }
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .adventureSelect:
            AdventureSelectView(viewModel: AdventureSelectViewModel(dependencies: dependencies))
        case .mission(let plan):
            MissionContainerView(viewModel: MissionViewModel(plan: plan, dependencies: dependencies))
        case .forest:
            ForestView(viewModel: ForestViewModel(dependencies: dependencies))
        case .parentGate:
            ParentGateView(dependencies: dependencies)
        case .parentDashboard:
            ParentDashboardView(viewModel: ParentDashboardViewModel(dependencies: dependencies))
        case .storyHistory:
            StoryHistory(viewModel: StoryHistoryViewModel(dependencies: dependencies))
        case .bunnyAssistant:
            BunnyAssistantView(viewModel: BunnyAssistantViewModel(dependencies: dependencies))
        case .arForest:
            ARForestView(dependencies: dependencies)
        case .starCatch:
            StarCatchGameView(viewModel: StarCatchViewModel(dependencies: dependencies))
        case .hindiAlphabet:
            HindiAlphabetView(dependencies: dependencies)
        case .hindiLearning:
            HindiLearningHomeView(dependencies: dependencies)
        case .hindiModule(let moduleID):
            if let module = HindiLearningCatalog.module(id: moduleID) {
                HindiModuleView(module: module, dependencies: dependencies)
            }
        case .puzzleWorlds:
            PuzzleWorldsView(viewModel: PuzzleWorldsViewModel(dependencies: dependencies))
        case .puzzleRun(let run):
            PuzzleRunView(viewModel: PuzzleRunViewModel(run: run, dependencies: dependencies))
        case .puzzleCollection:
            PuzzleCollectionView(viewModel: PuzzleCollectionViewModel(dependencies: dependencies))
        case .listeningHub:
            ListeningHubView(viewModel: ListeningHubViewModel(dependencies: dependencies))
        case .listeningMyWords:
            MyWordsView(viewModel: MyWordsViewModel(dependencies: dependencies))
        case .wordExplorer:
            WordExplorerView(viewModel: WordExplorerViewModel(dependencies: dependencies))
        case .barakhadi:
            BarakhadiView(dependencies: dependencies)
        case .multiplicationTables:
            TablesView(dependencies: dependencies)
        case .rhymes:
            RhymesView(dependencies: dependencies)
        case .moralStories:
            MoralStoriesView(dependencies: dependencies)
        case .hindiTracing:
            HindiTracingWorkbookView(dependencies: dependencies)
        case .clockGame:
            ClockGameView(dependencies: dependencies)
        case .learningRewards:
            LearningRewardsView(dependencies: dependencies)
        case .leafCatch:
            LeafCatchGameView(viewModel: LeafCatchViewModel(dependencies: dependencies))
        case .bubblePop:
            BubblePopGameView(viewModel: BubblePopViewModel(dependencies: dependencies))
        case .dotConnect:
            DotConnectView(viewModel: DotConnectViewModel(dependencies: dependencies))
        case .settings:
            SettingsView(viewModel: SettingsViewModel(dependencies: dependencies))
        }
    }
}

// MARK: - Splash

struct SplashView: View {
    @State private var scale: CGFloat = 0.6
    @State private var glow = false

    var body: some View {
        ZStack {
            ForestSceneBackground(place: .magicGrove, legibility: 0.14)

            VStack(spacing: 24) {
                LottieView(animation: .bunnyWave, loopMode: .loop)
                    .frame(width: 220, height: 220)
                    .scaleEffect(scale)
                    .shadow(color: .yellow.opacity(glow ? 0.6 : 0.2), radius: glow ? 40 : 16)

                Text("Focus Forest Adventure")
                    .font(ForestTheme.Fonts.title)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
            }
        }
        .onAppear {
            withAnimation(.bouncy(duration: 0.9)) { scale = 1.0 }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { glow = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Focus Forest Adventure is starting")
    }
}

// MARK: - Bunny welcome intro

struct ForestIntroView: View {
    @Environment(AppDependencies.self) private var dependencies
    let onFinished: () -> Void

    @State private var showBubble = false

    var body: some View {
        ZStack {
            AnimatedForestBackground(density: .light)

            VStack(spacing: 20) {
                Spacer()

                if showBubble {
                    SpeechBubble(text: String(localized: "Hello Explorer! Ready for an adventure?"))
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }

                LottieView(animation: .bunnyWave, loopMode: .loop)
                    .frame(width: 260, height: 260)

                BigBouncyButton(
                    title: String(localized: "Let's Go!"),
                    icon: "sparkles",
                    color: ForestTheme.Colors.sunshine
                ) {
                    onFinished()
                }
                .padding(.bottom, 48)
            }
        }
        .task {
            withAnimation(.bouncy(duration: 0.7).delay(0.4)) { showBubble = true }
            await dependencies.speechService.speak(BunnyPhrase.welcome.text)
        }
    }
}
