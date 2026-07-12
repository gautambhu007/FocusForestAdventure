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
        }
        .task {
            // Splash for 1.6s, then the bunny welcome intro.
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.smooth(duration: 0.6)) { phase = .intro }
        }
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
            ForestTheme.Gradients.morningSky.ignoresSafeArea()

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
