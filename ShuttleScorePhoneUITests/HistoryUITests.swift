import XCTest

/// Historique sur l'iPhone, pré-rempli au lancement (`-SeedHistory`) : le plus récent d'abord.
final class HistoryUITests: XCTestCase {
    @MainActor
    func testTheHistoryListsMatchesNewestFirstWithTheirScoreAndStatus() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITests", "-SeedHistory"]
        app.launch()

        let rows = app.descendants(matching: .any).matching(identifier: "history.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(rows.count, 2)

        // Le plus récent : un double interrompu, set 2 entamé.
        let newest = rows.element(boundBy: 0)
        XCTAssertTrue(newest.label.contains("Double"), newest.label)
        XCTAssertTrue(newest.label.contains("15–10 · 3–5"), newest.label)
        XCTAssertTrue(newest.label.contains("Interrompu"), newest.label)

        // Le plus ancien : un simple gagné en deux sets.
        let oldest = rows.element(boundBy: 1)
        XCTAssertTrue(oldest.label.contains("Simple"), oldest.label)
        XCTAssertTrue(oldest.label.contains("15–0 · 15–0"), oldest.label)
        XCTAssertTrue(oldest.label.contains("Gagné"), oldest.label)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Historique iPhone"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testAnEmptyHistoryExplainsWhereMatchesComeFrom() {
        let app = XCUIApplication()
        app.launchArguments = ["-UITests"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Aucun match"].waitForExistence(timeout: 10))
    }
}
