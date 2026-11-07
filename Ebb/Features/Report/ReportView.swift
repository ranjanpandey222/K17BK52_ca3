import SwiftUI
import SwiftData
import EbbCore

/// Builds the doctor report and shares it as a PDF.
struct ReportView: View {
    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DayLog.day) private var logs: [DayLog]
    @Query(sort: \Treatment.startDate) private var treatments: [Treatment]

    @State private var months = 3
    @State private var pdfURL: URL?
    @State private var isRendering = false
    @State private var includeName = true

    private var report: ReportData {
        ReportBuilder.build(
            records: logs.map(\.record),
            treatments: treatments.map(\.period),
            months: months,
            today: .now,
            stage: profile.stage
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    Text("A clear summary of your symptoms, patterns and treatments to bring to your next appointment.")
                        .foregroundStyle(Theme.textSecondary)

                    Picker("Period", selection: $months) {
                        Text("1 month").tag(1)
                        Text("3 months").tag(3)
                        Text("6 months").tag(6)
                    }
                    .pickerStyle(.segmented)

                    let data = report
                    if data.hasEnoughData {
                        preview(data)
                    } else {
                        Card {
                            EmptyStateView(
                                systemImage: "doc.text",
                                title: "A few more check-ins needed",
                                message: "Your report needs at least \(ReportBuilder.minimumLoggedDays) check-ins in this period. You have \(data.daysLogged)."
                            )
                        }
                    }

                    if !profile.firstName.isEmpty {
                        Toggle("Show my first name on the report", isOn: $includeName).tint(Theme.accent)
                    }

                    if let pdfURL {
                        ShareLink(item: pdfURL) {
                            Label("Share or print PDF", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Text("Tip: AirDrop or print it, or show it on your phone at the appointment. The PDF is created on your phone and isn't uploaded anywhere.")
                            .font(.footnote).foregroundStyle(Theme.textSecondary)
                    } else {
                        Button {
                            createPDF(data)
                        } label: {
                            if isRendering {
                                ProgressView().tint(.white)
                            } else {
                                Label("Create PDF report", systemImage: "doc.richtext")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!data.hasEnoughData || isRendering)
                    }
                }
                .padding(20)
            }
            .ebbScreen()
            .navigationTitle("Doctor report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onChange(of: months) { _, _ in pdfURL = nil }
            .onChange(of: includeName) { _, _ in pdfURL = nil }
        }
    }

    @ViewBuilder
    private func preview(_ data: ReportData) -> some View {
        Card {
            SectionHeader(title: "What's included")
            previewRow("calendar", "\(data.daysLogged) check-ins over \(data.daysInRange) days")
            if let average = data.averageScore {
                previewRow("gauge.medium", "Average symptom score \(Int(average.rounded()))/100")
            }
            if let top = data.symptoms.first(where: { $0.daysPresent > 0 }) {
                previewRow("list.number", "Top symptom: \(SymptomCatalog.phrase(for: top.symptomID)) (\(Phrasing.percent(top.frequency)) of days)")
            }
            previewRow("sparkles", data.insights.isEmpty ? "No reliable patterns yet" : "\(data.insights.count) pattern\(data.insights.count == 1 ? "" : "s") found")
            previewRow("pills", data.treatments.isEmpty ? "No treatments in this period" : "\(data.treatments.count) treatment\(data.treatments.count == 1 ? "" : "s") with before/after view")
            previewRow("questionmark.bubble", "\(data.questions.count) questions to ask")
        }

        if !data.questions.isEmpty {
            Card {
                SectionHeader(title: "Questions for your appointment")
                ForEach(Array(data.questions.enumerated()), id: \.offset) { index, question in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).").fontWeight(.semibold).foregroundStyle(Theme.accent)
                        Text(question).foregroundStyle(Theme.textPrimary)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private func previewRow(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text).foregroundStyle(Theme.textPrimary)
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.accent)
        }
        .font(.subheadline)
    }

    private func createPDF(_ data: ReportData) {
        isRendering = true
        let name = includeName ? profile.firstName : ""
        Task { @MainActor in
            // Let the button show its spinner before the (fast) render.
            await Task.yield()
            pdfURL = ReportPDFRenderer.render(report: data, name: name)
            isRendering = false
        }
    }
}
