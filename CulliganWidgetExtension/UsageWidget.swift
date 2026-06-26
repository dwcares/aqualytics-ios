import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry

struct UsageEntry: TimelineEntry {
    let date: Date
    let gallonsToday: Int
    /// Last 90 days of usage for the calendar heatmap: (date, gallons)
    let calendarData: [(date: Date, gallons: Double)]
    let maxUsage: Double
}

// MARK: - Timeline Provider

struct UsageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: .now, gallonsToday: 42, calendarData: [], maxUsage: 100)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let entry = fetchEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func fetchEntry() -> UsageEntry {
        guard let container = try? SharedConfig.makeModelContainer() else {
            return UsageEntry(date: .now, gallonsToday: 0, calendarData: [], maxUsage: 1)
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

        // Fetch last 180 days for calendar (covers ~22 weeks shown in medium widget)
        let startDate = cal.date(byAdding: .day, value: -179, to: today)!
        let rangeDescriptor = FetchDescriptor<DailyUsageRecord>(
            predicate: #Predicate {
                $0.serialNumber == serial &&
                $0.date >= startDate &&
                $0.date <= today
            },
            sortBy: [SortDescriptor(\.date)]
        )
        let records = (try? context.fetch(rangeDescriptor)) ?? []
        let calendarData = records.map { (date: $0.date, gallons: $0.gallons) }
        let maxUsage = records.map(\.gallons).max() ?? 1

        return UsageEntry(
            date: .now,
            gallonsToday: gallonsToday,
            calendarData: calendarData,
            maxUsage: maxUsage
        )
    }
}

// MARK: - Small Widget

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

// MARK: - Medium Widget — Calendar Heatmap

struct UsageWidgetMediumView: View {
    let entry: UsageEntry

    private let cellSize: CGFloat = 7
    private let cellSpacing: CGFloat = 1.5
    private let calendar = Calendar.current

    private var usageByDate: [String: Double] {
        Dictionary(uniqueKeysWithValues: entry.calendarData.map {
            (DailyUsageRecord.dateFormatter.string(from: $0.date), $0.gallons)
        })
    }

    /// Build weeks to fill available space — ~22 weeks (5 months)
    private var weeks: [[CellData]] {
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today)
        let daysUntilEndOfWeek = (7 - todayWeekday + calendar.firstWeekday) % 7
        let endOfWeek = calendar.date(byAdding: .day, value: daysUntilEndOfWeek, to: today)!

        let numWeeks = 22
        let totalDays = numWeeks * 7
        let gridStart = calendar.date(byAdding: .day, value: -(totalDays - 1), to: endOfWeek)!

        var result: [[CellData]] = []
        var current = gridStart

        for _ in 0..<numWeeks {
            var week: [CellData] = []
            for _ in 0..<7 {
                let isFuture = current > today
                let dateStr = DailyUsageRecord.dateFormatter.string(from: current)
                let gallons = usageByDate[dateStr]
                week.append(CellData(date: current, gallons: gallons, isInRange: !isFuture))
                current = calendar.date(byAdding: .day, value: 1, to: current)!
            }
            result.append(week)
        }
        return result
    }

    private var monthLabels: [(String, Int)] {
        var labels: [(String, Int)] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var lastMonth = -1

        for (colIndex, week) in weeks.enumerated() {
            // Use the first day of the week (Sunday) to determine column's month
            let firstDay = week[0]
            let month = calendar.component(.month, from: firstDay.date)
            if month != lastMonth {
                labels.append((formatter.string(from: firstDay.date), colIndex))
                lastMonth = month
            }
        }
        return labels
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: logo + today's usage
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.cyan)
                        .font(.caption2)
                    Text("Culligan")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(entry.gallonsToday)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("gal today")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            // Month labels — positioned to align with grid columns
            GeometryReader { geo in
                let totalSpacing = cellSpacing * CGFloat(weeks.count - 1)
                let colWidth = (geo.size.width - totalSpacing) / CGFloat(weeks.count)
                let step = colWidth + cellSpacing

                ZStack(alignment: .leading) {
                    ForEach(Array(monthLabels.enumerated()), id: \.offset) { _, label in
                        Text(label.0)
                            .font(.system(size: 7))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .offset(x: CGFloat(label.1) * step)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(height: 10)

            // Calendar grid — fills remaining space
            HStack(spacing: cellSpacing) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { rowIndex in
                            let cell = week[rowIndex]
                            if cell.isInRange {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(colorForUsage(cell.gallons ?? 0))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
            }
        }
    }

    private func colorForUsage(_ gallons: Double) -> Color {
        guard entry.maxUsage > 0 else { return Color.primary.opacity(0.06) }
        let level = min(1.0, gallons / entry.maxUsage)
        if level == 0 { return Color.primary.opacity(0.06) }
        return Color.cyan.opacity(0.15 + level * 0.75)
    }
}

private struct CellData {
    let date: Date
    let gallons: Double?
    let isInRange: Bool
}

// MARK: - Widget Container View

struct UsageWidgetContainerView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: UsageEntry

    var body: some View {
        switch widgetFamily {
        case .systemMedium:
            UsageWidgetMediumView(entry: entry)
        default:
            UsageWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Definition

struct UsageWidget: Widget {
    let kind = "UsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider()) { entry in
            UsageWidgetContainerView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Water Usage")
        .description("Today's water usage from your Culligan softener.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
