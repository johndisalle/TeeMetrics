// MARK: - WidgetKit Extensions
// "Today's Round" and "Last Round Stats" widgets

import WidgetKit
import SwiftUI

// MARK: - Widget Timeline Entry
struct RoundWidgetEntry: TimelineEntry {
    let date: Date
    let courseName: String
    let score: Int
    let scoreToPar: String
    let putts: Int
    let fairwayPct: String
    let isActive: Bool
    let currentHole: Int

    static let placeholder = RoundWidgetEntry(
        date: .now,
        courseName: "Pine Valley GC",
        score: 78,
        scoreToPar: "+6",
        putts: 32,
        fairwayPct: "57%",
        isActive: false,
        currentHole: 0
    )
}

// MARK: - Widget Timeline Provider
struct RoundTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RoundWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (RoundWidgetEntry) -> Void) {
        completion(.placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RoundWidgetEntry>) -> Void) {
        // In production, read from shared SwiftData container or App Group UserDefaults
        let entry = RoundWidgetEntry.placeholder
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900)))
        completion(timeline)
    }
}

// MARK: - Last Round Widget View
struct LastRoundWidgetView: View {
    let entry: RoundWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundStyle(Color(red: 0, green: 0.39, blue: 0))
                Text("TeeMetrics")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            if entry.isActive {
                Text("Hole \(entry.currentHole)")
                    .font(.headline)
                Text(entry.courseName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(entry.courseName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack {
                Text("\(entry.score)")
                    .font(.title.bold())
                Text(entry.scoreToPar)
                    .font(.caption.bold())
                    .foregroundStyle(entry.scoreToPar.hasPrefix("+") ? .red : .green)
            }

            HStack(spacing: 8) {
                Label("\(entry.putts)", systemImage: "circle.fill")
                Label(entry.fairwayPct, systemImage: "leaf.fill")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget Configuration
struct TeeMetricsLastRoundWidget: Widget {
    let kind = "TeeMetricsLastRound"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RoundTimelineProvider()) { entry in
            LastRoundWidgetView(entry: entry)
        }
        .configurationDisplayName("Last Round")
        .description("Your most recent round stats at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Widget Bundle
struct TeeMetricsWidgetBundle: WidgetBundle {
    var body: some Widget {
        TeeMetricsLastRoundWidget()
    }
}
