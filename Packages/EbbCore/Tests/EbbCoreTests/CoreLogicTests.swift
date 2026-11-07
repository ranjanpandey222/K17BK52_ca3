import XCTest
@testable import EbbCore

final class FisherExactTests: XCTestCase {
    func testLadyTastingTea() {
        // Classic example: two-sided p = 0.4857
        XCTAssertEqual(FisherExact.twoSidedPValue(a: 3, b: 1, c: 1, d: 3), 0.4857, accuracy: 0.0001)
    }

    func testStrongAssociation() {
        // 7/8 vs 2/14 (two-sided p ≈ 0.0019)
        let p = FisherExact.twoSidedPValue(a: 7, b: 1, c: 2, d: 12)
        XCTAssertLessThan(p, 0.005)
    }

    func testNoAssociation() {
        XCTAssertEqual(FisherExact.twoSidedPValue(a: 5, b: 5, c: 5, d: 5), 1.0, accuracy: 0.0001)
    }

    func testEmptyTable() {
        XCTAssertEqual(FisherExact.twoSidedPValue(a: 0, b: 0, c: 0, d: 0), 1)
    }
}

final class DayKeyTests: XCTestCase {
    func testRoundTrip() {
        let calendar = TestSupport.calendar
        let key = DayKey.string(from: TestSupport.today, calendar: calendar)
        XCTAssertEqual(key, "2026-06-30")
        let date = DayKey.date(from: key, calendar: calendar)!
        XCTAssertEqual(DayKey.string(from: date, calendar: calendar), key)
        XCTAssertNil(DayKey.date(from: "nonsense", calendar: calendar))
    }

    func testPadding() {
        let date = TestSupport.calendar.date(from: DateComponents(year: 2027, month: 1, day: 5))!
        XCTAssertEqual(DayKey.string(from: date, calendar: TestSupport.calendar), "2027-01-05")
    }
}

final class PhrasingTests: XCTestCase {
    func testFormatting() {
        XCTAssertEqual(Phrasing.percent(0.756), "76%")
        XCTAssertEqual(Phrasing.multiplier(2.0), "2×")
        XCTAssertEqual(Phrasing.multiplier(2.14), "2.1×")
        XCTAssertEqual(Phrasing.oneDecimal(1.0), "1")
        XCTAssertEqual(Phrasing.oneDecimal(1.26), "1.3")
        XCTAssertEqual(Phrasing.days(1), "1 day")
        XCTAssertEqual(Phrasing.days(3), "3 days")
    }
}

final class CatalogTests: XCTestCase {
    func testCatalogIDsAreUnique() {
        XCTAssertEqual(Set(SymptomCatalog.all.map(\.id)).count, SymptomCatalog.all.count)
        XCTAssertEqual(Set(TriggerCatalog.all.map(\.id)).count, TriggerCatalog.all.count)
    }

    func testDefaultsAndNormalization() {
        XCTAssertTrue(SymptomCatalog.defaultTrackedIDs.contains(SymptomCatalog.hotFlashes))
        XCTAssertEqual(
            SymptomCatalog.normalized([SymptomCatalog.anxiety, "unknown", SymptomCatalog.hotFlashes, SymptomCatalog.anxiety]),
            [SymptomCatalog.hotFlashes, SymptomCatalog.anxiety]
        )
        XCTAssertEqual(SymptomCatalog.name(for: "made_up_thing"), "Made Up Thing")
    }
}

final class StageEstimatorTests: XCTestCase {
    func testStages() {
        XCTAssertEqual(StageEstimator.estimate(lastPeriod: .overTwelveMonths, age: 53).stage, .likelyPostmenopause)
        XCTAssertEqual(StageEstimator.estimate(lastPeriod: .threeToTwelveMonths, age: 49).stage, .likelyLatePerimenopause)
        XCTAssertEqual(StageEstimator.estimate(lastPeriod: .withinThreeMonths, age: 45).stage, .possiblyPerimenopause)
        XCTAssertEqual(StageEstimator.estimate(lastPeriod: .withinThreeMonths, age: 35).stage, .unclear)
        XCTAssertEqual(StageEstimator.estimate(lastPeriod: .withinThreeMonths, age: nil).stage, .unclear)
        XCTAssertEqual(StageEstimator.estimate(lastPeriod: .otherReason, age: 50).stage, .unclear)
        XCTAssertEqual(StageEstimator.estimate(lastPeriod: nil, age: 50).stage, .unclear)
    }

    func testPostmenopauseMentionsBleedingCheck() {
        XCTAssertTrue(StageEstimator.estimate(lastPeriod: .overTwelveMonths, age: 55).explanation.contains("bleeding"))
    }

    func testAge() {
        XCTAssertEqual(StageEstimator.age(birthYear: 1978, today: TestSupport.today, calendar: TestSupport.calendar), 48)
        XCTAssertNil(StageEstimator.age(birthYear: nil, today: TestSupport.today))
        XCTAssertNil(StageEstimator.age(birthYear: 3000, today: TestSupport.today, calendar: TestSupport.calendar))
    }
}

final class ReportBuilderTests: XCTestCase {
    private let calendar = TestSupport.calendar

    func testBuildsReportWithQuestions() {
        var records: [DayRecord] = []
        for i in 0..<60 {
            records.append(TestSupport.record(
                -i,
                [SymptomCatalog.hotFlashes: i % 2 == 0 ? 2 : 0, SymptomCatalog.sleepTrouble: i % 5 == 0 ? 0 : 2, SymptomCatalog.anxiety: 0],
                triggers: i % 3 == 0 ? [TriggerCatalog.caffeine] : [],
                hotFlashes: i % 2 == 0 ? 5 : 0
            ))
        }
        let report = ReportBuilder.build(
            records: records,
            treatments: [],
            months: 3,
            today: TestSupport.today,
            stage: StageEstimator.estimate(lastPeriod: .overTwelveMonths, age: 54),
            calendar: calendar
        )

        XCTAssertTrue(report.hasEnoughData)
        XCTAssertEqual(report.daysLogged, 60)
        XCTAssertEqual(report.symptoms.first?.symptomID, SymptomCatalog.sleepTrouble)
        XCTAssertEqual(report.hotFlashes?.maximumInADay, 5)
        XCTAssertEqual(report.hotFlashes!.averagePerDay, 2.5, accuracy: 0.001)
        XCTAssertEqual(report.triggers.first?.triggerID, TriggerCatalog.caffeine)
        XCTAssertEqual(report.triggers.first?.days, 20)
        XCTAssertFalse(report.weeklyScores.isEmpty)

        XCTAssertTrue(report.questions.contains { $0.contains("hot flashes or night sweats") })
        XCTAssertTrue(report.questions.contains { $0.contains("trouble sleeping") })
        XCTAssertTrue(report.questions.contains { $0.contains("bone and heart health") })
        XCTAssertLessThanOrEqual(report.questions.count, QuestionGenerator.maximumQuestions)
    }

    func testReportRangeExcludesOldRecords() {
        let records = [TestSupport.record(0, [SymptomCatalog.hotFlashes: 1]), TestSupport.record(-200, [SymptomCatalog.hotFlashes: 3])]
        let report = ReportBuilder.build(records: records, treatments: [], months: 1, today: TestSupport.today, stage: nil, calendar: calendar)
        XCTAssertEqual(report.daysLogged, 1)
        XCTAssertFalse(report.hasEnoughData)
        XCTAssertEqual(report.daysInRange, 30)
    }

    func testHormonalTreatmentQuestions() {
        let start = -50
        var records: [DayRecord] = []
        for i in (start - 28)..<start { records.append(TestSupport.record(i, [SymptomCatalog.hotFlashes: 2])) }
        for i in (start + 14)..<(start + 42) { records.append(TestSupport.record(i, [SymptomCatalog.hotFlashes: 2])) }
        let hrt = TreatmentPeriod(id: "h", name: "Estradiol gel", isHormonal: true, start: TestSupport.day(start), end: nil)

        let report = ReportBuilder.build(records: records, treatments: [hrt], months: 3, today: TestSupport.today, stage: nil, calendar: calendar)
        XCTAssertEqual(report.treatments.count, 1)
        XCTAssertEqual(report.treatments.first?.comparison.status, .ready)
        // No change -> asks about reviewing the dose; doesn't ask about starting treatment.
        XCTAssertTrue(report.questions.first!.contains("haven't changed much"))
        XCTAssertFalse(report.questions.contains { $0.contains("What treatment options") })
    }
}
