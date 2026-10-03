import ShuttleCore
import Testing

/// Alterne les points (moi, adversaire, moi, …) puis donne le reste au camp qui en a le plus.
/// Permet d'atteindre un score sans terminer le set en route.
private func rallies(me: Int, opponent: Int) -> [Side] {
    let shared = min(me, opponent)
    var result: [Side] = []
    for _ in 0..<shared { result += [.me, .opponent] }
    result += Array(repeating: .me, count: me - shared)
    result += Array(repeating: .opponent, count: opponent - shared)
    return result
}

private func match(firstServer: Side = .me, _ points: [Side], rules: ScoringRules = .threeByFifteen)
    -> Match
{
    var match = Match(rules: rules, firstServer: firstServer)
    for side in points { match.recordRally(wonBy: side) }
    return match
}

@Suite struct NewMatch {
    @Test func startsAtLoveWithTheChosenServerOnTheRight() {
        let state = Match(firstServer: .opponent).state
        #expect(state.currentGame == GameScore(me: 0, opponent: 0))
        #expect(state.completedGames.isEmpty)
        #expect(state.server == .opponent)
        #expect(state.serviceCourt == .right)
        #expect(state.winner == nil)
    }

    @Test func eachRallyScoresAPointForItsWinnerWhoeverServed() {
        let state = match(firstServer: .me, [.opponent, .opponent, .me]).state
        #expect(state.currentGame == GameScore(me: 1, opponent: 2))
    }
}

@Suite struct GameEnd {
    @Test func fifteenWithATwoPointLeadWinsTheGame() {
        let state = match(rallies(me: 15, opponent: 13)).state
        #expect(state.completedGames == [GameScore(me: 15, opponent: 13)])
        #expect(state.currentGame == GameScore(me: 0, opponent: 0))
        #expect(state.gamesWon(by: .me) == 1)
        #expect(state.gamesWon(by: .opponent) == 0)
    }

    @Test func fifteenFourteenDoesNotEndTheGame() {
        let state = match(rallies(me: 15, opponent: 14)).state
        #expect(state.completedGames.isEmpty)
        #expect(state.currentGame == GameScore(me: 15, opponent: 14))
    }

    @Test func fromFourteenAllATwoPointLeadIsNeeded() {
        let state = match(rallies(me: 14, opponent: 14) + [.opponent, .opponent]).state
        #expect(state.completedGames == [GameScore(me: 14, opponent: 16)])
        #expect(state.gamesWon(by: .opponent) == 1)
    }

    @Test func atTwentyAllTheNextPointWinsBecauseOfTheCap() {
        let state = match(rallies(me: 20, opponent: 20) + [.me]).state
        #expect(state.completedGames == [GameScore(me: 21, opponent: 20)])
    }

    @Test func rulesAreParametersNotHardcodedValues() {
        let threeByTwentyOne = ScoringRules(
            pointsToWinGame: 21, pointCap: 30, gamesToWinMatch: 2, intervalAt: 11)
        let notOver = match(rallies(me: 15, opponent: 13), rules: threeByTwentyOne).state
        #expect(notOver.completedGames.isEmpty)
        let over = match(rallies(me: 21, opponent: 19), rules: threeByTwentyOne).state
        #expect(over.completedGames == [GameScore(me: 21, opponent: 19)])
        let capped = match(rallies(me: 30, opponent: 29), rules: threeByTwentyOne).state
        #expect(capped.completedGames == [GameScore(me: 30, opponent: 29)])
    }
}

@Suite struct MatchEnd {
    @Test func twoGamesToNilWinsTheMatch() {
        let state = match(rallies(me: 15, opponent: 10) + rallies(me: 15, opponent: 12)).state
        #expect(state.winner == .me)
        #expect(state.isOver)
        #expect(state.completedGames.count == 2)
        #expect(state.server == nil)
        #expect(state.serviceCourt == nil)
    }

    @Test func aThirdGameDecidesAtOneGameAll() {
        let points =
            rallies(me: 15, opponent: 10) + rallies(me: 8, opponent: 15)
            + rallies(me: 13, opponent: 15)
        let state = match(points).state
        #expect(state.winner == .opponent)
        #expect(
            state.completedGames == [
                GameScore(me: 15, opponent: 10), GameScore(me: 8, opponent: 15),
                GameScore(me: 13, opponent: 15),
            ])
    }

    @Test func noPointIsAcceptedOnceTheMatchIsOver() {
        var finished = match(rallies(me: 15, opponent: 0) + rallies(me: 15, opponent: 0))
        let before = finished.state
        finished.recordRally(wonBy: .opponent)
        #expect(finished.state == before)
        #expect(finished.rallies.count == 30)
    }
}

@Suite struct SinglesService {
    @Test func theRallyWinnerServesNext() {
        #expect(match(firstServer: .me, [.opponent]).state.server == .opponent)
        #expect(match(firstServer: .opponent, [.opponent, .me]).state.server == .me)
    }

    @Test func serverIsOnTheLeftWhenTheirScoreIsOdd() {
        let state = match(firstServer: .me, [.me]).state
        #expect(state.server == .me)
        #expect(state.serviceCourt == .left)
    }

    @Test func specExampleIWinAtFiveThree() {
        // Moi 5 - 3 Adv, je gagne le point (6-3) : je sers, à droite.
        let state = match(rallies(me: 5, opponent: 3) + [.me]).state
        #expect(state.currentGame == GameScore(me: 6, opponent: 3))
        #expect(state.server == .me)
        #expect(state.serviceCourt == .right)
    }

    @Test func specExampleOpponentWinsAtSixThree() {
        // Moi 6 - 3 Adv, l'adversaire gagne (6-4) : l'adversaire sert, à droite.
        let state = match(rallies(me: 6, opponent: 3) + [.opponent]).state
        #expect(state.currentGame == GameScore(me: 6, opponent: 4))
        #expect(state.server == .opponent)
        #expect(state.serviceCourt == .right)
    }

    @Test func theGameWinnerServesFirstInTheNextGameFromTheRight() {
        let state = match(firstServer: .me, rallies(me: 13, opponent: 15)).state
        #expect(state.currentGame == GameScore(me: 0, opponent: 0))
        #expect(state.server == .opponent)
        #expect(state.serviceCourt == .right)
    }
}

@Suite struct Undo {
    @Test func removesTheLastRally() {
        var m = match(firstServer: .me, [.me, .opponent])
        m.undo()
        #expect(m.state.currentGame == GameScore(me: 1, opponent: 0))
        #expect(m.state.server == .me)
        #expect(m.state.serviceCourt == .left)
    }

    @Test func undoingTheFirstRallyRestoresTheChosenServer() {
        var m = match(firstServer: .opponent, [.me])
        m.undo()
        #expect(m.state == Match(firstServer: .opponent).state)
    }

    @Test func reopensAFinishedGame() {
        var m = match(rallies(me: 15, opponent: 13))
        m.undo()
        #expect(m.state.completedGames.isEmpty)
        #expect(m.state.currentGame == GameScore(me: 14, opponent: 13))
    }

    @Test func reopensAFinishedMatch() {
        var m = match(rallies(me: 15, opponent: 0) + rallies(me: 15, opponent: 0))
        m.undo()
        #expect(m.state.winner == nil)
        #expect(m.state.currentGame == GameScore(me: 14, opponent: 0))
        m.recordRally(wonBy: .opponent)
        #expect(m.state.currentGame == GameScore(me: 14, opponent: 1))
    }

    @Test func doesNothingOnAnEmptyMatch() {
        var m = Match(firstServer: .me)
        m.undo()
        #expect(m.rallies.isEmpty)
        #expect(m.state == Match(firstServer: .me).state)
    }
}
