import SwiftUI
import SwiftData

struct UsageView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = UsageViewModel()

    // Get the selected device serial from settings or first available
    @Query private var settings: [UserSettings]

    private var serialNumber: String? {
        settings.first?.selectedDeviceSerial
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Range picker
                    Picker("Range", selection: $viewModel.selectedRange) {
                        ForEach(UsageViewModel.UsageRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.selectedRange) {
                        if let serial = serialNumber {
                            viewModel.currentPage = 0
                            viewModel.loadFromStore(serialNumber: serial, modelContext: modelContext)
                        }
                    }

                    // Summary stats
                    HStack(spacing: 16) {
                        MiniStat(label: "Total", value: "\(Int(viewModel.totalGallons))", unit: "gal")
                        MiniStat(label: "Daily Avg", value: String(format: "%.0f", viewModel.averageDaily), unit: "gal")
                        MiniStat(label: "Days", value: "\(viewModel.dailyUsage.count)", unit: "")
                    }

                    // Chart
                    VStack(spacing: 12) {
                        // Navigation (for 30D paginated view)
                        if viewModel.selectedRange == .thirtyDays {
                            HStack {
                                Button {
                                    if let serial = serialNumber {
                                        viewModel.loadOlder(serialNumber: serial, modelContext: modelContext)
                                    }
                                } label: {
                                    Label("Older", systemImage: "chevron.left")
                                        .font(.caption)
                                }
                                .disabled(viewModel.currentPage >= viewModel.totalPages - 1)

                                Spacer()

                                Text(viewModel.dateRangeText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button {
                                    if let serial = serialNumber {
                                        viewModel.loadNewer(serialNumber: serial, modelContext: modelContext)
                                    }
                                } label: {
                                    Label("Newer", systemImage: "chevron.right")
                                        .font(.caption)
                                        .environment(\.layoutDirection, .rightToLeft)
                                }
                                .disabled(viewModel.currentPage <= 0)
                            }
                        }

                        if viewModel.dailyUsage.isEmpty {
                            ContentUnavailableView(
                                "No Usage Data",
                                systemImage: "chart.bar",
                                description: Text("Pull to refresh to load data from your softener.")
                            )
                            .frame(height: 220)
                        } else {
                            UsageChartView(
                                dailyUsage: viewModel.dailyUsage,
                                selectedBarIndices: $viewModel.selectedBarIndices
                            )
                        }

                        // Selection info
                        if let total = viewModel.selectedTotal, let days = viewModel.selectedDayCount {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(Int(total)) gal")
                                        .font(.headline)
                                        .foregroundStyle(.cyan)
                                    Text("\(days) day\(days == 1 ? "" : "s") selected")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("Clear") {
                                    viewModel.clearSelection()
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                            .padding()
                            .background(.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding()
                    .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("Usage")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Export — Phase 4
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .refreshable {
                if let serial = serialNumber {
                    await viewModel.refresh(client: authViewModel.client, serialNumber: serial, modelContext: modelContext)
                }
            }
            .task {
                if let serial = serialNumber {
                    await viewModel.refresh(client: authViewModel.client, serialNumber: serial, modelContext: modelContext)
                }
            }
        }
    }
}

// MARK: - Mini Stat

struct MiniStat: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    UsageView()
        .environment(AuthViewModel())
        .modelContainer(for: [DailyUsageRecord.self, UserSettings.self], inMemory: true)
}
