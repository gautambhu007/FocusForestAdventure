//
//  ParentDashboardView.swift
//  Focus Forest Adventure
//
//  PIN-protected parent analytics: focus duration, subject strengths,
//  weekly/monthly charts (Swift Charts), achievements, AI recommendations.
//

import SwiftUI
import Charts
import Observation

@Observable
@MainActor
final class ParentDashboardViewModel {

    private let dependencies: AppDependencies

    private(set) var summary: PerformanceSummary?
    private(set) var recommendations: [String] = []
    private(set) var achievements: [AchievementRecord] = []
    private(set) var childName = ""
    /// Phase 2.3: week-over-week trend + streak (always 14-day based).
    private(set) var insights = DashboardInsights()
    /// Phase 2.3/2.8: what the app will adapt next, in plain language.
    private(set) var adaptationNotes: [String] = []
    /// Puzzle Adventure World: the seven-skill table + plain-language lines.
    private(set) var cognitiveProfile: [CognitiveRating] = []
    private(set) var puzzleNotes: [String] = []
    private(set) var puzzleGems = 0
    private(set) var puzzleBadges: [PuzzleBadge] = []
    private(set) var puzzleCrystals: [MagicCrystal] = []
    private(set) var hasPuzzleHistory = false
    /// Phase 2.4: export files, regenerated on each load.
    private(set) var pdfReportURL: URL?
    private(set) var csvReportURL: URL?
    var rangeDays = 7 {
        didSet { Task { await load() } }
    }
    /// Parent-controlled daily play limit (minutes, 0 = off).
    var dailyLimitMinutes: Int = 0 {
        didSet {
            dependencies.appState.settings.dailyLimitMinutes = dailyLimitMinutes
            UserDefaults.standard.set(dailyLimitMinutes, forKey: "settings.dailyLimit")
        }
    }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.dailyLimitMinutes = UserDefaults.standard.integer(forKey: "settings.dailyLimit")
    }

    func load() async {
        do {
            let child = try dependencies.childRepository.activeChild()
            childName = child.name
            let summary = try dependencies.fetchStatisticsUseCase.execute(child: child, days: rangeDays)
            self.summary = summary
            self.recommendations = dependencies.recommendationEngine.parentRecommendations(summary: summary)
            self.achievements = try dependencies.achievementRepository.earned(for: child)

            // Phase 2.3: trend/streak always use a 14-day window.
            let fortnight = try dependencies.fetchStatisticsUseCase.execute(child: child, days: 14)
            self.insights = DashboardInsights.compute(dailyFocus: fortnight.dailyFocus)

            // Phase 2.8: explain what the app adapts next.
            let daily = dependencies.recommendationEngine.makeDailyRecommendations(
                summary: summary,
                preference: dependencies.appState.settings.preferredDifficulty
            )
            self.adaptationNotes = daily.parentExplanations

            // Puzzle Adventure World, reported in cognitive-skill terms.
            let puzzles = try dependencies.puzzleRepository.snapshot(for: child)
            let engine = dependencies.puzzleProgressionEngine
            self.cognitiveProfile = engine.cognitiveProfile(snapshot: puzzles)
            self.puzzleNotes = engine.parentSummary(
                snapshot: puzzles,
                age: dependencies.appState.settings.childAge
            )
            self.puzzleGems = puzzles.gems
            self.puzzleBadges = PuzzleBadge.allCases.filter { puzzles.badges.contains($0) }
            self.puzzleCrystals = puzzles.earnedCrystals
            self.hasPuzzleHistory = puzzles.puzzlesAttempted > 0

            // Phase 2.4: refresh shareable reports.
            let report = ReportBuilder().makeReport(
                childName: child.name,
                rangeDays: rangeDays,
                summary: summary,
                achievements: achievements.compactMap(\.achievementID),
                recommendations: recommendations + adaptationNotes
            )
            self.csvReportURL = try? ReportExporter.writeCSV(report)
            self.pdfReportURL = try? ReportExporter.writePDF(report)
        } catch {
            assertionFailure("Dashboard load failed: \(error)")
        }
    }

    var strongSubjects: [(AdventureKind, Double)] {
        (summary?.perSubject ?? [:])
            .filter { $0.value.missions >= 2 && $0.value.accuracy >= 0.75 }
            .map { ($0.key, $0.value.accuracy) }
            .sorted { $0.1 > $1.1 }
    }

    var growingSubjects: [(AdventureKind, Double)] {
        (summary?.perSubject ?? [:])
            .filter { $0.value.missions >= 2 && $0.value.accuracy < 0.6 }
            .map { ($0.key, $0.value.accuracy) }
            .sorted { $0.1 < $1.1 }
    }

    var dailyFocusPoints: [(day: Date, minutes: Double)] {
        (summary?.dailyFocus ?? [:])
            .map { (day: $0.key, minutes: $0.value / 60) }
            .sorted { $0.day < $1.day }
    }

    var totalFocusMinutes: Int { Int((summary?.totalFocusSeconds ?? 0) / 60) }
    var averageAttention: Int { Int((summary?.averageAttentionScore ?? 0) * 100) }
}

struct ParentDashboardView: View {
    @State var viewModel: ParentDashboardViewModel

    var body: some View {
        List {
            Section {
                Picker(String(localized: "Range"), selection: Binding(
                    get: { viewModel.rangeDays },
                    set: { viewModel.rangeDays = $0 }
                )) {
                    Text(String(localized: "Week")).tag(7)
                    Text(String(localized: "Month")).tag(30)
                }
                .pickerStyle(.segmented)
            }

            Section(String(localized: "Overview")) {
                LabeledContent(String(localized: "Focus time"),
                               value: String(localized: "\(viewModel.totalFocusMinutes) min"))
                LabeledContent(String(localized: "Missions completed"),
                               value: "\(viewModel.summary?.totalMissions ?? 0)")
                LabeledContent(String(localized: "Average attention"),
                               value: "\(viewModel.averageAttention)%")
                LabeledContent(String(localized: "Learning streak"),
                               value: String(localized: "🔥 \(DailyStreak.current()) day(s)"))
            }

            Section {
                Picker(String(localized: "Daily play limit"), selection: Binding(
                    get: { viewModel.dailyLimitMinutes },
                    set: { viewModel.dailyLimitMinutes = $0 }
                )) {
                    Text(String(localized: "Off")).tag(0)
                    Text(String(localized: "15 min")).tag(15)
                    Text(String(localized: "30 min")).tag(30)
                    Text(String(localized: "45 min")).tag(45)
                    Text(String(localized: "60 min")).tag(60)
                }
                LabeledContent(String(localized: "Played today"),
                               value: String(localized: "\(DailyUsage.todayMinutes()) min"))
            } header: {
                Text(String(localized: "Screen time"))
            } footer: {
                Text(String(localized: "When the limit is reached, the child sees a gentle 'forest is sleeping' screen until tomorrow. You can always change it here."))
            }

            Section(String(localized: "This week")) {
                LabeledContent(String(localized: "Focus this week"),
                               value: String(localized: "\(viewModel.insights.thisWeekMinutes) min"))
                if let trend = viewModel.insights.weeklyTrendPercent {
                    LabeledContent(String(localized: "vs last week")) {
                        Label("\(abs(trend))%",
                              systemImage: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .foregroundStyle(trend >= 0 ? ForestTheme.Colors.leafGreen : .orange)
                    }
                } else {
                    Text(String(localized: "Trends appear after two weeks of play."))
                        .foregroundStyle(.secondary)
                }
                LabeledContent(String(localized: "Play streak"),
                               value: viewModel.insights.currentStreakDays > 0
                                   ? String(localized: "\(viewModel.insights.currentStreakDays) day(s) 🔥")
                                   : String(localized: "Ready for a fresh start!"))
            }

            Section(String(localized: "Daily focus")) {
                Chart(viewModel.dailyFocusPoints, id: \.day) { point in
                    BarMark(
                        x: .value("Day", point.day, unit: .day),
                        y: .value("Minutes", point.minutes)
                    )
                    .foregroundStyle(ForestTheme.Colors.leafGreen.gradient)
                    .cornerRadius(6)
                }
                .frame(height: 200)
                .chartYAxisLabel(String(localized: "minutes"))
                .accessibilityLabel(String(localized: "Daily focus chart"))
            }

            subjectSection(
                title: String(localized: "Strong subjects"),
                items: viewModel.strongSubjects,
                symbol: "star.fill",
                tint: ForestTheme.Colors.sunshine
            )
            subjectSection(
                title: String(localized: "Still growing"),
                items: viewModel.growingSubjects,
                symbol: "leaf.fill",
                tint: ForestTheme.Colors.leafGreen
            )

            Section(String(localized: "Recommendations")) {
                ForEach(viewModel.recommendations, id: \.self) { tip in
                    Label(tip, systemImage: "lightbulb.fill")
                        .foregroundStyle(.primary)
                }
            }

            Section {
                ForEach(viewModel.adaptationNotes, id: \.self) { note in
                    Label(note, systemImage: "wand.and.stars")
                        .foregroundStyle(.primary)
                }
            } header: {
                Text(String(localized: "What adapts next"))
            } footer: {
                Text(String(localized: "All personalization happens on this device, from play history only."))
            }

            Section {
                if !viewModel.hasPuzzleHistory {
                    Text(String(localized: "No puzzles played yet — find them under 🧩 Puzzles on the home screen."))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.cognitiveProfile) { rating in
                        LabeledContent(rating.skill.localizedName) {
                            Text(rating.starDisplay)
                                .font(rating.stars == nil ? .footnote : .body)
                                .foregroundStyle(rating.stars == nil ? .secondary : .primary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            rating.stars.map {
                                String(localized: "\(rating.skill.localizedName): \($0) of 5 stars")
                            } ?? String(localized: "\(rating.skill.localizedName): not enough play yet")
                        )
                    }
                    if !viewModel.puzzleCrystals.isEmpty {
                        LabeledContent(String(localized: "Crystals won")) {
                            Text(viewModel.puzzleCrystals.map(\.emoji).joined(separator: " "))
                        }
                    }
                    LabeledContent(String(localized: "Magic gems"), value: "💎 \(viewModel.puzzleGems)")
                    if !viewModel.puzzleBadges.isEmpty {
                        LabeledContent(String(localized: "Badges")) {
                            Text(viewModel.puzzleBadges.map(\.emoji).joined(separator: " "))
                        }
                    }
                }
            } header: {
                Text(String(localized: "Puzzle skills"))
            } footer: {
                if viewModel.hasPuzzleHistory {
                    Text(viewModel.puzzleNotes.joined(separator: "\n"))
                } else {
                    Text(String(localized: "Ratings appear once your child has played a few puzzles. Every skill is measured from play only — nothing leaves this device."))
                }
            }

            Section {
                let played = HindiLearningCatalog.modules
                    .map { ($0, LearningProgress.bestScore(for: $0.id)) }
                    .filter { $0.1 > 0 }
                if played.isEmpty {
                    Text(String(localized: "No Hindi quizzes played yet — find them under हिंदी on the home screen."))
                        .foregroundStyle(.secondary)
                }
                ForEach(played, id: \.0.id) { module, best in
                    LabeledContent("\(module.emoji) \(module.titleEnglish)",
                                   value: "\(best)/\(HindiModuleView.quizRounds) ⭐")
                }
            } header: {
                Text(String(localized: "Hindi learning"))
            } footer: {
                let weak = HindiLearningCatalog.modules
                    .filter { (1..<3).contains(LearningProgress.bestScore(for: $0.id)) }
                    .map(\.titleEnglish)
                if !weak.isEmpty {
                    Text(String(localized: "Could use more practice: \(weak.joined(separator: ", "))."))
                }
            }

            Section {
                if let pdf = viewModel.pdfReportURL {
                    ShareLink(item: pdf) {
                        Label(String(localized: "Share PDF report"), systemImage: "doc.richtext")
                    }
                }
                if let csv = viewModel.csvReportURL {
                    ShareLink(item: csv) {
                        Label(String(localized: "Share CSV data"), systemImage: "tablecells")
                    }
                }
                if let certificate = try? ReportExporter.writeCertificate(
                    childName: viewModel.childName.isEmpty ? String(localized: "Explorer") : viewModel.childName,
                    stars: LearningProgress.totalStars()
                ) {
                    ShareLink(item: certificate) {
                        Label(String(localized: "Print achievement certificate"), systemImage: "rosette")
                    }
                }
            } header: {
                Text(String(localized: "Teacher mode"))
            } footer: {
                Text(String(localized: "Share via AirDrop, email, or print — reports contain progress data only, no personal details beyond the first name."))
            }

            Section(String(localized: "Achievements")) {
                if viewModel.achievements.isEmpty {
                    Text(String(localized: "The first badge is just one mission away!"))
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.achievements, id: \.persistentModelID) { record in
                    if let id = record.achievementID {
                        LabeledContent {
                            Text(record.earnedAt, style: .date)
                        } label: {
                            Text("\(id.emoji) \(id.localizedTitle)")
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.childName.isEmpty
                         ? String(localized: "Dashboard")
                         : String(localized: "\(viewModel.childName)'s Journey"))
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private func subjectSection(
        title: String,
        items: [(AdventureKind, Double)],
        symbol: String,
        tint: Color
    ) -> some View {
        Section(title) {
            if items.isEmpty {
                Text(String(localized: "Not enough data yet — keep playing!"))
                    .foregroundStyle(.secondary)
            }
            ForEach(items, id: \.0) { kind, accuracy in
                HStack {
                    Label("\(kind.emoji) \(kind.localizedTitle)", systemImage: symbol)
                        .foregroundStyle(.primary)
                        .labelStyle(.titleOnly)
                    Spacer()
                    Gauge(value: accuracy) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                        .tint(tint)
                        .frame(width: 90)
                    Text("\(Int(accuracy * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "\(kind.localizedTitle): \(Int(accuracy * 100)) percent correct"))
            }
        }
    }
}
