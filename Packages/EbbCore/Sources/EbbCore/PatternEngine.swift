import Foundation

/// A finding shown to the user, written in plain language.
public struct Insight: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable, Codable {
        case treatment
        case trend
        case trigger
        case topSymptom
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let detail: String
    public let symptomID: String?
    public let factorID: String?
    /// Higher = more noteworthy. Used for ordering within a kind.
    public let strength: Double

    public init(id: String, kind: Kind, title: String, detail: String, symptomID: String?, factorID: String?, strength: Double) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.symptomID = symptomID
        self.factorID = factorID
        self.strength = strength
    }
}

/// How often a lifestyle factor and a symptom showed up together.
public struct TriggerAssociation: Hashable, Sendable {
    public enum Direction: String, Sendable { case more, less }

    public let triggerID: String
    public let symptomID: String
    public let daysWithFactor: Int
    public let presentWithFactor: Int
    public let daysWithoutFactor: Int
    public let presentWithoutFactor: Int
    public let pValue: Double

    public var rateWithFactor: Double { daysWithFactor == 0 ? 0 : Double(presentWithFactor) / Double(daysWithFactor) }
    public var rateWithoutFactor: Double { daysWithoutFactor == 0 ? 0 : Double(presentWithoutFactor) / Double(daysWithoutFactor) }
    public var direction: Direction { rateWithFactor >= rateWithoutFactor ? .more : .less }
}

public struct SymptomChange: Hashable, Sendable {
    public let symptomID: String
    /// Average severity (0...3) before and after.
    public let before: Double
    public let after: Double

    public var difference: Double { after - before }
}

/// Before/after comparison around the start of a treatment.
public struct TreatmentComparison: Hashable, Sendable {
    public enum Status: Hashable, Sendable {
        case ready
        /// Not enough time has passed since starting.
        case tooEarly(daysRemaining: Int)
        /// Not enough check-ins in the weeks before starting.
        case notEnoughBefore(loggedDays: Int)
        /// Enough time has passed, but not enough check-ins since.
        case notEnoughAfter(loggedDays: Int)
    }

    public let treatment: TreatmentPeriod
    public let status: Status
    public let beforeDays: Int
    public let afterDays: Int
    public let scoreBefore: Double?
    public let scoreAfter: Double?
    public let symptomChanges: [SymptomChange]
    public let hotFlashesPerDayBefore: Double?
    public let hotFlashesPerDayAfter: Double?

    /// Relative change of the symptom score (-0.3 = 30% lower). Nil unless ready.
    public var relativeChange: Double? {
        guard status == .ready, let before = scoreBefore, let after = scoreAfter, before > 0 else { return nil }
        return (after - before) / before
    }

    /// One-line plain-language summary for lists and reports.
    public var summary: String {
        switch status {
        case .tooEarly(let days):
            return "Too early to compare. Check back in \(Phrasing.days(days))."
        case .notEnoughBefore:
            return "Not enough check-ins before starting to compare."
        case .notEnoughAfter(let logged):
            return "Only \(Phrasing.days(logged)) logged since it had time to work. Keep checking in."
        case .ready:
            guard let before = scoreBefore, let after = scoreAfter else { return "Not enough data yet." }
            let beforeText = String(Int(before.rounded()))
            let afterText = String(Int(after.rounded()))
            if let change = relativeChange, abs(change) >= PatternEngine.meaningfulScoreChange {
                let direction = change < 0 ? "lower" : "higher"
                return "Symptom score \(beforeText) → \(afterText) (\(Phrasing.percent(abs(change))) \(direction))."
            }
            return "Symptom score \(beforeText) → \(afterText): little change so far."
        }
    }
}

public struct TrendSummary: Hashable, Sendable {
    public let recentScore: Double
    public let previousScore: Double
    public let recentDays: Int
    public let previousDays: Int

    public var relativeChange: Double {
        previousScore == 0 ? 0 : (recentScore - previousScore) / previousScore
    }
}

public struct SymptomFrequency: Hashable, Sendable, Identifiable {
    public var id: String { symptomID }
    public let symptomID: String
    public let daysTracked: Int
    public let daysPresent: Int
    /// Average severity on the days it was present (1...3).
    public let averageSeverityWhenPresent: Double
    public let severeDays: Int

    public var frequency: Double { daysTracked == 0 ? 0 : Double(daysPresent) / Double(daysTracked) }
}

public struct DailyScore: Hashable, Sendable, Identifiable {
    public var id: Date { day }
    public let day: Date
    public let score: Double
}

/// Finds patterns in the user's own check-ins. Everything runs on device and
/// is deliberately conservative: it needs enough data in each group, a
/// meaningful difference, and passes a significance test before saying
/// anything. Wording always describes association, never cause.
public struct PatternEngine: Sendable {
    /// Minimum logged days before any insight is shown.
    public static let minimumLoggedDays = 7
    /// A score change smaller than this (relative) is reported as "little change".
    public static let meaningfulScoreChange = 0.15

    public var calendar: Calendar
    /// How far back trigger patterns look.
    public var lookbackDays = 90
    /// Minimum days in each group (with / without a factor).
    public var minimumDaysPerGroup = 4
    /// Minimum difference in how often a symptom shows up (0.2 = 20 points).
    public var minimumRateDifference = 0.2
    /// Maximum p-value for a trigger association to be reported.
    public var maximumPValue = 0.1
    /// Days a treatment gets to take effect before the "after" window starts.
    public var treatmentSettleDays = 14
    /// Length of the before and after windows.
    public var treatmentWindowDays = 28
    /// Minimum logged days in each treatment window.
    public var minimumTreatmentWindowDays = 5

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: - All insights

    public func insights(records: [DayRecord], treatments: [TreatmentPeriod], today: Date) -> [Insight] {
        let logged = records.filter { $0.score != nil || $0.hotFlashCount != nil }
        guard logged.count >= Self.minimumLoggedDays else { return [] }

        var result: [Insight] = []

        for treatment in treatments {
            let comparison = treatmentComparison(for: treatment, records: records, today: today)
            let others = overlappingTreatments(for: treatment, in: treatments)
            if let insight = treatmentInsight(comparison, overlapping: others) { result.append(insight) }
        }

        if let trend = trend(records: records, today: today), let insight = trendInsight(trend) {
            result.append(insight)
        }

        let associations = triggerAssociations(records: records, today: today)
        result.append(contentsOf: associations.prefix(5).map(triggerInsight))

        if let top = symptomFrequencies(records: records, from: calendar.day(-29, from: today), to: today).first,
           top.daysPresent > 0 {
            result.append(topSymptomInsight(top))
        }

        return result
    }

    // MARK: - Trigger associations

    public func triggerAssociations(records: [DayRecord], today: Date) -> [TriggerAssociation] {
        let start = calendar.day(-(lookbackDays - 1), from: today)
        let end = calendar.day(1, from: today)
        let window = records.filter { $0.day >= start && $0.day < end }

        let triggerIDs = Set(window.flatMap(\.triggers))
        let symptomIDs = Set(window.flatMap { $0.symptoms.keys })
            .union(window.contains { $0.hotFlashCount != nil } ? [SymptomCatalog.hotFlashes] : [])

        var found: [TriggerAssociation] = []
        for triggerID in triggerIDs.sorted() {
            for symptomID in symptomIDs.sorted() {
                let days = window.filter { $0.tracked(symptomID) }
                let with = days.filter { $0.triggers.contains(triggerID) }
                let without = days.filter { !$0.triggers.contains(triggerID) }
                guard with.count >= minimumDaysPerGroup, without.count >= minimumDaysPerGroup else { continue }

                let presentWith = with.filter { $0.isPresent(symptomID) }.count
                let presentWithout = without.filter { $0.isPresent(symptomID) }.count
                let association = TriggerAssociation(
                    triggerID: triggerID,
                    symptomID: symptomID,
                    daysWithFactor: with.count,
                    presentWithFactor: presentWith,
                    daysWithoutFactor: without.count,
                    presentWithoutFactor: presentWithout,
                    pValue: FisherExact.twoSidedPValue(
                        a: presentWith,
                        b: with.count - presentWith,
                        c: presentWithout,
                        d: without.count - presentWithout
                    )
                )
                if isMeaningful(association) { found.append(association) }
            }
        }

        return found.sorted { lhs, rhs in
            if lhs.pValue != rhs.pValue { return lhs.pValue < rhs.pValue }
            return abs(lhs.rateWithFactor - lhs.rateWithoutFactor) > abs(rhs.rateWithFactor - rhs.rateWithoutFactor)
        }
    }

    private func isMeaningful(_ association: TriggerAssociation) -> Bool {
        let with = association.rateWithFactor
        let without = association.rateWithoutFactor
        guard abs(with - without) >= minimumRateDifference else { return false }
        guard association.pValue <= maximumPValue else { return false }
        if with > without {
            return without == 0 || with / without >= 1.5
        } else {
            return with == 0 || with / without <= 0.67
        }
    }

    private func triggerInsight(_ association: TriggerAssociation) -> Insight {
        let symptom = SymptomCatalog.name(for: association.symptomID)
        let factor = TriggerCatalog.phrase(for: association.triggerID)
        let withText = Phrasing.countOf(association.presentWithFactor, association.daysWithFactor)
        let withoutText = Phrasing.countOf(association.presentWithoutFactor, association.daysWithoutFactor)

        let title: String
        switch association.direction {
        case .more:
            if association.rateWithoutFactor == 0 {
                title = "\(symptom) only showed up on days with \(factor)"
            } else {
                let ratio = association.rateWithFactor / association.rateWithoutFactor
                title = "\(symptom) were \(Phrasing.multiplier(ratio)) as frequent on days with \(factor)"
            }
        case .less:
            title = "\(symptom) showed up less often on days with \(factor)"
        }

        let detail = "You logged \(SymptomCatalog.phrase(for: association.symptomID)) on \(withText) days with \(factor) "
            + "(\(Phrasing.percent(association.rateWithFactor))), compared with \(withoutText) other days "
            + "(\(Phrasing.percent(association.rateWithoutFactor))). This is a pattern in your own logs, not proof of cause."

        return Insight(
            id: "trigger-\(association.triggerID)-\(association.symptomID)",
            kind: .trigger,
            title: Self.grammar(title, symptomID: association.symptomID),
            detail: detail,
            symptomID: association.symptomID,
            factorID: association.triggerID,
            strength: abs(association.rateWithFactor - association.rateWithoutFactor) * (1 - association.pValue)
        )
    }

    /// Symptom names are mostly plural ("Hot flashes") but some are singular
    /// ("Anxiety"); fix the verb accordingly.
    static func grammar(_ text: String, symptomID: String) -> String {
        let plural: Set<String> = [
            SymptomCatalog.hotFlashes, SymptomCatalog.nightSweats, SymptomCatalog.moodSwings,
            SymptomCatalog.headaches, SymptomCatalog.palpitations
        ]
        if plural.contains(symptomID) { return text }
        return text.replacingOccurrences(of: " were ", with: " was ")
    }

    // MARK: - Treatments

    public func treatmentComparison(for treatment: TreatmentPeriod, records: [DayRecord], today: Date) -> TreatmentComparison {
        let start = calendar.startOfDay(for: treatment.start)
        let beforeStart = calendar.day(-treatmentWindowDays, from: start)
        let afterStart = calendar.day(treatmentSettleDays, from: start)
        var afterEnd = calendar.day(treatmentWindowDays, from: afterStart)
        if let end = treatment.end { afterEnd = min(afterEnd, calendar.startOfDay(for: end)) }
        afterEnd = min(afterEnd, calendar.day(1, from: today))

        let before = records.filter { $0.day >= beforeStart && $0.day < start && $0.score != nil }
        let after = records.filter { $0.day >= afterStart && $0.day < afterEnd && $0.score != nil }

        let earliestReady = calendar.day(minimumTreatmentWindowDays, from: afterStart)
        let status: TreatmentComparison.Status
        if before.count < minimumTreatmentWindowDays {
            status = .notEnoughBefore(loggedDays: before.count)
        } else if calendar.startOfDay(for: today) < earliestReady, after.count < minimumTreatmentWindowDays {
            status = .tooEarly(daysRemaining: max(1, calendar.daysBetween(today, earliestReady)))
        } else if after.count < minimumTreatmentWindowDays {
            status = .notEnoughAfter(loggedDays: after.count)
        } else {
            status = .ready
        }

        var changes: [SymptomChange] = []
        if status == .ready {
            let ids = Set(before.flatMap { $0.symptoms.keys }).intersection(after.flatMap { $0.symptoms.keys })
            for id in SymptomCatalog.normalized(Array(ids)) {
                let b = Stats.mean(before.compactMap { $0.symptoms[id] }) ?? 0
                let a = Stats.mean(after.compactMap { $0.symptoms[id] }) ?? 0
                changes.append(SymptomChange(symptomID: id, before: b, after: a))
            }
            changes.sort { $0.difference < $1.difference }
        }

        func hotFlashRate(_ days: [DayRecord]) -> Double? {
            let counts = days.compactMap(\.hotFlashCount)
            guard counts.count >= minimumTreatmentWindowDays else { return nil }
            return Stats.mean(counts)
        }

        return TreatmentComparison(
            treatment: treatment,
            status: status,
            beforeDays: before.count,
            afterDays: after.count,
            scoreBefore: Stats.mean(before.compactMap(\.score)),
            scoreAfter: status == .ready ? Stats.mean(after.compactMap(\.score)) : nil,
            symptomChanges: changes,
            hotFlashesPerDayBefore: status == .ready ? hotFlashRate(before) : nil,
            hotFlashesPerDayAfter: status == .ready ? hotFlashRate(after) : nil
        )
    }

    /// Other treatments that started or stopped inside this treatment's
    /// before/after comparison window. Their effect can't be separated.
    public func overlappingTreatments(for treatment: TreatmentPeriod, in all: [TreatmentPeriod]) -> [TreatmentPeriod] {
        let start = calendar.startOfDay(for: treatment.start)
        let windowStart = calendar.day(-treatmentWindowDays, from: start)
        let windowEnd = calendar.day(treatmentSettleDays + treatmentWindowDays, from: start)
        return all.filter { other in
            guard other.id != treatment.id else { return false }
            let otherStart = calendar.startOfDay(for: other.start)
            if otherStart > windowStart && otherStart < windowEnd { return true }
            if let otherEnd = other.end.map({ calendar.startOfDay(for: $0) }), otherEnd > windowStart && otherEnd < windowEnd { return true }
            return false
        }
    }

    private func treatmentInsight(_ comparison: TreatmentComparison, overlapping: [TreatmentPeriod] = []) -> Insight? {
        guard let change = comparison.relativeChange, abs(change) >= Self.meaningfulScoreChange else { return nil }
        let name = comparison.treatment.name
        let title = change < 0
            ? "Your symptom score is \(Phrasing.percent(-change)) lower since starting \(name)"
            : "Your symptom score is \(Phrasing.percent(change)) higher since starting \(name)"

        var detail = "Compared with the \(treatmentWindowDays) days before you started (after giving it \(treatmentSettleDays) days to take effect)."
        if let best = comparison.symptomChanges.first, best.difference <= -0.5 {
            detail += " Biggest change: \(SymptomCatalog.phrase(for: best.symptomID)), from \(Phrasing.oneDecimal(best.before)) to \(Phrasing.oneDecimal(best.after)) on a 0–3 scale."
        }
        if let before = comparison.hotFlashesPerDayBefore, let after = comparison.hotFlashesPerDayAfter {
            detail += " Hot flashes per day: \(Phrasing.oneDecimal(before)) → \(Phrasing.oneDecimal(after))."
        }
        if !overlapping.isEmpty {
            let names = overlapping.map(\.name).joined(separator: " and ")
            detail += " You also started or stopped \(names) around this time, so the change can't be put down to \(name) alone."
        } else {
            detail += " Other things may have changed too, so talk it through with your clinician."
        }

        return Insight(
            id: "treatment-\(comparison.treatment.id)",
            kind: .treatment,
            title: title,
            detail: detail,
            symptomID: nil,
            factorID: comparison.treatment.id,
            strength: abs(change)
        )
    }

    // MARK: - Trend

    public func trend(records: [DayRecord], today: Date) -> TrendSummary? {
        let recentStart = calendar.day(-13, from: today)
        let previousStart = calendar.day(-27, from: today)
        let end = calendar.day(1, from: today)

        let recent = records.filter { $0.day >= recentStart && $0.day < end }.compactMap(\.score)
        let previous = records.filter { $0.day >= previousStart && $0.day < recentStart }.compactMap(\.score)
        guard recent.count >= 5, previous.count >= 5,
              let recentMean = Stats.mean(recent), let previousMean = Stats.mean(previous) else { return nil }
        return TrendSummary(recentScore: recentMean, previousScore: previousMean, recentDays: recent.count, previousDays: previous.count)
    }

    private func trendInsight(_ trend: TrendSummary) -> Insight? {
        let change = trend.relativeChange
        guard abs(change) >= Self.meaningfulScoreChange, abs(trend.recentScore - trend.previousScore) >= 5 else { return nil }
        let direction = change < 0 ? "down" : "up"
        return Insight(
            id: "trend-14",
            kind: .trend,
            title: "Your symptom score is \(direction) \(Phrasing.percent(abs(change))) over the last 2 weeks",
            detail: "Average score \(Int(trend.recentScore.rounded())) in the last 14 days vs \(Int(trend.previousScore.rounded())) in the 14 days before (0 = no symptoms, 100 = all severe).",
            symptomID: nil,
            factorID: nil,
            strength: abs(change)
        )
    }

    // MARK: - Frequencies and scores

    public func symptomFrequencies(records: [DayRecord], from start: Date, to end: Date) -> [SymptomFrequency] {
        let lower = calendar.startOfDay(for: start)
        let upper = calendar.day(1, from: end)
        let window = records.filter { $0.day >= lower && $0.day < upper }

        var ids = Set(window.flatMap { $0.symptoms.keys })
        if window.contains(where: { $0.hotFlashCount != nil }) { ids.insert(SymptomCatalog.hotFlashes) }

        let frequencies: [SymptomFrequency] = ids.map { id in
            let tracked = window.filter { $0.tracked(id) }
            let present = tracked.filter { $0.isPresent(id) }
            let severities = present.map { max($0.severity(of: id), 1) }
            return SymptomFrequency(
                symptomID: id,
                daysTracked: tracked.count,
                daysPresent: present.count,
                averageSeverityWhenPresent: Stats.mean(severities) ?? 0,
                severeDays: present.filter { $0.severity(of: id) == 3 }.count
            )
        }

        let order = Dictionary(uniqueKeysWithValues: SymptomCatalog.all.enumerated().map { ($1.id, $0) })
        return frequencies.sorted { lhs, rhs in
            if lhs.frequency != rhs.frequency { return lhs.frequency > rhs.frequency }
            if lhs.averageSeverityWhenPresent != rhs.averageSeverityWhenPresent {
                return lhs.averageSeverityWhenPresent > rhs.averageSeverityWhenPresent
            }
            return (order[lhs.symptomID] ?? .max) < (order[rhs.symptomID] ?? .max)
        }
    }

    private func topSymptomInsight(_ top: SymptomFrequency) -> Insight {
        Insight(
            id: "top-\(top.symptomID)",
            kind: .topSymptom,
            title: "Your most frequent symptom lately: \(SymptomCatalog.phrase(for: top.symptomID))",
            detail: "Logged on \(Phrasing.countOf(top.daysPresent, top.daysTracked)) days in the last 30 (\(Phrasing.percent(top.frequency))), usually \(Severity(rawValue: Int(top.averageSeverityWhenPresent.rounded()))?.title.lowercased() ?? "mild").",
            symptomID: top.symptomID,
            factorID: nil,
            strength: top.frequency
        )
    }

    public func dailyScores(records: [DayRecord], from start: Date, to end: Date) -> [DailyScore] {
        let lower = calendar.startOfDay(for: start)
        let upper = calendar.day(1, from: end)
        return records
            .filter { $0.day >= lower && $0.day < upper }
            .compactMap { record in record.score.map { DailyScore(day: record.day, score: $0) } }
            .sorted { $0.day < $1.day }
    }

    /// Consecutive days with a check-in, ending today (or yesterday if today
    /// isn't logged yet).
    public func currentStreak(loggedDays: Set<Date>, today: Date) -> Int {
        let days = Set(loggedDays.map { calendar.startOfDay(for: $0) })
        var cursor = calendar.startOfDay(for: today)
        if !days.contains(cursor) { cursor = calendar.day(-1, from: cursor) }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            cursor = calendar.day(-1, from: cursor)
        }
        return streak
    }
}
