import Foundation
import ShuttleCore
import Testing

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

@Suite struct SavedMatch {
    @Test func aMatchSurvivesASaveAndReloadWithItsState() throws {
        var match = Match(doublesFirstService: ServiceChoice(server: .me, receiver: .opponent1))
        for _ in 0..<15 { match.recordRally(wonBy: .me) }
        match.chooseService(ServiceChoice(server: .partner, receiver: .opponent2))
        match.recordRally(wonBy: .opponent)

        let reloaded = try JSONDecoder().decode(Match.self, from: JSONEncoder().encode(match))
        #expect(reloaded.id == match.id)
        #expect(reloaded.events == match.events)
        #expect(reloaded.state == match.state)
        #expect(reloaded.rules == match.rules)
        #expect(reloaded.format == .doubles)
    }

    @Test func eachRallyIsLoggedWithItsWinnerServerAndTime() {
        var match = Match(firstServer: .me, startedAt: t0)
        match.recordRally(wonBy: .me, at: t0.addingTimeInterval(10))
        match.recordRally(wonBy: .opponent, at: t0.addingTimeInterval(25))
        match.recordRally(wonBy: .opponent, at: t0.addingTimeInterval(40))
        #expect(
            match.rallyRecords == [
                RallyRecord(winner: .me, server: .me, at: t0.addingTimeInterval(10)),
                RallyRecord(winner: .opponent, server: .me, at: t0.addingTimeInterval(25)),
                RallyRecord(winner: .opponent, server: .opponent1, at: t0.addingTimeInterval(40)),
            ])
    }

    @Test func doublesRallyRecordsFollowTheRotationAcrossGames() {
        var match = Match(doublesFirstService: ServiceChoice(server: .me, receiver: .opponent1))
        for _ in 0..<15 { match.recordRally(wonBy: .me) }
        match.chooseService(ServiceChoice(server: .partner, receiver: .opponent2))
        match.recordRally(wonBy: .opponent)
        let records = match.rallyRecords
        #expect(records.count == 16)
        #expect(records.first?.server == .me)
        #expect(records.last?.server == .partner)
    }

    @Test func onlyOfficialMatchesAreRecorded() {
        #expect(ScoringRules.threeByFifteen.isRecorded)
        #expect(!ScoringRules.fivePoints.isRecorded)
    }
}

@MainActor
@Suite struct Recorder {
    private func singles(_ points: [Side], rules: ScoringRules = .threeByFifteen) -> Match {
        var match = Match(rules: rules, firstServer: .me)
        for side in points { match.recordRally(wonBy: side) }
        return match
    }

    @Test func aMatchIsSavedInProgressFromItsFirstPoint() {
        let store = InMemoryStore()
        let recorder = MatchRecorder(store: store)
        let match = singles([.me])
        recorder.matchChanged(match)
        #expect(store.records[match.id]?.status == .inProgress)
        #expect(store.records[match.id]?.match.events == match.events)
    }

    @Test func aMatchWithoutAnyPointIsNotKept() {
        let store = InMemoryStore()
        let recorder = MatchRecorder(store: store)
        var match = singles([.me])
        recorder.matchChanged(match)
        match.undo()
        recorder.matchChanged(match)
        #expect(store.records.isEmpty)
    }

    @Test func aWonMatchIsSavedAsFinishedAndReopenedByUndo() {
        let store = InMemoryStore()
        let recorder = MatchRecorder(store: store)
        var match = singles(Array(repeating: .me, count: 30))
        recorder.matchChanged(match)
        #expect(store.records[match.id]?.status == .finished)
        match.undo()
        recorder.matchChanged(match)
        #expect(store.records[match.id]?.status == .inProgress)
    }

    @Test func stoppingAMatchSavesItAsInterrupted() {
        let store = InMemoryStore()
        let recorder = MatchRecorder(store: store)
        let match = singles([.me, .opponent])
        recorder.matchChanged(match)
        recorder.matchStopped(match)
        #expect(store.records[match.id]?.status == .interrupted)
        #expect(recorder.resumableMatch() == nil)
    }

    @Test func stoppingAMatchWithoutAnyPointKeepsNothing() {
        let store = InMemoryStore()
        let recorder = MatchRecorder(store: store)
        recorder.matchStopped(singles([]))
        #expect(store.records.isEmpty)
    }

    @Test func theMatchInProgressIsOfferedForResume() {
        let store = InMemoryStore()
        let match = singles([.me, .me, .opponent])
        MatchRecorder(store: store).matchChanged(match)
        // Relance de l'app : un nouveau recorder sur le même stockage.
        let resumed = MatchRecorder(store: store).resumableMatch()
        #expect(resumed?.id == match.id)
        #expect(resumed?.state == match.state)
    }

    @Test func aFinishedMatchIsNotOfferedForResume() {
        let store = InMemoryStore()
        MatchRecorder(store: store).matchChanged(singles(Array(repeating: .me, count: 30)))
        #expect(MatchRecorder(store: store).resumableMatch() == nil)
    }

    @Test func fivePointMatchesAreNeverSavedNorResumed() {
        let store = InMemoryStore()
        let recorder = MatchRecorder(store: store)
        let match = singles([.me, .me], rules: .fivePoints)
        recorder.matchChanged(match)
        recorder.matchStopped(match)
        #expect(store.records.isEmpty)
        #expect(recorder.resumableMatch() == nil)
    }

    @Test func aStorageFailureDoesNotStopTheMatch() {
        let store = InMemoryStore()
        store.failsOnSave = true
        let recorder = MatchRecorder(store: store)
        recorder.matchChanged(singles([.me]))
        #expect(store.records.isEmpty)
    }
}
