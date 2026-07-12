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
    var rangeDays = 7 {
        didSet { Task { await load() } }
    }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    func load() async {
        do {
            let child = try dependencies.childRepository.activeChild()
            childName = child.name
            let summary = try dependencies.fetchStatisticsUseCase.execute(child: child, days: rangeDays)
            self.summary = summary
            self.recommendations = dependencies.recommendationEngine.parentRecommendations(summary: summary)
            self.achievements = try dependencies.achievementRepository.earned(for: child)
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
