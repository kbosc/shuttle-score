import ShuttleCore
import Testing

private func expectPositions(
    _ state: MatchState, myRight: Player?, myLeft: Player?, theirRight: Player?,
    theirLeft: Player?, sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(state.player(of: .me, in: .right) == myRight, sourceLocation: sourceLocation)
    #expect(state.player(of: .me, in: .left) == myLeft, sourceLocation: sourceLocation)
    #expect(state.player(of: .opponent, in: .right) == theirRight, sourceLocation: sourceLocation)
    #expect(state.player(of: .opponent, in: .left) == theirLeft, sourceLocation: sourceLocation)
}

@Suite struct DoublesPositions {
    private func play(_ points: [Side]) -> MatchState {
        var match = Match(doublesFirstService: ServiceChoice(server: .me, receiver: .opponent1))
        for side in points { match.recordRally(wonBy: side) }
        return match.state
    }

    // Exemple de SPEC.md, « Service en double ». Cases vues depuis chaque camp.
    @Test func atStartTheChosenServerAndReceiverAreOnTheRight() {
        expectPositions(
            play([]), myRight: .me, myLeft: .partner, theirRight: .opponent1,
            theirLeft: .opponent2)
    }

    @Test func step1MyTeamPermutes() {
        expectPositions(
            play([.me]), myRight: .partner, myLeft: .me, theirRight: .opponent1,
            theirLeft: .opponent2)
    }

    @Test func step2NobodyMovesWhenTheReceiversWin() {
        expectPositions(
            play([.me, .opponent]), myRight: .partner, myLeft: .me, theirRight: .opponent1,
            theirLeft: .opponent2)
    }

    @Test func step3TheOpponentsPermute() {
        expectPositions(
            play([.me, .opponent, .opponent]), myRight: .partner, myLeft: .me,
            theirRight: .opponent2, theirLeft: .opponent1)
    }

    @Test func step4NobodyMoves() {
        expectPositions(
            play([.me, .opponent, .opponent, .me]), myRight: .partner, myLeft: .me,
            theirRight: .opponent2, theirLeft: .opponent1)
    }
}

@Suite struct SinglesPositions {
    @Test func bothPlayersStandInTheServiceCourt() {
        var match = Match(firstServer: .me)
        expectPositions(
            match.state, myRight: .me, myLeft: nil, theirRight: .opponent1, theirLeft: nil)
        match.recordRally(wonBy: .me)  // 1-0 : je sers à gauche, il reçoit à gauche
        expectPositions(
            match.state, myRight: nil, myLeft: .me, theirRight: nil, theirLeft: .opponent1)
        match.recordRally(wonBy: .opponent)  // 1-1 : il sert à gauche (1 impair)
        expectPositions(
            match.state, myRight: nil, myLeft: .me, theirRight: nil, theirLeft: .opponent1)
        match.recordRally(wonBy: .opponent)  // 1-2 : il sert à droite
        expectPositions(
            match.state, myRight: .me, myLeft: nil, theirRight: .opponent1, theirLeft: nil)
    }
}

@Suite struct PositionsOutsideAGame {
    @Test func noPositionsWhileTheServiceIsToBeChosen() {
        var match = Match(doublesFirstService: ServiceChoice(server: .me, receiver: .opponent1))
        for _ in 0..<15 { match.recordRally(wonBy: .me) }
        #expect(match.state.positions.isEmpty)
    }

    @Test func noPositionsOnceTheMatchIsOver() {
        var match = Match(firstServer: .me)
        for _ in 0..<30 { match.recordRally(wonBy: .me) }
        #expect(match.state.isOver)
        #expect(match.state.positions.isEmpty)
    }
}

@Suite struct SeenFromMyPlace {
    @Test func myLeftIsOnTheLeftOfTheScreen() {
        #expect(Side.me.courtsSeenFromMe == [.left, .right])
    }

    @Test func theOpponentsFaceMeSoTheirLeftIsOnMyRight() {
        #expect(Side.opponent.courtsSeenFromMe == [.right, .left])
    }
}
