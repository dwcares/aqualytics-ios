import Foundation
import Observation

@Observable
@MainActor
final class DashboardViewModel {
    var device: SoftenerDevice?
    var allDevices: [SoftenerDevice] = []
    var isLoading = false
    var errorMessage: String?

    func refresh(client: CulliganClient) async {
        isLoading = true
        errorMessage = nil

        do {
            let softeners = try await client.getSofteners()
            allDevices = softeners

            if let current = device {
                // Keep current selection if still available
                device = softeners.first { $0.serialNumber == current.serialNumber } ?? softeners.first
            } else {
                device = softeners.first
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

    func toggleBypass(client: CulliganClient) async {
        guard let device else { return }
        do {
            if device.isBypassed {
                _ = try await client.stopBypassMode(serialNumber: device.serialNumber, protocolVersion: device.protocolVersion)
            } else {
                _ = try await client.startBypassMode(serialNumber: device.serialNumber, protocolVersion: device.protocolVersion)
            }
            // Refresh to get updated state
            await refresh(client: client)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleVacation(client: CulliganClient) async {
        guard let device else { return }
        do {
            if device.isVacationMode {
                _ = try await client.stopVacationMode(serialNumber: device.serialNumber, protocolVersion: device.protocolVersion)
            } else {
                _ = try await client.startVacationMode(serialNumber: device.serialNumber, protocolVersion: device.protocolVersion)
            }
            await refresh(client: client)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
