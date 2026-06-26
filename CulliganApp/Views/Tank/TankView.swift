import SwiftUI
import SwiftData

struct TankView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TankViewModel()

    @Query(sort: \DailyUsageRecord.date) private var allUsageRecords: [DailyUsageRecord]
    @Query private var settings: [UserSettings]

    private var serialNumber: String? {
        settings.first?.selectedDeviceSerial
    }

    private var capacity: Double {
        settings.first?.tankCapacity ?? 2000
    }

    private var deviceRecords: [DailyUsageRecord] {
        guard let serial = serialNumber else { return [] }
        return allUsageRecords.filter { $0.serialNumber == serial }
    }

    // Pump state
    @State private var showPumpConfirm = false
    @State private var showDatePicker = false
    @State private var customPumpDate = Date()
    @State private var showDeleteConfirm = false
    @State private var eventToDelete: PumpEvent?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Gauge
                    TankGaugeView(
                        fillPercentage: viewModel.fillPercentage(usageRecords: deviceRecords, capacity: capacity),
                        gallonsUsed: viewModel.gallonsSincePump(usageRecords: deviceRecords),
                        capacity: capacity
                    )
                    .padding(.top, 8)

                    // Warning banner
                    let fill = viewModel.fillPercentage(usageRecords: deviceRecords, capacity: capacity)
                    if fill >= 80 {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text("Tank is nearly full. Schedule pumping soon.")
                                .font(.subheadline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Stats row
                    HStack(spacing: 12) {
                        TankStat(
                            label: "Since Pump",
                            value: "\(Int(viewModel.gallonsSincePump(usageRecords: deviceRecords)))",
                            unit: "gal"
                        )
                        TankStat(
                            label: "Remaining",
                            value: "\(Int(viewModel.remainingCapacity(usageRecords: deviceRecords, capacity: capacity)))",
                            unit: "gal"
                        )
                        TankStat(
                            label: "Days",
                            value: viewModel.daysSinceLastPump().map(String.init) ?? "--",
                            unit: ""
                        )
                    }

                    // Mark as pumped button
                    VStack(spacing: 8) {
                        Button {
                            showPumpConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Mark as Pumped")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)

                        Button {
                            customPumpDate = Date()
                            showDatePicker = true
                        } label: {
                            Text("Choose a different date")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Pump history
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pump History")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        PumpHistoryView(pumpEvents: viewModel.pumpEvents) { event in
                            eventToDelete = event
                            showDeleteConfirm = true
                        }
                    }
                    .padding()
                    .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("Tank")
            .task {
                if let serial = serialNumber {
                    viewModel.loadPumpEvents(serialNumber: serial, modelContext: modelContext)
                }
            }
            // Pump today confirmation
            .confirmationDialog("Mark as Pumped", isPresented: $showPumpConfirm) {
                Button("Pump Today") {
                    if let serial = serialNumber {
                        viewModel.markAsPumped(
                            serialNumber: serial,
                            usageRecords: deviceRecords,
                            modelContext: modelContext
                        )
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Record that your tank was pumped today?")
            }
            // Custom date picker
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    VStack(spacing: 20) {
                        DatePicker("Pump Date", selection: $customPumpDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(.cyan)

                        Button {
                            if let serial = serialNumber {
                                viewModel.markAsPumped(
                                    serialNumber: serial,
                                    date: customPumpDate,
                                    usageRecords: deviceRecords,
                                    modelContext: modelContext
                                )
                            }
                            showDatePicker = false
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Mark as Pumped")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                    }
                    .padding()
                    .navigationTitle("Choose Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showDatePicker = false }
                        }
                    }
                }
                .presentationDetents([.large])
            }
            // Delete confirmation
            .confirmationDialog("Delete Pump Event", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let event = eventToDelete, let serial = serialNumber {
                        viewModel.deletePumpEvent(event, serialNumber: serial, modelContext: modelContext)
                    }
                    eventToDelete = nil
                }
                Button("Cancel", role: .cancel) { eventToDelete = nil }
            } message: {
                Text("Are you sure you want to delete this pump event?")
            }
        }
    }
}

// MARK: - Tank Stat

struct TankStat: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.subheadline.bold())
                    .monospacedDigit()
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
        .padding(.vertical, 10)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    TankView()
        .modelContainer(for: [DailyUsageRecord.self, PumpEvent.self, UserSettings.self], inMemory: true)
}
