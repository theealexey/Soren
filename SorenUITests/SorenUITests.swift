import XCTest

final class SorenUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify tab bar exists with all 5 tabs (Russian localization)
        XCTAssertTrue(app.tabBars.buttons["Главная"].exists)
        XCTAssertTrue(app.tabBars.buttons["Подписки"].exists)
        XCTAssertTrue(app.tabBars.buttons["Календарь"].exists)
        XCTAssertTrue(app.tabBars.buttons["Аналитика"].exists)
        XCTAssertTrue(app.tabBars.buttons["Настройки"].exists)
    }
}
