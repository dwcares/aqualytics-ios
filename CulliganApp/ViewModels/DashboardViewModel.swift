import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    var device: SoftenerDevice?
    var allDevices: [SoftenerDevice] = []
    var isLoading = false
    var errorMessage: String?

    func refresh(client: CulliganClient, modelContext: ModelContext) async {
        isLoading = true
        errorMessage = nil

        do {
            let softeners = try await client.getSofteners()
            allDevices = softeners

            if let current = device {
                device = softeners.first { $0.serialNumber == current.serialNumber } ?? softeners.first
            } else {
                device = softeners.first
            }

            // Sync usage data for the active device
            if let device {
                let syncService = UsageSyncService(modelContext: modelContext)
                _ = syncService.sync(device: device)

                // Store selected device serial in settings
                let descriptor = FetchDescriptor<UserSettings>()
                let settings = (try? modelContext.fetch(descriptor))?.first
                if let settings {
                    settings.selectedDeviceSerial = device.serialNumber
                } else {
                    let newSettings = UserSettings()
                    newSettings.selectedDeviceSerial = device.serialNumber
                    modelContext.insert(newSettings)
                }
                try? modelContext.save()

                // Check device-level alerts (offline, salt)
                if let settings {
                    await NotificationService.shared.checkDeviceAlerts(device: device, settings: settings)
                    NotificationService.shared.checkAndNotify(modelContext: modelContext)
                }
            }

            if softeners.isEmpty {
                errorMessage = "No water softener found on your account."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func selectDevice(_ device: SoftenerDevice) {
        self.device = device
    }
}
