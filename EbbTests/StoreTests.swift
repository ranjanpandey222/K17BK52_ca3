import XCTest
import StoreKit
import StoreKitTest
@testable import Ebb

/// Verifies the subscription setup end to end with Apple's local StoreKit
/// test environment: the configuration file loads, the product IDs match the
/// app, the free trial is set up, a purchase succeeds, and the app unlocks.
@MainActor
final class StoreTests: XCTestCase {
    private var session: SKTestSession!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "Ebb")
        session.disableDialogs = true
        session.clearTransactions()
    }

    override func tearDown() async throws {
        session?.clearTransactions()
        session = nil
    }

    func testProductsMatchTheApp() async throws {
        let products = try await Product.products(for: StoreService.productIDs)
        XCTAssertEqual(Set(products.map(\.id)), Set(StoreService.productIDs), "StoreKit configuration and StoreService product IDs differ")

        let yearly = try XCTUnwrap(products.first { $0.id == StoreService.yearlyID })
        let monthly = try XCTUnwrap(products.first { $0.id == StoreService.monthlyID })

        XCTAssertEqual(yearly.type, .autoRenewable)
        XCTAssertEqual(yearly.subscription?.subscriptionPeriod.unit, .year)
        XCTAssertEqual(monthly.subscription?.subscriptionPeriod.unit, .month)
        XCTAssertEqual(yearly.price, Decimal(string: "59.99"))
        XCTAssertEqual(monthly.price, Decimal(string: "9.99"))
        XCTAssertEqual(yearly.subscription?.subscriptionGroupID, monthly.subscription?.subscriptionGroupID, "Both plans must be in the same group")

        let trial = try XCTUnwrap(yearly.subscription?.introductoryOffer, "Yearly plan has no free trial")
        XCTAssertEqual(trial.paymentMode, .freeTrial)
        XCTAssertEqual(trial.period.unit, .week)
        XCTAssertEqual(trial.period.value, 1)
    }

    func testPurchaseUnlocksPremium() async throws {
        let store = StoreService()
        await store.refreshEntitlements()
        #if DEBUG
        store.debugUnlocked = false
        #endif
        XCTAssertFalse(store.isPremium)

        let yearlyProducts = try await Product.products(for: [StoreService.yearlyID])
        let yearly = try XCTUnwrap(yearlyProducts.first)
        let result = try await yearly.purchase()
        guard case .success(let verification) = result, case .verified(let transaction) = verification else {
            return XCTFail("Purchase did not succeed: \(result)")
        }
        await transaction.finish()

        await store.refreshEntitlements()
        XCTAssertTrue(store.isPremium, "Premium was not unlocked after purchase")
        XCTAssertEqual(store.activeProductID, StoreService.yearlyID)
    }

    func testExpiredSubscriptionLocksAgain() async throws {
        let store = StoreService()
        let monthlyProducts = try await Product.products(for: [StoreService.monthlyID])
        let monthly = try XCTUnwrap(monthlyProducts.first)
        let result = try await monthly.purchase()
        guard case .success(let verification) = result, case .verified(let transaction) = verification else {
            return XCTFail("Purchase did not succeed")
        }
        await transaction.finish()
        await store.refreshEntitlements()
        XCTAssertTrue(store.isPremium)

        try session.expireSubscription(productIdentifier: StoreService.monthlyID)
        await store.refreshEntitlements()
        #if DEBUG
        store.debugUnlocked = false
        #endif
        XCTAssertFalse(store.isPremium, "Expired subscription should lock the app")
    }
}
