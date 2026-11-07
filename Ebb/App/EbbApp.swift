import SwiftUI
import SwiftData

@main
struct EbbApp: App {
    @StateObject private var profile = ProfileStore()
    @StateObject private var store = StoreService()
    @StateObject private var health = HealthKitService()
    @StateObject private var appLock = AppLockService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profile)
                .environmentObject(store)
                .environmentObject(health)
                .environmentObject(appLock)
                .tint(Theme.accent)
        }
        .modelContainer(for: [DayLog.self, Treatment.self, DoseLog.self])
    }
}
