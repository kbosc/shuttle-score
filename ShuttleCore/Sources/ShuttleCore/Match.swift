/// Un camp du match. En simple, un camp = un joueur.
public enum Side: Equatable, Sendable {
    case me
    case opponent

    public var opposite: Side {
        switch self {
        case .me: .opponent
        case .opponent: .me
        }
    }
}

/// Case de service, vue depuis le joueur qui sert.
public enum ServiceCourt: Equatable, Sendable {
    case right
    case left
}

/// Score d'un set.
public struct GameScore: Equatable, Sendable {
    public var me: Int
    public var opponent: Int

    public init(me: Int, opponent: Int) {
        self.me = me
        self.opponent = opponent
    }

    public subscript(side: Side) -> Int {
        get {
            switch side {
            case .me: me
            case .opponent: opponent
            }
        }
        set {
            switch side {
            case .me: me = newValue
            case .opponent: opponent = newValue
            }
        }
    }
}

/// Photographie du match, calculée à partir du journal des échanges.
public struct MatchState: Equatable, Sendable {
    public let completedGames: [GameScore]
    public let currentGame: GameScore
    /// `nil` une fois le match terminé.
    public let server: Side?
    /// `nil` une fois le match terminé.
    public let serviceCourt: ServiceCourt?
    public let winner: Side?

    public var isOver: Bool { winner != nil }

    public func gamesWon(by side: Side) -> Int {
        completedGames.filter { $0[side] > $0[side.opposite] }.count
    }
}

/// Un match : les réglages de départ plus le journal des gagnants de chaque échange.
/// L'état n'est jamais stocké, il est recalculé en rejouant le journal.
public struct Match: Sendable {
    public let rules: ScoringRules
    public let firstServer: Side
    public private(set) var rallies: [Side] = []

    public init(rules: ScoringRules = .threeByFifteen, firstServer: Side) {
        self.rules = rules
        self.firstServer = firstServer
    }

    public var state: MatchState {
        var completedGames: [GameScore] = []
        var currentGame = GameScore(me: 0, opponent: 0)
        var winner: Side?

        for side in rallies {
            currentGame[side] += 1
            guard rules.isGameWon(currentGame, by: side) else { continue }
            completedGames.append(currentGame)
            currentGame = GameScore(me: 0, opponent: 0)
            if completedGames.filter({ $0[side] > $0[side.opposite] }).count
                == rules.gamesToWinMatch
            {
                winner = side
            }
        }

        if winner != nil {
            return MatchState(
                completedGames: completedGames, currentGame: currentGame, server: nil,
                serviceCourt: nil, winner: winner)
        }
        // En simple, le gagnant du dernier échange sert ; il sert à droite si son score est pair.
        let server = rallies.last ?? firstServer
        return MatchState(
            completedGames: completedGames, currentGame: currentGame, server: server,
            serviceCourt: currentGame[server].isMultiple(of: 2) ? .right : .left, winner: nil)
    }

    /// Ignoré si le match est terminé.
    public mutating func recordRally(wonBy side: Side) {
        guard !state.isOver else { return }
        rallies.append(side)
    }

    /// Retire le dernier échange. Sans effet sur un match sans échange.
    public mutating func undo() {
        _ = rallies.popLast()
    }
}

extension ScoringRules {
    /// Le set est gagné à `pointsToWinGame` avec 2 points d'écart, ou au plafond `pointCap`.
    func isGameWon(_ score: GameScore, by side: Side) -> Bool {
        let points = score[side]
        let lead = points - score[side.opposite]
        return points == pointCap || (points >= pointsToWinGame && lead >= 2)
    }
}
