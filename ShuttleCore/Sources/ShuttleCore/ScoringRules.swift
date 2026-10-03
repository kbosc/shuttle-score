/// Paramètres de comptage d'un match. Seul le 3×15 est exposé dans l'UI,
/// mais le moteur ne doit dépendre que de ces valeurs (voir SPEC.md).
public struct ScoringRules: Equatable, Sendable {
    public let pointsToWinGame: Int
    public let pointCap: Int
    public let gamesToWinMatch: Int
    public let intervalAt: Int

    public init(pointsToWinGame: Int, pointCap: Int, gamesToWinMatch: Int, intervalAt: Int) {
        self.pointsToWinGame = pointsToWinGame
        self.pointCap = pointCap
        self.gamesToWinMatch = gamesToWinMatch
        self.intervalAt = intervalAt
    }

    /// Format BWF 3×15 : 15 points, 2 d'écart dès 14-14, plafond à 21,
    /// 2 sets gagnants, pause (et changement de côté au 3e set) à 8.
    public static let threeByFifteen = ScoringRules(
        pointsToWinGame: 15,
        pointCap: 21,
        gamesToWinMatch: 2,
        intervalAt: 8
    )
}
