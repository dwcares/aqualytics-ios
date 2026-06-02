import Foundation
import SwiftData

/// Syncs daily usage data from the Culligan API into SwiftData.
/// Implements the same merge logic as the web app's server.js:
/// - Always update today's value (it accumulates throughout the day)
/// - Past days: only update if missing OR new value > 0 and different
@MainActor
final class UsageSyncService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Sync fresh data from a softener device into local storage.
    /// Returns true if any records were changed.
    func sync(device: SoftenerDevice) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let todayStr = DailyUsageRecord.dateFormatter.string(from: today)
        var changed = false

        for usage in device.dailyUsage() {
            guard let date = Calendar.current.date(byAdding: .day, value: -usage.daysAgo, to: today) else {
                continue
            }
            let dateStr = DailyUsageRecord.dateFormatter.string(from: date)
            let recordId = "\(device.serialNumber)_\(dateStr)"
            let gallons = usage.gallons
            let isToday = dateStr == todayStr

            // Check if record exists
            let descriptor = FetchDescriptor<DailyUsageRecord>(
                predicate: #Predicate { $0.id == recordId }
            )

            if let existing = try? modelContext.fetch(descriptor).first {
                // Same logic as web app's updateHistory:
                // Always update today; past days only if value changed and non-zero
                let shouldUpdate: Bool
                if isToday {
                    shouldUpdate = existing.gallons != gallons
                } else {
                    shouldUpdate = gallons > 0 && gallons != existing.gallons
                }

                if shouldUpdate {
                    existing.gallons = gallons
                    existing.updatedAt = Date()
                    changed = true
                }
            } else {
                // New record
                let record = DailyUsageRecord(
                    serialNumber: device.serialNumber,
                    date: date,
                    gallons: gallons
                )
                modelContext.insert(record)
                changed = true
            }
        }

        if changed {
            try? modelContext.save()
        }

        return changed
    }

    /// Fetch usage records for a date range, sorted by date ascending.
    func fetchUsage(
        serialNumber: String,
        from startDate: Date,
        to endDate: Date
    ) -> [DailyUsageRecord] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)

        let descriptor = FetchDescriptor<DailyUsageRecord>(
            predicate: #Predicate {
                $0.serialNumber == serialNumber &&
                $0.date >= start &&
                $0.date <= end
            },
            sortBy: [SortDescriptor(\.date)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Fetch all usage records for a device, sorted by date ascending.
    func fetchAllUsage(serialNumber: String) -> [DailyUsageRecord] {
        let descriptor = FetchDescriptor<DailyUsageRecord>(
            predicate: #Predicate { $0.serialNumber == serialNumber },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Get the oldest record date for a device.
    func oldestRecordDate(serialNumber: String) -> Date? {
        let descriptor = FetchDescriptor<DailyUsageRecord>(
            predicate: #Predicate { $0.serialNumber == serialNumber },
            sortBy: [SortDescriptor(\.date)]
        )
        var limited = descriptor
        limited.fetchLimit = 1
        return (try? modelContext.fetch(limited))?.first?.date
    }
}
