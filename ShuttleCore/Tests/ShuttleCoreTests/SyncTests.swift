import Foundation
import ShuttleCore
import Testing

@MainActor
private final class FakeSync: MatchSync {
    var sent: [SyncMessage] = []
    func send(_ message: SyncMessage) { sent.append(message) }
}

private func singles(_ points: [Side], rules: ScoringRules = .threeByFifteen) -> Match {
    var match = Match(rules: rules, firstServer: .me)
    for side in points { match.recordRally(wonBy: side) }
    return match
}

@Suite struct SyncMessages {
    @Test func aMessageSurvivesTheTripThroughWatchConnectivity() throws {
        let record = MatchRecord(match: singles([.me, .opponent]), status: .interrupted)
        for message in [SyncMessage.upsert(record), .delete(matchID: record.match.id)] {
            #expect(try SyncMessage.decoded(from: message.encoded()) == message)
        }
    }
}

@MainActor
@Suite struct RecorderSendsToThePhone {
    @Test func aFinishedMatchIsSent() {
        let sync = FakeSync()
        let recorder = MatchRecorder(store: InMemoryStore(), sync: sync)
        let match = singles(Array(repeating: .me, count: 30))
        recorder.matchChanged(match)
        #expect(sync.sent == [.upsert(MatchRecord(match: match, status: .finished))])
    }

    @Test func anInterruptedMatchIsSent() {
        let sync = FakeSync()
        let recorder = MatchRecorder(store: InMemoryStore(), sync: sync)
        let match = singles([.me])
        recorder.matchChanged(match)
        recorder.matchStopped(match)
        #expect(sync.sent == [.upsert(MatchRecord(match: match, status: .interrupted))])
    }

    @Test func aMatchInProgressIsNotSentAtEachPoint() {
        let sync = FakeSync()
        let recorder = MatchRecorder(store: InMemoryStore(), sync: sync)
        recorder.matchChanged(singles([.me]))
        recorder.matchChanged(singles([.me, .opponent]))
        #expect(sync.sent.isEmpty)
    }

    @Test func aMatchWhosePointsAreAllUndoneIsDeletedOnThePhone() {
        let sync = FakeSync()
        let recorder = MatchRecorder(store: InMemoryStore(), sync: sync)
        var match = singles([.me])
        recorder.matchChanged(match)
        match.undo()
        recorder.matchChanged(match)
        #expect(sync.sent == [.delete(matchID: match.id)])
    }

    @Test func fivePointMatchesAreNeverSent() {
        let sync = FakeSync()
        let recorder = MatchRecorder(store: InMemoryStore(), sync: sync)
        let match = singles(Array(repeating: .me, count: 5), rules: .fivePoints)
        recorder.matchChanged(match)
        recorder.matchStopped(match)
        #expect(sync.sent.isEmpty)
    }
}

@MainActor
@Suite struct PhoneReceiver {
    @Test func aReceivedMatchIsStoredAndReplacedByItsLaterVersion() throws {
        let store = InMemoryStore()
        let receiver = MatchSyncReceiver(store: store)
        var match = singles([.me])
        receiver.receive(
            try SyncMessage.upsert(MatchRecord(match: match, status: .interrupted)).encoded())
        match.recordRally(wonBy: .opponent)
        receiver.receive(
            try SyncMessage.upsert(MatchRecord(match: match, status: .interrupted)).encoded())
        #expect(store.records.count == 1)
        #expect(store.records[match.id]?.match.events.count == 2)
    }

    @Test func aDeletionRemovesTheMatch() throws {
        let store = InMemoryStore()
        let receiver = MatchSyncReceiver(store: store)
        let match = singles([.me])
        receiver.receive(
            try SyncMessage.upsert(MatchRecord(match: match, status: .finished)).encoded())
        receiver.receive(try SyncMessage.delete(matchID: match.id).encoded())
        #expect(store.records.isEmpty)
    }

    @Test func anUnreadableMessageIsIgnored() {
        let store = InMemoryStore()
        MatchSyncReceiver(store: store).receive(Data("pas du JSON".utf8))
        #expect(store.records.isEmpty)
    }
}

@Suite struct Summary {
    @Test func aWonMatchShowsEachGame() {
        let match = singles(
            Array(repeating: .me, count: 15) + Array(repeating: .opponent, count: 15)
                + Array(repeating: .me, count: 15))
        let summary = MatchSummary(MatchRecord(match: match, status: .finished))
        #expect(summary.result == .won)
        #expect(
            summary.games == [
                GameScore(me: 15, opponent: 0), GameScore(me: 0, opponent: 15),
                GameScore(me: 15, opponent: 0),
            ])
        #expect(summary.format == .singles)
        #expect(summary.startedAt == match.startedAt)
    }

    @Test func aLostMatchIsLost() {
        let match = singles(Array(repeating: .opponent, count: 30))
        #expect(MatchSummary(MatchRecord(match: match, status: .finished)).result == .lost)
    }

    @Test func anInterruptedMatchShowsTheGameInProgress() {
        let match = singles(Array(repeating: .me, count: 15) + [.opponent, .opponent, .me])
        let summary = MatchSummary(MatchRecord(match: match, status: .interrupted))
        #expect(summary.result == .interrupted)
        #expect(summary.games == [GameScore(me: 15, opponent: 0), GameScore(me: 1, opponent: 2)])
    }

    @Test func anUnstartedGameIsNotShown() {
        let match = singles(Array(repeating: .me, count: 15))
        let summary = MatchSummary(MatchRecord(match: match, status: .interrupted))
        #expect(summary.games == [GameScore(me: 15, opponent: 0)])
    }
}

@Suite struct SummaryIdentity {
    @Test func aSummaryCarriesItsMatchID() {
        let match = Match(firstServer: .me)
        #expect(MatchSummary(MatchRecord(match: match, status: .interrupted)).id == match.id)
    }
}
