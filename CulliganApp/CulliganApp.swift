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

        BackgroundRefreshService.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    BackgroundRefreshService.scheduleNextRefresh()
                }
        }
        .modelContainer(container)
    }
}

// MARK: - Root View

/// Controls the app flow: onboarding → login → main content
struct RootView: View {
    @State private var authViewModel = AuthViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var showNotificationPrompt = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            } else if authViewModel.isAuthenticated {
                ContentView()
                    .environment(authViewModel)
                    .task {
                        let notified = UserDefaults.standard.bool(forKey: "hasShownNotificationPrompt")
                        if !notified {
                            try? await Task.sleep(for: .seconds(1.5))
                            showNotificationPrompt = true
                        }
                    }
                    .sheet(isPresented: $showNotificationPrompt) {
                        NotificationPromptView(
                            onEnable: {
                                showNotificationPrompt = false
                                UserDefaults.standard.set(true, forKey: "hasShownNotificationPrompt")
                                Task {
                                    let granted = await NotificationService.shared.requestPermission()
                                    if !granted {
                                        updateNotificationSetting(enabled: false)
                                    }
                                }
                            },
                            onSkip: {
                                showNotificationPrompt = false
                                UserDefaults.standard.set(true, forKey: "hasShownNotificationPrompt")
                                updateNotificationSetting(enabled: false)
                            }
                        )
                        .presentationDetents([.large])
                    }
            } else {
                LoginView()
                    .environment(authViewModel)
            }
        }
        .task {
            await authViewModel.checkExistingAuth()
        }
    }

    private func updateNotificationSetting(enabled: Bool) {
        let descriptor = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(descriptor).first {
            settings.notificationsEnabled = enabled
            try? modelContext.save()
        }
    }
}

// MARK: - Main Tab View

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
