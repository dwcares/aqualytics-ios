import SwiftUI

struct DashboardView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isLoading && viewModel.device == nil {
                        ProgressView("Loading devices...")
                    } else if let device = viewModel.device {
                        // Device status header
                        DeviceStatusCard(device: device)

                        // Stat cards grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: 16) {
                            StatCard(
                                title: "Today",
                                value: "\(Int(device.waterUsageToday ?? 0))",
                                unit: "gal",
                                icon: "drop.fill"
                            )
                            StatCard(
                                title: "Flow Rate",
                                value: String(format: "%.1f", device.currentFlowRate ?? 0),
                                unit: "gpm",
                                icon: "arrow.right.circle.fill"
                            )
                            StatCard(
                                title: "Salt Level",
                                value: "\(device.saltLevel ?? 0)",
                                unit: "%",
                                icon: "cube.fill"
                            )
                            StatCard(
                                title: "Salt Days",
                                value: "\(device.daysSaltRemaining ?? 0)",
                                unit: "days",
                                icon: "calendar"
                            )
                        }

                        // Quick actions
                        VStack(spacing: 12) {
                            Text("Quick Actions")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 12) {
                                ActionButton(
                                    title: device.isBypassed ? "End Bypass" : "Bypass",
                                    icon: "arrow.uturn.right.circle.fill",
                                    isActive: device.isBypassed
                                ) {
                                    await viewModel.toggleBypass(client: authViewModel.client)
                                }

                                ActionButton(
                                    title: device.isVacationMode ? "End Vacation" : "Vacation",
                                    icon: "airplane.circle.fill",
                                    isActive: device.isVacationMode
                                ) {
                                    await viewModel.toggleVacation(client: authViewModel.client)
                                }
                            }
                        }
                    } else if let error = viewModel.errorMessage {
                        ContentUnavailableView(
                            "Unable to Load",
                            systemImage: "exclamationmark.triangle",
                            description: Text(error)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await viewModel.refresh(client: authViewModel.client)
            }
            .task {
                await viewModel.refresh(client: authViewModel.client)
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () async -> Void

    @State private var isPerforming = false

    var body: some View {
        Button {
            Task {
                isPerforming = true
                await action()
                isPerforming = false
            }
        } label: {
            HStack {
                if isPerforming {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .tint(isActive ? .orange : .cyan)
        .disabled(isPerforming)
    }
}
