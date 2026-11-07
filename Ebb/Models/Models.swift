import Foundation
import SwiftData
import EbbCore

/// One day's check-in. Stored only on this device.
@Model
final class DayLog {
    /// "yyyy-MM-dd": one check-in per day.
    @Attribute(.unique) var dayKey: String
    var day: Date
    /// JSON-encoded [symptomID: severity]. Stored as Data for maximum
    /// compatibility; use `symptoms` to read and write it.
    var symptomData: Data
    var triggerIDs: [String]
    var hotFlashCount: Int?
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(day: Date, calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: day)
        self.dayKey = DayKey.string(from: start, calendar: calendar)
        self.day = start
        self.symptomData = Data()
        self.triggerIDs = []
        self.hotFlashCount = nil
        self.note = ""
        self.createdAt = .now
        self.updatedAt = .now
    }

    var symptoms: [String: Int] {
        get {
            guard !symptomData.isEmpty,
                  let decoded = try? JSONDecoder().decode([String: Int].self, from: symptomData) else { return [:] }
            return decoded
        }
        set {
            symptomData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var record: DayRecord {
        DayRecord(day: day, symptoms: symptoms, triggers: Set(triggerIDs), hotFlashCount: hotFlashCount)
    }
}

enum TreatmentKind: String, CaseIterable, Identifiable, Codable {
    case estrogenPatch
    case estrogenGel
    case estrogenPill
    case estrogenSpray
    case vaginalEstrogen
    case progesterone
    case combinedHRT
    case testosterone
    case nonHormonalMedicine
    case supplement
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .estrogenPatch: return "Estrogen patch"
        case .estrogenGel: return "Estrogen gel"
        case .estrogenPill: return "Estrogen pill"
        case .estrogenSpray: return "Estrogen spray"
        case .vaginalEstrogen: return "Vaginal estrogen"
        case .progesterone: return "Progesterone / progestin"
        case .combinedHRT: return "Combined HRT"
        case .testosterone: return "Testosterone"
        case .nonHormonalMedicine: return "Non-hormonal medicine"
        case .supplement: return "Supplement"
        case .other: return "Other"
        }
    }

    var isHormonal: Bool {
        switch self {
        case .nonHormonalMedicine, .supplement, .other: return false
        default: return true
        }
    }

    var systemImage: String {
        switch self {
        case .estrogenPatch: return "bandage"
        case .estrogenGel, .estrogenSpray: return "drop"
        case .estrogenPill, .progesterone, .combinedHRT, .nonHormonalMedicine: return "pills"
        case .vaginalEstrogen: return "cross.vial"
        case .testosterone: return "syringe"
        case .supplement: return "leaf"
        case .other: return "cross.case"
        }
    }

    /// Suggested default frequency when adding a treatment of this kind.
    var defaultFrequency: TreatmentFrequency {
        switch self {
        case .estrogenPatch: return .twiceWeekly
        case .vaginalEstrogen: return .twiceWeekly
        case .supplement, .other: return .daily
        default: return .daily
        }
    }
}

enum TreatmentFrequency: String, CaseIterable, Identifiable, Codable {
    case daily
    case twiceWeekly
    case weekly
    case asNeeded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "Every day"
        case .twiceWeekly: return "Twice a week"
        case .weekly: return "Once a week"
        case .asNeeded: return "As needed"
        }
    }

    /// Number of weekdays the user picks for reminders.
    var weekdayCount: Int {
        switch self {
        case .twiceWeekly: return 2
        case .weekly: return 1
        default: return 0
        }
    }
}

/// A treatment such as HRT, a non-hormonal medicine or a supplement.
/// A dose change ends the old record and starts a new one, so before/after
/// comparisons work for each dose.
@Model
final class Treatment {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var dose: String
    var frequencyRaw: String
    /// Calendar weekdays (1 = Sunday ... 7 = Saturday) for weekly schedules.
    var reminderWeekdays: [Int]
    var startDate: Date
    var endDate: Date?
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var notes: String
    var previousTreatmentID: UUID?
    var createdAt: Date

    init(
        name: String,
        kind: TreatmentKind,
        dose: String = "",
        frequency: TreatmentFrequency? = nil,
        startDate: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.dose = dose
        self.frequencyRaw = (frequency ?? kind.defaultFrequency).rawValue
        self.reminderWeekdays = []
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.endDate = nil
        self.reminderEnabled = false
        self.reminderHour = 9
        self.reminderMinute = 0
        self.notes = ""
        self.previousTreatmentID = nil
        self.createdAt = .now
    }

    var kind: TreatmentKind {
        get { TreatmentKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var frequency: TreatmentFrequency {
        get { TreatmentFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    var isActive: Bool {
        guard let endDate else { return true }
        return endDate > .now
    }

    var displayName: String {
        dose.isEmpty ? name : "\(name) · \(dose)"
    }

    var period: TreatmentPeriod {
        TreatmentPeriod(id: id.uuidString, name: name, isHormonal: kind.isHormonal, start: startDate, end: endDate)
    }

    /// Whether a dose is expected on the given day.
    func isDue(on date: Date, calendar: Calendar = .current) -> Bool {
        guard isActive, calendar.startOfDay(for: date) >= startDate else { return false }
        switch frequency {
        case .daily: return true
        case .asNeeded: return false
        case .twiceWeekly, .weekly:
            let weekday = calendar.component(.weekday, from: date)
            return reminderWeekdays.contains(weekday)
        }
    }
}

/// Records that a dose was taken (or a patch changed) on a day.
@Model
final class DoseLog {
    var treatmentID: UUID
    var dayKey: String
    var takenAt: Date

    init(treatmentID: UUID, day: Date, calendar: Calendar = .current) {
        self.treatmentID = treatmentID
        self.dayKey = DayKey.string(from: day, calendar: calendar)
        self.takenAt = .now
    }
}

enum EbbSchema {
    static let models: [any PersistentModel.Type] = [DayLog.self, Treatment.self, DoseLog.self]
}
