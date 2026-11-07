import Foundation
import SwiftUI
import EbbCore

/// Small user preferences, stored in UserDefaults on this device only.
@MainActor
final class ProfileStore: ObservableObject {
    private let defaults: UserDefaults

    @Published var firstName: String { didSet { defaults.set(firstName, forKey: Keys.firstName) } }
    @Published var birthYear: Int? { didSet { defaults.set(birthYear, forKey: Keys.birthYear) } }
    @Published var lastPeriodRaw: String? { didSet { defaults.set(lastPeriodRaw, forKey: Keys.lastPeriod) } }
    @Published var trackedSymptomIDs: [String] { didSet { defaults.set(trackedSymptomIDs, forKey: Keys.tracked) } }
    @Published var onboardingComplete: Bool { didSet { defaults.set(onboardingComplete, forKey: Keys.onboarding) } }
    @Published var dailyReminderEnabled: Bool { didSet { defaults.set(dailyReminderEnabled, forKey: Keys.reminderOn) } }
    @Published var dailyReminderHour: Int { didSet { defaults.set(dailyReminderHour, forKey: Keys.reminderHour) } }
    @Published var dailyReminderMinute: Int { didSet { defaults.set(dailyReminderMinute, forKey: Keys.reminderMinute) } }
    @Published var healthReadEnabled: Bool { didSet { defaults.set(healthReadEnabled, forKey: Keys.healthRead) } }
    @Published var healthWriteEnabled: Bool { didSet { defaults.set(healthWriteEnabled, forKey: Keys.healthWrite) } }
    @Published var appLockEnabled: Bool { didSet { defaults.set(appLockEnabled, forKey: Keys.appLock) } }
    @Published var countHotFlashes: Bool { didSet { defaults.set(countHotFlashes, forKey: Keys.countHotFlashes) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        firstName = defaults.string(forKey: Keys.firstName) ?? ""
        birthYear = defaults.object(forKey: Keys.birthYear) as? Int
        lastPeriodRaw = defaults.string(forKey: Keys.lastPeriod)
        trackedSymptomIDs = SymptomCatalog.normalized(defaults.stringArray(forKey: Keys.tracked) ?? SymptomCatalog.defaultTrackedIDs)
        onboardingComplete = defaults.bool(forKey: Keys.onboarding)
        dailyReminderEnabled = defaults.object(forKey: Keys.reminderOn) as? Bool ?? false
        dailyReminderHour = defaults.object(forKey: Keys.reminderHour) as? Int ?? 20
        dailyReminderMinute = defaults.object(forKey: Keys.reminderMinute) as? Int ?? 0
        healthReadEnabled = defaults.bool(forKey: Keys.healthRead)
        healthWriteEnabled = defaults.bool(forKey: Keys.healthWrite)
        appLockEnabled = defaults.bool(forKey: Keys.appLock)
        countHotFlashes = defaults.object(forKey: Keys.countHotFlashes) as? Bool ?? true
    }

    var lastPeriod: LastPeriodAnswer? {
        get { lastPeriodRaw.flatMap(LastPeriodAnswer.init(rawValue:)) }
        set { lastPeriodRaw = newValue?.rawValue }
    }

    var age: Int? { StageEstimator.age(birthYear: birthYear, today: .now) }

    var stage: StageEstimate { StageEstimator.estimate(lastPeriod: lastPeriod, age: age) }

    var trackedSymptoms: [SymptomDefinition] {
        trackedSymptomIDs.compactMap(SymptomCatalog.definition(for:))
    }

    var reminderTime: Date {
        get {
            Calendar.current.date(bySettingHour: dailyReminderHour, minute: dailyReminderMinute, second: 0, of: .now) ?? .now
        }
        set {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            dailyReminderHour = parts.hour ?? 20
            dailyReminderMinute = parts.minute ?? 0
        }
    }

    /// Clears everything (used by "Delete all my data").
    func reset() {
        for key in Keys.all { defaults.removeObject(forKey: key) }
        firstName = ""
        birthYear = nil
        lastPeriodRaw = nil
        trackedSymptomIDs = SymptomCatalog.defaultTrackedIDs
        dailyReminderEnabled = false
        dailyReminderHour = 20
        dailyReminderMinute = 0
        healthReadEnabled = false
        healthWriteEnabled = false
        appLockEnabled = false
        countHotFlashes = true
        onboardingComplete = false
    }

    private enum Keys {
        static let firstName = "profile.firstName"
        static let birthYear = "profile.birthYear"
        static let lastPeriod = "profile.lastPeriod"
        static let tracked = "profile.trackedSymptoms"
        static let onboarding = "profile.onboardingComplete"
        static let reminderOn = "reminder.enabled"
        static let reminderHour = "reminder.hour"
        static let reminderMinute = "reminder.minute"
        static let healthRead = "health.read"
        static let healthWrite = "health.write"
        static let appLock = "security.appLock"
        static let countHotFlashes = "checkin.countHotFlashes"

        static let all = [
            firstName, birthYear, lastPeriod, tracked, onboarding, reminderOn, reminderHour,
            reminderMinute, healthRead, healthWrite, appLock, countHotFlashes
        ]
    }
}
