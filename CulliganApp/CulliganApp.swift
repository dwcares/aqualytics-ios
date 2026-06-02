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
        }
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
