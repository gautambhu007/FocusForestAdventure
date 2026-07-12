//
//  HomeView.swift
//  Focus Forest Adventure
//
//  The living home screen: animated forest, bunny guide, today's goal,
//  magic chest, and the big "Adventure!" button.
//

import SwiftUI
import TipKit

struct HomeView: View {
    @State var viewModel: HomeViewModel

    var body: some View {
        ZStack {
            AnimatedForestBackground(density: viewModel.forestDensity)

            VStack(spacing: 0) {
                topBar
                Spacer()
                bunnySection
                Spacer()
                bottomSection
            }
            .padding(ForestTheme.Metrics.screenPadding)
            .adaptiveContentWidth(700)   // centered column on iPad
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.onAppear() }
    }

    // MARK: Top bar — stars, parent button, settings

    private var topBar: some View {
        HStack {
            StarCounter(count: viewModel.stars)

            Spacer()

            // Parent button is intentionally small & unexciting for children.
            Button {
                viewModel.parentButtonTapped()
            } label: {
                Image(systemName: "figure.and.child.holdinghands")
                    .font(.title3)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .padding(12)
                    .forestCard(cornerRadius: 18)
            }
            .accessibilityLabel(String(localized: "Grown-ups area"))
            .popoverTip(ParentDashboardTip())

            Button {
                viewModel.settingsTapped()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .padding(12)
                    .forestCard(cornerRadius: 18)
            }
            .accessibilityLabel(String(localized: "Settings"))
        }
    }

    // MARK: Bunny + greeting

    private var bunnySection: some View {
        VStack(spacing: 12) {
            SpeechBubble(text: viewModel.bunnyGreeting)

            Button {
                viewModel.forestTapped()
            } label: {
                LottieView(animation: .bunnyWave, loopMode: .loop)
                    .frame(width: 200, height: 200)
            }
            .buttonStyle(SquishyButtonStyle())
            .accessibilityLabel(String(localized: "Bunny. Tap to visit your forest"))

            Text(viewModel.forestLevelName)
                .font(ForestTheme.Fonts.caption)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .padding(.horizontal, 16).padding(.vertical, 6)
                .forestCard(cornerRadius: 16)
        }
    }

    // MARK: Bottom — goal, chest, adventure button

    private var bottomSection: some View {
        VStack(spacing: 18) {
            HStack(alignment: .bottom, spacing: 16) {
                ForestProgressBar(progress: viewModel.goalProgress)

                Button {
                    viewModel.magicChestTapped()
                } label: {
                    Text("🎁")
                        .font(.system(size: 44))
                        .floating(amplitude: 5, period: 1.8)
                }
                .buttonStyle(SquishyButtonStyle())
                .accessibilityLabel(String(localized: "Magic chest"))
            }
            .padding(16)
            .forestCard()

            BigBouncyButton(
                title: String(localized: "Adventure!"),
                icon: "map.fill",
                color: ForestTheme.Colors.sunshine
            ) {
                viewModel.startAdventureTapped()
            }
        }
        .padding(.bottom, 8)
    }
}

/// TipKit: shown once to introduce parents to the dashboard.
struct ParentDashboardTip: Tip {
    var title: Text { Text("For grown-ups") }
    var message: Text? { Text("See focus stats, progress, and tips in the parent dashboard.") }
    var image: Image? { Image(systemName: "chart.line.uptrend.xyaxis") }
}

#Preview {
    let container = ModelContainerFactory.makePreviewContainer()
    let deps = AppDependencies(modelContainer: container)
    return NavigationStack {
        HomeView(viewModel: HomeViewModel(dependencies: deps))
    }
    .environment(deps)
    .environment(deps.appState)
    .modelContainer(container)
}
