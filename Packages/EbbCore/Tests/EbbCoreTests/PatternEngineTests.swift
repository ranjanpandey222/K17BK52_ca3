import XCTest
@testable import EbbCore

final class PatternEngineTests: XCTestCase {
    private let engine = PatternEngine(calendar: TestSupport.calendar)
    private let hot = SymptomCatalog.hotFlashes
    private let anxiety = SymptomCatalog.anxiety
    private let sleep = SymptomCatalog.sleepTrouble

    // MARK: Day records

    func testScoreIsAverageSeverityScaledTo100() {
        let record = TestSupport.record(0, [hot: 3, anxiety: 0, sleep: 3])
        XCTAssertEqual(record.score!, 200.0 / 3.0, accuracy: 0.001)
        XCTAssertNil(TestSupport.record(0, [:]).score)
    }

    func testSeverityIsClamped() {
        let record = TestSupport.record(0, [hot: 9, anxiety: -2])
        XCTAssertEqual(record.severity(of: hot), 3)
        XCTAssertEqual(record.severity(of: anxiety), 0)
    }

    func testHotFlashCountCountsAsPresent() {
        let record = TestSupport.record(0, [:], hotFlashes: 4)
        XCTAssertTrue(record.tracked(hot))
        XCTAssertTrue(record.isPresent(hot))
        XCTAssertFalse(record.tracked(anxiety))
    }

    // MARK: Minimum data

    func testNoInsightsWithFewerThanSevenDays() {
        let records = (0..<6).map { TestSupport.record(-$0, [hot: 2]) }
        XCTAssertTrue(engine.insights(records: records, treatments: [], today: TestSupport.today).isEmpty)
    }

    // MARK: Triggers

    func testFindsAlcoholHotFlashPattern() {
        var records: [DayRecord] = []
        // 8 alcohol days, hot flashes on 7 of them.
        for i in 0..<8 {
            records.append(TestSupport.record(-i, [hot: i == 0 ? 0 : 2, sleep: 1], triggers: [TriggerCatalog.alcohol]))
        }
        // 14 other days, hot flashes on 2 of them.
        for i in 8..<22 {
            records.append(TestSupport.record(-i, [hot: i < 10 ? 2 : 0, sleep: 1]))
        }

        let associations = engine.triggerAssociations(records: records, today: TestSupport.today)
        let match = associations.first { $0.triggerID == TriggerCatalog.alcohol && $0.symptomID == hot }
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.daysWithFactor, 8)
        XCTAssertEqual(match?.presentWithFactor, 7)
        XCTAssertEqual(match?.daysWithoutFactor, 14)
        XCTAssertEqual(match?.presentWithoutFactor, 2)
        XCTAssertEqual(match?.direction, .more)
        XCTAssertLessThan(match!.pValue, 0.01)

        // Sleep was identical on all days, so no pattern should be reported for it.
        XCTAssertFalse(associations.contains { $0.symptomID == sleep })

        let insights = engine.insights(records: records, treatments: [], today: TestSupport.today)
        let insight = insights.first { $0.id == "trigger-alcohol-hot_flashes" }
        XCTAssertNotNil(insight)
        XCTAssertTrue(insight!.title.hasPrefix("Hot flashes were"), insight!.title)
        XCTAssertTrue(insight!.detail.contains("7 of 8"), insight!.detail)
        XCTAssertTrue(insight!.detail.contains("not proof of cause"))
    }

    func testFindsProtectiveExercisePatternWithSingularGrammar() {
        var records: [DayRecord] = []
        for i in 0..<10 {
            records.append(TestSupport.record(-i, [anxiety: i < 1 ? 2 : 0], triggers: [TriggerCatalog.exercise]))
        }
        for i in 10..<22 {
            records.append(TestSupport.record(-i, [anxiety: i < 20 ? 2 : 0]))
        }
        let association = engine.triggerAssociations(records: records, today: TestSupport.today)
            .first { $0.triggerID == TriggerCatalog.exercise && $0.symptomID == anxiety }
        XCTAssertEqual(association?.direction, .less)

        let insight = engine.insights(records: records, treatments: [], today: TestSupport.today)
            .first { $0.kind == .trigger }
        XCTAssertEqual(insight?.title, "Anxiety showed up less often on days with exercise")
    }

    func testIgnoresSmallOrChancePatterns() {
        var records: [DayRecord] = []
        // 4 of 6 with the factor vs 6 of 10 without: no real difference.
        for i in 0..<6 {
            records.append(TestSupport.record(-i, [hot: i < 4 ? 1 : 0], triggers: [TriggerCatalog.caffeine]))
        }
        for i in 6..<16 {
            records.append(TestSupport.record(-i, [hot: i < 12 ? 1 : 0]))
        }
        XCTAssertTrue(engine.triggerAssociations(records: records, today: TestSupport.today).isEmpty)
    }

    func testRequiresMinimumDaysWithFactor() {
        var records: [DayRecord] = []
        for i in 0..<3 {
            records.append(TestSupport.record(-i, [hot: 3], triggers: [TriggerCatalog.alcohol]))
        }
        for i in 3..<20 {
            records.append(TestSupport.record(-i, [hot: 0]))
        }
        XCTAssertTrue(engine.triggerAssociations(records: records, today: TestSupport.today).isEmpty)
    }

    func testIgnoresRecordsOutsideLookback() {
        var records: [DayRecord] = []
        for i in 100..<130 {
            records.append(TestSupport.record(-i, [hot: i % 2 == 0 ? 3 : 0], triggers: i % 2 == 0 ? [TriggerCatalog.alcohol] : []))
        }
        XCTAssertTrue(engine.triggerAssociations(records: records, today: TestSupport.today).isEmpty)
    }

    // MARK: Treatments

    private func treatment(startOffset: Int, end: Int? = nil) -> TreatmentPeriod {
        TreatmentPeriod(
            id: "t1",
            name: "Estradiol patch",
            isHormonal: true,
            start: TestSupport.day(startOffset),
            end: end.map(TestSupport.day)
        )
    }

    func testTreatmentComparisonShowsImprovement() {
        let start = -50
        var records: [DayRecord] = []
        // 28 days before: severe night sweats and sleep trouble.
        for i in (start - 28)..<start {
            records.append(TestSupport.record(i, [SymptomCatalog.nightSweats: 3, sleep: 2], hotFlashes: 8))
        }
        // From day 14 after start: much better.
        for i in (start + 14)..<(start + 42) {
            records.append(TestSupport.record(i, [SymptomCatalog.nightSweats: 1, sleep: 1], hotFlashes: 2))
        }

        let comparison = engine.treatmentComparison(for: treatment(startOffset: start), records: records, today: TestSupport.today)
        XCTAssertEqual(comparison.status, .ready)
        XCTAssertEqual(comparison.beforeDays, 28)
        XCTAssertEqual(comparison.afterDays, 28)
        XCTAssertEqual(comparison.relativeChange!, -0.6, accuracy: 0.001)
        XCTAssertEqual(comparison.symptomChanges.first?.symptomID, SymptomCatalog.nightSweats)
        XCTAssertEqual(comparison.hotFlashesPerDayBefore!, 8, accuracy: 0.001)
        XCTAssertEqual(comparison.hotFlashesPerDayAfter!, 2, accuracy: 0.001)
        XCTAssertTrue(comparison.summary.contains("60% lower"), comparison.summary)

        let insight = engine.insights(records: records, treatments: [treatment(startOffset: start)], today: TestSupport.today)
            .first { $0.kind == .treatment }
        XCTAssertEqual(insight?.title, "Your symptom score is 60% lower since starting Estradiol patch")
        XCTAssertTrue(insight!.detail.contains("night sweats"))
        XCTAssertTrue(insight!.detail.contains("Hot flashes per day: 8 → 2"))
    }

    func testTreatmentTooEarly() {
        var records: [DayRecord] = []
        for i in -40..<(-5) { records.append(TestSupport.record(i, [hot: 2])) }
        let comparison = engine.treatmentComparison(for: treatment(startOffset: -5), records: records, today: TestSupport.today)
        // Settles for 14 days and needs 5 more logged days: ready from day 19 after start.
        XCTAssertEqual(comparison.status, .tooEarly(daysRemaining: 14))
        XCTAssertNil(comparison.relativeChange)
    }

    func testTreatmentNeedsDataBefore() {
        var records: [DayRecord] = []
        for i in -10...0 { records.append(TestSupport.record(i, [hot: 1])) }
        let comparison = engine.treatmentComparison(for: treatment(startOffset: -40), records: records, today: TestSupport.today)
        XCTAssertEqual(comparison.status, .notEnoughBefore(loggedDays: 0))
    }

    func testTreatmentNotEnoughAfter() {
        var records: [DayRecord] = []
        for i in -80..<(-50) { records.append(TestSupport.record(i, [hot: 2])) }
        for i in -30..<(-28) { records.append(TestSupport.record(i, [hot: 1])) }
        let comparison = engine.treatmentComparison(for: treatment(startOffset: -50), records: records, today: TestSupport.today)
        XCTAssertEqual(comparison.status, .notEnoughAfter(loggedDays: 2))
    }

    // MARK: Trend & frequencies

    func testTrendDetectsImprovement() {
        var records: [DayRecord] = []
        for i in 0..<14 { records.append(TestSupport.record(-i, [hot: 1, sleep: 1])) }
        for i in 14..<28 { records.append(TestSupport.record(-i, [hot: 2, sleep: 2])) }
        let trend = engine.trend(records: records, today: TestSupport.today)
        XCTAssertEqual(trend!.relativeChange, -0.5, accuracy: 0.001)

        let insight = engine.insights(records: records, treatments: [], today: TestSupport.today).first { $0.kind == .trend }
        XCTAssertEqual(insight?.title, "Your symptom score is down 50% over the last 2 weeks")
    }

    func testFrequenciesSortedByHowOften() {
        var records: [DayRecord] = []
        for i in 0..<10 {
            records.append(TestSupport.record(-i, [hot: i < 8 ? 2 : 0, anxiety: i < 3 ? 3 : 0, sleep: 0]))
        }
        let frequencies = engine.symptomFrequencies(records: records, from: TestSupport.day(-29), to: TestSupport.today)
        XCTAssertEqual(frequencies.map(\.symptomID), [hot, anxiety, sleep])
        XCTAssertEqual(frequencies[0].frequency, 0.8, accuracy: 0.001)
        XCTAssertEqual(frequencies[1].severeDays, 3)
        XCTAssertEqual(frequencies[1].averageSeverityWhenPresent, 3, accuracy: 0.001)

        let top = engine.insights(records: records, treatments: [], today: TestSupport.today).first { $0.kind == .topSymptom }
        XCTAssertEqual(top?.title, "Your most frequent symptom lately: hot flashes")
    }

    func testStreak() {
        let days: Set<Date> = [TestSupport.day(0), TestSupport.day(-1), TestSupport.day(-2), TestSupport.day(-4)]
        XCTAssertEqual(engine.currentStreak(loggedDays: days, today: TestSupport.today), 3)
        let notToday: Set<Date> = [TestSupport.day(-1), TestSupport.day(-2)]
        XCTAssertEqual(engine.currentStreak(loggedDays: notToday, today: TestSupport.today), 2)
        XCTAssertEqual(engine.currentStreak(loggedDays: [], today: TestSupport.today), 0)
    }

    func testDailyScoresSorted() {
        let records = [TestSupport.record(0, [hot: 3]), TestSupport.record(-2, [hot: 0]), TestSupport.record(-40, [hot: 3])]
        let scores = engine.dailyScores(records: records, from: TestSupport.day(-29), to: TestSupport.today)
        XCTAssertEqual(scores.map(\.score), [0, 100])
    }
}
