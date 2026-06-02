import Foundation
import SwiftData

/// Records when the user's holding tank was pumped.
@Model
final class PumpEvent {
    @Attribute(.unique) var id: String
    var serialNumber: String
    var date: Date
    var gallonsAtPump: Double

    init(serialNumber: String, date: Date, gallonsAtPump: Double) {
        self.id = UUID().uuidString
        self.serialNumber = serialNumber
        self.date = date
        self.gallonsAtPump = gallonsAtPump
    }
}
