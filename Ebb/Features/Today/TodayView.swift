import SwiftUI
import SwiftData
import EbbCore

struct TodayView: View {
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var health: HealthKitService
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \DayLog.day, order: .reverse) private var logs: [DayLog]
    @Query(sort: \Treatment.startDate, order: .reverse) private var treatments: [Treatment]
    @Query private var doseLogs: [DoseLog]

    @State private var showCheckIn = false
    @State private var showStageInfo = false

    private var todayLog: DayLog? {
        let key = DayKey.string(from: .now)
        return logs.first { $0.dayKey == key }
    }

    private var engine: PatternEngine { PatternEngine() }

    private var insights: [Insight] {
        engine.insights(records: logs.map(\.record), treatments: treatments.map(\.period), today: .now)
    }

    private var streak: Int {
        engine.currentStreak(loggedDays: Set(logs.map(\.day)), today: .now)
    }

    private var dueTreatments: [Treatment] {
        treatments.filter { $0.isDue(on: .now) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacing) {
                    header
                    checkInCard
                    if !dueTreatments.isEmpty { treatmentsCard }
                    if profile.healthReadEnabled { healthCard }
                    insightCard
                    stageCard
                }
                .padding(20)
            }
            .ebbScreen()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCheckIn) {
                CheckInView(day: .now)
            }
            .sheet(isPresented: $showStageInfo) {
                NavigationStack {
                    LearnArticleView(article: LearnLibrary.stages)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) { Button("Done") { showStageInfo = false } }
                        }
                }
            }
            .task {
                if profile.healthReadEnabled { await health.refresh() }
            }
            .refreshable {
                if profile.healthReadEnabled { await health.refresh() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
            Text(greeting)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.top, 8)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
        return profile.firstName.isEmpty ? part : "\(part), \(profile.firstName)"
    }

    @ViewBuilder
    private var checkInCard: some View {
        if let todayLog {
            Card {
                HStack {
                    Label("Checked in today", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.positive)
                    Spacer()
                    Button("Edit") { showCheckIn = true }.font(.subheadline.weight(.semibold))
                }
                let present = todayLog.record.presentSymptomIDs
                if present.isEmpty {
                    Text("No symptoms today. Nice.").foregroundStyle(Theme.textSecondary)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(present, id: \.self) { id in
                            let severity = todayLog.symptoms[id] ?? 0
                            Text("\(SymptomCatalog.name(for: id)) · \(Severity(rawValue: severity)?.title ?? "")")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .foregroundStyle(severity >= 2 ? .white : Theme.textPrimary)
                                .background(Theme.severityColor(severity), in: Capsule())
                        }
                    }
                }
                if streak > 1 {
                    Text("🔥 \(streak)-day streak").font(.subheadline.weight(.medium)).foregroundStyle(Theme.textSecondary)
                }
            }
        } else {
            Card(padding: 20) {
                Text("How are you feeling today?").font(.title3.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                Text("A 30-second check-in keeps your patterns accurate.").foregroundStyle(Theme.textSecondary)
                Button("Check in") { showCheckIn = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 4)
                if streak > 0 {
                    Text("Keep your \(streak)-day streak going").font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var treatmentsCard: some View {
        Card {
            SectionHeader(title: "Today's treatments")
            ForEach(dueTreatments) { treatment in
                let taken = DataRepository.isTaken(treatmentID: treatment.id, on: .now, logs: doseLogs)
                Button {
                    DataRepository.toggleTaken(treatment: treatment, on: .now, logs: doseLogs, context: modelContext)
                } label: {
                    HStack {
                        Image(systemName: treatment.kind.systemImage).foregroundStyle(Theme.accent).frame(width: 28)
                        Text(treatment.displayName).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(taken ? Theme.positive : Theme.cardBorder)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(treatment.displayName), \(taken ? "taken" : "not taken yet")")
            }
        }
    }

    private var healthCard: some View {
        Card {
            SectionHeader(title: "Last night", subtitle: "From Apple Health")
            HStack(spacing: 12) {
                metric(
                    icon: "bed.double",
                    value: health.lastNightSleepHours.map { "\(Phrasing.oneDecimal($0)) h" } ?? "–",
                    label: "Sleep"
                )
                metric(
                    icon: "thermometer.medium",
                    value: health.wristTemperatureDeviationF.map { String(format: "%+.1f °F", $0) } ?? "–",
                    label: "Wrist temp vs usual"
                )
            }
        }
    }

    private func metric(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            IconBadge(systemImage: icon, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.headline).foregroundStyle(Theme.textPrimary)
                Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var insightCard: some View {
        let loggedDays = logs.count
        if let insight = insights.first {
            Card {
                Label("Pattern", systemImage: "sparkles").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                Text(insight.title).font(.headline).foregroundStyle(Theme.textPrimary)
                Text(insight.detail).font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
        } else {
            Card {
                Label("Your patterns", systemImage: "sparkles").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                let remaining = max(PatternEngine.minimumLoggedDays - loggedDays, 0)
                Text(remaining > 0
                     ? "\(remaining) more check-in\(remaining == 1 ? "" : "s") until Ebb can start finding your patterns."
                     : "Keep checking in. Ebb will show patterns as soon as it finds something reliable.")
                    .foregroundStyle(Theme.textPrimary)
                ProgressView(value: Double(min(loggedDays, PatternEngine.minimumLoggedDays)), total: Double(PatternEngine.minimumLoggedDays))
                    .tint(Theme.accent)
            }
        }
    }

    private var stageCard: some View {
        let stage = profile.stage
        return Button { showStageInfo = true } label: {
            Card {
                HStack {
                    Text(stage.title).font(.headline).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.textSecondary)
                }
                Text(stage.explanation).font(.subheadline).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
    }
}
