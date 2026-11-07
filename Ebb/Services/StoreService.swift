import Foundation
import StoreKit

/// Subscriptions via StoreKit 2. No third-party SDK and no server: Apple
/// verifies purchases on the device.
@MainActor
final class StoreService: ObservableObject {
    /// Must match the product IDs in App Store Connect and in StoreKit/Ebb.storekit.
    static let yearlyID = "ebb.premium.yearly"
    static let monthlyID = "ebb.premium.monthly"
    static let productIDs = [yearlyID, monthlyID]

    @Published private(set) var isPremium = false
    @Published private(set) var hasCheckedEntitlements = false
    @Published private(set) var activeProductID: String?

    #if DEBUG
    /// Lets you explore the app in debug builds without buying. Never in release builds.
    @Published var debugUnlocked = false {
        didSet { updatePremium() }
    }
    #endif

    private var hasActiveSubscription = false
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task { await refreshEntitlements() }
    }

    func refreshEntitlements() async {
        var active = false
        var productID: String?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration < .now { continue }
            active = true
            productID = transaction.productID
        }
        hasActiveSubscription = active
        activeProductID = productID
        hasCheckedEntitlements = true
        updatePremium()
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func updatePremium() {
        #if DEBUG
        isPremium = hasActiveSubscription || debugUnlocked
        #else
        isPremium = hasActiveSubscription
        #endif
    }
}
