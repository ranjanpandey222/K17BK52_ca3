import Foundation
import SwiftData
import EbbCore

/// Helpers for reading and writing check-ins with SwiftData.
@MainActor
enum DataRepository {
    static func dayLog(for day: Date, in context: ModelContext) -> DayLog? {
        let key = DayKey.string(from: day)
        var descriptor = FetchDescriptor<DayLog>(predicate: #Predicate { $0.dayKey == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Returns the existing log for the day, or inserts a new one.
    static func dayLogCreatingIfNeeded(for day: Date, in context: ModelContext) -> DayLog {
        if let existing = dayLog(for: day, in: context) { return existing }
        let log = DayLog(day: day)
        context.insert(log)
        return log
    }

    static func records(from logs: [DayLog]) -> [DayRecord] {
        logs.map(\.record)
    }

    static func isTaken(treatmentID: UUID, on day: Date, logs: [DoseLog]) -> Bool {
        let key = DayKey.string(from: day)
        return logs.contains { $0.treatmentID == treatmentID && $0.dayKey == key }
    }

    static func toggleTaken(treatment: Treatment, on day: Date, logs: [DoseLog], context: ModelContext) {
        let key = DayKey.string(from: day)
        if let existing = logs.first(where: { $0.treatmentID == treatment.id && $0.dayKey == key }) {
            context.delete(existing)
        } else {
            context.insert(DoseLog(treatmentID: treatment.id, day: day))
        }
        try? context.save()
    }

    /// Deletes every check-in, treatment and dose log on this device.
    static func deleteAll(in context: ModelContext) {
        try? context.delete(model: DayLog.self)
        try? context.delete(model: Treatment.self)
        try? context.delete(model: DoseLog.self)
        try? context.save()
    }

    // MARK: - Export

    struct ExportFile: Codable {
        struct Day: Codable {
            let date: String
            let symptoms: [String: Int]
            let triggers: [String]
            let hotFlashCount: Int?
            let note: String
        }

        struct TreatmentEntry: Codable {
            let name: String
            let kind: String
            let dose: String
            let frequency: String
            let start: String
            let end: String?
            let notes: String
        }

        let app: String
        let exportedAt: Date
        let severityScale: String
        let days: [Day]
        let treatments: [TreatmentEntry]
    }

    /// Writes a JSON export of all data to a temporary file and returns its URL.
    static func exportJSON(logs: [DayLog], treatments: [Treatment]) throws -> URL {
        let file = ExportFile(
            app: "Ebb",
            exportedAt: .now,
            severityScale: "0 = none, 1 = mild, 2 = moderate, 3 = severe",
            days: logs.sorted { $0.day < $1.day }.map {
                ExportFile.Day(date: $0.dayKey, symptoms: $0.symptoms, triggers: $0.triggerIDs, hotFlashCount: $0.hotFlashCount, note: $0.note)
            },
            treatments: treatments.sorted { $0.startDate < $1.startDate }.map {
                ExportFile.TreatmentEntry(
                    name: $0.name,
                    kind: $0.kind.title,
                    dose: $0.dose,
                    frequency: $0.frequency.title,
                    start: DayKey.string(from: $0.startDate),
                    end: $0.endDate.map { DayKey.string(from: $0) },
                    notes: $0.notes
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(file)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Ebb-export-\(DayKey.string(from: .now)).json")
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}
