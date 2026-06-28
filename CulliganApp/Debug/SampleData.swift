#if DEBUG
import Foundation
import SwiftData

/// DEBUG-only sample-data generator for App Store screenshots and offline
/// development. Compiled out of all Release/TestFlight/App Store builds.
///
/// Usage: Settings → Developer → "Load Demo Data", then force-quit and relaunch.
enum SampleData {
    static let demoSerial = "DEMO-AQUA-001"
    private static let demoModeKey = "demoModeEnabled"

    static var isDemoMode: Bool {
        get { UserDefaults.standard.bool(forKey: demoModeKey) }
        set { UserDefaults.standard.set(newValue, forKey: demoModeKey) }
    }

    /// A polished mock device so the dashboard hero looks great without a live login.
    static func demoDevice() -> SoftenerDevice? {
        let json = """
        {
          "serialNumber": "\(demoSerial)",
          "name": "Home Water Softener",
          "model": "Smart HE",
          "protocolVersion": 4,
          "swVersion": "3.4.1",
          "status": { "connection": { "online": true, "lastUpdate": "2026-06-27T13:30:00.000Z" } },
          "properties": {
            "manual_salt_level_rem_calc": 78,
            "days_salt_remaining": 39,
            "current_flow_rate": 0,
            "total_water_usage_today_tank_1": 168,
            "total_water_usage_since_install_tank_1": 184320,
            "last_regen_date_time_tank_1": "2026-06-25T02:00:00.000Z",
            "days_since_last_regen_tank_1": 2,
            "gbx_firmware_version": "3.4.1"
          }
        }
        """
        guard let data = json.data(using: .utf8),
              let item = try? JSONDecoder().decode(DeviceRegistryItem.self, from: data)
        else { return nil }
        return SoftenerDevice(registryItem: item)
    }

    /// Seeds ~10 months of realistic daily usage + tank settings + a pump event.
    static func load(modelContext: ModelContext) {
        clear(modelContext: modelContext)

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        for offset in 0..<300 {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let weekday = cal.component(.weekday, from: date)
            var base = 165.0
            if weekday == 1 || weekday == 7 { base += 75 }       // weekends run higher
            base += 35 * sin(Double(offset) / 28.0)              // gentle seasonal wave
            let jitter = Double((offset * 73) % 70) - 35         // organic day-to-day variation
            var gallons = max(0, base + jitter)
            if offset % 41 == 0 { gallons += 160 }               // occasional spikes
            if offset % 59 == 0 { gallons = 0 }                  // a few "away" days
            if offset == 0 { gallons = 168 }                     // today matches the hero value
            modelContext.insert(DailyUsageRecord(serialNumber: demoSerial, date: date, gallons: gallons.rounded()))
        }

        let settings = (try? modelContext.fetch(FetchDescriptor<UserSettings>()))?.first ?? {
            let s = UserSettings()
            modelContext.insert(s)
            return s
        }()
        settings.selectedDeviceSerial = demoSerial
        settings.tankTrackingEnabled = true
        settings.tankCapacity = 2500

        if let pumpDate = cal.date(byAdding: .day, value: -8, to: today) {
            modelContext.insert(PumpEvent(serialNumber: demoSerial, date: pumpDate, gallonsAtPump: 0))
        }

        try? modelContext.save()
        isDemoMode = true
    }

    /// Removes all seeded data and turns demo mode off.
    static func clear(modelContext: ModelContext) {
        try? modelContext.delete(model: DailyUsageRecord.self)
        try? modelContext.delete(model: PumpEvent.self)
        try? modelContext.save()
        isDemoMode = false
    }
}
#endif
