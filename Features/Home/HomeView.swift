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
            MeadowBackground()

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

    // MARK: Top bar — stars, and one quiet card for the grown-ups

    private var topBar: some View {
        HStack {
            StarCounter(count: viewModel.stars)

            Spacer()

            // Both adult controls live in one small card, so the child's
            // screen has a single unexciting corner instead of two.
            HStack(spacing: 4) {
                Button {
                    viewModel.parentButtonTapped()
                } label: {
                    Image(systemName: "figure.and.child.holdinghands")
                        .font(.title3)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(String(localized: "Grown-ups area"))
                .popoverTip(ParentDashboardTip())

                Divider().frame(height: 22)

                Button {
                    viewModel.settingsTapped()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(String(localized: "Settings"))
            }
            .padding(.horizontal, 4)
            .forestCard(cornerRadius: 20)
        }
    }

    // MARK: Bunny + greeting

    private var bunnySection: some View {
        VStack(spacing: 12) {
            SpeechBubble(text: viewModel.bunnyGreeting)
                .zIndex(1)

            Button {
                viewModel.forestTapped()
            } label: {
                CuteBunnyView()
                    .frame(width: 160, height: 200)
            }
            .buttonStyle(SquishyButtonStyle())
            .accessibilityLabel(String(localized: "Bunny. Tap to visit your forest"))

            // The forest gate, stated plainly: either it's open, or here's
            // what opens it. This is the loop the whole app turns on.
            magicForestStatus
        }
    }

    /// One pill under the bunny: "Magic Forest open!" or "next: Rocking Chair".
    private var magicForestStatus: some View {
        Button {
            viewModel.forestTapped()
        } label: {
            HStack(spacing: 8) {
                Text(viewModel.canEnterMagicForest ? "🌟" : "🔒")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(viewModel.canEnterMagicForest
                         ? String(localized: "Magic Forest is open!")
                         : viewModel.forestLevelName)
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                    if viewModel.canEnterMagicForest {
                        Text(String(localized: "4 minutes to explore"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if let next = viewModel.nextTreasure {
                        Text(String(localized: "Earn \(next.emoji) \(next.name) to go in"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .forestCard(cornerRadius: 20)
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(String(localized: "Opens your forest"))
    }

    /// The three learning hubs, sized alike so none shouts louder.
    private var learningHubs: some View {
        HStack(spacing: 10) {
            hubButton("🐰", String(localized: "Bunny"),
                      label: String(localized: "Talk to Bunny")) {
                viewModel.talkToBunnyTapped()
            }
            hubButton("📖", String(localized: "हिंदी"),
                      label: String(localized: "Learn Hindi")) {
                viewModel.hindiLearningTapped()
            }
            hubButton("👂", String(localized: "Listen"),
                      label: String(localized: "Listening Corner")) {
                viewModel.listeningCornerTapped()
            }
            hubButton("🧩", String(localized: "Puzzles"),
                      label: String(localized: "Puzzle Quest")) {
                viewModel.puzzleQuestTapped()
            }
        }
    }

    private func hubButton(_ emoji: String, _ title: String,
                           label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(emoji).font(.title2)
                Text(title)
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .forestCard(cornerRadius: 20)
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel(label)
    }

    // MARK: Bottom — goal, chest, adventure button

    private var bottomSection: some View {
        VStack(spacing: 14) {
            learningHubs

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
