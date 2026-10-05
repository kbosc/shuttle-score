import XCTest

/// Supprimer un match de l'historique (glisser vers la gauche, puis confirmer).
final class DeleteMatchUITests: XCTestCase {
    @MainActor
    private func launchWithSeededHistory() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITests", "-SeedHistory"]
        app.launch()
        return app
    }

    @MainActor
    func testADeletedMatchLeavesTheHistoryAndTheStats() {
        let app = launchWithSeededHistory()
        let rows = app.descendants(matching: .any).matching(identifier: "history.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(rows.count, 2)

        // Le simple gagné est la 2e ligne : on le supprime.
        rows.element(boundBy: 1).swipeLeft()
        app.buttons["history.delete"].tap()
        let confirm = app.buttons["Supprimer le match"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()

        XCTAssertTrue(rows.element(boundBy: 1).waitForNonExistence(timeout: 5))
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows.element(boundBy: 0).label.contains("Interrompu"))

        // Les stats ne comptent plus la victoire supprimée.
        app.buttons["history.stats"].tap()
        XCTAssertTrue(app.staticTexts["stats.wins"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["stats.wins"].label, "0")
    }

    @MainActor
    func testCancellingTheConfirmationKeepsTheMatch() {
        let app = launchWithSeededHistory()
        let rows = app.descendants(matching: .any).matching(identifier: "history.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))

        rows.element(boundBy: 0).swipeLeft()
        app.buttons["history.delete"].tap()
        let confirm = app.buttons["Supprimer le match"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        // iOS 26 n'affiche pas de bouton « Annuler » : on annule en touchant à côté,
        // en bas de l'écran (la bulle s'ouvre en haut).
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))

        XCTAssertEqual(rows.count, 2)
    }
}
