import SwiftUI
import Charts

struct UsageChartView: View {
    let dailyUsage: [DailyUsageRecord]
    @Binding var selectedBarIndices: ClosedRange<Int>?

    @State private var dragStart: Int?
    @State private var isDragging = false

    var body: some View {
        Chart {
            ForEach(Array(dailyUsage.enumerated()), id: \.offset) { index, record in
                BarMark(
                    x: .value("Date", record.date, unit: .day),
                    y: .value("Gallons", record.gallons)
                )
                .foregroundStyle(barColor(for: index))
                .cornerRadius(3)
            }

            // Show rule mark for selection range
            if let range = selectedBarIndices,
               range.lowerBound < dailyUsage.count,
               range.upperBound < dailyUsage.count {
                RectangleMark(
                    xStart: .value("Start", dailyUsage[range.lowerBound].date, unit: .day),
                    xEnd: .value("End", Calendar.current.date(byAdding: .day, value: 1, to: dailyUsage[range.upperBound].date)!, unit: .day)
                )
                .foregroundStyle(.cyan.opacity(0.08))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: xAxisStride)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                AxisValueLabel()
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let startIndex = barIndex(at: value.startLocation, proxy: proxy, geometry: geometry) else { return }

                                if !isDragging {
                                    dragStart = startIndex
                                    isDragging = true
                                }

                                if let ds = dragStart,
                                   let currentIndex = barIndex(at: value.location, proxy: proxy, geometry: geometry) {
                                    let lo = min(ds, currentIndex)
                                    let hi = max(ds, currentIndex)
                                    selectedBarIndices = lo...hi
                                }
                            }
                            .onEnded { _ in
                                isDragging = false
                                dragStart = nil
                            }
                    )
            }
        }
        .frame(height: 220)
    }

    private func barColor(for index: Int) -> Color {
        if let range = selectedBarIndices, range.contains(index) {
            return .cyan
        }
        return .cyan.opacity(0.6)
    }

    private var xAxisStride: Int {
        let count = dailyUsage.count
        if count <= 7 { return 1 }
        if count <= 14 { return 2 }
        if count <= 30 { return 5 }
        if count <= 60 { return 7 }
        return 14
    }

    private func barIndex(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) -> Int? {
        let origin = geometry[proxy.plotFrame!].origin
        let adjustedX = location.x - origin.x

        guard let date: Date = proxy.value(atX: adjustedX) else { return nil }

        // Find the closest bar index
        let target = Calendar.current.startOfDay(for: date)
        var closest: Int?
        var minDist: TimeInterval = .infinity

        for (i, record) in dailyUsage.enumerated() {
            let dist = abs(record.date.timeIntervalSince(target))
            if dist < minDist {
                minDist = dist
                closest = i
            }
        }

        return closest
    }
}
