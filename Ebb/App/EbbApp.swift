import SwiftUI
import SwiftData

@main
struct EbbApp: App {
    @StateObject private var profile: ProfileStore
    @StateObject private var store: StoreService
    @StateObject private var health = HealthKitService()
    @StateObject private var appLock = AppLockService()
    private let container: ModelContainer

    init() {
        let container = AppEnvironment.makeContainer()
        let profile = ProfileStore(defaults: AppEnvironment.makeDefaults())
        let store = StoreService()

        #if DEBUG
        if AppEnvironment.loadsDemoData {
            profile.firstName = "Sarah"
            profile.birthYear = Calendar.current.component(.year, from: .now) - 49
            profile.lastPeriod = .threeToTwelveMonths
            profile.onboardingComplete = true
            store.debugUnlocked = true
            DemoData.seed(into: container.mainContext)
        }
        #endif

        self.container = container
        _profile = StateObject(wrappedValue: profile)
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profile)
                .environmentObject(store)
                .environmentObject(health)
                .environmentObject(appLock)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
