//
//  HindiLearningViews.swift
//  Focus Forest Adventure
//
//  The Hindi Learning hub (category grid with progress) and the ONE
//  reusable lesson screen every module shares: swipeable bilingual flash
//  cards with hi-IN + English speech, then a listen-and-select quiz with
//  stars. Progress persists per module. Fully offline.
//

import SwiftUI

// MARK: - Progress storage

enum LearningProgress {
    static func bestScore(for moduleID: String) -> Int {
        UserDefaults.standard.integer(forKey: "hindi.quizBest.\(moduleID)")
    }

    static func recordScore(_ score: Int, for moduleID: String) {
        if score > bestScore(for: moduleID) {
            UserDefaults.standard.set(score, forKey: "hindi.quizBest.\(moduleID)")
        }
    }
}

// MARK: - Hub (category grid)

struct HindiLearningHomeView: View {
    let dependencies: AppDependencies

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 14)]

    var body: some View {
        ZStack {
            ForestTheme.Gradients.morningSky.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    Text(String(localized: "हिंदी सीखें"))
                        .font(ForestTheme.Fonts.title)
                        .foregroundStyle(ForestTheme.Colors.deepGreen)
                        .padding(.top, 12)
                        .accessibilityAddTraits(.isHeader)

                    LazyVGrid(columns: columns, spacing: 14) {
                        // Varnamala opens the dedicated alphabet explorer.
                        categoryCard(emoji: "📖",
                                     titleHindi: String(localized: "वर्णमाला"),
                                     titleEnglish: String(localized: "Hindi Alphabet"),
                                     progress: nil) {
                            dependencies.appState.navigationPath.append(.hindiAlphabet)
                        }

                        categoryCard(emoji: "🔤",
                                     titleHindi: String(localized: "बारहखड़ी"),
                                     titleEnglish: String(localized: "Barakhadi"),
                                     progress: nil) {
                            dependencies.appState.navigationPath.append(.barakhadi)
                        }

                        categoryCard(emoji: "✖️",
                                     titleHindi: String(localized: "पहाड़े"),
                                     titleEnglish: String(localized: "Times Tables"),
                                     progress: nil) {
                            dependencies.appState.navigationPath.append(.multiplicationTables)
                        }

                        categoryCard(emoji: "🎵",
                                     titleHindi: String(localized: "बाल गीत"),
                                     titleEnglish: String(localized: "Nursery Rhymes"),
                                     progress: nil) {
                            dependencies.appState.navigationPath.append(.rhymes)
                        }

                        categoryCard(emoji: "📚",
                                     titleHindi: String(localized: "कहानियाँ"),
                                     titleEnglish: String(localized: "Moral Stories"),
                                     progress: nil) {
                            dependencies.appState.navigationPath.append(.moralStories)
                        }

                        ForEach(HindiLearningCatalog.modules) { module in
                            let best = LearningProgress.bestScore(for: module.id)
                            categoryCard(emoji: module.emoji,
                                         titleHindi: module.titleHindi,
                                         titleEnglish: module.titleEnglish,
                                         progress: Double(best) / Double(HindiModuleView.quizRounds)) {
                                dependencies.appState.navigationPath.append(.hindiModule(module.id))
                            }
                        }
                    }
                }
                .padding(ForestTheme.Metrics.screenPadding)
                .adaptiveContentWidth(900)
            }
        }
        .navigationTitle(String(localized: "Hindi Learning"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func categoryCard(
        emoji: String, titleHindi: String, titleEnglish: String,
        progress: Double?, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(emoji).font(.system(size: 44))
                Text(titleHindi)
                    .font(ForestTheme.Fonts.body)
                    .foregroundStyle(ForestTheme.Colors.deepGreen)
                Text(titleEnglish)
                    .font(ForestTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                if let progress, progress > 0 {
                    Gauge(value: min(progress, 1)) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                        .tint(ForestTheme.Colors.leafGreen)
                        .frame(width: 90)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .forestCard(cornerRadius: 22)
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel("\(titleEnglish), \(titleHindi)")
    }
}

// MARK: - Module lesson (cards + quiz)

struct HindiModuleView: View {
    static let quizRounds = 5

    let module: LearningModule
    let dependencies: AppDependencies

    @State private var pageIndex = 0
    @State private var isQuizzing = false

    var body: some View {
        ZStack {
            ForestTheme.Gradients.meadow.ignoresSafeArea()

            if isQuizzing {
                LearningQuizView(module: module, dependencies: dependencies) {
                    isQuizzing = false
                }
            } else {
                lessonPager
            }
        }
        .navigationTitle("\(module.titleHindi) · \(module.titleEnglish)")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { dependencies.speechService.stop() }
    }

    private var lessonPager: some View {
        VStack(spacing: 14) {
            TabView(selection: $pageIndex) {
                ForEach(Array(module.items.enumerated()), id: \.offset) { index, item in
                    itemCard(item).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onAppear { speak(module.items[0]) }
            .onChange(of: pageIndex) { _, newIndex in
                dependencies.hapticsService.playGentleTap()
                speak(module.items[newIndex])
            }

            Text(String(localized: "\(pageIndex + 1) of \(module.items.count) · swipe to explore"))
                .font(ForestTheme.Fonts.caption)
                .foregroundStyle(.white.opacity(0.9))

            BigBouncyButton(
                title: String(localized: "Play Quiz!"),
                icon: "star.fill",
                color: ForestTheme.Colors.sunshine
            ) {
                dependencies.speechService.stop()
                isQuizzing = true
            }
            .padding(.bottom, 20)
        }
    }

    private func itemCard(_ item: LearningItem) -> some View {
        VStack(spacing: 16) {
            Text(item.emoji)
                .font(.system(size: 110))
                .floating(amplitude: 7, period: 2)

            Text(item.hindi)
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(ForestTheme.Colors.deepGreen)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(item.english)
                .font(ForestTheme.Fonts.heading)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                speakButton(module.language == nil ? "🔊" : "🇮🇳",
                            label: module.language == nil
                                ? String(localized: "Say it")
                                : String(localized: "Hindi")) {
                    speakPrimary(item.hindi)
                }
                speakButton("🔤", label: String(localized: "English")) {
                    Task { await dependencies.speechService.speak(item.english) }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .forestCard(cornerRadius: 28)
        .padding(.horizontal, 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.hindi), \(item.english)")
    }

    private func speakButton(_ emoji: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(emoji).font(.title2)
                Text(label).font(ForestTheme.Fonts.caption)
            }
            .foregroundStyle(ForestTheme.Colors.deepGreen)
            .padding(.horizontal, 18).padding(.vertical, 8)
            .forestCard(cornerRadius: 16)
        }
        .buttonStyle(SquishyButtonStyle())
        .accessibilityLabel(String(localized: "Hear it in \(label)"))
    }

    private func speak(_ item: LearningItem) {
        speakPrimary(item.hindi)
    }

    private func speakPrimary(_ text: String) {
        Task {
            if let language = module.language {
                await dependencies.speechService.speak(text, language: language)
            } else {
                await dependencies.speechService.speak(text)
            }
        }
    }
}

// MARK: - Listen-and-select quiz

struct LearningQuizView: View {
    let module: LearningModule
    let dependencies: AppDependencies
    let onFinished: () -> Void

    @State private var round = 0
    @State private var score = 0
    @State private var target: LearningItem?
    @State private var options: [LearningItem] = []
    @State private var isDone = false
    @State private var shakingID: String?

    var body: some View {
        VStack(spacing: 20) {
            if isDone {
                results
            } else if let target {
                Text(String(localized: "Listen! Which one is it?"))
                    .font(ForestTheme.Fonts.heading)
                    .foregroundStyle(.white)

                // Stars earned so far
                HStack(spacing: 6) {
                    ForEach(0..<HindiModuleView.quizRounds, id: \.self) { star in
                        Image(systemName: star < score ? "star.fill" : "star")
                            .foregroundStyle(ForestTheme.Colors.sunshine)
                    }
                }
                .accessibilityLabel(String(localized: "\(score) stars earned"))

                Button {
                    speakTarget()
                } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                        .frame(width: 84, height: 84)
                        .background(Circle().fill(ForestTheme.Colors.leafGreen))
                }
                .buttonStyle(SquishyButtonStyle())
                .accessibilityLabel(String(localized: "Hear the word again"))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 14)], spacing: 14) {
                    ForEach(options) { option in
                        Button {
                            tapped(option, target: target)
                        } label: {
                            Text(option.emoji)
                                .font(.system(size: 64))
                                .frame(maxWidth: .infinity, minHeight: 110)
                                .forestCard(cornerRadius: 22)
                        }
                        .buttonStyle(SquishyButtonStyle())
                        .gentleShake(trigger: shakingID == option.id)
                        .accessibilityLabel(option.english)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear { nextRound() }
    }

    private var results: some View {
        VStack(spacing: 16) {
            ConfettiView(particleCount: 60).ignoresSafeArea().allowsHitTesting(false)
            Text(score == HindiModuleView.quizRounds
                 ? String(localized: "शाबाश! Perfect!")
                 : String(localized: "बहुत अच्छे! You earned \(score) stars!"))
                .font(ForestTheme.Fonts.title)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            BigBouncyButton(
                title: String(localized: "Back to cards"),
                icon: "book.fill",
                color: ForestTheme.Colors.sunshine
            ) {
                onFinished()
            }
        }
        .padding(24)
    }

    private func nextRound() {
        guard round < HindiModuleView.quizRounds else {
            LearningProgress.recordScore(score, for: module.id)
            dependencies.hapticsService.playSuccess()
            Task { await dependencies.speechService.speak(String(localized: "शाबाश!"), language: "hi-IN") }
            isDone = true
            return
        }
        round += 1
        let picked = module.items.shuffled().prefix(4)
        options = Array(picked)
        target = picked.first
        options.shuffle()
        speakTarget()
    }

    private func speakTarget() {
        guard let target else { return }
        Task {
            if let language = module.language {
                await dependencies.speechService.speak(target.hindi, language: language)
            } else {
                await dependencies.speechService.speak(target.hindi)
            }
        }
    }

    private func tapped(_ option: LearningItem, target: LearningItem) {
        if option.id == target.id {
            score += 1
            dependencies.hapticsService.playSuccess()
            dependencies.soundEngine.play(.starEarned)
            nextRound()
        } else {
            shakingID = option.id
            dependencies.hapticsService.playSoftWobble()
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                shakingID = nil
            }
        }
    }
}
