import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry

struct UsageEntry: TimelineEntry {
    let date: Date
    let gallonsToday: Int
    let weeklyData: [(day: String, gallons: Double)] // last 7 days for sparkline
}

// MARK: - Timeline Provider

struct UsageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: .now, gallonsToday: 42, weeklyData: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        let entry = fetchEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let entry = fetchEntry()
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchEntry() -> UsageEntry {
        guard let container = try? SharedConfig.makeModelContainer() else {
            return UsageEntry(date: .now, gallonsToday: 0, weeklyData: [])
        }

        let context = ModelContext(container)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Get selected device serial
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let serial = (try? context.fetch(settingsDescriptor))?.first?.selectedDeviceSerial ?? ""

        // Fetch today's usage
        let todayStr = DailyUsageRecord.dateFormatter.string(from: today)
        let todayId = "\(serial)_\(todayStr)"
        let todayDescriptor = FetchDescriptor<DailyUsageRecord>(
            predicate: #Predicate { $0.id == todayId }
        )
        let gallonsToday = Int((try? context.fetch(todayDescriptor))?.first?.gallons ?? 0)

        // Fetch last 7 days for sparkline
        let sevenDaysAgo = cal.date(byAdding: .day, value: -6, to: today)!
        let weekDescriptor = FetchDescriptor<DailyUsageRecord>(
            predicate: #Predicate {
                $0.serialNumber == serial &&
                $0.date >= sevenDaysAgo &&
                $0.date <= today
            },
            sortBy: [SortDescriptor(\.date)]
        )
        let weekRecords = (try? context.fetch(weekDescriptor)) ?? []

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "E"

        var weeklyData: [(String, Double)] = []
        for i in 0..<7 {
            let date = cal.date(byAdding: .day, value: -6 + i, to: today)!
            let dateStr = DailyUsageRecord.dateFormatter.string(from: date)
            let gallons = weekRecords.first(where: { $0.dateString == dateStr })?.gallons ?? 0
            weeklyData.append((dayFormatter.string(from: date), gallons))
        }

        return UsageEntry(
            date: .now,
            gallonsToday: gallonsToday,
            weeklyData: weeklyData
        )
    }
}

// MARK: - Widget Views

struct UsageWidgetSmallView: View {
    let entry: UsageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.cyan)
                    .font(.caption)
                Text("Culligan")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(entry.gallonsToday)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("gal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("today")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UsageWidgetMediumView: View {
    let entry: UsageEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: today's usage
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.cyan)
                        .font(.caption)
                    Text("Culligan")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(entry.gallonsToday)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("gal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("today")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Right: 7-day sparkline
            if !entry.weeklyData.isEmpty {
                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: 3) {
                        let maxVal = entry.weeklyData.map(\.gallons).max() ?? 1
                        ForEach(Array(entry.weeklyData.enumerated()), id: \.offset) { i, data in
                            let height = maxVal > 0 ? data.gallons / maxVal : 0
                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(i == entry.weeklyData.count - 1 ? Color.cyan : Color.cyan.opacity(0.4))
                                    .frame(width: 12, height: max(4, CGFloat(height) * 50))
                                Text(data.day)
                                    .font(.system(size: 7))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }
}

// MARK: - Widget Definition

struct UsageWidget: Widget {
    let kind = "UsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider()) { entry in
            Group {
                switch entry.widgetFamily {
                case .systemMedium:
                    UsageWidgetMediumView(entry: entry)
                default:
                    UsageWidgetSmallView(entry: entry)
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Water Usage")
        .description("Today's water usage from your Culligan softener.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private extension UsageEntry {
    var widgetFamily: WidgetFamily {
        .systemSmall // default, overridden by SwiftUI
    }
}
