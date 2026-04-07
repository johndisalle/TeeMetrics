// MARK: - PDF Round Report Generator
// Beautiful, printable round reports

import UIKit
import PDFKit

@MainActor
enum PDFReportGenerator {

    static func generateReport(round: GolfRound) -> Data {
        let pageWidth: CGFloat = 612  // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            context.beginPage()

            var y: CGFloat = margin

            // MARK: - Header
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor(red: 0.13, green: 0.37, blue: 0.25, alpha: 1)
            ]
            let title = "TeeMetrics Round Report"
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
            y += 40

            // Divider
            let dividerPath = UIBezierPath()
            dividerPath.move(to: CGPoint(x: margin, y: y))
            dividerPath.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            UIColor(red: 0.13, green: 0.37, blue: 0.25, alpha: 0.3).setStroke()
            dividerPath.lineWidth = 1
            dividerPath.stroke()
            y += 16

            // MARK: - Course & Date
            let courseAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            let courseName = round.course?.name ?? "Unknown Course"
            courseName.draw(at: CGPoint(x: margin, y: y), withAttributes: courseAttrs)
            y += 26

            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            let dateStr = round.date.formatted(date: .long, time: .omitted)
            dateStr.draw(at: CGPoint(x: margin, y: y), withAttributes: dateAttrs)
            y += 30

            // MARK: - Summary Stats
            let statFont = UIFont.systemFont(ofSize: 13)
            let statBoldFont = UIFont.systemFont(ofSize: 13, weight: .bold)
            let statColor = UIColor.darkGray

            let stats: [(String, String)] = [
                ("Total Score", "\(round.totalScore) (\(round.scoreToParString))"),
                ("Front 9", "\(round.frontNine)"),
                ("Back 9", "\(round.backNine)"),
                ("Total Putts", "\(round.totalPutts)"),
                ("Fairway %", String(format: "%.0f%%", round.fairwayPercentage)),
                ("GIR %", String(format: "%.0f%%", round.girPercentage)),
                ("Avg Putts/Hole", String(format: "%.1f", round.averagePutts)),
            ]

            for (label, value) in stats {
                label.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: statFont, .foregroundColor: statColor])
                value.draw(at: CGPoint(x: margin + 180, y: y), withAttributes: [.font: statBoldFont, .foregroundColor: UIColor.black])
                y += 20
            }
            y += 16

            // MARK: - Scorecard Header
            let scFont = UIFont.systemFont(ofSize: 10, weight: .bold)
            let scDataFont = UIFont.systemFont(ofSize: 10)
            let colWidth: CGFloat = contentWidth / 11 // 9 holes + OUT/label column

            // Column headers
            let headers = ["Hole", "1", "2", "3", "4", "5", "6", "7", "8", "9", "OUT"]
            for (i, h) in headers.enumerated() {
                let x = margin + CGFloat(i) * colWidth
                h.draw(at: CGPoint(x: x + 4, y: y), withAttributes: [.font: scFont, .foregroundColor: UIColor.gray])
            }
            y += 16

            let entries = round.holeEntries.sorted { $0.holeNumber < $1.holeNumber }
            let front = entries.filter { $0.holeNumber <= 9 }
            let back = entries.filter { $0.holeNumber > 9 }

            // Par row
            drawScorecardRow(y: &y, label: "Par", entries: front, getValue: { "\($0.par)" }, total: front.reduce(0) { $0 + $1.par }, margin: margin, colWidth: colWidth, font: scDataFont)

            // Score row
            drawScorecardRow(y: &y, label: "Score", entries: front, getValue: { "\($0.score)" }, total: front.reduce(0) { $0 + $1.score }, margin: margin, colWidth: colWidth, font: scDataFont)

            // Putts row
            drawScorecardRow(y: &y, label: "Putts", entries: front, getValue: { "\($0.putts)" }, total: front.reduce(0) { $0 + $1.putts }, margin: margin, colWidth: colWidth, font: scDataFont)

            y += 12

            // Back 9
            let backHeaders = ["Hole", "10", "11", "12", "13", "14", "15", "16", "17", "18", "IN"]
            for (i, h) in backHeaders.enumerated() {
                let x = margin + CGFloat(i) * colWidth
                h.draw(at: CGPoint(x: x + 4, y: y), withAttributes: [.font: scFont, .foregroundColor: UIColor.gray])
            }
            y += 16

            drawScorecardRow(y: &y, label: "Par", entries: back, getValue: { "\($0.par)" }, total: back.reduce(0) { $0 + $1.par }, margin: margin, colWidth: colWidth, font: scDataFont)
            drawScorecardRow(y: &y, label: "Score", entries: back, getValue: { "\($0.score)" }, total: back.reduce(0) { $0 + $1.score }, margin: margin, colWidth: colWidth, font: scDataFont)
            drawScorecardRow(y: &y, label: "Putts", entries: back, getValue: { "\($0.putts)" }, total: back.reduce(0) { $0 + $1.putts }, margin: margin, colWidth: colWidth, font: scDataFont)

            // MARK: - Footer
            y = pageHeight - margin - 20
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.lightGray
            ]
            "Generated by TeeMetrics — teemetrics.app".draw(at: CGPoint(x: margin, y: y), withAttributes: footerAttrs)
        }
    }

    private static func drawScorecardRow(
        y: inout CGFloat,
        label: String,
        entries: [HoleEntry],
        getValue: (HoleEntry) -> String,
        total: Int,
        margin: CGFloat,
        colWidth: CGFloat,
        font: UIFont
    ) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: UIColor.darkGray]

        label.draw(at: CGPoint(x: margin + 4, y: y), withAttributes: labelAttrs)
        for (i, entry) in entries.enumerated() {
            let x = margin + CGFloat(i + 1) * colWidth
            getValue(entry).draw(at: CGPoint(x: x + 4, y: y), withAttributes: attrs)
        }
        let totalX = margin + CGFloat(entries.count + 1) * colWidth
        "\(total)".draw(at: CGPoint(x: totalX + 4, y: y), withAttributes: [.font: UIFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: UIColor.black])
        y += 16
    }
}
