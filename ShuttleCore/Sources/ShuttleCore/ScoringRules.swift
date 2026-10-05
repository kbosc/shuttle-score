/// Paramètres de comptage d'un match. L'UI expose le 3×15 et, en simple, le 5 points ;
/// le moteur ne doit dépendre que de ces valeurs (voir SPEC.md).
public struct ScoringRules: Codable, Equatable, Sendable {
    public let pointsToWinGame: Int
    public let pointCap: Int
    public let gamesToWinMatch: Int
    /// Score qui déclenche la pause (et le changement de côté au set décisif). `nil` : pas de pause.
    public let intervalAt: Int?
    /// Les matchs joués avec ces règles sont-ils sauvegardés (historique, stats, reprise) ?
    public let isRecorded: Bool

    public init(
        pointsToWinGame: Int, pointCap: Int, gamesToWinMatch: Int, intervalAt: Int?,
        isRecorded: Bool = true
    ) {
        self.pointsToWinGame = pointsToWinGame
        self.pointCap = pointCap
        self.gamesToWinMatch = gamesToWinMatch
        self.intervalAt = intervalAt
        self.isRecorded = isRecorded
    }

    /// Format BWF 3×15 : 15 points, 2 d'écart dès 14-14, plafond à 21,
    /// 2 sets gagnants, pause (et changement de côté au 3e set) à 8.
    public static let threeByFifteen = ScoringRules(
        pointsToWinGame: 15,
        pointCap: 21,
        gamesToWinMatch: 2,
        intervalAt: 8
    )

    /// Petit simple en attendant d'autres joueurs : un seul set, sec (5-4 gagne), sans pause.
    public static let fivePoints = ScoringRules(
        pointsToWinGame: 5,
        pointCap: 5,
        gamesToWinMatch: 1,
        intervalAt: nil,
        isRecorded: false
    )
}
