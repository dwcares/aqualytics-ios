import Foundation
import UserNotifications
import SwiftData

/// Manages local notification scheduling and permissions.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    // MARK: - Permissions

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    // MARK: - Check & Notify

    /// Checks all notification conditions and schedules alerts as needed.
    /// Called from background refresh or when app becomes active.
    func checkAndNotify(modelContext: ModelContext) {
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        guard let settings = try? modelContext.fetch(settingsDescriptor).first,
              settings.notificationsEnabled else { return }

        let serial = settings.selectedDeviceSerial ?? ""
        guard !serial.isEmpty else { return }

        // Fetch usage records
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: today)!

        let usageDescriptor = FetchDescriptor<DailyUsageRecord>(
            predicate: #Predicate {
                $0.serialNumber == serial &&
                $0.date >= sevenDaysAgo &&
                $0.date <= today
            },
            sortBy: [SortDescriptor(\.date)]
        )
        let recentRecords = (try? modelContext.fetch(usageDescriptor)) ?? []

        // 1. Usage spike detection
        if settings.notifyUsageSpike {
            checkUsageSpike(records: recentRecords, serial: serial)
        }

        // 2. Tank nearly full
        if settings.notifyTankFull && settings.tankTrackingEnabled {
            checkTankLevel(
                serial: serial,
                capacity: settings.tankCapacity,
                threshold: settings.tankWarningThreshold,
                modelContext: modelContext
            )
        }

        // 3. Salt low — checked via last known device data
        // (Salt alerts require fresh API data, handled in background refresh)
    }

    // MARK: - Usage Spike

    private func checkUsageSpike(records: [DailyUsageRecord], serial: String) {
        guard records.count >= 2 else { return }

        // Calculate 7-day average (excluding today)
        let pastRecords = records.dropLast()
        guard !pastRecords.isEmpty else { return }
        let avg = pastRecords.reduce(0.0) { $0 + $1.gallons } / Double(pastRecords.count)

        // Check if today is > 2x average
        guard let todayRecord = records.last, avg > 0 else { return }
        if todayRecord.gallons > avg * 2 && todayRecord.gallons > 20 {
            scheduleNotification(
                id: "usage-spike-\(serial)",
                title: "High Water Usage",
                body: "Today's usage (\(Int(todayRecord.gallons)) gal) is more than double your average (\(Int(avg)) gal). Possible leak?",
                category: "USAGE_SPIKE"
            )
        }
    }

    // MARK: - Tank Level

    private func checkTankLevel(serial: String, capacity: Double, threshold: Double, modelContext: ModelContext) {
        // Fetch all usage records
        let usageDescriptor = FetchDescriptor<DailyUsageRecord>(
            predicate: #Predicate { $0.serialNumber == serial },
            sortBy: [SortDescriptor(\.date)]
        )
        let allRecords = (try? modelContext.fetch(usageDescriptor)) ?? []

        // Fetch pump events
        let pumpDescriptor = FetchDescriptor<PumpEvent>(
            predicate: #Predicate { $0.serialNumber == serial },
            sortBy: [SortDescriptor(\.date)]
        )
        let pumpEvents = (try? modelContext.fetch(pumpDescriptor)) ?? []

        // Calculate gallons since last pump
        let gallonsSincePump: Double
        if let lastPump = pumpEvents.last {
            gallonsSincePump = allRecords
                .filter { $0.date > lastPump.date }
                .reduce(0) { $0 + $1.gallons }
        } else {
            gallonsSincePump = allRecords.reduce(0) { $0 + $1.gallons }
        }

        let fillPct = capacity > 0 ? gallonsSincePump / capacity : 0

        if fillPct >= threshold {
            let pctText = Int(fillPct * 100)
            scheduleNotification(
                id: "tank-warning-\(serial)",
                title: "Tank Nearly Full",
                body: "Your holding tank is \(pctText)% full (\(Int(gallonsSincePump)) gal). Schedule pumping soon.",
                category: "TANK_WARNING"
            )
        }
    }

    // MARK: - Device Offline & Salt Low (called from API refresh)

    func checkDeviceAlerts(device: SoftenerDevice, settings: UserSettings) {
        let serial = device.serialNumber

        // Device offline
        if settings.notifyDeviceOffline && !device.isOnline {
            scheduleNotification(
                id: "device-offline-\(serial)",
                title: "Softener Offline",
                body: "\(device.name) is not responding. Check your WiFi connection.",
                category: "DEVICE_OFFLINE"
            )
        } else {
            // Remove offline notification if device is back online
            removeNotification(id: "device-offline-\(serial)")
        }

        // Salt low
        if settings.notifySaltLow {
            if let daysRemaining = device.daysSaltRemaining, daysRemaining < 14 {
                scheduleNotification(
                    id: "salt-low-\(serial)",
                    title: "Salt Running Low",
                    body: "Your softener has about \(daysRemaining) days of salt remaining. Time to refill.",
                    category: "SALT_LOW"
                )
            }
        }
    }

    // MARK: - Schedule / Remove

    private func scheduleNotification(id: String, title: String, body: String, category: String) {
        let center = UNUserNotificationCenter.current()

        // Don't re-schedule if we already have this notification pending
        center.getPendingNotificationRequests { requests in
            if requests.contains(where: { $0.identifier == id }) { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = category

            // Deliver immediately (1 second delay required)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            center.add(request) { error in
                if let error {
                    print("Notification scheduling error: \(error)")
                }
            }
        }
    }

    private func removeNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }
}
