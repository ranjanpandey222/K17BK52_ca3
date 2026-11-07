import Foundation
import SwiftData

/// Launch-time configuration: normal use vs. automated UI tests.
enum AppEnvironment {
    private static let arguments = ProcessInfo.processInfo.arguments

    /// Set by UI tests. Uses a throwaway in-memory database and separate settings,
    /// and skips system permission prompts.
    static let isUITesting = arguments.contains("-uiTesting")

    /// Start already onboarded and unlocked, with sample data (debug builds only).
    static let loadsDemoData = isUITesting && arguments.contains("-uiTestDemo")

    static func makeDefaults() -> UserDefaults {
        guard isUITesting, let defaults = UserDefaults(suiteName: "ebb.uitest") else { return .standard }
        defaults.removePersistentDomain(forName: "ebb.uitest")
        return defaults
    }

    @MainActor
    static func makeContainer() -> ModelContainer {
        let schema = Schema([DayLog.self, Treatment.self, DoseLog.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }
        // Last resort so the app still opens instead of crashing. Data won't persist in this state.
        let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [fallback])
        } catch {
            fatalError("Unable to create the data store: \(error)")
        }
    }
}
