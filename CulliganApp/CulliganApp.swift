import SwiftUI
import SwiftData

@main
struct CulliganApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                DailyUsageRecord.self,
                PumpEvent.self,
                UserSettings.self,
            ])
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            container = try ModelContainer(
                for: schema,
                configurations: [config]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
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
        // Check if we already have significant history
        let descriptor = FetchDescriptor<DailyUsageRecord>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count < 60 else { return } // already have data

        // Get the device serial from settings, or use a placeholder
        let settingsDescriptor = FetchDescriptor<UserSettings>()
        let serial = (try? modelContext.fetch(settingsDescriptor))?.first?.selectedDeviceSerial ?? "MOCK_DEVICE"

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Generate 2 years of data with realistic patterns
        for daysAgo in 0..<730 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }

            // Base usage: 40-80 gal/day with seasonal variation
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
            let seasonalFactor = 1.0 + 0.3 * sin(Double(dayOfYear) / 365.0 * 2 * .pi) // higher in summer
            let weekday = calendar.component(.weekday, from: date)
            let weekendFactor = (weekday == 1 || weekday == 7) ? 1.2 : 1.0 // more on weekends

            let base = Double.random(in: 40...80)
            let gallons = base * seasonalFactor * weekendFactor

            let record = DailyUsageRecord(serialNumber: serial, date: date, gallons: round(gallons))
            modelContext.insert(record)
        }

        try? modelContext.save()
        print("Seeded 730 days of mock usage data")
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
