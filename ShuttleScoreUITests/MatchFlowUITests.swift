import XCTest

/// Parcours principal : démarrer un match, marquer des points, annuler.
final class MatchFlowUITests: XCTestCase {
    @MainActor
    func testScoringAndUndo() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["setup.firstServer.me"].tap()

        let me = app.buttons["match.half.me"]
        let opponent = app.buttons["match.half.opponent"]
        let myScore = app.staticTexts["match.score.me"]
        let opponentScore = app.staticTexts["match.score.opponent"]

        XCTAssertTrue(me.waitForExistence(timeout: 5))
        XCTAssertTrue(me.label.contains("Sert à droite"))

        me.tap()
        me.tap()
        opponent.tap()
        XCTAssertEqual(myScore.label, "2")
        XCTAssertEqual(opponentScore.label, "1")
        XCTAssertTrue(opponent.label.contains("Sert à gauche"))
        attachScreenshot(named: "En cours, 2-1", of: app)

        app.buttons["match.undo"].tap()
        XCTAssertEqual(opponentScore.label, "0")
        XCTAssertTrue(me.label.contains("Sert à droite"))
    }

    /// En fin de match, les sets gagnés et le score de chaque set restent affichés.
    @MainActor
    func testFinalScoreStaysVisibleAfterTheMatch() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["setup.firstServer.me"].tap()

        let me = app.buttons["match.half.me"]
        let opponent = app.buttons["match.half.opponent"]
        XCTAssertTrue(me.waitForExistence(timeout: 5))

        // Set 1 : 15-13. Set 2 : 15-0.
        for _ in 0..<13 {
            me.tap()
            opponent.tap()
        }
        for _ in 0..<2 { me.tap() }
        for _ in 0..<15 { me.tap() }

        XCTAssertEqual(app.staticTexts["match.result"].label, "Gagné")
        XCTAssertEqual(app.staticTexts["match.score.me"].label, "2")
        XCTAssertEqual(app.staticTexts["match.score.opponent"].label, "0")
        XCTAssertTrue(me.label.contains("15 · 15"))
        XCTAssertTrue(opponent.label.contains("13 · 0"))
        attachScreenshot(named: "Fin de match", of: app)
    }

    /// Capture gardée dans le .xcresult, pour relire le rendu sans lancer l'app.
    @MainActor
    private func attachScreenshot(named name: String, of app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
