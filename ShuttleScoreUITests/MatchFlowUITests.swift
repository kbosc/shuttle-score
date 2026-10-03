import XCTest

/// Parcours principal : démarrer un match, marquer des points, annuler.
final class MatchFlowUITests: XCTestCase {
    @MainActor
    func testScoringAndUndo() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["setup.format.singles"].tap()
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

    /// Le bouton d'annulation doit être une vraie cible de doigt (44 pt, recommandation Apple),
    /// sinon on le rate et on marque un point dans la moitié voisine.
    @MainActor
    func testUndoButtonIsLargeEnoughToHitWithAFinger() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["setup.format.singles"].tap()
        app.buttons["setup.firstServer.me"].tap()

        let undo = app.buttons["match.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(undo.frame.height, 44)
        XCTAssertGreaterThanOrEqual(undo.frame.width, 60)
    }

    /// En fin de match, les sets gagnés et le score de chaque set restent affichés.
    @MainActor
    func testFinalScoreStaysVisibleAfterTheMatch() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["setup.format.singles"].tap()
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

    /// Double : choix du service au set 1, rotation, puis nouveau choix au set 2.
    @MainActor
    func testDoublesServiceRotationAndNextGameChoice() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["setup.format.doubles"].tap()
        app.buttons["choice.server.me"].tap()
        app.buttons["choice.receiver.opponent1"].tap()

        let me = app.buttons["match.half.me"]
        let opponent = app.buttons["match.half.opponent"]
        XCTAssertTrue(me.waitForExistence(timeout: 5))
        XCTAssertTrue(me.label.contains("Moi"))
        XCTAssertTrue(me.label.contains("Sert à droite"))

        // Exemple de SPEC.md : M gagne (M ressert à gauche), puis perd (A2 sert à gauche).
        me.tap()
        XCTAssertTrue(me.label.contains("Sert à gauche"))
        opponent.tap()
        XCTAssertTrue(opponent.label.contains("Adv. 2"))
        XCTAssertTrue(opponent.label.contains("Sert à gauche"))
        attachScreenshot(named: "Double, A2 sert", of: app)

        // Je gagne le set 1 (15-1) : le set 2 demande mon serveur.
        for _ in 0..<14 { me.tap() }
        let partner = app.buttons["choice.server.partner"]
        XCTAssertTrue(partner.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["choice.server.opponent1"].exists)
        attachScreenshot(named: "Choix du service, set 2", of: app)

        // Un tap raté a pu finir le set : on peut encore l'annuler depuis le choix.
        app.buttons["choice.undo"].tap()
        XCTAssertEqual(app.staticTexts["match.score.me"].label, "14")
        me.tap()

        partner.tap()
        app.buttons["choice.receiver.opponent2"].tap()
        XCTAssertTrue(me.waitForExistence(timeout: 5))
        XCTAssertTrue(me.label.contains("Partenaire"))
        XCTAssertTrue(me.label.contains("Sert à droite"))
        XCTAssertEqual(app.staticTexts["match.games"].label, "Sets 1 – 0")
    }

    /// Un mauvais choix du premier service se corrige : annuler avant le premier point
    /// ramène au choix du service, dans le même format.
    @MainActor
    func testUndoBeforeTheFirstPointGoesBackToTheFirstServiceChoice() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["setup.format.doubles"].tap()
        app.buttons["choice.server.opponent1"].tap()
        app.buttons["choice.receiver.me"].tap()

        let undo = app.buttons["match.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        XCTAssertTrue(app.buttons["choice.server.me"].waitForExistence(timeout: 5))

        app.buttons["choice.server.me"].tap()
        app.buttons["choice.receiver.opponent1"].tap()
        XCTAssertTrue(app.buttons["match.half.me"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["match.half.me"].label.contains("Moi"))
        XCTAssertTrue(app.buttons["match.half.me"].label.contains("Sert à droite"))
    }

    /// Depuis le choix du serveur en simple, on peut revenir au choix simple ou double.
    @MainActor
    func testSinglesSetupCanGoBackToTheFormatChoice() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["setup.format.singles"].tap()
        app.buttons["setup.back"].tap()
        XCTAssertTrue(app.buttons["setup.format.doubles"].waitForExistence(timeout: 5))
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
