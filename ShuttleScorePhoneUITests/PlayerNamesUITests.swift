import XCTest

/// Nommer les joueurs d'un match après coup, depuis l'historique.
final class PlayerNamesUITests: XCTestCase {
    @MainActor
    private func launchWithSeededHistory() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITests", "-SeedHistory"]
        app.launch()
        return app
    }

    @MainActor
    private func rows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "history.row")
    }

    @MainActor
    func testANameIsSavedSuggestedElsewhereAndCountedPerPlayer() {
        let app = launchWithSeededHistory()
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 10))

        // Simple gagné (2e ligne) : l'adversaire s'appelle Lucas.
        rows(app).element(boundBy: 1).tap()
        let opponent = app.textFields["names.field.opponent1"]
        XCTAssertTrue(opponent.waitForExistence(timeout: 5))
        opponent.tap()
        opponent.typeText("Lucas")
        app.buttons["names.save"].tap()
        XCTAssertTrue(rows(app).element(boundBy: 1).waitForExistence(timeout: 5))
        XCTAssertTrue(rows(app).element(boundBy: 1).label.contains("Lucas"))

        // Double interrompu (1re ligne) : la convention est rappelée, et « lu » propose Lucas.
        rows(app).element(boundBy: 0).tap()
        let convention = app.staticTexts["names.convention"]
        XCTAssertTrue(convention.waitForExistence(timeout: 5))
        XCTAssertTrue(convention.label.contains("reçu le premier service"), convention.label)
        let partner = app.textFields["names.field.partner"]
        partner.tap()
        partner.typeText("lu")
        let suggestion = app.buttons["names.suggestion.Lucas"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        suggestion.tap()
        XCTAssertEqual(partner.value as? String, "Lucas")
        app.buttons["names.save"].tap()

        // Bilan par joueur : seul le simple terminé compte (gagné contre Lucas).
        XCTAssertTrue(app.buttons["history.stats"].waitForExistence(timeout: 5))
        app.buttons["history.stats"].tap()
        let lucas = app.descendants(matching: .any)["stats.player.Lucas"]
        if !lucas.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(lucas.waitForExistence(timeout: 5))
        XCTAssertTrue(lucas.label.contains("contre 1 V – 0 D"), lucas.label)
        // Contre Lucas, j'ai servi et gagné les 30 échanges du simple.
        XCTAssertTrue(lucas.label.contains("service 100"), lucas.label)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Stats par joueur"
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testTheSamePersonCannotHoldTwoRolesOfAMatch() {
        let app = launchWithSeededHistory()
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 10))
        rows(app).element(boundBy: 0).tap()

        let first = app.textFields["names.field.opponent1"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        first.typeText("Marc")
        let second = app.textFields["names.field.opponent2"]
        second.tap()
        second.typeText("marc")
        app.buttons["names.save"].tap()

        XCTAssertTrue(app.staticTexts["names.error"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["names.save"].exists)  // on reste sur la fiche
    }
}
