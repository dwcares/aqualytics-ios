import SwiftUI
import SwiftData

@main
struct CulliganApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try SharedConfig.makeModelContainer()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Register background refresh
        BackgroundRefreshService.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Check notifications when app becomes active
                    BackgroundRefreshService.scheduleNextRefresh()
                }
        }
        .modelContainer(container)
    }
}

/// Root view that shows either login or the main tab view
struct RootView: View {
    @State private var authViewModel = AuthViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                ContentView()
                    .environment(authViewModel)
                    .task {
                        // Request notification permission on first authenticated launch
                        _ = await NotificationService.shared.requestPermission()
                    }
            } else {
                LoginView()
                    .environment(authViewModel)
            }
        }
        .task {
            await authViewModel.checkExistingAuth()
            seedMockDataIfNeeded()
        }
    }

    /// Seed ~2 years of mock usage data for testing. Only runs once.
    private func seedMockDataIfNeeded() {
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let existingSettings = try? modelContext.fetch(settingsDescriptor)

        // Enable tank tracking for testing
        if let settings = existingSettings?.first {
            settings.tankTrackingEnabled = true
        }

        // If we have MOCK_DEVICE records and a real device serial, migrate them
        let realSerial = existingSettings?.first?.selectedDeviceSerial
        if let realSerial, !realSerial.isEmpty, realSerial != "MOCK_DEVICE" {
            let mockDescriptor = FetchDescriptor<DailyUsageRecord>(
                predicate: #Predicate { $0.serialNumber == "MOCK_DEVICE" }
            )
            if let mockRecords = try? modelContext.fetch(mockDescriptor), !mockRecords.isEmpty {
                for record in mockRecords {
                    // Create new record with real serial (can't change id)
                    let newRecord = DailyUsageRecord(serialNumber: realSerial, date: record.date, gallons: record.gallons)
                    modelContext.insert(newRecord)
                    modelContext.delete(record)
                }
                try? modelContext.save()
                print("Migrated \(mockRecords.count) mock records to \(realSerial)")
                return
            }
        }

        // Check if we already have significant history
        let descriptor = FetchDescriptor<DailyUsageRecord>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count < 60 else { return }

        let serial = realSerial ?? "MOCK_DEVICE"

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Generate 2 years of data with realistic patterns
        for daysAgo in 0..<730 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }

            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
            let seasonalFactor = 1.0 + 0.3 * sin(Double(dayOfYear) / 365.0 * 2 * .pi)
            let weekday = calendar.component(.weekday, from: date)
            let weekendFactor = (weekday == 1 || weekday == 7) ? 1.2 : 1.0

            let base = Double.random(in: 40...80)
            let gallons = base * seasonalFactor * weekendFactor

            let record = DailyUsageRecord(serialNumber: serial, date: date, gallons: round(gallons))
            modelContext.insert(record)
        }

        try? modelContext.save()
        print("Seeded 730 days of mock usage data for \(serial)")
    }
}

/// Main tab view shown after authentication
struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Query private var settings: [UserSettings]

    private var tankEnabled: Bool {
        settings.first?.tankTrackingEnabled ?? false
    }

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "drop.fill")
                }

            UsageView()
                .tabItem {
                    Label("Usage", systemImage: "chart.bar.fill")
                }

            if tankEnabled {
                TankView()
                    .tabItem {
                        Label("Tank", systemImage: "cylinder.fill")
                    }
            }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(.cyan)
    }
}
