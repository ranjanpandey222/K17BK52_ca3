import Foundation
import UserNotifications

/// Local reminders only. Nothing is sent from a server.
enum NotificationService {
    private static let dailyCheckInID = "ebb.daily-checkin"
    private static let treatmentPrefix = "ebb.treatment."

    private static var center: UNUserNotificationCenter { .current() }

    /// Asks for permission. Returns true if notifications are allowed.
    @discardableResult
    static func requestPermission() async -> Bool {
        // UI tests can't answer the system prompt.
        if AppEnvironment.isUITesting { return false }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func scheduleDailyCheckIn(hour: Int, minute: Int) async {
        cancelDailyCheckIn()
        let content = UNMutableNotificationContent()
        content.title = "How are you feeling today?"
        content.body = "Your 30-second check-in keeps your patterns accurate."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: dailyCheckInID, content: content, trigger: trigger))
    }

    static func cancelDailyCheckIn() {
        center.removePendingNotificationRequests(withIdentifiers: [dailyCheckInID])
    }

    /// Schedules reminders for a treatment, replacing any existing ones.
    static func scheduleTreatmentReminders(
        id: UUID,
        name: String,
        frequency: TreatmentFrequency,
        weekdays: [Int],
        hour: Int,
        minute: Int
    ) async {
        await cancelTreatmentReminders(id: id)

        let content = UNMutableNotificationContent()
        content.title = "Treatment reminder"
        content.body = frequency == .daily ? "Time for \(name)." : "Time to take or change \(name)."
        content.sound = .default

        var schedules: [DateComponents] = []
        switch frequency {
        case .daily:
            schedules = [DateComponents(hour: hour, minute: minute)]
        case .twiceWeekly, .weekly:
            schedules = weekdays.map { DateComponents(hour: hour, minute: minute, weekday: $0) }
        case .asNeeded:
            schedules = []
        }

        for (index, components) in schedules.enumerated() {
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "\(treatmentPrefix)\(id.uuidString).\(index)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    static func cancelTreatmentReminders(id: UUID) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("\(treatmentPrefix)\(id.uuidString)") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
