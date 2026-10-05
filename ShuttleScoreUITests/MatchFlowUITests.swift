import XCTest

/// Parcours principal : démarrer un match, marquer des points, annuler.
final class MatchFlowUITests: XCTestCase {
    @MainActor
    func testScoringAndUndo() {
        let app = launchApp()

        app.buttons["setup.format.singles"].tap()
        app.buttons["setup.rules.official"].tap()
        app.buttons["setup.firstServer.me"].tap()

        let me = app.buttons["match.half.me"]
        let opponent = app.buttons["match.half.opponent"]
        let myScore = app.staticTexts["match.score.me"]
        let opponentScore = app.staticTexts["match.score.opponent"]

        XCTAssertTrue(me.waitForExistence(timeout: 5))
        // Je sers depuis ma droite ; il reçoit depuis sa droite, qui est à ma gauche.
        expectCourt(app, "me", "screenRight", "Moi", "sert")
        expectCourt(app, "opponent", "screenLeft", "Adversaire", "reçoit")

        me.tap()
        me.tap()
        opponent.tap()
        XCTAssertEqual(myScore.label, "2")
        XCTAssertEqual(opponentScore.label, "1")
        // 2-1 : il sert depuis sa gauche (1 impair), donc à ma droite ; je reçois à ma gauche.
        expectCourt(app, "opponent", "screenRight", "Adversaire", "sert")
        expectCourt(app, "me", "screenLeft", "Moi", "reçoit")
        attachScreenshot(named: "En cours, 2-1", of: app)

        app.buttons["match.undo"].tap()
        XCTAssertEqual(opponentScore.label, "0")
        expectCourt(app, "me", "screenRight", "Moi", "sert")
    }

    /// Le bouton d'annulation doit être une vraie cible de doigt (44 pt, recommandation Apple),
    /// sinon on le rate et on marque un point dans la moitié voisine.
    @MainActor
    func testUndoButtonIsLargeEnoughToHitWithAFinger() {
        let app = launchApp()
        app.buttons["setup.format.singles"].tap()
        app.buttons["setup.rules.official"].tap()
        app.buttons["setup.firstServer.me"].tap()

        let undo = app.buttons["match.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(undo.frame.height, 44)
        XCTAssertGreaterThanOrEqual(undo.frame.width, 60)
    }

    /// En fin de match, les sets gagnés et le score de chaque set restent affichés.
    @MainActor
    func testFinalScoreStaysVisibleAfterTheMatch() {
        let app = launchApp()
        app.buttons["setup.format.singles"].tap()
        app.buttons["setup.rules.official"].tap()
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
        let app = launchApp()
        app.buttons["setup.format.doubles"].tap()
        app.buttons["choice.server.me"].tap()
        app.buttons["choice.receiver.opponent1"].tap()

        let me = app.buttons["match.half.me"]
        let opponent = app.buttons["match.half.opponent"]
        XCTAssertTrue(me.waitForExistence(timeout: 5))
        // Départ : M à ma droite, P à ma gauche ; A1 à sa droite (ma gauche), A2 à ma droite.
        expectCourt(app, "me", "screenRight", "Moi", "sert")
        expectCourt(app, "me", "screenLeft", "Partenaire", "")
        expectCourt(app, "opponent", "screenLeft", "Adv. 1", "reçoit")
        expectCourt(app, "opponent", "screenRight", "Adv. 2", "")

        // Exemple de SPEC.md : M gagne (on permute, M ressert de la gauche)…
        me.tap()
        expectCourt(app, "me", "screenLeft", "Moi", "sert")
        expectCourt(app, "me", "screenRight", "Partenaire", "")
        expectCourt(app, "opponent", "screenRight", "Adv. 2", "reçoit")
        // … puis perd : personne ne bouge, A2 sert de sa gauche (à ma droite), je reçois.
        opponent.tap()
        expectCourt(app, "opponent", "screenRight", "Adv. 2", "sert")
        expectCourt(app, "me", "screenLeft", "Moi", "reçoit")
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
        expectCourt(app, "me", "screenRight", "Partenaire", "sert")
        expectCourt(app, "opponent", "screenLeft", "Adv. 2", "reçoit")
        XCTAssertEqual(app.staticTexts["match.games"].label, "Sets 1 – 0")
    }

    /// Un mauvais choix du premier service se corrige : annuler avant le premier point
    /// ramène au choix du service, dans le même format.
    @MainActor
    func testUndoBeforeTheFirstPointGoesBackToTheFirstServiceChoice() {
        let app = launchApp()
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
        expectCourt(app, "me", "screenRight", "Moi", "sert")
    }

    /// Depuis le choix 3×15 / 5 points du simple, on peut revenir au choix simple ou double.
    @MainActor
    func testSinglesSetupCanGoBackToTheFormatChoice() {
        let app = launchApp()
        app.buttons["setup.format.singles"].tap()
        app.buttons["setup.back"].tap()
        XCTAssertTrue(app.buttons["setup.format.doubles"].waitForExistence(timeout: 5))
    }

    /// Simple en 5 points : un seul set, sec, le score final reste affiché.
    @MainActor
    func testFivePointsSinglesEndsAtFiveFour() {
        let app = launchApp()
        app.buttons["setup.format.singles"].tap()
        app.buttons["setup.rules.fivePoints"].tap()
        // Retour depuis le choix du serveur : on retrouve le choix du format de points.
        app.buttons["setup.back"].tap()
        app.buttons["setup.rules.fivePoints"].tap()
        // Mauvais serveur : annuler avant le premier point ramène au choix du serveur, en 5 points.
        app.buttons["setup.firstServer.opponent"].tap()
        let undo = app.buttons["match.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()
        XCTAssertTrue(app.buttons["setup.firstServer.me"].waitForExistence(timeout: 5))
        app.buttons["setup.firstServer.me"].tap()

        let me = app.buttons["match.half.me"]
        let opponent = app.buttons["match.half.opponent"]
        XCTAssertTrue(me.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["match.games"].label, "5 points")

        for _ in 0..<4 {
            me.tap()
            opponent.tap()
        }
        me.tap()

        XCTAssertEqual(app.staticTexts["match.result"].label, "Gagné")
        // Seul le score reste dans chaque moitié : il devient le libellé de la moitié.
        XCTAssertEqual(me.label, "5")
        XCTAssertEqual(opponent.label, "4")
        attachScreenshot(named: "Fin d'un 5 points", of: app)
    }

    /// Un match en cours survit à la fermeture de l'app : il est proposé à la reprise.
    @MainActor
    func testAMatchInProgressIsOfferedForResumeAfterRelaunch() {
        let app = launchApp()
        startSingles(app, rules: "official")
        let me = app.buttons["match.half.me"]
        XCTAssertTrue(me.waitForExistence(timeout: 5))
        me.tap()
        me.tap()
        app.buttons["match.half.opponent"].tap()

        app.terminate()
        relaunch(app)
        let resume = app.buttons["resume.continue"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        attachScreenshot(named: "Reprise", of: app)
        resume.tap()
        XCTAssertEqual(app.staticTexts["match.score.me"].label, "2")
        XCTAssertEqual(app.staticTexts["match.score.opponent"].label, "1")

        // Refuser la reprise arrête le match : il n'est plus proposé ensuite.
        app.terminate()
        relaunch(app)
        XCTAssertTrue(app.buttons["resume.stop"].waitForExistence(timeout: 5))
        app.buttons["resume.stop"].tap()
        XCTAssertTrue(app.buttons["setup.format.singles"].waitForExistence(timeout: 5))
        app.terminate()
        relaunch(app)
        XCTAssertTrue(app.buttons["setup.format.singles"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["resume.continue"].exists)
    }

    /// Le bouton Arrêter (avec confirmation) termine le match : il n'est pas repris.
    @MainActor
    func testAStoppedMatchIsNotOfferedForResume() {
        let app = launchApp()
        startSingles(app, rules: "official")
        let me = app.buttons["match.half.me"]
        XCTAssertTrue(me.waitForExistence(timeout: 5))
        me.tap()

        app.buttons["match.stop"].tap()
        let confirm = app.buttons["Arrêter le match"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.buttons["setup.format.singles"].waitForExistence(timeout: 5))

        app.terminate()
        relaunch(app)
        XCTAssertTrue(app.buttons["setup.format.singles"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["resume.continue"].exists)
    }

    /// Un 5 points n'est jamais sauvegardé, donc jamais proposé à la reprise.
    @MainActor
    func testAFivePointsMatchIsNeverOfferedForResume() {
        let app = launchApp()
        startSingles(app, rules: "fivePoints")
        let me = app.buttons["match.half.me"]
        XCTAssertTrue(me.waitForExistence(timeout: 5))
        me.tap()
        me.tap()

        app.terminate()
        relaunch(app)
        XCTAssertTrue(app.buttons["setup.format.singles"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["resume.continue"].exists)
    }

    @MainActor
    private func startSingles(_ app: XCUIApplication, rules: String) {
        app.buttons["setup.format.singles"].tap()
        app.buttons["setup.rules.\(rules)"].tap()
        app.buttons["setup.firstServer.me"].tap()
    }

    /// Relance l'app sans effacer les matchs sauvegardés.
    @MainActor
    private func relaunch(_ app: XCUIApplication) {
        app.launchArguments = ["-UITests"]
        app.launch()
    }

    /// Vérifie qui occupe une case, vue depuis ma place, et son rôle (« sert », « reçoit » ou rien).
    @MainActor
    private func expectCourt(
        _ app: XCUIApplication, _ side: String, _ screenPosition: String, _ name: String,
        _ role: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let slot = app.descendants(matching: .any)["match.court.\(side).\(screenPosition)"]
        XCTAssertTrue(slot.waitForExistence(timeout: 2), file: file, line: line)
        XCTAssertEqual(slot.label, name, file: file, line: line)
        XCTAssertEqual(slot.value as? String ?? "", role, file: file, line: line)
    }

    /// Lance l'app avec une séance factice (la demande d'accès HealthKit bloquerait l'écran)
    /// et sans aucun match sauvegardé.
    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITests", "-ResetStore"]
        app.launch()
        return app
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
