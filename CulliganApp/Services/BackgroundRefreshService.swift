import Foundation
import BackgroundTasks
import SwiftData

/// Manages background app refresh to sync data and check notification conditions.
enum BackgroundRefreshService {
    static let taskIdentifier = "com.dwcares.culligan.refresh"

    /// Register the background task on app launch.
    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            handleRefresh(task: task)
        }
    }

    /// Schedule the next background refresh.
    static func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 60 * 60) // 12 hours
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Background refresh scheduling error: \(error)")
        }
    }

    /// Handle a background refresh task.
    nonisolated private static func handleRefresh(task: BGAppRefreshTask) {
        scheduleNextRefresh()

        let sendableTask = UncheckedSendableBox(task)
        Task { @MainActor in
            await performRefresh()
            sendableTask.value.setTaskCompleted(success: true)
        }
    }

    /// Perform the actual refresh: re-auth, fetch data, sync, check alerts.
    @MainActor
    private static func performRefresh() async {
        guard let container = try? SharedConfig.makeModelContainer() else { return }
        let context = ModelContext(container)

        // Get settings
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        guard let settings = try? context.fetch(settingsDescriptor).first,
              let serial = settings.selectedDeviceSerial,
              !serial.isEmpty else { return }

        // Try to fetch fresh data from Culligan API
        let client = CulliganClient()

        // Try stored auth or re-login
        if await !client.isAuthenticated {
            if let creds = KeychainService.loadCredentials() {
                do {
                    try await client.login(email: creds.email, password: creds.password)
                } catch {
                    print("Background re-auth failed: \(error)")
                    return
                }
            } else {
                return
            }
        }

        do {
            let softeners = try await client.getSofteners()
            guard let device = softeners.first(where: { $0.serialNumber == serial }) ?? softeners.first else { return }

            // Sync usage data
            let syncService = UsageSyncService(modelContext: context)
            _ = syncService.sync(device: device)

            // Check device-level alerts (offline, salt)
            if settings.notificationsEnabled {
                await NotificationService.shared.checkDeviceAlerts(device: device, settings: settings)
            }
        } catch {
            print("Background data fetch failed: \(error)")
        }

        // Check local alerts (usage spike, tank level)
        if settings.notificationsEnabled {
            await NotificationService.shared.checkAndNotify(modelContext: context)
        }
    }
}

/// Wrapper to pass non-Sendable types across isolation boundaries.
private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}