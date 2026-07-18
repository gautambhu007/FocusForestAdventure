//
//  ReportService.swift
//  Focus Forest Adventure
//
//  Phase 2.4 Teacher Mode: weekly summary reports as PDF and CSV, shared
//  through the system share sheet (AirDrop, Mail, print, Files…).
//
//  Data minimization: reports carry the child's first name, aggregate
//  progress numbers, and recommendations — nothing else.
//

import Foundation
import UIKit

// MARK: - Report model (pure, testable)

struct ProgressReport: Sendable, Equatable {
    struct SubjectRow: Sendable, Equatable {
        let subject: String
        let missions: Int
        let accuracyPercent: Int
        let averageResponseSeconds: Double
        let difficulty: Int
    }

    let childName: String
    let generatedAt: Date
    let rangeDays: Int
    let totalMissions: Int
    let focusMinutes: Int
    let attentionPercent: Int
    let subjects: [SubjectRow]
    let achievements: [String]
    let recommendations: [String]
}

/// Builds a report from the dashboard's aggregates. Pure transformation.
struct ReportBuilder: Sendable {

    func makeReport(
        childName: String,
        rangeDays: Int,
        summary: PerformanceSummary,
        achievements: [AchievementID],
        recommendations: [String],
        generatedAt: Date = .now
    ) -> ProgressReport {
        let rows = summary.perSubject
            .map { kind, stats in
                ProgressReport.SubjectRow(
                    subject: kind.localizedTitle,
                    missions: stats.missions,
                    accuracyPercent: Int((stats.accuracy * 100).rounded()),
                    averageResponseSeconds: (stats.averageResponseTime * 10).rounded() / 10,
                    difficulty: stats.currentDifficulty
                )
            }
            .sorted { $0.missions > $1.missions }

        return ProgressReport(
            childName: childName,
            generatedAt: generatedAt,
            rangeDays: rangeDays,
            totalMissions: summary.totalMissions,
            focusMinutes: Int(summary.totalFocusSeconds / 60),
            attentionPercent: Int((summary.averageAttentionScore * 100).rounded()),
            subjects: rows,
            achievements: achievements.map { "\($0.emoji) \($0.localizedTitle)" },
            recommendations: recommendations
        )
    }
}

// MARK: - CSV (stable schema, pure, testable)

enum ReportCSVEncoder {

    /// Stable column names — external tools may depend on them.
    static let header = "subject,missions,accuracy_percent,avg_response_seconds,difficulty"

    static func encode(_ report: ProgressReport) -> String {
        var lines: [String] = []
        lines.append("child,\(escape(report.childName))")
        lines.append("generated_at,\(ISO8601DateFormatter().string(from: report.generatedAt))")
        lines.append("range_days,\(report.rangeDays)")
        lines.append("total_missions,\(report.totalMissions)")
        lines.append("focus_minutes,\(report.focusMinutes)")
        lines.append("attention_percent,\(report.attentionPercent)")
        lines.append("")
        lines.append(header)
        for row in report.subjects {
            lines.append([
                escape(row.subject),
                "\(row.missions)",
                "\(row.accuracyPercent)",
                "\(row.averageResponseSeconds)",
                "\(row.difficulty)"
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// Quote fields containing commas/quotes/newlines per RFC 4180.
    static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
}

// MARK: - PDF rendering + file export

@MainActor
enum ReportExporter {

    static func writeCSV(_ report: ProgressReport) throws -> URL {
        let url = exportURL(named: "FocusForest-Progress.csv")
        try ReportCSVEncoder.encode(report).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func writePDF(_ report: ProgressReport) throws -> URL {
        let url = exportURL(named: "FocusForest-Report.pdf")
        try renderPDF(report).write(to: url, options: .atomic)
        return url
    }

    private static func exportURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    // MARK: Achievement certificate

    /// A printable certificate for the child's Hindi learning stars.
    static func writeCertificate(childName: String, stars: Int) throws -> URL {
        let url = exportURL(named: "FocusForest-Certificate.pdf")
        try renderCertificate(childName: childName, stars: stars).write(to: url, options: .atomic)
        return url
    }

    private static func renderCertificate(childName: String, stars: Int) -> Data {
        let page = CGRect(x: 0, y: 0, width: 842, height: 595)   // A4 landscape
        let renderer = UIGraphicsPDFRenderer(bounds: page)

        func drawCentered(_ text: String, font: UIFont, y: CGFloat, color: UIColor = .darkText) {
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let size = (text as NSString).size(withAttributes: attributes)
            (text as NSString).draw(at: CGPoint(x: (page.width - size.width) / 2, y: y),
                                    withAttributes: attributes)
        }

        return renderer.pdfData { context in
            context.beginPage()
            // Decorative double border
            let green = UIColor(red: 0.13, green: 0.42, blue: 0.30, alpha: 1)
            green.setStroke()
            let outer = UIBezierPath(rect: page.insetBy(dx: 24, dy: 24)); outer.lineWidth = 4; outer.stroke()
            let inner = UIBezierPath(rect: page.insetBy(dx: 34, dy: 34)); inner.lineWidth = 1.5; inner.stroke()

            drawCentered("🐰 🌟 🐰", font: .systemFont(ofSize: 34), y: 70)
            drawCentered("Certificate of Achievement", font: .systemFont(ofSize: 40, weight: .heavy), y: 120, color: green)
            drawCentered("प्रमाण पत्र", font: .systemFont(ofSize: 22, weight: .semibold), y: 172, color: green)
            drawCentered("This certificate is proudly presented to", font: .systemFont(ofSize: 18), y: 230)
            drawCentered(childName, font: .systemFont(ofSize: 44, weight: .bold), y: 265, color: green)
            drawCentered("for earning \(stars) stars while learning Hindi", font: .systemFont(ofSize: 20), y: 340)
            drawCentered("शाबाश! Keep exploring, keep growing! 🌳", font: .systemFont(ofSize: 18), y: 380)
            let date = Date().formatted(date: .long, time: .omitted)
            drawCentered("Focus Forest Adventure · \(date)", font: .systemFont(ofSize: 14), y: 480, color: .gray)
        }
    }

    /// Single-page A4 summary. Kept deliberately simple: headline numbers,
    /// per-subject table, achievements, recommendations.
    private static func renderPDF(_ report: ProgressReport) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)   // A4 @72dpi
        let margin: CGFloat = 48
        let renderer = UIGraphicsPDFRenderer(bounds: page)

        let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
        let headingFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let bodyFont = UIFont.systemFont(ofSize: 11)

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin

            func draw(_ text: String, font: UIFont, indent: CGFloat = 0, spacing: CGFloat = 6) {
                let attributes: [NSAttributedString.Key: Any] = [.font: font]
                let width = page.width - margin * 2 - indent
                let bounds = (text as NSString).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes, context: nil
                )
                if y + bounds.height > page.height - margin {
                    context.beginPage()
                    y = margin
                }
                (text as NSString).draw(
                    in: CGRect(x: margin + indent, y: y, width: width, height: bounds.height),
                    withAttributes: attributes
                )
                y += bounds.height + spacing
            }

            let dateText = report.generatedAt.formatted(date: .abbreviated, time: .omitted)
            draw(String(localized: "Focus Forest — Progress Report"), font: titleFont, spacing: 4)
            draw(String(localized: "\(report.childName) · last \(report.rangeDays) days · generated \(dateText)"),
                 font: bodyFont, spacing: 18)

            draw(String(localized: "Summary"), font: headingFont)
            draw(String(localized: "Missions completed: \(report.totalMissions)"), font: bodyFont, indent: 12)
            draw(String(localized: "Focus time: \(report.focusMinutes) minutes"), font: bodyFont, indent: 12)
            draw(String(localized: "Average attention: \(report.attentionPercent)%"), font: bodyFont, indent: 12, spacing: 18)

            draw(String(localized: "Subjects"), font: headingFont)
            if report.subjects.isEmpty {
                draw(String(localized: "No missions in this period yet."), font: bodyFont, indent: 12, spacing: 18)
            }
            for row in report.subjects {
                draw("\(row.subject): \(row.missions) missions · \(row.accuracyPercent)% correct · level \(row.difficulty)",
                     font: bodyFont, indent: 12)
            }
            y += 12

            draw(String(localized: "Achievements"), font: headingFont)
            if report.achievements.isEmpty {
                draw(String(localized: "First badge coming soon!"), font: bodyFont, indent: 12)
            }
            for achievement in report.achievements {
                draw(achievement, font: bodyFont, indent: 12)
            }
            y += 12

            draw(String(localized: "Recommendations"), font: headingFont)
            for tip in report.recommendations {
                draw("• \(tip)", font: bodyFont, indent: 12)
            }
        }
    }
}
