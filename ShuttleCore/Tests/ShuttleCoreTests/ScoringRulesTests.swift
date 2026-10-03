import ShuttleCore
import Testing

@Test func threeByFifteenMatchesBWFRules() {
    let rules = ScoringRules.threeByFifteen
    #expect(rules.pointsToWinGame == 15)
    #expect(rules.pointCap == 21)
    #expect(rules.gamesToWinMatch == 2)
    #expect(rules.intervalAt == 8)
}
