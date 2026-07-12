//
//  MissionContainerView.swift
//  Focus Forest Adventure
//
//  Hosts the active mission: progress vine, bunny reactions, and the
//  per-question game renderer chosen from the question content.
//

import SwiftUI

struct MissionContainerView: View {
    @State var viewModel: MissionViewModel

    var body: some View {
        ZStack {
            switch viewModel.phase {
            case .playing:
                playingView
                    .transition(.opacity)
            case .reward(let bundle):
                RewardCelebrationView(
                    bundle: bundle,
                    dependencies: viewModel.dependencies,
                    continueTitle: viewModel.pendingStory != nil
                        ? String(localized: "Story Time!")
                        : String(localized: "Wiggle Time!"),
                    continueIcon: viewModel.pendingStory != nil ? "book.fill" : "figure.dance",
                    emphasis: viewModel.rewardEmphasis
                ) {
                    viewModel.continueFromReward()
                }
                .transition(.opacity.combined(with: .scale(scale: 1.04)))
            case .story:
                if let story = viewModel.pendingStory {
                    StoryView(story: story, dependencies: viewModel.dependencies) {
                        viewModel.continueToMovementBreak()
                    }
                    .transition(.opacity)
                } else {
                    // Defensive: no story available — skip ahead.
                    Color.clear.onAppear { viewModel.continueToMovementBreak() }
                }
            case .movementBreak(let activity):
                MovementBreakView(activity: activity, dependencies: viewModel.dependencies)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.45), value: viewModel.phase)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    // MARK: Playing phase

    private var playingView: some View {
        ZStack {
            viewModel.plan.adventure.tint.opacity(0.25).ignoresSafeArea()
            ForestTheme.Gradients.morningSky.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    // Deliberate exit (system nav bar is hidden so little hands
                    // can't accidentally swipe out). Ends the mission kindly —
                    // answered questions still count toward rewards.
                    Button {
                        Task { await viewModel.exitEarly() }
                    } label: {
                        Image(systemName: "house.fill")
                            .font(.title3)
                            .foregroundStyle(ForestTheme.Colors.deepGreen)
                            .padding(12)
                            .forestCard(cornerRadius: 18)
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .accessibilityLabel(String(localized: "Go back home"))

                    ForestProgressBar(
                        progress: viewModel.progress,
                        label: String(localized: "Mission progress")
                    )
                }
                .padding(.horizontal)

                if let question = viewModel.currentQuestion {
                    questionView(question)
                        .id(question.id)   // fresh transition per question
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }

                Spacer(minLength: 0)

                bunnyReaction
            }
            .padding(.top, 8)
            .adaptiveContentWidth()   // comfortable width on iPad
            .animation(.bouncy(duration: 0.5), value: viewModel.questionIndex)

            // Celebration overlays
            SparkleBurstView(trigger: viewModel.sparkleTrigger)
            if viewModel.feedback == .correct {
                ConfettiView(particleCount: 40).ignoresSafeArea()
            }
        }
    }

    // MARK: Question routing

    @ViewBuilder
    private func questionView(_ question: MissionQuestion) -> some View {
        VStack(spacing: 20) {
            Text(question.prompt)
                .font(ForestTheme.Fonts.heading)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

            switch question.content {
            case .tapCorrect(let options, let correctID):
                TapCorrectGameView(options: options, correctID: correctID, viewModel: viewModel)
            case .countObjects(let emoji, let count, let choices):
                CountingGameView(objectEmoji: emoji, count: count, choices: choices, viewModel: viewModel)
            case .memoryPairs(let pairs):
                MemoryGameView(pairs: pairs, viewModel: viewModel)
            case .sequence(let items, let interval):
                SequenceGameView(items: items, playbackInterval: interval, viewModel: viewModel)
            case .traceLetter(let letter, let guidePoints):
                TraceLetterGameView(letter: letter, guidePoints: guidePoints, viewModel: viewModel)
            case .soundGuess(let sound, let options, let correctID):
                SoundGuessGameView(soundName: sound, options: options, correctID: correctID, viewModel: viewModel)
            }
        }
    }

    // MARK: Bunny reaction bar

    private var bunnyReaction: some View {
        HStack(spacing: 12) {
            LottieView(
                animation: viewModel.feedback == .correct ? .bunnyCheer : .bunnyThinking,
                loopMode: .loop
            )
            .frame(width: 90, height: 90)

            if viewModel.feedback == .tryAgain {
                Text(String(localized: "Almost! Try again! 😊"))
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .transition(.scale.combined(with: .opacity))
            } else if viewModel.feedback == .correct {
                Text(String(localized: "Amazing! ⭐"))
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.bottom, 12)
        .animation(.bouncy(duration: 0.4), value: viewModel.feedback)
    }
}
