import Foundation
import SwiftData

/// Stores daily water usage for a specific device and date.
/// Keyed by "{serialNumber}_{yyyy-MM-dd}" to ensure uniqueness.
@Model
final class DailyUsageRecord {
    @Attribute(.unique) var id: String
    var serialNumber: String
    var date: Date
    var gallons: Double
    var updatedAt: Date

    init(serialNumber: String, date: Date, gallons: Double) {
        let dateStr = Self.dateFormatter.string(from: date)
        self.id = "\(serialNumber)_\(dateStr)"
        self.serialNumber = serialNumber
        self.date = Calendar.current.startOfDay(for: date)
        self.gallons = gallons
        self.updatedAt = Date()
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    var dateString: String {
        Self.dateFormatter.string(from: date)
    }
}
