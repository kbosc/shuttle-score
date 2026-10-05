import ShuttleCore
import Testing

@Suite struct FivePoints {
    private func play(_ points: [Side], firstServer: Side = .me) -> Match {
        var match = Match(rules: .fivePoints, firstServer: firstServer)
        for side in points { match.recordRally(wonBy: side) }
        return match
    }

    @Test func fiveFourWinsTheMatchWithoutATwoPointLead() {
        let state = play([.me, .opponent, .me, .opponent, .me, .opponent, .me, .opponent, .me])
            .state
        #expect(state.winner == .me)
        #expect(state.completedGames == [GameScore(me: 5, opponent: 4)])
    }

    @Test func fourAllContinues() {
        let state = play([.me, .opponent, .me, .opponent, .me, .opponent, .me, .opponent]).state
        #expect(state.winner == nil)
        #expect(state.currentGame == GameScore(me: 4, opponent: 4))
    }

    @Test func aSingleGameDecidesTheMatch() {
        var match = play(Array(repeating: .opponent, count: 5))
        #expect(match.state.winner == .opponent)
        #expect(match.state.gamesWon(by: .opponent) == 1)
        match.recordRally(wonBy: .me)
        #expect(match.state.completedGames == [GameScore(me: 0, opponent: 5)])
    }

    @Test func serviceAndPositionsFollowTheSinglesRules() {
        // 4-3, l'adversaire vient de marquer : il sert depuis sa gauche (3 impair).
        let state = play([.me, .me, .me, .me, .opponent, .opponent, .opponent]).state
        #expect(state.server == .opponent1)
        #expect(state.serviceCourt == .left)
        #expect(state.player(of: .opponent, in: .left) == .opponent1)
        #expect(state.player(of: .me, in: .left) == .me)
    }
}
