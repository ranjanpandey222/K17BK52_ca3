import SwiftUI
import Charts
import EbbCore

/// Renders the doctor report to a two-page US Letter PDF, entirely on device.
@MainActor
enum ReportPDFRenderer {
    static let pageSize = CGSize(width: 612, height: 792)

    static func render(report: ReportData, name: String) -> URL? {
        let fileName = "Ebb-Symptom-Report-\(DayKey.string(from: report.rangeEnd)).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)

        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        let pages: [AnyView] = [
            AnyView(ReportPageOne(report: report, name: name)),
            AnyView(ReportPageTwo(report: report))
        ]

        for page in pages {
            let renderer = ImageRenderer(content: page.frame(width: pageSize.width, height: pageSize.height).environment(\.colorScheme, .light))
            renderer.proposedSize = ProposedViewSize(pageSize)
            renderer.render { _, draw in
                context.beginPDFPage(nil)
                draw(context)
                context.endPDFPage()
            }
        }
        context.closePDF()
        return url
    }
}

// MARK: - Shared pieces

private enum PDFStyle {
    static let ink = Color(red: 0.17, green: 0.17, blue: 0.18)
    static let muted = Color(red: 0.42, green: 0.41, blue: 0.45)
    static let accent = Color(red: 0.48, green: 0.37, blue: 0.65)
    static let soft = Color(red: 0.96, green: 0.95, blue: 0.98)
    static let line = Color(red: 0.88, green: 0.86, blue: 0.92)
}

private struct PDFHeader: View {
    let title: String
    let report: ReportData

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(PDFStyle.ink)
                Text("\(report.rangeStart.formatted(date: .abbreviated, time: .omitted)) – \(report.rangeEnd.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 10)).foregroundStyle(PDFStyle.muted)
            }
            Spacer()
            Text("Ebb").font(.system(size: 14, weight: .bold)).foregroundStyle(PDFStyle.accent)
        }
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(PDFStyle.line).frame(height: 1) }
    }
}

private struct PDFSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(PDFStyle.accent)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PDFFooter: View {
    let page: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Rectangle().fill(PDFStyle.line).frame(height: 1)
            HStack {
                Text("Self-reported by the patient using the Ebb app. \(Disclaimer.short)")
                    .font(.system(size: 7)).foregroundStyle(PDFStyle.muted)
                Spacer()
                Text("Page \(page) of 2").font(.system(size: 7)).foregroundStyle(PDFStyle.muted)
            }
        }
    }
}

private struct StatBox: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 16, weight: .bold)).foregroundStyle(PDFStyle.ink)
            Text(label).font(.system(size: 8)).foregroundStyle(PDFStyle.muted)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PDFStyle.soft, in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Page 1: overview and symptoms

private struct ReportPageOne: View {
    let report: ReportData
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PDFHeader(title: name.isEmpty ? "Menopause symptom report" : "Menopause symptom report: \(name)", report: report)

            HStack(spacing: 8) {
                StatBox(value: "\(report.daysLogged)/\(report.daysInRange)", label: "days checked in")
                StatBox(value: report.averageScore.map { String(Int($0.rounded())) } ?? "–", label: "avg symptom score (0–100)")
                StatBox(value: report.hotFlashes.map { Phrasing.oneDecimal($0.averagePerDay) } ?? "–", label: "avg hot flashes on days counted")
                StatBox(value: report.hotFlashes.map { String($0.maximumInADay) } ?? "–", label: "most hot flashes in a day")
            }

            if let stage = report.stage {
                PDFSection(title: "Stage (self-reported, not a diagnosis)") {
                    Text(stage.title).font(.system(size: 10, weight: .semibold)).foregroundStyle(PDFStyle.ink)
                }
            }

            if report.weeklyScores.count >= 2 {
                PDFSection(title: "Weekly symptom score") {
                    Chart(report.weeklyScores) { week in
                        LineMark(x: .value("Week", week.weekStart), y: .value("Score", week.averageScore))
                            .foregroundStyle(PDFStyle.accent)
                        PointMark(x: .value("Week", week.weekStart), y: .value("Score", week.averageScore))
                            .foregroundStyle(PDFStyle.accent)
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxis { AxisMarks(values: [0, 25, 50, 75, 100]) }
                    .frame(height: 120)
                }
            }

            PDFSection(title: "Symptoms") {
                VStack(spacing: 0) {
                    HStack {
                        Text("Symptom").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Days present").frame(width: 80, alignment: .trailing)
                        Text("Frequency").frame(width: 70, alignment: .trailing)
                        Text("Usual severity").frame(width: 80, alignment: .trailing)
                        Text("Severe days").frame(width: 70, alignment: .trailing)
                    }
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(PDFStyle.muted)
                    .padding(.vertical, 4)

                    ForEach(report.symptoms.prefix(14)) { symptom in
                        HStack {
                            Text(SymptomCatalog.name(for: symptom.symptomID)).frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(symptom.daysPresent) of \(symptom.daysTracked)").frame(width: 80, alignment: .trailing)
                            Text(Phrasing.percent(symptom.frequency)).frame(width: 70, alignment: .trailing)
                            Text(severityText(symptom)).frame(width: 80, alignment: .trailing)
                            Text("\(symptom.severeDays)").frame(width: 70, alignment: .trailing)
                        }
                        .font(.system(size: 9))
                        .foregroundStyle(PDFStyle.ink)
                        .padding(.vertical, 3)
                        .overlay(alignment: .top) { Rectangle().fill(PDFStyle.line).frame(height: 0.5) }
                    }
                }
            }

            if !report.triggers.isEmpty {
                PDFSection(title: "Logged lifestyle factors") {
                    Text(report.triggers.prefix(8).map { "\(TriggerCatalog.name(for: $0.triggerID)) (\($0.days) days)" }.joined(separator: " · "))
                        .font(.system(size: 9)).foregroundStyle(PDFStyle.ink)
                }
            }

            Spacer(minLength: 0)
            PDFFooter(page: 1)
        }
        .padding(36)
        .background(Color.white)
    }

    private func severityText(_ symptom: SymptomFrequency) -> String {
        guard symptom.daysPresent > 0 else { return "–" }
        return Severity(rawValue: Int(symptom.averageSeverityWhenPresent.rounded()))?.title ?? "–"
    }
}

// MARK: - Page 2: patterns, treatments, questions

private struct ReportPageTwo: View {
    let report: ReportData

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PDFHeader(title: "Patterns, treatments & questions", report: report)

            PDFSection(title: "Treatments") {
                if report.treatments.isEmpty {
                    Text("No treatments logged in this period.").font(.system(size: 9)).foregroundStyle(PDFStyle.muted)
                } else {
                    ForEach(report.treatments) { line in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(treatmentTitle(line.treatment))
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(PDFStyle.ink)
                            Text(line.comparison.summary).font(.system(size: 9)).foregroundStyle(PDFStyle.ink)
                            let changes = line.comparison.symptomChanges.filter { abs($0.difference) >= 0.5 }.prefix(4)
                            if !changes.isEmpty {
                                Text(changes.map { "\(SymptomCatalog.name(for: $0.symptomID)) \(Phrasing.oneDecimal($0.before)) → \(Phrasing.oneDecimal($0.after))" }.joined(separator: " · ") + " (avg severity 0–3)")
                                    .font(.system(size: 8)).foregroundStyle(PDFStyle.muted)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            PDFSection(title: "Patterns found in the patient's logs") {
                if report.insights.isEmpty {
                    Text("Not enough data to find patterns yet.").font(.system(size: 9)).foregroundStyle(PDFStyle.muted)
                } else {
                    ForEach(report.insights.prefix(6)) { insight in
                        VStack(alignment: .leading, spacing: 1) {
                            Text("• " + insight.title).font(.system(size: 9, weight: .semibold)).foregroundStyle(PDFStyle.ink)
                            Text(insight.detail).font(.system(size: 8)).foregroundStyle(PDFStyle.muted)
                        }
                    }
                    Text("Patterns are associations in self-reported data, not evidence of cause.")
                        .font(.system(size: 7)).italic().foregroundStyle(PDFStyle.muted)
                }
            }

            PDFSection(title: "Questions I'd like to discuss") {
                ForEach(Array(report.questions.enumerated()), id: \.offset) { index, question in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(index + 1).").font(.system(size: 9, weight: .semibold)).foregroundStyle(PDFStyle.accent)
                        Text(question).font(.system(size: 9)).foregroundStyle(PDFStyle.ink)
                    }
                }
            }

            PDFSection(title: "Notes") {
                VStack(spacing: 14) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle().fill(PDFStyle.line).frame(height: 0.5)
                    }
                }
                .padding(.top, 10)
            }

            Spacer(minLength: 0)
            PDFFooter(page: 2)
        }
        .padding(36)
        .background(Color.white)
    }

    private func treatmentTitle(_ treatment: TreatmentPeriod) -> String {
        var text = "\(treatment.name), started \(treatment.start.formatted(date: .abbreviated, time: .omitted))"
        if let end = treatment.end {
            text += ", stopped \(end.formatted(date: .abbreviated, time: .omitted))"
        }
        return text
    }
}
