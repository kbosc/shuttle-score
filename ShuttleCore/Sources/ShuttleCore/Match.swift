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

/// Un joueur du match. En simple, seuls `me` et `opponent1` jouent.
public enum Player: Hashable, Sendable, CaseIterable {
    case me
    case partner
    case opponent1
    case opponent2

    public var side: Side {
        switch self {
        case .me, .partner: .me
        case .opponent1, .opponent2: .opponent
        }
    }

    public var teammate: Player {
        switch self {
        case .me: .partner
        case .partner: .me
        case .opponent1: .opponent2
        case .opponent2: .opponent1
        }
    }
}

public enum MatchFormat: Equatable, Sendable {
    case singles
    case doubles
}

/// Qui sert et qui reçoit le premier échange d'un set.
public struct ServiceChoice: Equatable, Sendable {
    public let server: Player
    public let receiver: Player

    public init(server: Player, receiver: Player) {
        self.server = server
        self.receiver = receiver
    }
}

/// Une entrée du journal du match.
public enum MatchEvent: Equatable, Sendable {
    case rally(wonBy: Side)
    /// Choix du service au début d'un set (en double, à partir du 2e set).
    case serviceChoice(ServiceChoice)
}

/// Photographie du match, calculée à partir du journal.
public struct MatchState: Equatable, Sendable {
    public let completedGames: [GameScore]
    public let currentGame: GameScore
    /// Camp au service. `nil` si le match est terminé ou si le service reste à choisir.
    public let servingSide: Side?
    public let server: Player?
    public let receiver: Player?
    public let serviceCourt: ServiceCourt?
    /// En double, au début d'un set : le camp qui doit choisir son serveur
    /// (le gagnant du set précédent). Aucun point n'est accepté tant qu'il est renseigné.
    public let awaitingServiceChoice: Side?
    public let winner: Side?

    public var isOver: Bool { winner != nil }

    public func gamesWon(by side: Side) -> Int {
        completedGames.filter { $0[side] > $0[side.opposite] }.count
    }
}

/// Un match : les réglages de départ plus le journal des événements.
/// L'état n'est jamais stocké, il est recalculé en rejouant le journal.
public struct Match: Sendable {
    public let rules: ScoringRules
    public let format: MatchFormat
    /// Service du premier set, choisi au démarrage. Il ne s'annule pas.
    public let firstService: ServiceChoice
    public private(set) var events: [MatchEvent] = []

    /// Match en simple.
    public init(rules: ScoringRules = .threeByFifteen, firstServer: Side) {
        self.rules = rules
        self.format = .singles
        let server: Player = firstServer == .me ? .me : .opponent1
        self.firstService = ServiceChoice(
            server: server, receiver: server == .me ? .opponent1 : .me)
    }

    /// Match en double. Le serveur et le receveur doivent être dans des camps opposés.
    public init(rules: ScoringRules = .threeByFifteen, doublesFirstService: ServiceChoice) {
        precondition(
            doublesFirstService.server.side != doublesFirstService.receiver.side,
            "Le serveur et le receveur doivent être dans des camps opposés")
        self.rules = rules
        self.format = .doubles
        self.firstService = doublesFirstService
    }

    /// Les gagnants des échanges, dans l'ordre.
    public var rallies: [Side] {
        events.compactMap {
            if case .rally(let side) = $0 { side } else { nil }
        }
    }

    public var state: MatchState {
        var completedGames: [GameScore] = []
        var game = GameScore(me: 0, opponent: 0)
        var rotation: Rotation? = Rotation(firstService, format: format)
        var awaiting: Side?
        var winner: Side?

        for event in events {
            switch event {
            case .serviceChoice(let choice):
                rotation = Rotation(choice, format: format)
                awaiting = nil
            case .rally(let side):
                game[side] += 1
                rotation?.rallyWon(by: side, newScore: game[side])
                guard rules.isGameWon(game, by: side) else { continue }
                completedGames.append(game)
                game = GameScore(me: 0, opponent: 0)
                if completedGames.filter({ $0[side] > $0[side.opposite] }).count
                    == rules.gamesToWinMatch
                {
                    winner = side
                    rotation = nil
                } else if format == .singles {
                    // En simple, le gagnant du set sert le set suivant, sans choix à faire.
                    let server: Player = side == .me ? .me : .opponent1
                    rotation = Rotation(
                        ServiceChoice(server: server, receiver: server.singlesOpponent),
                        format: format)
                } else {
                    rotation = nil
                    awaiting = side
                }
            }
        }

        let service = rotation?.service(score: game)
        return MatchState(
            completedGames: completedGames, currentGame: game, servingSide: service?.server.side,
            server: service?.server, receiver: service?.receiver, serviceCourt: service?.court,
            awaitingServiceChoice: awaiting, winner: winner)
    }

    /// Ignoré si le match est terminé ou si le service du set reste à choisir.
    public mutating func recordRally(wonBy side: Side) {
        let current = state
        guard !current.isOver, current.awaitingServiceChoice == nil else { return }
        events.append(.rally(wonBy: side))
    }

    /// Ignoré si aucun choix n'est attendu, ou si le choix ne respecte pas
    /// le camp attendu au service et un receveur adverse.
    public mutating func chooseService(_ choice: ServiceChoice) {
        guard let side = state.awaitingServiceChoice, choice.server.side == side,
            choice.receiver.side == side.opposite
        else { return }
        events.append(.serviceChoice(choice))
    }

    /// Retire le dernier événement du journal (un échange ou un choix de service).
    /// Sans effet sur un match sans événement.
    public mutating func undo() {
        _ = events.popLast()
    }
}

/// Position des joueurs pendant un set : qui sert, et qui occupe la case droite de chaque camp.
private struct Rotation {
    var server: Player
    var rightCourt: [Side: Player]
    let format: MatchFormat

    init(_ choice: ServiceChoice, format: MatchFormat) {
        self.format = format
        server = choice.server
        // Au premier échange d'un set, le serveur et le receveur choisis sont à droite.
        rightCourt = [choice.server.side: choice.server, choice.receiver.side: choice.receiver]
    }

    mutating func rallyWon(by side: Side, newScore: Int) {
        guard let right = rightCourt[side] else { return }
        if server.side == side {
            // Le camp au service gagne : le même joueur ressert, son camp permute.
            rightCourt[side] = teammate(of: right)
        } else {
            // Le camp à la réception gagne : personne ne bouge, sert le joueur
            // placé dans la case de la parité du score de son camp.
            server = newScore.isMultiple(of: 2) ? right : teammate(of: right)
        }
    }

    /// Serveur, case de service (parité du score du camp au service) et receveur en diagonale.
    func service(score: GameScore) -> (server: Player, court: ServiceCourt, receiver: Player) {
        let court: ServiceCourt = score[server.side].isMultiple(of: 2) ? .right : .left
        let receivingRight = rightCourt[server.side.opposite] ?? server.singlesOpponent
        return (server, court, court == .right ? receivingRight : teammate(of: receivingRight))
    }

    /// En simple, chaque camp n'a qu'un joueur : il couvre les deux cases, personne ne permute.
    private func teammate(of player: Player) -> Player {
        format == .doubles ? player.teammate : player
    }
}

extension Player {
    fileprivate var singlesOpponent: Player { side == .me ? .opponent1 : .me }
}

extension ScoringRules {
    /// Le set est gagné à `pointsToWinGame` avec 2 points d'écart, ou au plafond `pointCap`.
    func isGameWon(_ score: GameScore, by side: Side) -> Bool {
        let points = score[side]
        let lead = points - score[side.opposite]
        return points == pointCap || (points >= pointsToWinGame && lead >= 2)
    }
}
