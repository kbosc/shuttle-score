import XCTest

/// Écran Stats, ouvert depuis l'historique.
final class StatsUITests: XCTestCase {
    @MainActor
    func testStatsShowTheRecordAndRatesOfTheSeededMatches() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITests", "-SeedHistory"]
        app.launch()

        let statsButton = app.buttons["history.stats"]
        XCTAssertTrue(statsButton.waitForExistence(timeout: 10))
        statsButton.tap()

        // Historique pré-rempli : un simple gagné, un double interrompu (ne compte pas au bilan).
        XCTAssertTrue(app.staticTexts["stats.wins"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["stats.wins"].label, "1")
        XCTAssertEqual(app.staticTexts["stats.losses"].label, "0")
        XCTAssertTrue(app.staticTexts["stats.serve"].label.hasSuffix("%"))
        XCTAssertTrue(app.staticTexts["stats.receive"].label.hasSuffix("%"))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Stats iPhone"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.swipeUp()
        let bottom = XCTAttachment(screenshot: app.screenshot())
        bottom.name = "Stats iPhone, bas"
        bottom.lifetime = .keepAlways
        add(bottom)
    }

    @MainActor
    func testWithoutMatchesTheStatsScreenSaysSo() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITests"]
        app.launch()
        app.buttons["history.stats"].tap()
        XCTAssertTrue(app.staticTexts["Pas encore de stats"].waitForExistence(timeout: 5))
    }
}
