import Foundation
import ShuttleCore
import ShuttleStore
import Testing

@MainActor
@Suite struct SwiftDataMatchStoreTests {
    private func match(points: Int, startedAt: Date = Date()) -> Match {
        var match = Match(firstServer: .me, startedAt: startedAt)
        for _ in 0..<points { match.recordRally(wonBy: .me) }
        return match
    }

    @Test func aSavedMatchInProgressIsReloadedWithItsJournal() throws {
        let store = try SwiftDataMatchStore(inMemory: true)
        let saved = match(points: 3)
        try store.save(MatchRecord(match: saved, status: .inProgress))
        let reloaded = try #require(try store.latestInProgress())
        #expect(reloaded.match.id == saved.id)
        #expect(reloaded.match.log == saved.log)
        #expect(reloaded.status == .inProgress)
    }

    @Test func savingTheSameMatchAgainUpdatesItInsteadOfDuplicating() throws {
        let store = try SwiftDataMatchStore(inMemory: true)
        var played = match(points: 1)
        try store.save(MatchRecord(match: played, status: .inProgress))
        played.recordRally(wonBy: .opponent)
        try store.save(MatchRecord(match: played, status: .inProgress))
        #expect(try store.count() == 1)
        #expect(try store.latestInProgress()?.match.events.count == 2)
    }

    @Test func finishedAndInterruptedMatchesAreNotInProgress() throws {
        let store = try SwiftDataMatchStore(inMemory: true)
        try store.save(MatchRecord(match: match(points: 30), status: .finished))
        try store.save(MatchRecord(match: match(points: 4), status: .interrupted))
        #expect(try store.latestInProgress() == nil)
        #expect(try store.count() == 2)
    }

    @Test func theMostRecentMatchInProgressWins() throws {
        let store = try SwiftDataMatchStore(inMemory: true)
        let older = match(points: 1, startedAt: Date(timeIntervalSince1970: 1_000))
        let newer = match(points: 2, startedAt: Date(timeIntervalSince1970: 2_000))
        try store.save(MatchRecord(match: newer, status: .inProgress))
        try store.save(MatchRecord(match: older, status: .inProgress))
        #expect(try store.latestInProgress()?.match.id == newer.id)
    }

    @Test func deleteRemovesTheMatch() throws {
        let store = try SwiftDataMatchStore(inMemory: true)
        let saved = match(points: 1)
        try store.save(MatchRecord(match: saved, status: .inProgress))
        try store.delete(matchID: saved.id)
        #expect(try store.count() == 0)
    }

    @Test func matchesSurviveARelaunchOfTheApp() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shuttle-\(UUID().uuidString).store")
        let saved = match(points: 5)
        try SwiftDataMatchStore(url: url).save(MatchRecord(match: saved, status: .inProgress))
        // Nouveau stockage sur le même fichier : comme au relancement de l'app.
        let reloaded = try SwiftDataMatchStore(url: url).latestInProgress()
        #expect(reloaded?.match.id == saved.id)
        #expect(reloaded?.match.state == saved.state)
    }

    @Test func theHistoryListsFinishedAndInterruptedMatchesNewestFirst() throws {
        let store = try SwiftDataMatchStore(inMemory: true)
        let oldest = match(points: 30, startedAt: Date(timeIntervalSince1970: 1_000))
        let newest = match(points: 4, startedAt: Date(timeIntervalSince1970: 3_000))
        let inProgress = match(points: 2, startedAt: Date(timeIntervalSince1970: 4_000))
        try store.save(MatchRecord(match: oldest, status: .finished))
        try store.save(MatchRecord(match: newest, status: .interrupted))
        try store.save(MatchRecord(match: inProgress, status: .inProgress))
        let history = try store.history()
        #expect(history.map(\.match.id) == [newest.id, oldest.id])
        #expect(history.map(\.status) == [.interrupted, .finished])
    }
}
