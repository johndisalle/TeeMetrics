// MARK: - WidgetKit Extensions
// Real widgets reading from UserDefaults shared via App Group
// "Last Round" and "Today's Round" widgets

import WidgetKit
import SwiftUI

// MARK: - Shared Data Keys (duplicated here since widget is a separate target)
private enum Keys {
    static let suiteName = "group.com.teemetrics.shared"
    static let lastCourseName = "widget_lastCourseName"
    static let lastScore = "widget_lastScore"
    static let lastScoreToPar = "widget_lastScoreToPar"
    static let lastPutts = "widget_lastPutts"
    static let lastFairway = "widget_lastFairway"
    static let lastDate = "widget_lastDate"
    static let activeHole = "widget_activeHole"
    static let activeCourseName = "widget_activeCourseName"
    static let activeRunningScore = "widget_activeRunningScore"
    static let isRoundActive = "widget_isRoundActive"
    static let handicap = "widget_handicap"
    static let roundCount = "widget_roundCount"
}

// MARK: - Widget Timeline Entry
struct RoundWidgetEntry: TimelineEntry {
    let date: Date
    let courseName: String
    let score: Int
    let scoreToPar: String
    let putts: Int
    let fairwayPct: String
    let roundDate: String
    let isActive: Bool
    let currentHole: Int
    let runningScore: Int
    let handicap: Double
    let roundCount: Int

    static let placeholder = RoundWidgetEntry(
        date: .now, courseName: "Pine Valley GC", score: 78,
        scoreToPar: "+6", putts: 32, fairwayPct: "57%", roundDate: "Today",
        isActive: false, currentHole: 0, runningScore: 0,
        handicap: 15.2, roundCount: 12
    )
}

// MARK: - Timeline Provider
struct RoundTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RoundWidgetEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (RoundWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RoundWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(300)))
        completion(timeline)
    }

    private func loadEntry() -> RoundWidgetEntry {
        guard let defaults = UserDefaults(suiteName: Keys.suiteName) else { return .placeholder }
        return RoundWidgetEntry(
            date: .now,
            courseName: defaults.string(forKey: Keys.lastCourseName) ?? "No rounds yet",
            score: defaults.integer(forKey: Keys.lastScore),
            scoreToPar: defaults.string(forKey: Keys.lastScoreToPar) ?? "-",
            putts: defaults.integer(forKey: Keys.lastPutts),
            fairwayPct: defaults.string(forKey: Keys.lastFairway) ?? "-",
            roundDate: defaults.string(forKey: Keys.lastDate) ?? "-",
            isActive: defaults.bool(forKey: Keys.isRoundActive),
            currentHole: defaults.integer(forKey: Keys.activeHole),
            runningScore: defaults.integer(forKey: Keys.activeRunningScore),
            handicap: defaults.double(forKey: Keys.handicap),
            roundCount: defaults.integer(forKey: Keys.roundCount)
        )
    }
}

// MARK: - Last Round Widget View
struct LastRoundWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: RoundWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryRectangular:
            lockScreenView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "flag.fill")
                    .foregroundStyle(Color(red: 0.13, green: 0.37, blue: 0.25))
                Spacer()
                if entry.isActive {
                    Text("LIVE")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green)
                        .clipShape(Capsule())
                }
            }

            if entry.isActive {
                Text("Hole \(entry.currentHole)")
                    .font(.headline.bold())
                Text(entry.courseName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(entry.runningScore)")
                    .font(.title.bold())
            } else if entry.score > 0 {
                Text(entry.courseName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(entry.score)")
                        .font(.title.bold())
                    Text(entry.scoreToPar)
                        .font(.caption.bold())
                        .foregroundStyle(entry.scoreToPar.hasPrefix("+") ? .red : entry.scoreToPar == "E" ? .orange : .green)
                }
                Text(entry.roundDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("No rounds yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Start tracking!")
                    .font(.caption2)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: score
            VStack(spacing: 4) {
                if entry.score > 0 {
                    Text("\(entry.score)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text(entry.scoreToPar)
                        .font(.caption.bold())
                        .foregroundStyle(entry.scoreToPar.hasPrefix("+") ? .red : .green)
                } else {
                    Image(systemName: "flag.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color(red: 0.13, green: 0.37, blue: 0.25))
                }
            }
            .frame(width: 80)

            // Right: details
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.courseName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text(entry.roundDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if entry.score > 0 {
                    HStack(spacing: 12) {
                        Label("\(entry.putts)", systemImage: "circle.fill")
                        Label(entry.fairwayPct, systemImage: "leaf.fill")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    if entry.handicap > 0 {
                        Text("HCP \(String(format: "%.1f", entry.handicap))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var lockScreenView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if entry.isActive {
                Text("Hole \(entry.currentHole) \u{2022} \(entry.runningScore)")
                    .font(.headline)
                Text(entry.courseName)
                    .font(.caption2)
            } else if entry.score > 0 {
                HStack {
                    Text("\(entry.score)")
                        .font(.headline)
                    Text(entry.scoreToPar)
                        .font(.caption.bold())
                }
                Text(entry.courseName)
                    .font(.caption2)
            } else {
                Text("TeeMetrics")
                    .font(.headline)
                Text("Start a round")
                    .font(.caption2)
            }
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
        .configurationDisplayName("Golf Stats")
        .description("Your latest round stats and live scoring at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Widget Bundle
@main
struct TeeMetricsWidgetBundle: WidgetBundle {
    var body: some Widget {
        TeeMetricsLastRoundWidget()
    }
}
