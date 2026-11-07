import SwiftUI
import SwiftData
import Charts
import EbbCore

struct InsightsView: View {
    @Query(sort: \DayLog.day) private var logs: [DayLog]
    @Query(sort: \Treatment.startDate) private var treatments: [Treatment]

    @State private var weeklySummary: String?
    @State private var summaryKey = ""
    @State private var showReport = false

    private let engine = PatternEngine()

    private var records: [DayRecord] { logs.map(\.record) }

    private var insights: [Insight] {
        engine.insights(records: records, treatments: treatments.map(\.period), today: .now)
    }

    private var scores: [DailyScore] {
        engine.dailyScores(records: records, from: Calendar.current.day(-29, from: .now), to: .now)
    }

    private var frequencies: [SymptomFrequency] {
        engine.symptomFrequencies(records: records, from: Calendar.current.day(-29, from: .now), to: .now)
            .filter { $0.daysPresent > 0 }
    }

    private var loggedCount: Int { logs.filter { $0.record.score != nil }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    if loggedCount < PatternEngine.minimumLoggedDays {
                        lockedState
                    } else {
                        summaryCard
                        scoreChart
                        if !frequencies.isEmpty { frequencyChart }
                        patterns
                    }
                    reportButton
                }
                .padding(20)
            }
            .ebbScreen()
            .navigationTitle("Insights")
            .sheet(isPresented: $showReport) { ReportView() }
            .task(id: logs.count) { await loadSummary() }
        }
    }

    private var lockedState: some View {
        Card {
            EmptyStateView(
                systemImage: "sparkles",
                title: "Your patterns are on the way",
                message: "Ebb needs \(PatternEngine.minimumLoggedDays) check-ins to start finding patterns. You have \(loggedCount)."
            )
            ProgressView(value: Double(loggedCount), total: Double(PatternEngine.minimumLoggedDays))
                .tint(Theme.accent)
        }
    }

    private var summaryCard: some View {
        Card {
            HStack {
                Label("This week", systemImage: "text.quote").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                Spacer()
                if WeeklySummaryWriter.isOnDeviceAIAvailable {
                    Text("On-device AI").font(.caption2.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                }
            }
            if let weeklySummary {
                Text(weeklySummary).foregroundStyle(Theme.textPrimary)
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    private var scoreChart: some View {
        Card {
            SectionHeader(title: "Symptom score", subtitle: "Last 30 days · 0 = no symptoms, 100 = all severe")
            Chart(scores) { point in
                AreaMark(x: .value("Day", point.day, unit: .day), y: .value("Score", point.score))
                    .foregroundStyle(Theme.accent.opacity(0.15))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Day", point.day, unit: .day), y: .value("Score", point.score))
                    .foregroundStyle(Theme.accent)
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Day", point.day, unit: .day), y: .value("Score", point.score))
                    .foregroundStyle(Theme.accent)
                    .symbolSize(18)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis { AxisMarks(values: [0, 50, 100]) }
            .frame(height: 180)
            .accessibilityLabel("Symptom score chart for the last 30 days")
        }
    }

    private var frequencyChart: some View {
        Card {
            SectionHeader(title: "Most frequent symptoms", subtitle: "Share of check-ins in the last 30 days")
            Chart(frequencies.prefix(6)) { item in
                BarMark(
                    x: .value("Frequency", item.frequency * 100),
                    y: .value("Symptom", SymptomCatalog.name(for: item.symptomID))
                )
                .foregroundStyle(Theme.accent.gradient)
                .cornerRadius(6)
                .annotation(position: .trailing) {
                    Text(Phrasing.percent(item.frequency)).font(.caption2).foregroundStyle(Theme.textSecondary)
                }
            }
            .chartXScale(domain: 0...110)
            .chartXAxis(.hidden)
            .frame(height: CGFloat(min(frequencies.count, 6)) * 36 + 10)
        }
    }

    @ViewBuilder
    private var patterns: some View {
        SectionHeader(title: "Patterns", subtitle: "Found in your own check-ins. Patterns show links, not causes.")
        if insights.isEmpty {
            Card {
                Text("No reliable patterns yet. Logging lifestyle factors (like alcohol, caffeine or exercise) on your check-ins helps Ebb find them.")
                    .foregroundStyle(Theme.textSecondary)
            }
        } else {
            ForEach(insights) { insight in
                Card {
                    Label(kindTitle(insight.kind), systemImage: kindIcon(insight.kind))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(insight.title).font(.headline).foregroundStyle(Theme.textPrimary)
                    Text(insight.detail).font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var reportButton: some View {
        Button {
            showReport = true
        } label: {
            Label("Create doctor report", systemImage: "doc.text")
        }
        .buttonStyle(SecondaryButtonStyle())
        .padding(.top, 4)
    }

    private func kindTitle(_ kind: Insight.Kind) -> String {
        switch kind {
        case .treatment: return "Treatment"
        case .trend: return "Trend"
        case .trigger: return "Possible trigger"
        case .topSymptom: return "Most frequent"
        }
    }

    private func kindIcon(_ kind: Insight.Kind) -> String {
        switch kind {
        case .treatment: return "pills"
        case .trend: return "chart.line.downtrend.xyaxis"
        case .trigger: return "link"
        case .topSymptom: return "list.number"
        }
    }

    private func loadSummary() async {
        let calendar = Calendar.current
        let thisWeek = records.filter { $0.day >= calendar.day(-6, from: .now) }
        let lastWeek = records.filter { $0.day >= calendar.day(-13, from: .now) && $0.day < calendar.day(-6, from: .now) }
        let thisScores = thisWeek.compactMap(\.score)
        let lastScores = lastWeek.compactMap(\.score)
        let weekFrequencies = engine.symptomFrequencies(records: records, from: calendar.day(-6, from: .now), to: .now)
            .filter { $0.daysPresent > 0 }

        let facts = WeeklySummaryWriter.Facts(
            daysLogged: thisScores.count,
            averageScore: thisScores.isEmpty ? nil : thisScores.reduce(0, +) / Double(thisScores.count),
            previousAverageScore: lastScores.count >= 3 ? lastScores.reduce(0, +) / Double(lastScores.count) : nil,
            topSymptoms: weekFrequencies.prefix(3).map { (name: SymptomCatalog.name(for: $0.symptomID), days: $0.daysPresent) },
            insightTitles: insights.map(\.title)
        )
        let key = facts.asText
        guard key != summaryKey else { return }
        summaryKey = key
        weeklySummary = nil
        weeklySummary = await WeeklySummaryWriter.summary(facts)
    }
}
