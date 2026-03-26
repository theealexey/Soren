import WidgetKit
import SwiftUI

struct SorenUpcomingWidget: Widget {
    let kind = "SorenUpcomingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UpcomingTimelineProvider()) { entry in
            UpcomingWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Upcoming Charges")
        .description("See your next recurring payments at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Provider

struct UpcomingEntry: TimelineEntry {
    let date: Date
}

struct UpcomingTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingEntry {
        UpcomingEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingEntry) -> Void) {
        completion(UpcomingEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingEntry>) -> Void) {
        let entry = UpcomingEntry(date: .now)
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600)))
        completion(timeline)
    }
}

// MARK: - Widget View

struct UpcomingWidgetEntryView: View {
    var entry: UpcomingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Soren")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("No items yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview(as: .systemSmall) {
    SorenUpcomingWidget()
} timeline: {
    UpcomingEntry(date: .now)
}
