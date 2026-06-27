import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DashboardViewModel()
    @State private var tankViewModel = TankViewModel()
    @Query(sort: \DailyUsageRecord.date) private var allUsageRecords: [DailyUsageRecord]
    @Query private var settings: [UserSettings]

    private var tankEnabled: Bool {
        settings.first?.tankTrackingEnabled ?? false
    }

    private var tankCapacity: Double {
        settings.first?.tankCapacity ?? 2000
    }

    private var deviceRecords: [DailyUsageRecord] {
        guard let serial = viewModel.device?.serialNumber else { return [] }
        return allUsageRecords.filter { $0.serialNumber == serial }
    }

    // MARK: - Weekly stats

    private func usageForDaysAgo(_ start: Int, _ end: Int) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return deviceRecords.filter { record in
            let daysAgo = cal.dateComponents([.day], from: record.date, to: today).day ?? 0
            return daysAgo >= start && daysAgo <= end
        }.reduce(0) { $0 + Int($1.gallons) }
    }

    private var weekTotal: Int { usageForDaysAgo(0, 6) }

    private var weekAvg: Int {
        let total = weekTotal
        return total > 0 ? total / 7 : 0
    }

    private var lastWeekTotal: Int { usageForDaysAgo(7, 13) }

    private var weekTrend: String {
        guard lastWeekTotal > 0 else { return "--" }
        let pct = Int(round(Double(weekTotal - lastWeekTotal) / Double(lastWeekTotal) * 100))
        if pct > 0 { return "+\(pct)%" }
        if pct < 0 { return "\(pct)%" }
        return "0%"
    }

    private var weekTrendIcon: String {
        if weekTotal > lastWeekTotal { return "arrow.up.right" }
        if weekTotal < lastWeekTotal { return "arrow.down.right" }
        return "equal"
    }

    private var weekTrendColor: Color {
        if weekTotal > lastWeekTotal { return .orange }
        if weekTotal < lastWeekTotal { return .green }
        return .secondary
    }

    private func formatRegenDate(_ dateStr: String) -> String {
        // Try parsing ISO date
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateStr) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return dateStr
    }

    private var isInitialLoading: Bool {
        viewModel.isLoading && viewModel.device == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if isInitialLoading {
                        DashboardSkeletonContent()
                            .transition(.opacity)
                    } else if let device = viewModel.device {

                        // 1. HERO — today's usage, big and prominent
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(device.waterUsageToday ?? 0))")
                                .font(.system(size: 56, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text("gal today")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)

                        // 2. CONTEXT — calendar heatmap
                        UsageCalendarView(records: deviceRecords)
                            .padding()
                            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16))

                        // 2.5 TANK — compact progress bar (if enabled)
                        if tankEnabled {
                            let fill = tankViewModel.fillPercentage(usageRecords: deviceRecords, capacity: tankCapacity)
                            let used = tankViewModel.gallonsSincePump(usageRecords: deviceRecords)
                            let remaining = tankViewModel.remainingCapacity(usageRecords: deviceRecords, capacity: tankCapacity)

                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "cylinder.fill")
                                        .font(.caption)
                                        .foregroundStyle(fill >= 80 ? .red : fill >= 70 ? .orange : .cyan)
                                    Text("Tank")
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text("\(Int(fill))%")
                                        .font(.subheadline.bold())
                                        .monospacedDigit()
                                        .foregroundStyle(fill >= 80 ? .red : fill >= 70 ? .orange : .primary)
                                }

                                // Progress bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(.systemGray5))
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(fill >= 80 ? Color.red.gradient : fill >= 70 ? Color.orange.gradient : Color.cyan.gradient)
                                            .frame(width: geo.size.width * min(1, fill / 100))
                                    }
                                }
                                .frame(height: 8)

                                HStack {
                                    Text("\(Int(used)) gal used")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(remaining)) gal remaining")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding()
                            .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16))
                        }

                        // 3. SECONDARY INFO — device + salt in a compact row
                        HStack(spacing: 12) {
                            // Device status
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(device.isOnline ? .green : .red)
                                    .frame(width: 8, height: 8)
                                Text(device.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            // Salt level
                            HStack(spacing: 4) {
                                Image(systemName: "cube.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.cyan)
                                Text("Salt \(device.saltLevel ?? 0)%")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            // Salt days
                            if let days = device.daysSaltRemaining {
                                Text("·")
                                    .foregroundStyle(.quaternary)
                                Text("\(days)d")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 4)

                        // 5. INSIGHTS — weekly summary cards
                        VStack(spacing: 12) {
                            Text("This Week")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 12) {
                                InsightCard(
                                    value: "\(weekTotal)",
                                    unit: "gal",
                                    label: "Total",
                                    icon: "drop.fill"
                                )
                                InsightCard(
                                    value: "\(weekAvg)",
                                    unit: "gal",
                                    label: "Daily Avg",
                                    icon: "chart.line.uptrend.xyaxis"
                                )
                                InsightCard(
                                    value: weekTrend,
                                    unit: "",
                                    label: "vs Last Week",
                                    icon: weekTrendIcon,
                                    valueColor: weekTrendColor
                                )
                            }
                        }

                        // 6. DEVICE DETAILS
                        VStack(spacing: 0) {
                            Text("Device")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 8)

                            DetailRow(label: "Model", value: device.model ?? device.name)
                            DetailRow(label: "Flow Rate", value: String(format: "%.1f gpm", device.currentFlowRate ?? 0))
                            if let lastRegen = device.lastRegeneration {
                                DetailRow(label: "Last Regen", value: formatRegenDate(lastRegen))
                            }
                            if let daysSince = device.daysSinceRegeneration {
                                DetailRow(label: "Days Since Regen", value: "\(daysSince)")
                            }
                            DetailRow(label: "Salt Remaining", value: "\(device.daysSaltRemaining ?? 0) days")
                            if let firmware = device.firmwareVersion {
                                DetailRow(label: "Firmware", value: firmware)
                            }
                        }
                        .padding()
                        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16))

                    } else if let error = viewModel.errorMessage {
                        ContentUnavailableView(
                            "Unable to Load",
                            systemImage: "exclamationmark.triangle",
                            description: Text(error)
                        )
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.3), value: isInitialLoading)
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await viewModel.refresh(client: authViewModel.client, modelContext: modelContext)
            }
            .task {
                await viewModel.refresh(client: authViewModel.client, modelContext: modelContext)
                if let serial = viewModel.device?.serialNumber, tankEnabled {
                    tankViewModel.loadPumpEvents(serialNumber: serial, modelContext: modelContext)
                }
            }
        }
    }
}

// MARK: - Loading Skeleton

/// Shimmering placeholder mirroring the dashboard layout, shown while the first
/// load is in flight. Mirrors `DashboardView`'s structure so the swap to real
/// content lands in roughly the same positions.
struct DashboardSkeletonContent: View {
    var body: some View {
        VStack(spacing: 16) {
            // Hero — today's usage
            SkeletonBlock(cornerRadius: 12)
                .frame(width: 200, height: 52)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

            // Calendar heatmap
            SkeletonBlock(cornerRadius: 16)
                .frame(height: 150)

            // Secondary info row
            HStack {
                SkeletonBlock(cornerRadius: 6).frame(width: 130, height: 16)
                Spacer()
                SkeletonBlock(cornerRadius: 6).frame(width: 70, height: 16)
            }
            .padding(.horizontal, 4)

            // This week — section header + three cards
            VStack(spacing: 12) {
                SkeletonBlock(cornerRadius: 4)
                    .frame(width: 90, height: 12)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonBlock(cornerRadius: 12).frame(height: 76)
                    }
                }
            }

            // Device details card
            SkeletonBlock(cornerRadius: 16)
                .frame(height: 200)
        }
        .accessibilityElement()
        .accessibilityLabel("Loading dashboard")
    }
}

/// A single rounded placeholder block with a subtle shimmer sweep.
struct SkeletonBlock: View {
    var cornerRadius: CGFloat = 12
    @State private var animate = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        shape
            .fill(Color.secondary.opacity(0.18))
            .overlay {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.25), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 0.7)
                    .offset(x: animate ? width : -width)
                }
            }
            .clipShape(shape)
            .onAppear {
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let value: String
    let unit: String
    let label: String
    let icon: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.cyan)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
