import Foundation
import SwiftData

/// Per-device user settings stored locally.
@Model
final class UserSettings {
    @Attribute(.unique) var id: String  // "global" or serialNumber

    // Tank tracking
    var tankTrackingEnabled: Bool
    var tankCapacity: Double  // gallons

    // Notifications
    var notificationsEnabled: Bool
    var notifyTankFull: Bool
    var tankWarningThreshold: Double  // 0.5, 0.75, or 0.9
    var notifyDeviceOffline: Bool
    var notifySaltLow: Bool
    var notifyUsageSpike: Bool

    // Display
    var selectedDeviceSerial: String?

    init() {
        self.id = "global"
        self.tankTrackingEnabled = false
        self.tankCapacity = 2000
        self.notificationsEnabled = true
        self.notifyTankFull = true
        self.tankWarningThreshold = 0.75
        self.notifyDeviceOffline = true
        self.notifySaltLow = true
        self.notifyUsageSpike = true
        self.selectedDeviceSerial = nil
    }
}
