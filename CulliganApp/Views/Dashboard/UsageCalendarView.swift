import SwiftUI
import SwiftData

/// A GitHub-style calendar heatmap showing daily water usage.
/// Uses a native TabView with .page style for swipeable pagination.
struct UsageCalendarView: View {
    let records: [DailyUsageRecord]

    @State private var selectedDay: DailyUsageRecord?
    @State private var currentPage: Int? // nil = not yet initialized

    private var calendar: Calendar { .current }

    private var usageByDate: [String: Double] {
        Dictionary(grouping: records, by: { $0.dateString })
            .mapValues { $0.first?.gallons ?? 0 }
    }

    private var maxUsage: Double {
        records.map(\.gallons).max() ?? 1
    }

    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3
    private let dayLabelWidth: CGFloat = 16
    private let maxColumns: Int = 26

    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width - dayLabelWidth - cellSpacing
            let columnWidth = cellSize + cellSpacing
            let visibleColumns = min(maxColumns, max(1, Int(floor(availableWidth / columnWidth))))
            let pages = totalPages(visibleColumns: visibleColumns)

            VStack(alignment: .leading, spacing: 0) {
                // Swipeable pages — index 0 = oldest, pages-1 = newest
                TabView(selection: Binding(
                    get: { currentPage ?? pages - 1 },
                    set: { currentPage = $0 }
                )) {
                    ForEach(0..<pages, id: \.self) { pageIndex in
                        // Convert: pageIndex 0 = oldest = highest "page back" offset
                        let pageBack = pages - 1 - pageIndex
                        calendarPage(
                            visibleColumns: visibleColumns,
                            page: pageBack,
                            containerWidth: geo.size.width
                        )
                        .tag(pageIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 130)
                .onAppear {
                    if currentPage == nil {
                        currentPage = pages - 1
                    }
                }

                // Selected day detail
                if let selected = selectedDay {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colorForUsage(selected.gallons))
                            .frame(width: 10, height: 10)
                        Text(selected.date, format: .dateTime.month(.abbreviated).day().year())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("\(Int(selected.gallons)) gal")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.top, 4)
                }

                // Legend
                HStack(spacing: 4) {
                    Text("Less")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorForLevel(level))
                            .frame(width: cellSize, height: cellSize)
                    }
                    Text("More")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if pages > 1 {
                        // Dot indicators
                        HStack(spacing: 4) {
                            ForEach(0..<pages, id: \.self) { i in
                                Circle()
                                    .fill(i == (currentPage ?? pages - 1) ? Color.cyan : Color(.systemGray4))
                                    .frame(width: 5, height: 5)
                            }
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
        .frame(height: selectedDay != nil ? 175 : 155)
    }

    // MARK: - Single Calendar Page

    private func calendarPage(visibleColumns: Int, page: Int, containerWidth: CGFloat) -> some View {
        let weeksData = buildWeeks(visibleColumns: visibleColumns, page: page)

        return VStack(alignment: .leading, spacing: 4) {
            // Month labels
            monthLabelRow(weeks: weeksData)

            // Grid
            HStack(alignment: .top, spacing: cellSpacing) {
                // Day-of-week labels
                VStack(spacing: cellSpacing) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        if dayIndex == 1 || dayIndex == 3 || dayIndex == 5 {
                            Text(shortDayName(dayIndex))
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .frame(width: dayLabelWidth, height: cellSize)
                        } else {
                            Color.clear.frame(width: dayLabelWidth, height: cellSize)
                        }
                    }
                }

                // Week columns
                HStack(spacing: cellSpacing) {
                    ForEach(Array(weeksData.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<7, id: \.self) { rowIndex in
                                cellView(week[rowIndex])
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Build Weeks

    private func totalPages(visibleColumns: Int) -> Int {
        guard let oldest = records.map(\.date).min() else { return 1 }
        let today = calendar.startOfDay(for: Date())
        let totalWeeks = max(1, Int(ceil(Double(calendar.dateComponents([.day], from: oldest, to: today).day ?? 0) / 7.0)))
        return max(1, Int(ceil(Double(totalWeeks) / Double(visibleColumns))))
    }

    private func buildWeeks(visibleColumns: Int, page: Int) -> [[DayCell]] {
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today)
        let daysUntilEndOfWeek = (7 - todayWeekday + calendar.firstWeekday) % 7
        let endOfCurrentWeek = calendar.date(byAdding: .day, value: daysUntilEndOfWeek, to: today)!

        let pageOffsetDays = page * visibleColumns * 7
        let endOfPage = calendar.date(byAdding: .day, value: -pageOffsetDays, to: endOfCurrentWeek)!

        let totalDays = visibleColumns * 7
        let gridStart = calendar.date(byAdding: .day, value: -(totalDays - 1), to: endOfPage)!

        var result: [[DayCell]] = []
        var current = gridStart

        for _ in 0..<visibleColumns {
            var week: [DayCell] = []
            for _ in 0..<7 {
                let isFuture = current > today
                let dateStr = DailyUsageRecord.dateFormatter.string(from: current)
                let gallons = usageByDate[dateStr]
                week.append(DayCell(date: current, gallons: gallons, isInRange: !isFuture))
                current = calendar.date(byAdding: .day, value: 1, to: current)!
            }
            result.append(week)
        }

        return result
    }

    // MARK: - Month Labels

    private func monthLabelRow(weeks: [[DayCell]]) -> some View {
        let labels = computeMonthLabels(weeks: weeks)
        let columnWidth = cellSize + cellSpacing

        return HStack(spacing: 0) {
            Color.clear.frame(width: dayLabelWidth + cellSpacing, height: 1)

            ForEach(Array(labels.enumerated()), id: \.offset) { i, label in
                let (name, col) = label
                let nextCol = i + 1 < labels.count ? labels[i + 1].1 : weeks.count
                let colSpan = nextCol - col
                let width = CGFloat(colSpan) * columnWidth
                // Hide label if column span is too narrow to fit
                let minWidth: CGFloat = name.count > 3 ? 42 : 24
                if width >= minWidth {
                    Text(name)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: width, alignment: .leading)
                        .lineLimit(1)
                        .clipped()
                } else {
                    Color.clear.frame(width: width, height: 1)
                }
            }
        }
    }

    private func computeMonthLabels(weeks: [[DayCell]]) -> [(String, Int)] {
        var labels: [(String, Int)] = []
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yy"
        var lastMonth = -1
        var lastYear = -1

        for (colIndex, week) in weeks.enumerated() {
            if let firstDay = week.first(where: { $0.isInRange }) {
                let month = calendar.component(.month, from: firstDay.date)
                let year = calendar.component(.year, from: firstDay.date)
                if month != lastMonth {
                    var name = monthFormatter.string(from: firstDay.date)
                    // Show year on first label, or when year changes
                    if lastYear == -1 || year != lastYear {
                        name += " '\(yearFormatter.string(from: firstDay.date))"
                    }
                    labels.append((name, colIndex))
                    lastMonth = month
                    lastYear = year
                }
            }
        }
        return labels
    }

    // MARK: - Cell View

    @ViewBuilder
    private func cellView(_ cell: DayCell) -> some View {
        if cell.isInRange {
            RoundedRectangle(cornerRadius: 2)
                .fill(colorForUsage(cell.gallons ?? 0))
                .frame(width: cellSize, height: cellSize)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(
                            isSelected(cell) ? Color.primary.opacity(0.5) : Color.clear,
                            lineWidth: 1.5
                        )
                )
                .onTapGesture {
                    if let gallons = cell.gallons {
                        selectedDay = DailyUsageRecord(serialNumber: "", date: cell.date, gallons: gallons)
                    }
                }
        } else {
            Color.clear.frame(width: cellSize, height: cellSize)
        }
    }

    private func isSelected(_ cell: DayCell) -> Bool {
        guard let selected = selectedDay else { return false }
        return DailyUsageRecord.dateFormatter.string(from: cell.date) == selected.dateString
    }

    // MARK: - Colors

    private func colorForUsage(_ gallons: Double) -> Color {
        guard maxUsage > 0 else { return Color(.systemGray5) }
        let level = min(1.0, gallons / maxUsage)
        return colorForLevel(level)
    }

    private func colorForLevel(_ level: Double) -> Color {
        if level == 0 { return Color(.systemGray5) }
        return Color.cyan.opacity(0.15 + level * 0.75)
    }

    private func shortDayName(_ index: Int) -> String {
        let names = ["S", "M", "T", "W", "T", "F", "S"]
        let adjusted = (index + calendar.firstWeekday - 1) % 7
        return names[adjusted]
    }
}

private struct DayCell {
    let date: Date
    let gallons: Double?
    let isInRange: Bool
}
