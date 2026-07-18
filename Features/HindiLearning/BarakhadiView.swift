//
//  BarakhadiView.swift
//  Focus Forest Adventure
//
//  Interactive Hindi barakhadi chart: pick a consonant, see its twelve
//  matra forms (क का कि की कु कू के कै को कौ कं कः), tap any form to
//  hear it in Hindi. Forms are generated programmatically from the
//  consonant + combining matras — no data tables needed.
//

import SwiftUI

struct BarakhadiView: View {
    let dependencies: AppDependencies

    /// Combining matras with their romanization.
    private static let matras: [(mark: String, roman: String)] = [
        ("", "a"), ("ा", "aa"), ("ि", "i"), ("ी", "ee"),
        ("ु", "u"), ("ू", "oo"), ("े", "e"), ("ै", "ai"),
        ("ो", "o"), ("ौ", "au"), ("ं", "an"), ("ः", "ah")
    ]

    /// Base consonants only (single scalar — excludes conjuncts & nuktas).
    private let consonants = HindiAlphabet.consonants
        .filter { $0.letter.unicodeScalars.count == 1 }

    @State private var selected = 0
    @State private var tappedForm: String?

    // Quiz mode
    @State private var isQuizzing = false
    @State private var quizRound = 0
    @State private var quizScore = 0
    @State private var quizTarget = ""
    @State private var quizChoices: [String] = []
    @State private var quizDone = false
    @State private var shakingChoice: String?

    private let columns = [GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 12)]

    var body: some View {
        ZStack {
            ForestTheme.Gradients.morningSky.ignoresSafeArea()

            if isQuizzing {
                quizView
            } else {
                chartView
            }
        }
        .navigationTitle(String(localized: "बारहखड़ी · Barakhadi"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { dependencies.speechService.stop() }
    }

    // MARK: Quiz mode ("listen and find the form")

    private var quizView: some View {
        VStack(spacing: 18) {
            if quizDone {
                ConfettiView(particleCount: 50).ignoresSafeArea().allowsHitTesting(false)
                Text(String(localized: "You earned \(quizScore) of 5 stars!"))
                    .font(ForestTheme.Fonts.title)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                    .multilineTextAlignment(.center)
                BigBouncyButton(title: String(localized: "Back to chart"),
                                icon: "square.grid.3x3.fill",
                                color: ForestTheme.Colors.sunshine) {
                    isQuizzing = false
                }
            } else {
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { star in
                        Image(systemName: star < quizScore ? "star.fill" : "star")
                            .foregroundStyle(ForestTheme.Colors.sunshine)
                    }
                }

                Text(String(localized: "Listen! Find the matching sound"))
                    .font(ForestTheme.Fonts.heading)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)

                Button {
                    speak(quizTarget)
                } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(ForestTheme.Colors.leafGreen))
                }
                .buttonStyle(SquishyButtonStyle())

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 14)], spacing: 14) {
                    ForEach(quizChoices, id: \.self) { choice in
                        Button {
                            quizTapped(choice)
                        } label: {
                            Text(choice)
                                .font(.system(size: 44, weight: .heavy, design: .rounded))
                                .foregroundStyle(ForestTheme.Colors.deepGreen)
                                .frame(maxWidth: .infinity, minHeight: 96)
                                .forestCard(cornerRadius: 20)
                        }
                        .buttonStyle(SquishyButtonStyle())
                        .gentleShake(trigger: shakingChoice == choice)
                        .accessibilityLabel(choice)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .adaptiveContentWidth(600)
    }

    private func startQuiz() {
        quizRound = 0
        quizScore = 0
        quizDone = false
        isQuizzing = true
        nextQuizRound()
    }

    private func nextQuizRound() {
        guard quizRound < 5 else {
            LearningProgress.recordScore(quizScore, for: "barakhadi")
            dependencies.hapticsService.playSuccess()
            quizDone = true
            return
        }
        quizRound += 1
        // One consonant, four of its matra forms — hear one, find it.
        let consonant = consonants.randomElement()!.letter
        let forms = Self.matras.shuffled().prefix(4).map { consonant + $0.mark }
        quizChoices = Array(forms)
        quizTarget = forms.randomElement()!
        speak(quizTarget)
    }

    private func quizTapped(_ choice: String) {
        if choice == quizTarget {
            quizScore += 1
            dependencies.hapticsService.playSuccess()
            dependencies.soundEngine.play(.starEarned)
            nextQuizRound()
        } else {
            shakingChoice = choice
            dependencies.hapticsService.playSoftWobble()
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                shakingChoice = nil
            }
        }
    }

    // MARK: Chart mode

    private var chartView: some View {
            VStack(spacing: 12) {
                // Consonant picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(consonants.indices, id: \.self) { index in
                            Button {
                                selected = index
                                dependencies.hapticsService.playGentleTap()
                                speak(consonants[index].letter)
                            } label: {
                                Text(consonants[index].letter)
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                    .foregroundStyle(selected == index
                                                     ? .white : ForestTheme.Colors.deepGreen)
                                    .frame(width: 52, height: 52)
                                    .background(
                                        Circle().fill(selected == index
                                                      ? ForestTheme.Colors.leafGreen
                                                      : ForestTheme.Colors.cloudWhite)
                                    )
                            }
                            .buttonStyle(SquishyButtonStyle())
                        }
                    }
                    .padding(.horizontal, ForestTheme.Metrics.screenPadding)
                    .padding(.vertical, 8)
                }

                // The twelve forms
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Self.matras, id: \.roman) { matra in
                            let form = consonants[selected].letter + matra.mark
                            Button {
                                tappedForm = form
                                dependencies.hapticsService.playGentleTap()
                                speak(form)
                            } label: {
                                VStack(spacing: 4) {
                                    Text(form)
                                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                                    Text(romanized(matra))
                                        .font(ForestTheme.Fonts.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 96)
                                .forestCard(cornerRadius: 18)
                                .scaleEffect(tappedForm == form ? 1.1 : 1.0)
                                .animation(.bouncy(duration: 0.3), value: tappedForm)
                            }
                            .buttonStyle(SquishyButtonStyle())
                            .accessibilityLabel(form)
                        }
                    }
                    .padding(ForestTheme.Metrics.screenPadding)
                    .adaptiveContentWidth(700)
                }

                BigBouncyButton(
                    title: String(localized: "Practice Quiz!"),
                    icon: "star.fill",
                    color: ForestTheme.Colors.sunshine
                ) {
                    dependencies.speechService.stop()
                    startQuiz()
                }
                .padding(.bottom, 14)
            }
    }

    private func romanized(_ matra: (mark: String, roman: String)) -> String {
        let base = consonants[selected].roman.lowercased()
        // "ka" style: consonant roman minus trailing 'a' + matra sound.
        let stem = base.hasSuffix("a") ? String(base.dropLast()) : base
        return stem + matra.roman
    }

    private func speak(_ text: String) {
        Task {
            await dependencies.speechService.speak(text, language: "hi-IN")
        }
    }
}
