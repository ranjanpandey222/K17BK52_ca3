import SwiftUI

/// Decides what to show: onboarding → paywall → the app, with an optional lock screen on top.
struct RootView: View {
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var appLock: AppLockService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Group {
                if !profile.onboardingComplete {
                    OnboardingView()
                } else if !store.hasCheckedEntitlements {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.background)
                } else if !store.isPremium {
                    PaywallView()
                } else {
                    MainTabView()
                }
            }
            .animation(.default, value: profile.onboardingComplete)
            .animation(.default, value: store.isPremium)

            if appLock.isLocked && profile.appLockEnabled {
                LockScreen()
                    .transition(.opacity)
            }
        }
        .onAppear {
            if profile.appLockEnabled { appLock.lock() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                if profile.appLockEnabled { appLock.lock() }
            case .active:
                Task { await store.refreshEntitlements() }
            default:
                break
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            HistoryView()
                .tabItem { Label("History", systemImage: "calendar") }
            InsightsView()
                .tabItem { Label("Insights", systemImage: "sparkles") }
            TreatmentsView()
                .tabItem { Label("Treatments", systemImage: "pills") }
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
    }
}

/// Covers the app until Face ID / passcode succeeds.
struct LockScreen: View {
    @EnvironmentObject private var appLock: AppLockService

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            EbbLogo(size: 72)
            Text("Ebb is locked").font(.title2.weight(.semibold)).foregroundStyle(Theme.textPrimary)
            Text("Your health notes are private.").foregroundStyle(Theme.textSecondary)
            Spacer()
            Button("Unlock with \(appLock.biometryName)") {
                Task { await appLock.unlock() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .task { await appLock.unlock() }
    }
}
