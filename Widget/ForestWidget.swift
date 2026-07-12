//
//  ForestWidget.swift
//  ForestWidgetExtension
//
//  Home-screen widget showing today's goal progress and forest level.
//  Data is shared via an App Group UserDefaults suite, written by the app
//  after every mission.
//

import WidgetKit
import SwiftUI

// MARK: - Shared snapshot (written by the main app)

struct ForestWidgetSnapshot: Codable {
    var forestLevel: Int = 1
    var levelName: String = "Sleepy Meadow"
    var goalProgress: Double = 0
    var stars: Int = 0
    var lastUpdated: Date = .distantPast

    static let suiteName = "group.com.focusforest.adventure"
    static let key = "forestWidgetSnapshot"

    static func load() -> ForestWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(ForestWidgetSnapshot.self, from: data)
        else { return ForestWidgetSnapshot() }
        return snapshot
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: Self.suiteName),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
        WidgetCenter.shared.reloadTimelines(ofKind: "ForestWidget")
    }
}

// MARK: - Timeline

struct ForestEntry: TimelineEntry {
    let date: Date
    let snapshot: ForestWidgetSnapshot
}

struct ForestTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ForestEntry {
        ForestEntry(date: .now, snapshot: ForestWidgetSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (ForestEntry) -> Void) {
        completion(ForestEntry(date: .now, snapshot: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ForestEntry>) -> Void) {
        let entry = ForestEntry(date: .now, snapshot: .load())
        // Refresh a few times a day; the app force-reloads after missions anyway.
        let next = Calendar.current.date(byAdding: .hour, value: 4, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

struct ForestWidgetEntryView: View {
    var entry: ForestEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🌳").font(.title2)
                Text(entry.snapshot.levelName)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .lineLimit(1)
                Spacer()
            }

            Gauge(value: entry.snapshot.goalProgress) {
                Text("Today")
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(.green)

            HStack {
                Label("\(entry.snapshot.stars)", systemImage: "star.fill")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(.yellow)
                Spacer()
                if entry.snapshot.goalProgress >= 1 {
                    Text("Goal done! 🎉").font(.caption2)
                } else {
                    Text("Level \(entry.snapshot.forestLevel)").font(.caption2)
                }
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: [.mint.opacity(0.4), .green.opacity(0.2)],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

struct ForestWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ForestWidget", provider: ForestTimelineProvider()) { entry in
            ForestWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Focus Forest")
        .description("See today's adventure progress and your growing forest.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ForestWidgetBundle: WidgetBundle {
    var body: some Widget {
        ForestWidget()
    }
}
