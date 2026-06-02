import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class UsageViewModel {
    var dailyUsage: [DailyUsageRecord] = []
    var isLoading = false
    var errorMessage: String?

    // Pagination
    var currentPage = 0
    var totalPages = 1

    // Time range
    var selectedRange: UsageRange = .thirtyDays

    // Selection
    var selectedBarIndices: ClosedRange<Int>?

    private let daysPerPage = 30

    enum UsageRange: String, CaseIterable, Identifiable {
        case sevenDays = "7D"
        case thirtyDays = "30D"
        case ninetyDays = "90D"
        case allTime = "All"

        var id: String { rawValue }

        var days: Int? {
            switch self {
            case .sevenDays: return 7
            case .thirtyDays: return 30
            case .ninetyDays: return 90
            case .allTime: return nil
            }
        }
    }

    /// Load usage data from local SwiftData store
    func loadFromStore(serialNumber: String, modelContext: ModelContext) {
        let syncService = UsageSyncService(modelContext: modelContext)
        let today = Calendar.current.startOfDay(for: Date())

        switch selectedRange {
        case .allTime:
            dailyUsage = syncService.fetchAllUsage(serialNumber: serialNumber)
        default:
            guard let days = selectedRange.days else { return }
            let startDate = Calendar.current.date(byAdding: .day, value: -(days - 1), to: today)!
            dailyUsage = syncService.fetchUsage(serialNumber: serialNumber, from: startDate, to: today)
        }

        // Fill in missing days with zero
        dailyUsage = fillMissingDays(records: dailyUsage, serialNumber: serialNumber)

        // Calculate total pages for pagination within the range
        if let oldest = syncService.oldestRecordDate(serialNumber: serialNumber) {
            let totalDays = max(1, Calendar.current.dateComponents([.day], from: oldest, to: today).day ?? 1)
            totalPages = max(1, Int(ceil(Double(totalDays) / Double(daysPerPage))))
        }
    }

    /// Refresh from the API and sync to local store
    func refresh(client: CulliganClient, serialNumber: String, modelContext: ModelContext) async {
        isLoading = true
        errorMessage = nil

        do {
            let softeners = try await client.getSofteners()
            guard let device = softeners.first(where: { $0.serialNumber == serialNumber }) ?? softeners.first else {
                errorMessage = "No softener found"
                isLoading = false
                return
            }

            // Sync API data to SwiftData
            let syncService = UsageSyncService(modelContext: modelContext)
            _ = syncService.sync(device: device)

            // Reload from store
            loadFromStore(serialNumber: serialNumber, modelContext: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Navigate to older data
    func loadOlder(serialNumber: String, modelContext: ModelContext) {
        guard currentPage < totalPages - 1 else { return }
        currentPage += 1
        loadPagedData(serialNumber: serialNumber, modelContext: modelContext)
    }

    /// Navigate to newer data
    func loadNewer(serialNumber: String, modelContext: ModelContext) {
        guard currentPage > 0 else { return }
        currentPage -= 1
        loadPagedData(serialNumber: serialNumber, modelContext: modelContext)
    }

    private func loadPagedData(serialNumber: String, modelContext: ModelContext) {
        let syncService = UsageSyncService(modelContext: modelContext)
        let today = Calendar.current.startOfDay(for: Date())

        let startDaysAgo = (currentPage + 1) * daysPerPage - 1
        let endDaysAgo = currentPage * daysPerPage

        let startDate = Calendar.current.date(byAdding: .day, value: -startDaysAgo, to: today)!
        let endDate = Calendar.current.date(byAdding: .day, value: -endDaysAgo, to: today)!

        dailyUsage = syncService.fetchUsage(serialNumber: serialNumber, from: startDate, to: endDate)
        dailyUsage = fillMissingDays(records: dailyUsage, serialNumber: serialNumber, from: startDate, to: endDate)
        clearSelection()
    }

    func clearSelection() {
        selectedBarIndices = nil
    }

    // MARK: - Computed Properties

    var totalGallons: Double {
        dailyUsage.reduce(0) { $0 + $1.gallons }
    }

    var averageDaily: Double {
        guard !dailyUsage.isEmpty else { return 0 }
        return totalGallons / Double(dailyUsage.count)
    }

    var selectedTotal: Double? {
        guard let range = selectedBarIndices else { return nil }
        let clamped = range.clamped(to: 0...max(0, dailyUsage.count - 1))
        return dailyUsage[clamped].reduce(0) { $0 + $1.gallons }
    }

    var selectedDayCount: Int? {
        guard let range = selectedBarIndices else { return nil }
        return range.count
    }

    var dateRangeText: String {
        guard let first = dailyUsage.first, let last = dailyUsage.last else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: first.date)) – \(formatter.string(from: last.date))"
    }

    // MARK: - Helpers

    /// Fill in missing days with 0 gallons so the chart has no gaps
    private func fillMissingDays(
        records: [DailyUsageRecord],
        serialNumber: String,
        from startDate: Date? = nil,
        to endDate: Date? = nil
    ) -> [DailyUsageRecord] {
        let today = Calendar.current.startOfDay(for: Date())
        let start = startDate ?? records.first?.date ?? today
        let end = endDate ?? today

        let existingByDate = Dictionary(grouping: records, by: { $0.dateString })

        var filled: [DailyUsageRecord] = []
        var current = Calendar.current.startOfDay(for: start)
        let endDay = Calendar.current.startOfDay(for: end)

        while current <= endDay {
            let dateStr = DailyUsageRecord.dateFormatter.string(from: current)
            if let existing = existingByDate[dateStr]?.first {
                filled.append(existing)
            } else {
                filled.append(DailyUsageRecord(serialNumber: serialNumber, date: current, gallons: 0))
            }
            current = Calendar.current.date(byAdding: .day, value: 1, to: current)!
        }

        return filled
    }
}
