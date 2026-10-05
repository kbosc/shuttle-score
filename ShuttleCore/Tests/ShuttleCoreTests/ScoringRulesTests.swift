import ShuttleCore
import Testing

@Test func threeByFifteenMatchesBWFRules() {
    let rules = ScoringRules.threeByFifteen
    #expect(rules.pointsToWinGame == 15)
    #expect(rules.pointCap == 21)
    #expect(rules.gamesToWinMatch == 2)
    #expect(rules.intervalAt == 8)
}

@Test func fivePointsIsASingleSuddenDeathGameWithoutInterval() {
    let rules = ScoringRules.fivePoints
    #expect(rules.pointsToWinGame == 5)
    #expect(rules.pointCap == 5)
    #expect(rules.gamesToWinMatch == 1)
    #expect(rules.intervalAt == nil)
}
