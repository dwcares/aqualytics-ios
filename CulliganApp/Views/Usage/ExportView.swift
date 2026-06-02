import SwiftUI
import SwiftData

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let serialNumber: String
    let deviceName: String

    @State private var selectedRange: ExportService.ExportRange = .thirtyDays
    @State private var selectedFormat: ExportService.ExportFormat = .csv
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            List {
                Section("Date Range") {
                    ForEach(ExportService.ExportRange.allCases) { range in
                        HStack {
                            Text(range.rawValue)
                            Spacer()
                            if range == selectedRange {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.cyan)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedRange = range }
                    }
                }

                Section("Format") {
                    ForEach(ExportService.ExportFormat.allCases) { format in
                        HStack {
                            Image(systemName: format == .csv ? "tablecells" : "doc.richtext")
                                .foregroundStyle(.cyan)
                                .frame(width: 24)
                            Text(format.rawValue)
                            Spacer()
                            if format == selectedFormat {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.cyan)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedFormat = format }
                    }
                }

                Section {
                    let records = fetchRecords()
                    let count = records.count
                    let total = records.reduce(0) { $0 + Int($1.gallons) }

                    HStack {
                        Text("\(count) days")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(total.formatted()) gal total")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                } header: {
                    Text("Preview")
                }

                Section {
                    Button {
                        exportData()
                    } label: {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export \(selectedFormat.rawValue)")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isExporting)
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func fetchRecords() -> [DailyUsageRecord] {
        let today = Calendar.current.startOfDay(for: Date())

        if let days = selectedRange.days {
            let startDate = Calendar.current.date(byAdding: .day, value: -(days - 1), to: today)!
            let descriptor = FetchDescriptor<DailyUsageRecord>(
                predicate: #Predicate {
                    $0.serialNumber == serialNumber &&
                    $0.date >= startDate &&
                    $0.date <= today
                },
                sortBy: [SortDescriptor(\.date)]
            )
            return (try? modelContext.fetch(descriptor)) ?? []
        } else {
            let descriptor = FetchDescriptor<DailyUsageRecord>(
                predicate: #Predicate { $0.serialNumber == serialNumber },
                sortBy: [SortDescriptor(\.date)]
            )
            return (try? modelContext.fetch(descriptor)) ?? []
        }
    }

    private func exportData() {
        isExporting = true
        let records = fetchRecords()

        let url: URL?
        switch selectedFormat {
        case .csv:
            url = ExportService.generateCSV(records: records, deviceName: deviceName)
        case .pdf:
            url = ExportService.generatePDF(records: records, deviceName: deviceName)
        }

        if let url {
            exportURL = url
            showShareSheet = true
        }
        isExporting = false
    }
}

// MARK: - Share Sheet (UIKit bridge)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
