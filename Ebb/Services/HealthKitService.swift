import Foundation
import HealthKit
import EbbCore

/// Optional Apple Health connection. Reads last night's sleep and wrist
/// temperature; can also save symptoms to Apple Health. Data read from
/// Health is only shown on this device and never leaves it.
@MainActor
final class HealthKitService: ObservableObject {
    @Published private(set) var lastNightSleepHours: Double?
    /// Last night's wrist temperature minus the average of the previous
    /// nights, in °F. Needs Apple Watch Series 8 or later.
    @Published private(set) var wristTemperatureDeviationF: Double?

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Mapping from Ebb symptom IDs to Apple Health symptom types.
    private static let symptomTypes: [String: HKCategoryTypeIdentifier] = [
        SymptomCatalog.hotFlashes: .hotFlashes,
        SymptomCatalog.nightSweats: .nightSweats,
        SymptomCatalog.sleepTrouble: .sleepChanges,
        SymptomCatalog.fatigue: .fatigue,
        SymptomCatalog.moodSwings: .moodChanges,
        SymptomCatalog.brainFog: .memoryLapse,
        SymptomCatalog.headaches: .headache,
        SymptomCatalog.palpitations: .rapidPoundingOrFlutteringHeartbeat,
        SymptomCatalog.bloating: .bloating,
        SymptomCatalog.drySkin: .drySkin,
        SymptomCatalog.dizziness: .dizziness,
        SymptomCatalog.bladderUrgency: .bladderIncontinence,
        SymptomCatalog.vaginalDryness: .vaginalDryness
    ]

    private var readTypes: Set<HKObjectType> {
        [
            HKCategoryType(.sleepAnalysis),
            HKQuantityType(.appleSleepingWristTemperature)
        ]
    }

    private var shareTypes: Set<HKSampleType> {
        Set(Self.symptomTypes.values.map { HKCategoryType($0) })
    }

    /// Shows Apple's permission sheet. Returns false if Health isn't available
    /// or the request failed. (Apple never reveals whether reading was allowed.)
    func requestAuthorization(includeWrite: Bool) async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: includeWrite ? shareTypes : [], read: readTypes)
            return true
        } catch {
            return false
        }
    }

    func refresh() async {
        guard isAvailable else { return }
        lastNightSleepHours = try? await sleepHours(nightEnding: .now)
        wristTemperatureDeviationF = try? await wristTemperatureDeviation(nightEnding: .now)
    }

    // MARK: - Reading

    /// Hours asleep in the night that ends on `day` (6 pm the day before to noon).
    func sleepHours(nightEnding day: Date) async throws -> Double? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard let start = calendar.date(byAdding: .hour, value: -6, to: dayStart),
              let end = calendar.date(byAdding: .hour, value: 12, to: dayStart) else { return nil }

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(
                type: HKCategoryType(.sleepAnalysis),
                predicate: HKQuery.predicateForSamples(withStart: start, end: end)
            )],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: store)
        let asleepValues = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
        let intervals = samples
            .filter { asleepValues.contains($0.value) }
            .map { DateInterval(start: max($0.startDate, start), end: min($0.endDate, end)) }
        let seconds = Self.mergedDuration(intervals)
        return seconds > 0 ? seconds / 3600 : nil
    }

    /// Sleep data from iPhone and Apple Watch can overlap; merge before adding up.
    static func mergedDuration(_ intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        var total: TimeInterval = 0
        var current: DateInterval?
        for interval in sorted {
            if let existing = current, interval.start <= existing.end {
                current = DateInterval(start: existing.start, end: max(existing.end, interval.end))
            } else {
                if let existing = current { total += existing.duration }
                current = interval
            }
        }
        if let existing = current { total += existing.duration }
        return total
    }

    func wristTemperatureDeviation(nightEnding day: Date) async throws -> Double? {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .hour, value: 12, to: calendar.startOfDay(for: day)) ?? day
        guard let start = calendar.date(byAdding: .day, value: -31, to: end) else { return nil }

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(
                type: HKQuantityType(.appleSleepingWristTemperature),
                predicate: HKQuery.predicateForSamples(withStart: start, end: end)
            )],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
        )
        let samples = try await descriptor.result(for: store)
        guard let latest = samples.first,
              calendar.dateComponents([.hour], from: latest.endDate, to: end).hour ?? 99 <= 24 else { return nil }

        let unit = HKUnit.degreeCelsius()
        let baseline = samples.dropFirst().map { $0.quantity.doubleValue(for: unit) }
        guard baseline.count >= 5 else { return nil }
        let average = baseline.reduce(0, +) / Double(baseline.count)
        let deviationC = latest.quantity.doubleValue(for: unit) - average
        return deviationC * 1.8
    }

    // MARK: - Writing

    /// Replaces the symptoms Ebb saved for this day in Apple Health.
    func saveSymptoms(_ symptoms: [String: Int], day: Date) async {
        guard isAvailable else { return }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

        let datePredicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let ownPredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, ownPredicate])

        var samples: [HKObject] = []
        for (symptomID, identifier) in Self.symptomTypes {
            let type = HKCategoryType(identifier)
            guard store.authorizationStatus(for: type) == .sharingAuthorized else { continue }
            await delete(type: type, predicate: predicate)

            guard let severity = symptoms[symptomID], severity > 0 else { continue }
            let value: HKCategoryValueSeverity
            switch severity {
            case 1: value = .mild
            case 2: value = .moderate
            default: value = .severe
            }
            // Use midday so the sample sits clearly inside the day.
            let moment = calendar.date(byAdding: .hour, value: 12, to: start) ?? start
            samples.append(HKCategorySample(type: type, value: value.rawValue, start: moment, end: moment))
        }

        guard !samples.isEmpty else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.save(samples) { _, _ in continuation.resume() }
        }
    }

    private func delete(type: HKObjectType, predicate: NSPredicate) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.deleteObjects(of: type, predicate: predicate) { _, _, _ in continuation.resume() }
        }
    }
}
