import SwiftUI
import StoreKit

/// Shown after onboarding. Uses Apple's built-in subscription UI, which
/// handles prices, the free trial, purchase and legal text.
struct PaywallView: View {
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var profile: ProfileStore

    var body: some View {
        SubscriptionStoreView(productIDs: StoreService.productIDs) {
            marketing
        }
        .subscriptionStoreControlStyle(.picker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStorePolicyDestination(url: AppConfig.privacyPolicyURL, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: AppConfig.termsURL, for: .termsOfService)
        .onInAppPurchaseCompletion { _, _ in
            await store.refreshEntitlements()
        }
        .tint(Theme.accent)
        .background(Theme.background.ignoresSafeArea())
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            Button("Skip (debug)") { store.debugUnlocked = true }
                .font(.caption.weight(.semibold))
                .padding(8)
                .background(.thinMaterial, in: Capsule())
                .padding()
        }
        #endif
    }

    private var marketing: some View {
        VStack(spacing: 18) {
            EbbLogo(size: 72)
                .padding(.top, 24)
            Text(profile.firstName.isEmpty ? "Understand your symptoms.\nGet heard." : "\(profile.firstName), understand your symptoms. Get heard.")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal)
            VStack(alignment: .leading, spacing: 12) {
                benefit("sparkles", "Pattern finder", "See what's linked to your hot flashes, sleep and mood")
                benefit("pills", "Is my treatment working?", "Before-and-after view for HRT and other treatments")
                benefit("doc.text", "Doctor-ready reports", "A clear PDF to bring to every appointment")
                benefit("lock.shield", "Private by design", "Your data stays on your iPhone. No ad trackers.")
            }
            .padding(.horizontal, 24)
            Text("Start with a free week. Cancel anytime in Settings.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.bottom, 8)
    }

    private func benefit(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemImage: icon, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Theme.textPrimary)
                Text(subtitle).font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }
}
