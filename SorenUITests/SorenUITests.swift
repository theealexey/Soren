import XCTest

final class SorenUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // The app uses a custom floating pill instead of a system TabBar.
        // Verify all four navigation buttons exist (accessibility labels set in RootView).
        XCTAssertTrue(app.buttons["Обзор"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Подписки"].exists)
        XCTAssertTrue(app.buttons["Календарь"].exists)
        XCTAssertTrue(app.buttons["Аналитика"].exists)
    }

    @MainActor
    func testTabNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        guard app.buttons["Обзор"].waitForExistence(timeout: 5) else {
            XCTFail("Navigation pill did not appear")
            return
        }

        // Tap each tab and verify the app doesn't crash
        app.buttons["Подписки"].tap()
        app.buttons["Календарь"].tap()
        app.buttons["Аналитика"].tap()
        app.buttons["Обзор"].tap()
    }
}
