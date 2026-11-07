import Foundation
@testable import EbbCore

enum TestSupport {
    static var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// 2026-06-30, noon UTC.
    static let today: Date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 30, hour: 12))!

    static func day(_ offset: Int) -> Date {
        calendar.day(offset, from: today)
    }

    static func record(
        _ offset: Int,
        _ symptoms: [String: Int],
        triggers: Set<String> = [],
        hotFlashes: Int? = nil
    ) -> DayRecord {
        DayRecord(day: day(offset), symptoms: symptoms, triggers: triggers, hotFlashCount: hotFlashes)
    }
}
