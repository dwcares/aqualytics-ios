import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry

struct TankEntry: TimelineEntry {
    let date: Date
    let fillPercentage: Double
    let gallonsUsed: Double
    let capacity: Double
    let daysUntilFull: Int?
    let isEnabled: Bool
}

// MARK: - Timeline Provider

struct TankTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TankEntry {
        TankEntry(date: .now, fillPercentage: 45, gallonsUsed: 900, capacity: 2000, daysUntilFull: 12, isEnabled: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (TankEntry) -> Void) {
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TankEntry>) -> Void) {
        let entry = fetchEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func fetchEntry() -> TankEntry {
        guard let container = try? SharedConfig.makeModelContainer() else {
            return TankEntry(date: .now, fillPercentage: 0, gallonsUsed: 0, capacity: 2000, daysUntilFull: nil, isEnabled: false)
        }

        let context = ModelContext(container)

        // Get settings
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let settings = (try? context.fetch(settingsDescriptor))?.first

        guard let settings, settings.tankTrackingEnabled else {
            return TankEntry(date: .now, fillPercentage: 0, gallonsUsed: 0, capacity: 2000, daysUntilFull: nil, isEnabled: false)
        }

        let serial = settings.selectedDeviceSerial ?? ""
        let capacity = settings.tankCapacity

        // Fetch usage records
        let usageDescriptor = FetchDescriptor<DailyUsageRecord>(
            predicate: #Predicate { $0.serialNumber == serial },
            sortBy: [SortDescriptor(\.date)]
        )
        let usageRecords = (try? context.fetch(usageDescriptor)) ?? []

        // Fetch pump events
        let pumpDescriptor = FetchDescriptor<PumpEvent>(
            predicate: #Predicate { $0.serialNumber == serial },
            sortBy: [SortDescriptor(\.date)]
        )
        let pumpEvents = (try? context.fetch(pumpDescriptor)) ?? []

        // Calculate gallons since last pump
        let gallonsUsed: Double
        if let lastPump = pumpEvents.last {
            gallonsUsed = usageRecords
                .filter { $0.date > lastPump.date }
                .reduce(0) { $0 + $1.gallons }
        } else {
            gallonsUsed = usageRecords.reduce(0) { $0 + $1.gallons }
        }

        let fillPct = capacity > 0 ? min(100, (gallonsUsed / capacity) * 100) : 0

        // Estimate days until full
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let recentRecords = usageRecords.filter { record in
            let daysAgo = cal.dateComponents([.day], from: record.date, to: today).day ?? 0
            return daysAgo >= 1 && daysAgo <= 7
        }
        let avgDaily = recentRecords.isEmpty ? 0 : recentRecords.reduce(0) { $0 + $1.gallons } / Double(recentRecords.count)
        let remaining = max(0, capacity - gallonsUsed)
        let daysUntilFull = avgDaily > 0 ? Int(remaining / avgDaily) : nil

        return TankEntry(
            date: .now,
            fillPercentage: fillPct,
            gallonsUsed: gallonsUsed,
            capacity: capacity,
            daysUntilFull: daysUntilFull,
            isEnabled: true
        )
    }
}

// MARK: - Widget View

struct TankWidgetView: View {
    let entry: TankEntry

    private var fillColor: Color {
        if entry.fillPercentage >= 80 { return .red }
        if entry.fillPercentage >= 70 { return .orange }
        return .cyan
    }

    var body: some View {
        if !entry.isEnabled {
            VStack(spacing: 8) {
                Image(systemName: "cylinder.fill")
                    .foregroundStyle(.tertiary)
                Text("Tank tracking\nnot enabled")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "cylinder.fill")
                        .foregroundStyle(fillColor)
                        .font(.caption)
                    Text("Tank")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Spacer()

                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: entry.fillPercentage / 100)
                        .stroke(fillColor.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(entry.fillPercentage))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .frame(width: 60, height: 60)
                .frame(maxWidth: .infinity)

                Spacer()

                Text("\(Int(entry.gallonsUsed)) of \(Int(entry.capacity)) gal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Widget Definition

struct TankWidget: Widget {
    let kind = "TankWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TankTimelineProvider()) { entry in
            TankWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tank Level")
        .description("Holding tank fill level and estimated time until full.")
        .supportedFamilies([.systemSmall])
    }
}
