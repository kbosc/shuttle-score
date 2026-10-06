import ShuttleCore
import Testing

@Suite struct ActionButton {
    @Test func withoutAMatchThePressOpensTheApp() {
        #expect(ActionButtonEffect.of(nil) == .openApp)
    }

    @Test func duringAMatchThePressScoresForMyTeam() {
        var match = Match(firstServer: .opponent)
        #expect(ActionButtonEffect.of(match) == .scorePointForMyTeam)
        match.recordRally(wonBy: .opponent)
        #expect(ActionButtonEffect.of(match) == .scorePointForMyTeam)
    }

    @Test func aFinishedMatchIgnoresThePress() {
        var match = Match(rules: .fivePoints, firstServer: .me)
        for _ in 0..<5 { match.recordRally(wonBy: .me) }
        #expect(ActionButtonEffect.of(match) == .ignored)
    }

    @Test func thePressIsIgnoredWhileTheServiceIsToBeChosen() {
        var match = Match(doublesFirstService: .firstDoublesService(myTeamServer: .me))
        for _ in 0..<15 { match.recordRally(wonBy: .me) }
        #expect(match.state.awaitingServiceChoice != nil)
        #expect(ActionButtonEffect.of(match) == .ignored)
    }

    @MainActor
    @Test func eachPressIsCounted() {
        let presses = ActionButtonPresses()
        presses.press()
        presses.press()
        #expect(presses.count == 2)
    }
}
