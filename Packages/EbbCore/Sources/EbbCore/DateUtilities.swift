import Foundation

/// Stable "yyyy-MM-dd" keys for days, used as the unique ID of a check-in.
public enum DayKey {
    public static func string(from date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return pad(parts.year ?? 0, 4) + "-" + pad(parts.month ?? 0, 2) + "-" + pad(parts.day ?? 0, 2)
    }

    public static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let pieces = key.split(separator: "-").compactMap { Int($0) }
        guard pieces.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: pieces[0], month: pieces[1], day: pieces[2]))
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let text = String(value)
        return text.count >= width ? text : String(repeating: "0", count: width - text.count) + text
    }
}

extension Calendar {
    /// Start of the day `days` days after `date` (negative values go back).
    public func day(_ days: Int, from date: Date) -> Date {
        let start = startOfDay(for: date)
        return self.date(byAdding: .day, value: days, to: start) ?? start
    }

    /// Whole days between the starts of two dates.
    public func daysBetween(_ from: Date, _ to: Date) -> Int {
        dateComponents([.day], from: startOfDay(for: from), to: startOfDay(for: to)).day ?? 0
    }
}

enum Stats {
    static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    static func mean(_ values: [Int]) -> Double? {
        mean(values.map(Double.init))
    }
}

/// Two-sided Fisher's exact test for a 2x2 table:
///
///                  symptom   no symptom
///     factor          a          b
///     no factor       c          d
///
/// Used to avoid reporting "patterns" that are likely just chance.
public enum FisherExact {
    public static func twoSidedPValue(a: Int, b: Int, c: Int, d: Int) -> Double {
        guard a >= 0, b >= 0, c >= 0, d >= 0 else { return 1 }
        let row1 = a + b
        let row2 = c + d
        let col1 = a + c
        let col2 = b + d
        let total = row1 + row2
        guard total > 0 else { return 1 }

        let fixed = logFactorial(row1) + logFactorial(row2) + logFactorial(col1) + logFactorial(col2) - logFactorial(total)

        func probability(_ x: Int) -> Double {
            let y = row1 - x
            let z = col1 - x
            let w = row2 - z
            guard x >= 0, y >= 0, z >= 0, w >= 0 else { return 0 }
            return exp(fixed - logFactorial(x) - logFactorial(y) - logFactorial(z) - logFactorial(w))
        }

        let observed = probability(a)
        let lower = max(0, col1 - row2)
        let upper = min(row1, col1)
        guard lower <= upper else { return 1 }

        var p = 0.0
        for x in lower...upper {
            let px = probability(x)
            if px <= observed * (1 + 1e-7) { p += px }
        }
        return min(1, p)
    }

    static func logFactorial(_ n: Int) -> Double {
        lgamma(Double(n) + 1)
    }
}

/// Small helpers for consistent wording in insights and reports.
public enum Phrasing {
    public static func percent(_ fraction: Double) -> String {
        String(Int((fraction * 100).rounded())) + "%"
    }

    /// "2×", "1.5×"
    public static func multiplier(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() { return String(Int(rounded)) + "×" }
        return String(rounded) + "×"
    }

    /// "6 of 8"
    public static func countOf(_ part: Int, _ whole: Int) -> String {
        "\(part) of \(whole)"
    }

    public static func days(_ n: Int) -> String {
        n == 1 ? "1 day" : "\(n) days"
    }

    /// One decimal place, without a trailing ".0".
    public static func oneDecimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(rounded)
    }
}
