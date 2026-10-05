import ShuttleCore
import Testing

/// Alterne moi / adversaire puis donne le reste au camp qui en a le plus.
private func rallies(me: Int, opponent: Int) -> [Side] {
    let shared = min(me, opponent)
    var result: [Side] = []
    for _ in 0..<shared { result += [.me, .opponent] }
    result += Array(repeating: .me, count: me - shared)
    result += Array(repeating: .opponent, count: opponent - shared)
    return result
}

private func play(_ points: [Side], rules: ScoringRules = .threeByFifteen) -> Match {
    var match = Match(rules: rules, firstServer: .me)
    for side in points { match.recordRally(wonBy: side) }
    return match
}

@Suite struct Interval {
    @Test func theFirstSideToReachEightTriggersThePause() {
        #expect(play(rallies(me: 8, opponent: 3)).state.announcement == .interval)
    }

    @Test func itWorksForTheOpponentToo() {
        #expect(play(rallies(me: 7, opponent: 8)).state.announcement == .interval)
    }

    @Test func noAnnouncementBeforeEight() {
        #expect(play(rallies(me: 7, opponent: 7)).state.announcement == nil)
    }

    @Test func theAnnouncementOnlyFollowsTheRallyThatReachedEight() {
        #expect(play(rallies(me: 8, opponent: 3) + [.me]).state.announcement == nil)
    }

    @Test func onlyOncePerGameEvenWhenTheOtherSideReachesEightLater() {
        // 8-7 puis l'adversaire égalise à 8-8 : pas de seconde pause.
        let points = rallies(me: 7, opponent: 7) + [.me, .opponent]
        let state = play(points).state
        #expect(state.currentGame == GameScore(me: 8, opponent: 8))
        #expect(state.announcement == nil)
    }

    @Test func eachGameHasItsOwnPause() {
        let state = play(rallies(me: 15, opponent: 3) + rallies(me: 2, opponent: 8)).state
        #expect(state.completedGames.count == 1)
        #expect(state.announcement == .interval)
    }

    @Test func inTheDecidingGameThePlayersAlsoChangeEnds() {
        let points =
            rallies(me: 15, opponent: 3) + rallies(me: 3, opponent: 15)
            + rallies(me: 8, opponent: 5)
        let state = play(points).state
        #expect(state.completedGames.count == 2)
        #expect(state.announcement == .intervalAndChangeOfEnds)
    }

    @Test func undoRemovesTheAnnouncementAndReachingEightAgainRestoresIt() {
        var match = play(rallies(me: 8, opponent: 3))
        match.undo()
        #expect(match.state.announcement == nil)
        match.recordRally(wonBy: .me)
        #expect(match.state.announcement == .interval)
    }

    @Test func noPauseInFivePoints() {
        for count in 0...4 {
            let state = play(rallies(me: count, opponent: count), rules: .fivePoints).state
            #expect(state.announcement == nil)
        }
    }

    @Test func thePauseScoreComesFromTheRules() {
        let threeByTwentyOne = ScoringRules(
            pointsToWinGame: 21, pointCap: 30, gamesToWinMatch: 2, intervalAt: 11)
        #expect(
            play(rallies(me: 8, opponent: 2), rules: threeByTwentyOne).state.announcement == nil)
        #expect(
            play(rallies(me: 11, opponent: 2), rules: threeByTwentyOne).state.announcement
                == .interval)
    }
}
