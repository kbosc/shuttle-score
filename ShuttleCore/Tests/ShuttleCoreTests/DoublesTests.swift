import ShuttleCore
import Testing

/// M = moi, P = partenaire, A1/A2 = adversaires.
private let meServesToOpponent1 = ServiceChoice(server: .me, receiver: .opponent1)

private func doubles(
    _ first: ServiceChoice = meServesToOpponent1, _ points: [Side] = []
) -> Match {
    var match = Match(doublesFirstService: first)
    for side in points { match.recordRally(wonBy: side) }
    return match
}

private func expectService(
    _ state: MatchState, server: Player, court: ServiceCourt, receiver: Player,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(state.server == server, sourceLocation: sourceLocation)
    #expect(state.servingSide == server.side, sourceLocation: sourceLocation)
    #expect(state.serviceCourt == court, sourceLocation: sourceLocation)
    #expect(state.receiver == receiver, sourceLocation: sourceLocation)
}

@Suite struct DoublesSpecExample {
    // SPEC.md, Règles métier, Service en double : M sert, A1 reçoit.
    // M à droite, P à gauche ; A1 à droite, A2 à gauche.

    @Test func start() {
        expectService(doubles().state, server: .me, court: .right, receiver: .opponent1)
    }

    @Test func step1ServingSideWinsSoTheyPermute() {
        // 0-0, M sert depuis la droite et gagne : 1-0, M passe à gauche et ressert.
        let state = doubles(meServesToOpponent1, [.me]).state
        #expect(state.currentGame == GameScore(me: 1, opponent: 0))
        expectService(state, server: .me, court: .left, receiver: .opponent2)
    }

    @Test func step2ReceivingSideWinsNobodyMoves() {
        // 1-0, M sert et perd : 1-1. Score adverse impair : sert le joueur adverse à gauche, A2.
        let state = doubles(meServesToOpponent1, [.me, .opponent]).state
        #expect(state.currentGame == GameScore(me: 1, opponent: 1))
        expectService(state, server: .opponent2, court: .left, receiver: .me)
    }

    @Test func step3() {
        // 1-1, A2 sert et gagne : 1-2. A1 et A2 permutent, A2 sert depuis la droite.
        let state = doubles(meServesToOpponent1, [.me, .opponent, .opponent]).state
        #expect(state.currentGame == GameScore(me: 1, opponent: 2))
        expectService(state, server: .opponent2, court: .right, receiver: .partner)
    }

    @Test func step4() {
        // 1-2, A2 sert et perd : 2-2. Mon score pair : sert le joueur de mon camp à droite, P.
        let state = doubles(meServesToOpponent1, [.me, .opponent, .opponent, .me]).state
        #expect(state.currentGame == GameScore(me: 2, opponent: 2))
        expectService(state, server: .partner, court: .right, receiver: .opponent2)
    }
}

@Suite struct DoublesService {
    @Test func aServerKeepsServingWhileTheirSideWinsAlternatingCourts() {
        var match = doubles()
        let expected: [(ServiceCourt, Player)] = [
            (.left, .opponent2), (.right, .opponent1), (.left, .opponent2),
        ]
        for (court, receiver) in expected {
            match.recordRally(wonBy: .me)
            expectService(match.state, server: .me, court: court, receiver: receiver)
        }
    }

    @Test func theChosenReceiverStartsOnTheRightEvenIfOpponent2() {
        let state = doubles(ServiceChoice(server: .opponent1, receiver: .partner)).state
        expectService(state, server: .opponent1, court: .right, receiver: .partner)
        // L'adversaire perd son service : mon camp à 1 (impair) sert depuis la gauche, c'est moi.
        let after = doubles(ServiceChoice(server: .opponent1, receiver: .partner), [.me]).state
        expectService(after, server: .me, court: .left, receiver: .opponent2)
    }
}

@Suite struct DoublesNextGame {
    private let firstGameToMe = Array(repeating: Side.me, count: 15)

    @Test func theGameWinnerMustChooseTheirServerAndNoPointIsAcceptedMeanwhile() {
        var match = doubles(meServesToOpponent1, firstGameToMe)
        #expect(match.state.awaitingServiceChoice == .me)
        #expect(match.state.server == nil)
        #expect(match.state.servingSide == nil)
        match.recordRally(wonBy: .opponent)
        #expect(match.state.currentGame == GameScore(me: 0, opponent: 0))
    }

    @Test func aValidChoiceStartsTheGameFromTheRight() {
        var match = doubles(meServesToOpponent1, firstGameToMe)
        match.chooseService(ServiceChoice(server: .partner, receiver: .opponent2))
        #expect(match.state.awaitingServiceChoice == nil)
        expectService(match.state, server: .partner, court: .right, receiver: .opponent2)
        match.recordRally(wonBy: .opponent)
        // Adversaire à 1 (impair) : A1 est à gauche (A2 a été choisi à droite).
        expectService(match.state, server: .opponent1, court: .left, receiver: .me)
    }

    @Test func whenTheOpponentsWinTheGameTheyChooseTheirServer() {
        var match = doubles(meServesToOpponent1, Array(repeating: .opponent, count: 15))
        #expect(match.state.awaitingServiceChoice == .opponent)
        match.chooseService(ServiceChoice(server: .me, receiver: .opponent2))
        #expect(match.state.awaitingServiceChoice == .opponent)
        match.chooseService(ServiceChoice(server: .opponent2, receiver: .partner))
        #expect(match.state.awaitingServiceChoice == nil)
        expectService(match.state, server: .opponent2, court: .right, receiver: .partner)
    }

    @Test func theLoserOfTheGameCannotServe() {
        var match = doubles(meServesToOpponent1, firstGameToMe)
        match.chooseService(ServiceChoice(server: .opponent1, receiver: .me))
        #expect(match.state.awaitingServiceChoice == .me)
    }

    @Test func theReceiverMustBeAnOpponentOfTheServer() {
        var match = doubles(meServesToOpponent1, firstGameToMe)
        match.chooseService(ServiceChoice(server: .me, receiver: .partner))
        #expect(match.state.awaitingServiceChoice == .me)
    }

    @Test func aChoiceIsIgnoredWhenNoneIsExpected() {
        var match = doubles()
        match.chooseService(ServiceChoice(server: .partner, receiver: .opponent2))
        #expect(match.events.isEmpty)
        expectService(match.state, server: .me, court: .right, receiver: .opponent1)
    }

    @Test func noChoiceIsAskedOnceTheMatchIsOver() {
        let match = doubles(
            meServesToOpponent1,
            firstGameToMe + Array(repeating: .opponent, count: 15) + firstGameToMe)
        let afterFirst = match.state
        #expect(afterFirst.awaitingServiceChoice == .me)  // le 2e set n'a jamais commencé
        var full = doubles(meServesToOpponent1, firstGameToMe)
        full.chooseService(ServiceChoice(server: .me, receiver: .opponent1))
        for _ in 0..<15 { full.recordRally(wonBy: .me) }
        #expect(full.state.winner == .me)
        #expect(full.state.awaitingServiceChoice == nil)
        #expect(full.state.server == nil)
    }

    @Test func singlesOnlyEverInvolveMeAndOpponent1() {
        var match = Match(firstServer: .me)
        let points: [Side] = [.me, .me, .opponent, .opponent, .me, .opponent, .me, .me]
        for side in points {
            match.recordRally(wonBy: side)
            let state = match.state
            #expect([Player.me, .opponent1].contains(state.server))
            #expect([Player.me, .opponent1].contains(state.receiver))
            #expect(state.server?.side == side)
            #expect(state.receiver?.side == side.opposite)
        }
    }

    @Test func singlesNeverAskForAChoice() {
        var match = Match(firstServer: .me)
        for _ in 0..<15 { match.recordRally(wonBy: .opponent) }
        #expect(match.state.awaitingServiceChoice == nil)
        #expect(match.state.server == .opponent1)
        #expect(match.state.receiver == .me)
    }
}

@Suite struct DoublesUndo {
    private func secondGameAfterOneRally() -> Match {
        var match = doubles(meServesToOpponent1, Array(repeating: .me, count: 15))
        match.chooseService(ServiceChoice(server: .partner, receiver: .opponent2))
        match.recordRally(wonBy: .opponent)
        return match
    }

    @Test func undoingTheFirstRallyOfAGameKeepsTheChosenService() {
        var match = secondGameAfterOneRally()
        match.undo()
        #expect(match.state.currentGame == GameScore(me: 0, opponent: 0))
        expectService(match.state, server: .partner, court: .right, receiver: .opponent2)
    }

    @Test func undoingAgainGoesBackToTheChoice() {
        var match = secondGameAfterOneRally()
        match.undo()
        match.undo()
        #expect(match.state.awaitingServiceChoice == .me)
    }

    @Test func undoingOnceMoreReopensThePreviousGameWithItsRotation() {
        var match = secondGameAfterOneRally()
        match.undo()
        match.undo()
        match.undo()
        #expect(match.state.completedGames.isEmpty)
        #expect(match.state.currentGame == GameScore(me: 14, opponent: 0))
        // M a servi les 14 points en permutant : 14 est pair, M est revenu à droite.
        expectService(match.state, server: .me, court: .right, receiver: .opponent1)
    }

    @Test func theFirstServiceChosenAtSetupCannotBeUndone() {
        var match = doubles()
        match.undo()
        expectService(match.state, server: .me, court: .right, receiver: .opponent1)
    }
}
