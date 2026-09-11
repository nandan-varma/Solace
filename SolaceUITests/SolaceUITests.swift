import XCTest

final class SolaceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingPreferencesTargetAndRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-onboarding"]
        app.launch()
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        next.tap()
        XCTAssertTrue(app.staticTexts["Make it yours."].waitForExistence(timeout: 5))
        if !app.buttons["Peanuts"].isSelected { app.buttons["Peanuts"].tap() }
        next.tap()
        let target = app.textFields["onboarding.target"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        target.tap()
        if let value = target.value as? String, value != "Enter a target" {
            target.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        target.typeText("2100")
        app.buttons["Done"].tap()
        next.tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Custom Target"].exists)
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboarding.continue"].exists)
    }

    @MainActor
    func testTodaySearchFocusesKeyboardOnEveryPresentation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-onboarding"]
        app.launch()
        XCTAssertTrue(app.buttons["Skip setup"].waitForExistence(timeout: 15))
        app.buttons["Skip setup"].tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 10))
        for _ in 0..<2 {
            app.buttons["Search"].tap()
            XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            // Typing without tapping the field proves that focus, not just visibility, is correct.
            app.typeText("  ")
            XCTAssertEqual(app.searchFields.firstMatch.value as? String, "  ")
            app.buttons["Close"].tap()
            XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 5))
        }
    }

    @MainActor
    func testSkipSetupAndManualBarcodeValidation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-onboarding"]
        app.launch()
        let skip = app.buttons["Skip setup"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15))
        skip.tap()
        XCTAssertTrue(app.navigationBars["Today"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Scan"].tap()
        app.buttons["Enter Barcode Manually"].tap()
        let lookup = app.buttons["Look Up"]
        XCTAssertTrue(lookup.waitForExistence(timeout: 5))
        XCTAssertFalse(lookup.isEnabled)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let barcode = app.textFields.firstMatch
        barcode.tap()
        barcode.typeText("123")
        XCTAssertFalse(lookup.isEnabled)
        barcode.typeText("45678")
        XCTAssertTrue(lookup.isEnabled)
        app.buttons["Cancel"].tap()
    }
}
