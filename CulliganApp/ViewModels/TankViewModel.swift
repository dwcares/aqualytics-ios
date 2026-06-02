import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class TankViewModel {
    var pumpEvents: [PumpEvent] = []
    var isLoading = false

    // MARK: - Tank Calculations

    func loadPumpEvents(serialNumber: String, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<PumpEvent>(
            predicate: #Predicate { $0.serialNumber == serialNumber },
            sortBy: [SortDescriptor(\.date)]
        )
        pumpEvents = (try? modelContext.fetch(descriptor)) ?? []
    }

    func gallonsSincePump(usageRecords: [DailyUsageRecord]) -> Double {
        guard let lastPump = pumpEvents.last else {
            // No pump events — sum all usage
            return usageRecords.reduce(0) { $0 + $1.gallons }
        }

        // Sum usage after last pump
        return usageRecords
            .filter { $0.date > lastPump.date }
            .reduce(0) { $0 + $1.gallons }
    }

    func fillPercentage(usageRecords: [DailyUsageRecord], capacity: Double) -> Double {
        guard capacity > 0 else { return 0 }
        let used = gallonsSincePump(usageRecords: usageRecords)
        return min(100, (used / capacity) * 100)
    }

    func remainingCapacity(usageRecords: [DailyUsageRecord], capacity: Double) -> Double {
        max(0, capacity - gallonsSincePump(usageRecords: usageRecords))
    }

    func daysSinceLastPump() -> Int? {
        guard let lastPump = pumpEvents.last else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let pumpDay = cal.startOfDay(for: lastPump.date)
        return cal.dateComponents([.day], from: pumpDay, to: today).day
    }

    func averageDailyUsage(usageRecords: [DailyUsageRecord], days: Int = 7) -> Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let recent = usageRecords.filter { record in
            let daysAgo = cal.dateComponents([.day], from: record.date, to: today).day ?? 0
            return daysAgo >= 1 && daysAgo <= days
        }
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(0) { $0 + $1.gallons } / Double(recent.count)
    }

    func estimatedDaysUntilFull(usageRecords: [DailyUsageRecord], capacity: Double) -> Int? {
        let avg = averageDailyUsage(usageRecords: usageRecords)
        guard avg > 0 else { return nil }
        let remaining = remainingCapacity(usageRecords: usageRecords, capacity: capacity)
        return Int(remaining / avg)
    }

    // MARK: - Pump Actions

    func markAsPumped(
        serialNumber: String,
        date: Date = Date(),
        usageRecords: [DailyUsageRecord],
        modelContext: ModelContext
    ) {
        // Calculate gallons at time of pump
        let gallonsAtPump: Double
        if let lastPump = pumpEvents.last {
            gallonsAtPump = usageRecords
                .filter { $0.date > lastPump.date && $0.date <= date }
                .reduce(0) { $0 + $1.gallons }
        } else {
            gallonsAtPump = usageRecords
                .filter { $0.date <= date }
                .reduce(0) { $0 + $1.gallons }
        }

        let event = PumpEvent(serialNumber: serialNumber, date: date, gallonsAtPump: gallonsAtPump)
        modelContext.insert(event)
        try? modelContext.save()

        // Reload
        loadPumpEvents(serialNumber: serialNumber, modelContext: modelContext)
    }

    func deletePumpEvent(_ event: PumpEvent, serialNumber: String, modelContext: ModelContext) {
        modelContext.delete(event)
        try? modelContext.save()
        loadPumpEvents(serialNumber: serialNumber, modelContext: modelContext)
    }
}
