import Foundation
import UIKit

/// Generates CSV and PDF exports of usage data.
enum ExportService {

    enum ExportFormat: String, CaseIterable, Identifiable {
        case csv = "CSV"
        case pdf = "PDF"
        var id: String { rawValue }
    }

    enum ExportRange: String, CaseIterable, Identifiable {
        case sevenDays = "7 Days"
        case thirtyDays = "30 Days"
        case ninetyDays = "90 Days"
        case oneYear = "1 Year"
        case allTime = "All Time"

        var id: String { rawValue }

        var days: Int? {
            switch self {
            case .sevenDays: return 7
            case .thirtyDays: return 30
            case .ninetyDays: return 90
            case .oneYear: return 365
            case .allTime: return nil
            }
        }
    }

    // MARK: - CSV

    static func generateCSV(records: [DailyUsageRecord], deviceName: String) -> URL? {
        var csv = "Date,Gallons\n"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for record in records.sorted(by: { $0.date < $1.date }) {
            csv += "\(formatter.string(from: record.date)),\(Int(record.gallons))\n"
        }

        let fileName = "culligan-usage-\(sanitize(deviceName)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("CSV export error: \(error)")
            return nil
        }
    }

    // MARK: - PDF

    static func generatePDF(records: [DailyUsageRecord], deviceName: String) -> URL? {
        let sorted = records.sorted(by: { $0.date < $1.date })
        guard let first = sorted.first, let last = sorted.last else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let totalGallons = sorted.reduce(0) { $0 + Int($1.gallons) }
        let avgDaily = sorted.isEmpty ? 0 : totalGallons / sorted.count
        let maxDay = sorted.max(by: { $0.gallons < $1.gallons })

        // PDF dimensions (US Letter)
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            let title = "Water Usage Report"
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 36

            // Subtitle
            let subtitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let subtitle = "\(deviceName) · \(dateFormatter.string(from: first.date)) – \(dateFormatter.string(from: last.date))"
            subtitle.draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
            y += 30

            // Divider
            let dividerPath = UIBezierPath()
            dividerPath.move(to: CGPoint(x: margin, y: y))
            dividerPath.addLine(to: CGPoint(x: margin + contentWidth, y: y))
            UIColor.separator.setStroke()
            dividerPath.lineWidth = 0.5
            dividerPath.stroke()
            y += 20

            // Summary stats
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.secondaryLabel
            ]

            "SUMMARY".draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
            y += 24

            let stats: [(String, String)] = [
                ("Total Usage", "\(totalGallons.formatted()) gal"),
                ("Daily Average", "\(avgDaily) gal"),
                ("Days Tracked", "\(sorted.count)"),
                ("Peak Day", maxDay.map { "\(dateFormatter.string(from: $0.date)) (\(Int($0.gallons)) gal)" } ?? "--"),
            ]

            for (label, value) in stats {
                value.draw(at: CGPoint(x: margin, y: y), withAttributes: valueAttrs)
                label.draw(at: CGPoint(x: margin + 200, y: y + 2), withAttributes: labelAttrs)
                y += 24
            }
            y += 16

            // Divider
            let divider2 = UIBezierPath()
            divider2.move(to: CGPoint(x: margin, y: y))
            divider2.addLine(to: CGPoint(x: margin + contentWidth, y: y))
            UIColor.separator.setStroke()
            divider2.lineWidth = 0.5
            divider2.stroke()
            y += 20

            // Daily data table header
            "DAILY USAGE".draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
            y += 24

            let colDateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.label
            ]
            let colValAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.label
            ]

            let rowFormatter = DateFormatter()
            rowFormatter.dateFormat = "yyyy-MM-dd"

            for record in sorted {
                if y > pageHeight - margin - 20 {
                    context.beginPage()
                    y = margin
                }

                let dateStr = rowFormatter.string(from: record.date)
                let galStr = "\(Int(record.gallons)) gal"

                dateStr.draw(at: CGPoint(x: margin, y: y), withAttributes: colDateAttrs)
                galStr.draw(at: CGPoint(x: margin + 120, y: y), withAttributes: colValAttrs)
                y += 16
            }

            // Footer
            y = pageHeight - margin
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: UIColor.tertiaryLabel
            ]
            "Generated by Culligan Water Usage Analytics".draw(at: CGPoint(x: margin, y: y), withAttributes: footerAttrs)
        }

        let fileName = "culligan-usage-\(sanitize(deviceName)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url)
            return url
        } catch {
            print("PDF export error: \(error)")
            return nil
        }
    }

    // MARK: - Helpers

    private static func sanitize(_ name: String) -> String {
        name.replacingOccurrences(of: " ", with: "-")
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
