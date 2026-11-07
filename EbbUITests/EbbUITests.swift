import XCTest
import StoreKitTest

/// End-to-end checks that run the real app in the iOS Simulator, plus
/// screenshots of every main screen (saved as test attachments).
final class EbbUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - New user: onboarding → paywall → first check-in

    func testOnboardingPaywallAndFirstCheckIn() throws {
        // Local StoreKit test environment: real paywall, no real money.
        let storeSession = try SKTestSession(configurationFileNamed: "Ebb")
        storeSession.disableDialogs = true
        storeSession.clearTransactions()

        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        tapButton(app, "Get started")
        attach("01-about-you")
        tapButton(app, "Continue")

        // Last period
        let answer = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "More than 12 months ago")).firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        answer.tap()
        tapButton(app, "Continue")

        // Symptoms (defaults pre-selected)
        attach("02-symptoms")
        tapButton(app, "Continue")

        // Treatment
        tapButton(app, "Skip")

        // Reminder
        tapButton(app, "Continue")

        // Apple Health (shown when available)
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 3) { notNow.tap() }

        // Privacy promise + disclaimer
        let understand = app.switches["I understand"]
        XCTAssertTrue(understand.waitForExistence(timeout: 5))
        understand.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        attach("03-privacy")
        tapButton(app, "Continue")

        // Plan summary
        attach("04-plan")
        tapButton(app, "Continue")

        // Paywall: start the free trial through Apple's subscription view.
        XCTAssertTrue(app.buttons["Skip (debug)"].waitForExistence(timeout: 15), "Paywall did not appear")
        let trialButton = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'free' OR label CONTAINS[c] 'subscribe' OR label CONTAINS[c] 'trial'"
        )).firstMatch
        XCTAssertTrue(trialButton.waitForExistence(timeout: 20), "Subscription products did not load on the paywall")
        sleep(2)
        attach("05-paywall")
        trialButton.tap()

        // Today → first check-in
        tapButton(app, "Check in", timeout: 10)
        let moderate = app.buttons["Moderate"].firstMatch
        XCTAssertTrue(moderate.waitForExistence(timeout: 5))
        moderate.tap()
        attach("06-check-in")
        tapButton(app, "Save check-in")

        XCTAssertTrue(app.staticTexts["Checked in today"].waitForExistence(timeout: 5), "Check-in was not saved")
        attach("07-today-after-check-in")
    }

    // MARK: - Returning user with 10 weeks of data: every main screen

    func testMainScreensWithSampleData() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestDemo"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Checked in today"].waitForExistence(timeout: 15), "Today screen did not load")
        attach("10-today")

        openTab(app, "History")
        XCTAssertTrue(app.staticTexts["This month"].waitForExistence(timeout: 5))
        attach("11-history")

        openTab(app, "Insights")
        XCTAssertTrue(app.staticTexts["Patterns"].waitForExistence(timeout: 10), "Insights did not unlock with sample data")
        sleep(2)
        attach("12-insights")
        app.swipeUp()
        sleep(1)
        attach("13-insights-patterns")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "alcohol")).firstMatch.exists
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Estradiol patch")).firstMatch.exists,
            "Expected the sample data's patterns to be found"
        )

        openTab(app, "Treatments")
        let patch = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Estradiol patch")).firstMatch
        XCTAssertTrue(patch.waitForExistence(timeout: 5))
        attach("14-treatments")
        patch.tap()
        XCTAssertTrue(app.staticTexts["Is it working?"].waitForExistence(timeout: 5))
        attach("15-treatment-detail")

        openTab(app, "More")
        tapButton(app, "Doctor report")
        tapButton(app, "Create PDF report", timeout: 10)
        let share = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Share or print PDF")).firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 15), "PDF was not created")
        attach("16-doctor-report")
        tapButton(app, "Done")

        tapButton(app, "Learn")
        XCTAssertTrue(app.staticTexts["The stages of menopause"].waitForExistence(timeout: 5))
        attach("17-learn")
        app.navigationBars.buttons.firstMatch.tap()

        tapButton(app, "Settings")
        XCTAssertTrue(app.staticTexts["Privacy"].waitForExistence(timeout: 5) || app.otherElements["Privacy"].exists)
        attach("18-settings")

        openTab(app, "Today")
        tapButton(app, "Edit")
        XCTAssertTrue(app.buttons["Save changes"].waitForExistence(timeout: 5))
        attach("19-edit-check-in")
    }

    // MARK: - Helpers

    private func tapButton(_ app: XCUIApplication, _ label: String, timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Button '\(label)' not found", file: file, line: line)
        button.tap()
    }

    private func openTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 3) {
            tab.tap()
        } else {
            app.buttons[name].firstMatch.tap()
        }
    }

    private func attach(_ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
