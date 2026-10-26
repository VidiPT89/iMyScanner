import XCTest

/// UI tests against the debug sample library (`-uiTestSampleData`).
/// The store-screenshot tour only runs with `TEST_RUNNER_STORE_SHOTS=1`.
@MainActor
final class iMyScannerUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(language: String = "en") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestSampleData",
            "-app.onboarding.completed", "YES",
            "-app.language.option", language,
            "-fiscal.nif", "234567899",
            "-AppleLanguages", "(\(language))"
        ]
        app.launch()
        return app
    }

    /// Page cells in on-screen reading order (top to bottom, then left to right).
    private func pageOrder(in app: XCUIApplication) -> [String] {
        let cells = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'page.'")).allElementsBoundByIndex
        return cells.sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }.map(\.identifier)
    }

    func testMovingAPageLaterSwapsItWithTheNextOne() {
        let app = launch()
        app.staticTexts["Electricity bill"].tap()
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'page.'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let before = pageOrder(in: app)
        XCTAssertEqual(before.count, 2)

        app.buttons[before[0]].press(forDuration: 1.0)
        XCTAssertFalse(app.buttons["Move Earlier"].exists, "The first page cannot move earlier")
        app.buttons["Move Later"].tap()

        let swapped = expectation(for: NSPredicate { _, _ in self.pageOrder(in: app) == [before[1], before[0]] }, evaluatedWith: nil)
        wait(for: [swapped], timeout: 5)
    }

    func testDeletingADocumentAsksForConfirmation() {
        let app = launch()
        let title = app.staticTexts["Grocery receipt"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))

        title.press(forDuration: 1.0)
        app.buttons["Delete"].tap()
        let question = app.staticTexts["Delete this document?"]
        XCTAssertTrue(question.waitForExistence(timeout: 3))
        // iOS 26 shows the dialog as a popover without a Cancel button; tapping outside dismisses it.
        // On iPad the popover has its own dismiss region.
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        } else if app.otherElements["PopoverDismissRegion"].exists {
            app.otherElements["PopoverDismissRegion"].tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
        XCTAssertTrue(question.waitForNonExistence(timeout: 3))
        XCTAssertTrue(title.exists, "Dismissing the question keeps the document")

        title.press(forDuration: 1.0)
        app.buttons["Delete"].tap()
        XCTAssertTrue(question.waitForExistence(timeout: 3))
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 3))
    }

    func testInvoiceQRCodeIsReadAndChecked() {
        let app = launch()
        app.staticTexts["Electricity bill"].tap()
        let total = app.staticTexts["invoice.total"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(total.label, "€78.93")
        XCTAssertTrue(app.staticTexts["Issued to your NIF: it counts towards your IRS deductions."].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.staticTexts["Grocery receipt"].tap()
        XCTAssertTrue(app.staticTexts["Issued without a NIF (final consumer): it will not count towards your IRS deductions."].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["expenses.open"].tap()
        let yearTotal = app.staticTexts["expenses.total"]
        XCTAssertTrue(yearTotal.waitForExistence(timeout: 5))
        XCTAssertEqual(yearTotal.label, "€122.35", "Electricity + pharmacy + grocery")
        XCTAssertTrue(app.staticTexts["Health"].exists)
    }

    // MARK: - App Store screenshots

    func testStoreScreenshotsEnglish() throws {
        try storeTour(language: "en", document: "Electricity bill", receipt: "Grocery receipt", done: "Done", close: "Close")
    }

    func testStoreScreenshotsPortuguese() throws {
        try storeTour(language: "pt-PT", document: "Fatura da eletricidade", receipt: "Recibo do supermercado", done: "Concluído", close: "Fechar")
    }

    private func storeTour(language: String, document: String, receipt: String, done: String, close: String) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STORE_SHOTS"] == "1", "Set TEST_RUNNER_STORE_SHOTS=1")
        let app = launch(language: language)
        XCTAssertTrue(app.staticTexts[document].waitForExistence(timeout: 5))
        sleep(2) // let thumbnails decode

        app.staticTexts[document].tap()
        XCTAssertTrue(app.staticTexts["invoice.total"].waitForExistence(timeout: 5))
        sleep(2)
        shot("1-invoice", language)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["expenses.open"].tap()
        XCTAssertTrue(app.staticTexts["expenses.total"].waitForExistence(timeout: 5))
        sleep(1)
        shot("2-expenses", language)
        app.buttons[done].firstMatch.tap()

        sleep(1)
        shot("3-library", language)

        app.staticTexts[receipt].tap()
        XCTAssertTrue(app.staticTexts["invoice.total"].waitForExistence(timeout: 5))
        sleep(2)
        shot("4-receipt", language)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.staticTexts[document].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'page.'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["filter.enhance"].waitForExistence(timeout: 5))
        app.buttons["filter.enhance"].tap()
        sleep(2)
        shot("5-editor", language)

        app.buttons["editor.extractText"].tap()
        XCTAssertTrue(app.buttons[close].waitForExistence(timeout: 15))
        sleep(1)
        shot("6-text", language)
    }

    private func shot(_ name: String, _ language: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(language)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
