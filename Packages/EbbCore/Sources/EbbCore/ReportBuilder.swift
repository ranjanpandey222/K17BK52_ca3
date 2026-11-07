import Foundation

public struct HotFlashSummary: Hashable, Sendable {
    public let daysCounted: Int
    public let averagePerDay: Double
    public let maximumInADay: Int
}

public struct WeeklyScore: Hashable, Sendable, Identifiable {
    public var id: Date { weekStart }
    public let weekStart: Date
    public let averageScore: Double
    public let daysLogged: Int
}

public struct TriggerCount: Hashable, Sendable, Identifiable {
    public var id: String { triggerID }
    public let triggerID: String
    public let days: Int
}

public struct ReportTreatmentLine: Hashable, Sendable, Identifiable {
    public var id: String { treatment.id }
    public let treatment: TreatmentPeriod
    public let comparison: TreatmentComparison
}

/// Everything shown in the doctor report, already computed.
public struct ReportData: Sendable {
    public let generatedAt: Date
    public let rangeStart: Date
    public let rangeEnd: Date
    public let daysInRange: Int
    public let daysLogged: Int
    public let averageScore: Double?
    public let symptoms: [SymptomFrequency]
    public let hotFlashes: HotFlashSummary?
    public let weeklyScores: [WeeklyScore]
    public let insights: [Insight]
    public let treatments: [ReportTreatmentLine]
    public let triggers: [TriggerCount]
    public let questions: [String]
    public let stage: StageEstimate?

    public var hasEnoughData: Bool { daysLogged >= ReportBuilder.minimumLoggedDays }
}

public enum ReportBuilder {
    public static let minimumLoggedDays = 7

    /// Builds a report covering `months` months up to and including `today`.
    public static func build(
        records: [DayRecord],
        treatments: [TreatmentPeriod],
        months: Int,
        today: Date,
        stage: StageEstimate?,
        calendar: Calendar = .current
    ) -> ReportData {
        let end = calendar.startOfDay(for: today)
        let start = calendar.date(byAdding: .month, value: -max(1, months), to: calendar.day(1, from: end)) ?? calendar.day(-30 * months, from: end)
        let upper = calendar.day(1, from: end)
        let inRange = records.filter { $0.day >= start && $0.day < upper }.sorted { $0.day < $1.day }
        let logged = inRange.filter { $0.score != nil || $0.hotFlashCount != nil }

        let engine = PatternEngine(calendar: calendar)
        let frequencies = engine.symptomFrequencies(records: inRange, from: start, to: end).filter { $0.daysTracked > 0 }

        let counts = inRange.compactMap(\.hotFlashCount)
        let hotFlashes: HotFlashSummary? = counts.isEmpty ? nil : HotFlashSummary(
            daysCounted: counts.count,
            averagePerDay: Stats.mean(counts) ?? 0,
            maximumInADay: counts.max() ?? 0
        )

        var weeks: [Date: [Double]] = [:]
        for record in inRange {
            guard let score = record.score,
                  let week = calendar.dateInterval(of: .weekOfYear, for: record.day)?.start else { continue }
            weeks[week, default: []].append(score)
        }
        let weeklyScores = weeks
            .map { WeeklyScore(weekStart: $0.key, averageScore: Stats.mean($0.value) ?? 0, daysLogged: $0.value.count) }
            .sorted { $0.weekStart < $1.weekStart }

        let relevantTreatments = treatments.filter { treatment in
            treatment.start < upper && (treatment.end.map { $0 > start } ?? true)
        }
        let lines = relevantTreatments
            .sorted { $0.start < $1.start }
            .map { ReportTreatmentLine(treatment: $0, comparison: engine.treatmentComparison(for: $0, records: records, today: today)) }

        var triggerDays: [String: Int] = [:]
        for record in inRange {
            for trigger in record.triggers { triggerDays[trigger, default: 0] += 1 }
        }
        let triggers = triggerDays
            .map { TriggerCount(triggerID: $0.key, days: $0.value) }
            .sorted { $0.days == $1.days ? $0.triggerID < $1.triggerID : $0.days > $1.days }

        let insights = engine.insights(records: inRange, treatments: relevantTreatments, today: end)

        return ReportData(
            generatedAt: today,
            rangeStart: start,
            rangeEnd: end,
            daysInRange: calendar.daysBetween(start, upper),
            daysLogged: logged.count,
            averageScore: Stats.mean(inRange.compactMap(\.score)),
            symptoms: frequencies,
            hotFlashes: hotFlashes,
            weeklyScores: weeklyScores,
            insights: insights,
            treatments: lines,
            triggers: triggers,
            questions: QuestionGenerator.questions(
                symptoms: frequencies,
                treatments: lines,
                stage: stage,
                today: today
            ),
            stage: stage
        )
    }
}

/// Suggests questions the user may want to ask their clinician, based on what
/// they logged. These are prompts for a conversation, never advice.
public enum QuestionGenerator {
    public static let maximumQuestions = 6

    public static func questions(
        symptoms: [SymptomFrequency],
        treatments: [ReportTreatmentLine],
        stage: StageEstimate?,
        today: Date
    ) -> [String] {
        var result: [String] = []

        func frequency(_ id: String) -> Double {
            symptoms.first { $0.symptomID == id }?.frequency ?? 0
        }

        let activeHormonal = treatments.filter { $0.treatment.isHormonal && $0.treatment.isActive(on: today) }

        for line in activeHormonal {
            guard line.comparison.status == .ready, let change = line.comparison.relativeChange else { continue }
            if change > -PatternEngine.meaningfulScoreChange {
                result.append("I started \(line.treatment.name) and my symptoms haven't changed much. Should we review the dose or try something different?")
            } else {
                result.append("My symptoms have improved since starting \(line.treatment.name). How long should I stay on it, and how often should we review it?")
            }
        }

        let vasomotor = max(frequency(SymptomCatalog.hotFlashes), frequency(SymptomCatalog.nightSweats))
        if vasomotor >= 0.3, activeHormonal.isEmpty {
            result.append("I have hot flashes or night sweats on about \(Phrasing.percent(vasomotor)) of days. What treatment options, hormonal or non-hormonal, could suit me?")
        }

        let sleep = frequency(SymptomCatalog.sleepTrouble)
        if sleep >= 0.4 {
            result.append("I have trouble sleeping on \(Phrasing.percent(sleep)) of days. Could this be related to menopause, and what could help?")
        }

        let mood = max(frequency(SymptomCatalog.anxiety), frequency(SymptomCatalog.lowMood), frequency(SymptomCatalog.moodSwings))
        if mood >= 0.3 {
            result.append("I've had frequent mood changes or anxiety. Could these be linked to hormonal changes, and what support is available?")
        }

        if frequency(SymptomCatalog.brainFog) >= 0.3 {
            result.append("I'm noticing brain fog and memory lapses. Is this common at this stage, and should anything else be checked?")
        }

        if frequency(SymptomCatalog.jointPain) >= 0.3 {
            result.append("I've had joint pain often. Could it be connected to menopause, and what can I do about it?")
        }

        if max(frequency(SymptomCatalog.vaginalDryness), frequency(SymptomCatalog.lowLibido)) >= 0.2 {
            result.append("I've noticed vaginal dryness or lower libido. What options are there, including local treatments?")
        }

        if frequency(SymptomCatalog.palpitations) >= 0.1 {
            result.append("I've logged heart palpitations. Should these be checked?")
        }

        if stage?.stage == .likelyPostmenopause {
            result.append("What should I know about bone and heart health after menopause?")
        }

        result.append("Are there any tests or screenings I should have at this stage?")

        var seen = Set<String>()
        return result.filter { seen.insert($0).inserted }.prefix(maximumQuestions).map { $0 }
    }
}
