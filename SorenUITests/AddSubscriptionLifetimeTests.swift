import XCTest

final class AddSubscriptionLifetimeTests: XCTestCase {
    @MainActor
    func testBillingDayChangePreservesDraftAndNextPresentationStartsFresh() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        let add = app.buttons["Добавить подписку"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let manual = app.buttons["Добавить вручную"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        manual.tap()

        let title = app.textFields["Название"]
        let amount = app.textFields["Сумма"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Lifetime QA")
        amount.tap()
        amount.typeText("123")

        let nextChargeControls = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Дата списания, ")
        )
        XCTAssertEqual(nextChargeControls.count, 1)
        let nextCharge = nextChargeControls.element
        XCTAssertTrue(nextCharge.waitForExistence(timeout: 5))

        // Derive a different, known civil day in the displayed month, rather
        // than assuming a device clock or hard-coding the default billing day.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("dMMMyyyy")
        let initialLabel = nextCharge.label
        let initialText = String(initialLabel.dropFirst("Дата списания, ".count))
        let initialDate = try XCTUnwrap(formatter.date(from: initialText))
        var chosenComponents = calendar.dateComponents([.year, .month, .day], from: initialDate)
        let chosenDay = chosenComponents.day == 15 ? 16 : 15
        chosenComponents.day = chosenDay
        let chosenDate = try XCTUnwrap(calendar.date(from: chosenComponents))
        let expectedLabel = "Дата списания, " + formatter.string(from: chosenDate)

        nextCharge.tap()
        let done = app.buttons["Готово"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        // Only the active native picker can supply a selectable day. Persisted
        // subscription rows behind the sheets may contain the same date text.
        XCTAssertEqual(app.datePickers.count, 1)
        let dayControls = app.datePickers.element.buttons.matching(
            NSPredicate(format: "label MATCHES %@", ".*, \(chosenDay) .*" )
        )
        XCTAssertEqual(dayControls.count, 1)
        let day = dayControls.element
        XCTAssertTrue(day.waitForExistence(timeout: 5))
        day.tap() // The normal picker flow dismisses after selection.
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))

        XCTAssertEqual(title.value as? String, "Lifetime QA")
        XCTAssertEqual(amount.value as? String, "123")
        XCTAssertEqual(nextCharge.label, expectedLabel)
        XCTAssertNotEqual(nextCharge.label, initialLabel)
        XCTAssertTrue(app.buttons["Сохранить"].isEnabled)

        // Dismiss the unsaved presentation through the native sheet gesture.
        let navigationBar = app.navigationBars["Добавить вручную"]
        navigationBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)
            ))
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        manual.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Название")
        XCTAssertEqual(amount.value as? String, "Сумма")
        XCTAssertFalse(app.buttons["Сохранить"].isEnabled)

        // Leave no saved subscription or unsaved presentation behind.
        navigationBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)
            ))
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))
    }
}
