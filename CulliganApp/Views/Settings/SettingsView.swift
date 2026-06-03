import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @State private var showNotificationPrompt = false

    private var currentSettings: UserSettings {
        if let existing = settings.first {
            return existing
        }
        let newSettings = UserSettings()
        modelContext.insert(newSettings)
        return newSettings
    }

    var body: some View {
        NavigationStack {
            List {
                // Account section
                Section("Account") {
                    Button("Sign Out", role: .destructive) {
                        Task {
                            await authViewModel.logout()
                        }
                    }
                }

                // Tank tracking section
                Section {
                    Toggle("Track Holding Tank", isOn: Bindable(currentSettings).tankTrackingEnabled)

                    if currentSettings.tankTrackingEnabled {
                        HStack {
                            Text("Tank Capacity")
                            Spacer()
                            TextField("Gallons", value: Bindable(currentSettings).tankCapacity, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                                .frame(width: 100)
                        }
                    }
                } header: {
                    Text("Holding Tank")
                } footer: {
                    Text("Enable to track your septic holding tank fill level and pump history.")
                }

                // Notifications section
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: Binding(
                        get: { currentSettings.notificationsEnabled },
                        set: { newValue in
                            if newValue {
                                // Show prompt before enabling
                                showNotificationPrompt = true
                            } else {
                                currentSettings.notificationsEnabled = false
                            }
                        }
                    ))

                    if currentSettings.notificationsEnabled {
                        Toggle("Device Offline", isOn: Bindable(currentSettings).notifyDeviceOffline)
                        Toggle("Salt Low", isOn: Bindable(currentSettings).notifySaltLow)
                        Toggle("Usage Spike", isOn: Bindable(currentSettings).notifyUsageSpike)

                        if currentSettings.tankTrackingEnabled {
                            Toggle("Tank Nearly Full", isOn: Bindable(currentSettings).notifyTankFull)
                        }
                    }
                }

                // About section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/dwcares/culligan-ios")!) {
                        HStack {
                            Text("Source Code")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("About")
                } footer: {
                    Text("Culligan Water Usage Analytics is not affiliated with Culligan International. Data is stored locally on your device.")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showNotificationPrompt) {
                NotificationPromptView(
                    onEnable: {
                        showNotificationPrompt = false
                        Task {
                            let granted = await NotificationService.shared.requestPermission()
                            currentSettings.notificationsEnabled = granted
                        }
                    },
                    onSkip: {
                        showNotificationPrompt = false
                        currentSettings.notificationsEnabled = false
                    }
                )
                .presentationDetents([.large])
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AuthViewModel())
        .modelContainer(for: UserSettings.self, inMemory: true)
}
