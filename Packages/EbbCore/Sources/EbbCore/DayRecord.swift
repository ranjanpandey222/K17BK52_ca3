import Foundation

/// One day of check-in data, independent of how it is stored.
public struct DayRecord: Hashable, Sendable {
    /// Start of the day this record belongs to.
    public var day: Date
    /// Symptom ID -> severity (0...3). A key that is present means the symptom
    /// was tracked that day; 0 means "tracked, not present".
    public var symptoms: [String: Int]
    public var triggers: Set<String>
    /// Number of hot flashes, if the user counted them.
    public var hotFlashCount: Int?

    public init(day: Date, symptoms: [String: Int], triggers: Set<String> = [], hotFlashCount: Int? = nil) {
        self.day = day
        self.symptoms = symptoms.mapValues(Severity.clamped)
        self.triggers = triggers
        self.hotFlashCount = hotFlashCount.map { max(0, $0) }
    }

    public func severity(of symptomID: String) -> Int { symptoms[symptomID] ?? 0 }

    /// True when the symptom was tracked on this day (logged, even if "none").
    public func tracked(_ symptomID: String) -> Bool {
        if symptoms[symptomID] != nil { return true }
        return symptomID == SymptomCatalog.hotFlashes && hotFlashCount != nil
    }

    /// True when the symptom was present (any severity, or a counted hot flash).
    public func isPresent(_ symptomID: String) -> Bool {
        if severity(of: symptomID) > 0 { return true }
        if symptomID == SymptomCatalog.hotFlashes, let count = hotFlashCount, count > 0 { return true }
        return false
    }

    /// Symptom score from 0 to 100: the average severity of everything logged
    /// that day, scaled so "all severe" = 100. Nil when nothing was logged.
    public var score: Double? {
        guard !symptoms.isEmpty else { return nil }
        let total = symptoms.values.reduce(0, +)
        return Double(total) / Double(symptoms.count) / 3.0 * 100.0
    }

    /// IDs of symptoms present on this day.
    public var presentSymptomIDs: [String] {
        SymptomCatalog.normalized(symptoms.filter { $0.value > 0 }.map(\.key))
    }
}

/// A treatment (HRT, non-hormonal medicine, supplement...) as a time span.
public struct TreatmentPeriod: Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let isHormonal: Bool
    public let start: Date
    public let end: Date?

    public init(id: String, name: String, isHormonal: Bool, start: Date, end: Date?) {
        self.id = id
        self.name = name
        self.isHormonal = isHormonal
        self.start = start
        self.end = end
    }

    public func isActive(on date: Date) -> Bool {
        if date < start { return false }
        if let end, date >= end { return false }
        return true
    }
}
