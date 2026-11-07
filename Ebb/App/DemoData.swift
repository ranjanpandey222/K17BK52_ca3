#if DEBUG
import Foundation
import SwiftData
import EbbCore

/// Realistic sample data for UI tests, screenshots and exploring the app in
/// debug builds. Never included in release builds.
///
/// The data is deterministic and contains real patterns the app should find:
/// alcohol → more hot flashes and night sweats, exercise → less anxiety, and
/// an estrogen patch started 5 weeks ago that reduces vasomotor symptoms.
@MainActor
enum DemoData {
    static func seed(into context: ModelContext, days: Int = 70) {
        var random = SeededRandom(seed: 20261107)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let patchStart = calendar.day(-35, from: today)

        let existingTreatments = (try? context.fetch(FetchDescriptor<Treatment>())) ?? []
        var patch = existingTreatments.first { $0.name == "Estradiol patch" }
        if patch == nil {
            let newPatch = Treatment(name: "Estradiol patch", kind: .estrogenPatch, dose: "50 mcg", frequency: .twiceWeekly, startDate: patchStart)
            newPatch.reminderWeekdays = [1, 4]
            context.insert(newPatch)
            patch = newPatch
            let magnesium = Treatment(name: "Magnesium", kind: .supplement, dose: "200 mg", frequency: .daily, startDate: calendar.day(-200, from: today))
            context.insert(magnesium)
        }

        for offset in stride(from: -(days - 1), through: 0, by: 1) {
            let day = calendar.day(offset, from: today)
            // Skip ~1 in 8 days (but always log today), like a real user.
            if offset != 0 && random.next(8) == 0 { continue }
            if DataRepository.dayLog(for: day, in: context) != nil { continue }

            let patchWorking = day >= calendar.day(14, from: patchStart)
            var triggers: Set<String> = []
            if random.next(100) < 30 { triggers.insert(TriggerCatalog.alcohol) }
            if random.next(100) < 60 { triggers.insert(TriggerCatalog.caffeine) }
            if random.next(100) < 40 { triggers.insert(TriggerCatalog.exercise) }
            if random.next(100) < 25 { triggers.insert(TriggerCatalog.stress) }

            func level(_ base: Int) -> Int { Severity.clamped(base + random.next(3) - 1) }

            let alcohol = triggers.contains(TriggerCatalog.alcohol) ? 1 : 0
            let stress = triggers.contains(TriggerCatalog.stress) ? 1 : 0
            let exercise = triggers.contains(TriggerCatalog.exercise) ? 1 : 0
            let vasomotorBase = patchWorking ? 0 : 2

            var symptoms: [String: Int] = [:]
            symptoms[SymptomCatalog.hotFlashes] = level(vasomotorBase + alcohol * 2)
            symptoms[SymptomCatalog.nightSweats] = level(vasomotorBase + alcohol)
            symptoms[SymptomCatalog.sleepTrouble] = level(1 + alcohol + stress - (patchWorking ? 1 : 0))
            symptoms[SymptomCatalog.fatigue] = level(1 + stress)
            symptoms[SymptomCatalog.moodSwings] = level(1 + stress - exercise)
            symptoms[SymptomCatalog.anxiety] = exercise == 1 ? Severity.clamped(random.next(4) == 0 ? 1 : 0) : level(2 + stress)
            symptoms[SymptomCatalog.brainFog] = level(1)
            symptoms[SymptomCatalog.jointPain] = level(1)
            symptoms[SymptomCatalog.headaches] = level(0 + stress)

            let log = DayLog(day: day)
            log.symptoms = symptoms
            log.triggerIDs = TriggerCatalog.all.map(\.id).filter { triggers.contains($0) }
            if let hot = symptoms[SymptomCatalog.hotFlashes], hot > 0 {
                log.hotFlashCount = hot * 3 + random.next(3)
            }
            if offset == -3 { log.note = "Busy week at work. Woke up twice drenched." }
            context.insert(log)

            // Dose logs for the patch on its change days.
            if day >= patchStart, let patch, patch.isDue(on: day) {
                context.insert(DoseLog(treatmentID: patch.id, day: day))
            }
        }
        try? context.save()
    }
}

/// Small deterministic random generator so sample data looks the same every time.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    /// A number from 0 to upper - 1.
    mutating func next(_ upper: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 33) % UInt64(max(upper, 1)))
    }
}
#endif
