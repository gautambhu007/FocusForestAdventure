//
//  RewardCelebrationView.swift
//  Focus Forest Adventure
//
//  Post-mission celebration: confetti, counted-up rewards, unlocks,
//  then hands off to the movement break.
//

import SwiftUI

struct RewardCelebrationView: View {
    let bundle: RewardBundle
    let dependencies: AppDependencies
    /// Advances the mission flow (rendered inside MissionContainerView —
    /// no NavigationStack changes happen here).
    var continueTitle: String = String(localized: "Wiggle Time!")
    var continueIcon: String = "figure.dance"
    /// Phase 2.8: reward to visually spotlight (from daily recommendations).
    var emphasis: RewardEmphasis?
    let onContinue: () -> Void

    @Environment(AppState.self) private var appState
    @State private var shownStars = 0
    @State private var revealUnlocks = false

    var body: some View {
        ZStack {
            ForestTheme.Gradients.sunset.ignoresSafeArea()
            ConfettiView(particleCount: 80).ignoresSafeArea()

            // Scrollable: with unlocks + achievements the celebration can be
            // taller than one screen — nothing may ever push the button away.
            ScrollView {
                VStack(spacing: 18) {
                    LottieView(animation: .bunnyCheer, loopMode: .loop)
                        .frame(width: 150, height: 150)

                    Text(bundle.bunnyPhrase)
                        .font(ForestTheme.Fonts.title)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)   // wrap, never truncate
                        .padding(.horizontal)

                    // Stars pop in one at a time.
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: "star.fill")
                                .font(.system(size: 52))
                                .foregroundStyle(index < shownStars
                                                 ? ForestTheme.Colors.sunshine
                                                 : .white.opacity(0.4))
                                .scaleEffect(index < shownStars ? 1 : 0.6)
                                .animation(.bouncy(duration: 0.5).delay(Double(index) * 0.35),
                                           value: shownStars)
                        }
                    }
                    .accessibilityLabel(String(localized: "You earned \(bundle.stars) stars!"))

                    rewardRow

                    if revealUnlocks && !bundle.newlyUnlocked.isEmpty {
                        unlocksSection
                    }
                    if revealUnlocks && !bundle.newAchievements.isEmpty {
                        achievementsSection
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
                .adaptiveContentWidth(700)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        // Pinned outside the scroll content — always visible, always tappable.
        .safeAreaInset(edge: .bottom) {
            BigBouncyButton(
                title: continueTitle,
                icon: continueIcon,
                color: ForestTheme.Colors.leafGreen
            ) {
                onContinue()
            }
            .padding(.vertical, 10)
        }
        // Small home escape hatch, mirroring the mission screen.
        .overlay(alignment: .topLeading) {
            Button {
                appState.navigationPath.removeAll()
            } label: {
                Image(systemName: "house.fill")
                    .font(.title3)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .padding(12)
                    .forestCard(cornerRadius: 18)
            }
            .buttonStyle(SquishyButtonStyle())
            .accessibilityLabel(String(localized: "Go back home"))
            .padding(.leading, ForestTheme.Metrics.screenPadding)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            dependencies.soundEngine.play(.starEarned)
            dependencies.hapticsService.playSuccess()
            await dependencies.speechService.speak(bundle.bunnyPhrase)
            shownStars = bundle.stars
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.bouncy(duration: 0.6)) { revealUnlocks = true }
            if !bundle.newlyUnlocked.isEmpty {
                await dependencies.speechService.speak(BunnyPhrase.forestGrew.text)
            }
        }
    }

    private var rewardRow: some View {
        HStack(spacing: 18) {
            rewardChip("🌰", bundle.seeds, String(localized: "seeds"), spotlight: emphasis == .seeds)
            rewardChip("🌸", bundle.flowers, String(localized: "flowers"), spotlight: false)
            if bundle.magicDust > 0 {
                rewardChip("✨", bundle.magicDust, String(localized: "magic dust"), spotlight: emphasis == .magicDust)
            }
        }
        .padding(16)
        .forestCard()
    }

    private func rewardChip(_ emoji: String, _ count: Int, _ label: String, spotlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: spotlight ? 44 : 36))
                .shadow(color: spotlight ? ForestTheme.Colors.sunshine.opacity(0.8) : .clear,
                        radius: spotlight ? 12 : 0)
            Text("+\(count)")
                .font(ForestTheme.Fonts.body)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(count) \(label) earned"))
    }

    private var unlocksSection: some View {
        VStack(spacing: 8) {
            Text(String(localized: "Your forest grew!"))
                .font(ForestTheme.Fonts.heading)
                .foregroundStyle(ForestTheme.Colors.deepGreen)
            HStack(spacing: 14) {
                ForEach(bundle.newlyUnlocked, id: \.self) { element in
                    VStack {
                        Text(element.emoji).font(.system(size: 44)).floating()
                        Text(element.localizedName)
                            .font(ForestTheme.Fonts.caption)
                            .foregroundStyle(ForestTheme.Colors.deepGreen)
                    }
                }
            }
        }
        .padding(16)
        .forestCard()
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }

    private var achievementsSection: some View {
        HStack(spacing: 12) {
            ForEach(bundle.newAchievements, id: \.self) { achievement in
                VStack {
                    Text(achievement.emoji).font(.system(size: 40))
                    Text(achievement.localizedTitle)
                        .font(ForestTheme.Fonts.caption)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                }
            }
        }
        .padding(14)
        .forestCard()
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }
}

// MARK: - Movement Break (2-minute animated exercise routine)

/// One kid exercise: a name, Bunny's instruction, and emoji "flip-book"
/// frames that animate without any Lottie assets.
private struct ExerciseStep {
    let title: String
    let instruction: String
    let frames: [String]
}

struct MovementBreakView: View {
    let activity: MovementBreak
    let dependencies: AppDependencies

    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let totalSeconds = 120        // 2 minutes of wiggling
    private static let secondsPerExercise = 15   // 8 exercises per routine

    /// Kid-safe, equipment-free exercises. Shuffled fresh every break.
    private static let allExercises: [ExerciseStep] = [
        ExerciseStep(title: String(localized: "Grow Like a Tree"),
                     instruction: String(localized: "Curl up small… now grow up taaaall like a tree!"),
                     frames: ["🧎", "🧍", "🙆"]),
        ExerciseStep(title: String(localized: "Jumping Jacks"),
                     instruction: String(localized: "Jump wide and clap your hands up high!"),
                     frames: ["🧍", "🤸"]),
        ExerciseStep(title: String(localized: "Toe Touches"),
                     instruction: String(localized: "Reach up high… now touch your toes!"),
                     frames: ["🙆", "🧍", "🙇"]),
        ExerciseStep(title: String(localized: "Bunny Hops"),
                     instruction: String(localized: "Hop hop hop like Bunny!"),
                     frames: ["🐰", "🐇"]),
        ExerciseStep(title: String(localized: "Arm Circles"),
                     instruction: String(localized: "Draw big circles with your arms!"),
                     frames: ["🙋", "💪", "🙆"]),
        ExerciseStep(title: String(localized: "Wiggle Dance"),
                     instruction: String(localized: "Shake and wiggle everywhere!"),
                     frames: ["💃", "🕺"]),
        ExerciseStep(title: String(localized: "Flamingo Balance"),
                     instruction: String(localized: "Stand on one leg, steady like a flamingo!"),
                     frames: ["🦩", "🧍"]),
        ExerciseStep(title: String(localized: "Reach for the Stars"),
                     instruction: String(localized: "Stretch way up and grab a star!"),
                     frames: ["🧍", "🙆", "🤩"])
    ]

    @State private var routine: [ExerciseStep] = MovementBreakView.allExercises.shuffled()
    @State private var stepIndex = 0
    @State private var secondsLeft = MovementBreakView.totalSeconds
    @State private var isDone = false

    private var currentStep: ExerciseStep { routine[min(stepIndex, routine.count - 1)] }

    var body: some View {
        ZStack {
            ForestTheme.Gradients.meadow.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Text(currentStep.title)
                    .font(ForestTheme.Fonts.title)
                    .foregroundStyle(.white)
                    .id(stepIndex)
                    .transition(.scale.combined(with: .opacity))

                // Flip-book exercise animation: frames swap on a timeline,
                // with a gentle bounce. Freezes on one frame for Reduce Motion.
                TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
                    let tick = Int(timeline.date.timeIntervalSinceReferenceDate / 0.5)
                    let frame = reduceMotion ? 0 : tick % currentStep.frames.count
                    Text(currentStep.frames[frame])
                        .font(.system(size: 130))
                        .scaleEffect(reduceMotion ? 1 : (tick.isMultiple(of: 2) ? 1.0 : 1.12))
                        .animation(.bouncy(duration: 0.45), value: tick)
                }
                .frame(height: 160)
                .accessibilityHidden(true)

                Text(currentStep.instruction)
                    .font(ForestTheme.Fonts.heading)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 30)
                    .id("instruction\(stepIndex)")
                    .transition(.opacity)

                // Exercise progress: one leaf per exercise.
                HStack(spacing: 6) {
                    ForEach(routine.indices, id: \.self) { index in
                        Image(systemName: "leaf.fill")
                            .font(.caption)
                            .foregroundStyle(index <= stepIndex
                                             ? ForestTheme.Colors.sunshine
                                             : .white.opacity(0.45))
                    }
                }
                .accessibilityLabel(String(localized: "Exercise \(stepIndex + 1) of \(routine.count)"))

                // A shrinking sun instead of scary countdown numbers.
                Circle()
                    .trim(from: 0, to: CGFloat(secondsLeft) / CGFloat(Self.totalSeconds))
                    .stroke(ForestTheme.Colors.sunshine, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: secondsLeft)
                    .accessibilityLabel(String(localized: "\(secondsLeft) seconds of wiggle time left"))

                Spacer()

                if isDone {
                    BigBouncyButton(
                        title: String(localized: "Back to the Forest!"),
                        icon: "tree.fill",
                        color: ForestTheme.Colors.sunshine
                    ) {
                        appState.navigationPath.removeAll()
                    }
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // Tired little legs can always stop early — never a failure.
                    Button {
                        secondsLeft = 0
                    } label: {
                        Text(String(localized: "All done!"))
                            .font(ForestTheme.Fonts.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.18)))
                    }
                    .buttonStyle(SquishyButtonStyle())
                    .padding(.bottom, 24)
                }
            }
            .adaptiveContentWidth(700)
            .animation(.bouncy(duration: 0.5), value: stepIndex)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // Gentle synthesized melody while the child moves — honors
            // the parent's Music setting, quiet under Bunny's voice.
            if appState.settings.isMusicEnabled {
                dependencies.breakMusicEngine.start()
            }
            await dependencies.speechService.speak(
                "\(BunnyPhrase.movementBreak.text) \(currentStep.instruction)"
            )
            while secondsLeft > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                secondsLeft -= 1

                // Next exercise every 15s; Bunny announces each one.
                let nextIndex = min((Self.totalSeconds - secondsLeft) / Self.secondsPerExercise,
                                    routine.count - 1)
                if nextIndex != stepIndex && secondsLeft > 0 {
                    stepIndex = nextIndex
                    dependencies.hapticsService.playGentleTap()
                    await dependencies.speechService.speak(routine[nextIndex].instruction)
                }
            }
            dependencies.breakMusicEngine.stop()
            dependencies.soundEngine.play(.correctChime)
            await dependencies.speechService.speak(BunnyPhrase.celebration.text)
            withAnimation(.bouncy(duration: 0.6)) { isDone = true }
        }
        .onDisappear { dependencies.breakMusicEngine.stop() }
    }
}
