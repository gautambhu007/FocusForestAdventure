//
//  TablesView.swift
//  Focus Forest Adventure
//
//  Multiplication tables 2–20: pick a table, hear each line read aloud,
//  then a five-question practice quiz with four answer choices.
//  Best quiz score per table persists (same store as other modules).
//

import SwiftUI

struct TablesView: View {
    let dependencies: AppDependencies

    @State private var table = 2
    @State private var isQuizzing = false

    var body: some View {
        ZStack {
            ForestSceneBackground(place: .meadow, legibility: 0.22)

            if isQuizzing {
                TableQuizView(table: table, dependencies: dependencies) {
                    isQuizzing = false
                }
            } else {
                learnView
            }
        }
        .navigationTitle(String(localized: "पहाड़े · Tables"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { dependencies.speechService.stop() }
    }

    private var learnView: some View {
        VStack(spacing: 12) {
            // Table picker 2–20
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(2...20, id: \.self) { n in
                        Button {
                            table = n
                            dependencies.hapticsService.playGentleTap()
                        } label: {
                            Text("\(n)")
                                .font(ForestTheme.Fonts.body)
                                .foregroundStyle(table == n ? .white : ForestTheme.Colors.deepGreen)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(table == n
                                                          ? ForestTheme.Colors.leafGreen
                                                          : ForestTheme.Colors.cloudWhite))
                        }
                        .buttonStyle(SquishyButtonStyle())
                        .accessibilityLabel(String(localized: "Table of \(n)"))
                    }
                }
                .padding(.horizontal, ForestTheme.Metrics.screenPadding)
                .padding(.vertical, 8)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(1...10, id: \.self) { i in
                        Button {
                            speakLine(i)
                        } label: {
                            HStack {
                                Text("\(table) × \(i)")
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                Spacer()
                                Text("= \(table * i)")
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                Image(systemName: "speaker.wave.2")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(ForestTheme.Colors.deepGreen)
                            .padding(.horizontal, 20).padding(.vertical, 12)
                            .forestCard(cornerRadius: 16)
                        }
                        .buttonStyle(SquishyButtonStyle())
                        .accessibilityLabel(String(localized: "\(table) times \(i) equals \(table * i)"))
                    }
                }
                .padding(.horizontal, ForestTheme.Metrics.screenPadding)
                .adaptiveContentWidth(600)
            }

            BigBouncyButton(
                title: String(localized: "Practice Quiz!"),
                icon: "star.fill",
                color: ForestTheme.Colors.sunshine
            ) {
                dependencies.speechService.stop()
                isQuizzing = true
            }
            .padding(.bottom, 16)
        }
    }

    private func speakLine(_ i: Int) {
        dependencies.hapticsService.playGentleTap()
        Task {
            await dependencies.speechService.speak(
                String(localized: "\(table) times \(i) is \(table * i)")
            )
        }
    }
}

// MARK: - Practice quiz

struct TableQuizView: View {
    let table: Int
    let dependencies: AppDependencies
    let onFinished: () -> Void

    private static let rounds = 5

    @State private var round = 0
    @State private var score = 0
    @State private var multiplier = 1
    @State private var choices: [Int] = []
    @State private var isDone = false
    @State private var shaking: Int?

    var body: some View {
        VStack(spacing: 20) {
            if isDone {
                VStack(spacing: 16) {
                    ConfettiView(particleCount: 50).ignoresSafeArea().allowsHitTesting(false)
                    Text(String(localized: "You earned \(score) of \(Self.rounds) stars!"))
                        .font(ForestTheme.Fonts.title)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    BigBouncyButton(
                        title: String(localized: "Back to tables"),
                        icon: "book.fill",
                        color: ForestTheme.Colors.sunshine
                    ) { onFinished() }
                }
                .padding(24)
            } else {
                HStack(spacing: 6) {
                    ForEach(0..<Self.rounds, id: \.self) { star in
                        Image(systemName: star < score ? "star.fill" : "star")
                            .foregroundStyle(ForestTheme.Colors.sunshine)
                    }
                }

                Text("\(table) × \(multiplier) = ?")
                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .accessibilityLabel(String(localized: "\(table) times \(multiplier) equals what?"))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 14)], spacing: 14) {
                    ForEach(choices, id: \.self) { choice in
                        Button {
                            tapped(choice)
                        } label: {
                            Text("\(choice)")
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                                .foregroundStyle(ForestTheme.Colors.deepGreen)
                                .frame(maxWidth: .infinity, minHeight: 96)
                                .forestCard(cornerRadius: 20)
                        }
                        .buttonStyle(SquishyButtonStyle())
                        .gentleShake(trigger: shaking == choice)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear { nextRound() }
    }

    private func nextRound() {
        guard round < Self.rounds else {
            LearningProgress.recordScore(score, for: "table\(table)")
            dependencies.hapticsService.playSuccess()
            isDone = true
            return
        }
        round += 1
        multiplier = Int.random(in: 1...10)
        let answer = table * multiplier
        var set: Set<Int> = [answer]
        while set.count < 4 {
            let near = answer + [table, -table, 1, -1, 2, -2].randomElement()! * Int.random(in: 1...2)
            if near > 0 { set.insert(near) }
        }
        choices = Array(set).shuffled()
        Task {
            await dependencies.speechService.speak(String(localized: "What is \(table) times \(multiplier)?"))
        }
    }

    private func tapped(_ choice: Int) {
        if choice == table * multiplier {
            score += 1
            dependencies.hapticsService.playSuccess()
            dependencies.soundEngine.play(.starEarned)
            nextRound()
        } else {
            shaking = choice
            dependencies.hapticsService.playSoftWobble()
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                shaking = nil
            }
        }
    }
}
