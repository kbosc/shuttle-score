import Foundation

/// Un camp du match. En simple, un camp = un joueur.
public enum Side: String, Codable, Equatable, Sendable {
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
public enum ServiceCourt: String, Codable, Hashable, Sendable {
    case right
    case left
}

extension Side {
    /// Cases du camp dans l'ordre où je les vois, de gauche à droite, depuis ma place.
    /// Les adversaires me font face : leur case droite est à ma gauche.
    public var courtsSeenFromMe: [ServiceCourt] {
        switch self {
        case .me: [.left, .right]
        case .opponent: [.right, .left]
        }
    }
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
public enum Player: String, Codable, Hashable, Sendable, CaseIterable {
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

public enum MatchFormat: String, Codable, Equatable, Sendable {
    case singles
    case doubles
}

/// Qui sert et qui reçoit le premier échange d'un set.
public struct ServiceChoice: Codable, Equatable, Sendable {
    public let server: Player
    public let receiver: Player

    public init(server: Player, receiver: Player) {
        self.server = server
        self.receiver = receiver
    }
}

extension ServiceChoice {
    /// Premier set d'un double, quand mon camp sert : par convention, Adv. 1 est celui
    /// qui reçoit (voir SPEC.md, « Joueurs »).
    public static func firstDoublesService(myTeamServer server: Player) -> ServiceChoice {
        precondition(server.side == .me, "Le serveur doit être de mon camp")
        return ServiceChoice(server: server, receiver: .opponent1)
    }

    /// Premier set d'un double, quand le camp adverse sert : par convention, Adv. 1 est
    /// celui qui sert ; seul le receveur de mon camp est à choisir.
    public static func firstDoublesService(opponentsServeTo receiver: Player) -> ServiceChoice {
        precondition(receiver.side == .me, "Le receveur doit être de mon camp")
        return ServiceChoice(server: .opponent1, receiver: receiver)
    }
}

/// Une entrée du journal du match.
public enum MatchEvent: Codable, Equatable, Sendable {
    case rally(wonBy: Side)
    /// Choix du service au début d'un set (en double, à partir du 2e set).
    case serviceChoice(ServiceChoice)
}

/// Ce que l'app doit annoncer après un échange.
public enum Announcement: Equatable, Sendable {
    /// Un camp atteint le score de pause pour la première fois du set.
    case interval
    /// Même chose au set décisif : la pause s'accompagne d'un changement de côté.
    case intervalAndChangeOfEnds
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
    /// Qui occupe chaque case, vue depuis son propre camp. Vide hors d'un set
    /// (service à choisir, match terminé). En simple, un camp n'occupe qu'une case.
    public let positions: [Side: [ServiceCourt: Player]]
    /// Annonce déclenchée par l'échange qui vient d'être joué, s'il y en a une.
    public let announcement: Announcement?
    public let winner: Side?

    public var isOver: Bool { winner != nil }

    /// Joueur placé dans la case `court` (vue depuis son camp), s'il y en a un.
    public func player(of side: Side, in court: ServiceCourt) -> Player? {
        positions[side]?[court]
    }

    public func gamesWon(by side: Side) -> Int {
        completedGames.filter { $0[side] > $0[side.opposite] }.count
    }
}

/// Un événement du journal et son heure.
public struct LoggedEvent: Codable, Equatable, Sendable {
    public let event: MatchEvent
    public let at: Date
}

/// Un échange tel qu'il est gardé pour les stats : qui l'a gagné, qui servait, et quand.
public struct RallyRecord: Equatable, Sendable {
    public let winner: Side
    public let server: Player
    public let at: Date

    public init(winner: Side, server: Player, at: Date) {
        self.winner = winner
        self.server = server
        self.at = at
    }
}

/// Un match : les réglages de départ plus le journal des événements.
/// L'état n'est jamais stocké, il est recalculé en rejouant le journal.
/// `Codable` : c'est ce qui est sauvegardé sur la montre.
public struct Match: Codable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let rules: ScoringRules
    public let format: MatchFormat
    /// Service du premier set, choisi au démarrage. Il ne s'annule pas.
    public let firstService: ServiceChoice
    public private(set) var log: [LoggedEvent] = []

    /// Les événements du journal, sans leur heure.
    public var events: [MatchEvent] { log.map(\.event) }

    /// Match en simple.
    public init(
        rules: ScoringRules = .threeByFifteen, firstServer: Side, id: UUID = UUID(),
        startedAt: Date = Date()
    ) {
        self.id = id
        self.startedAt = startedAt
        self.rules = rules
        self.format = .singles
        let server: Player = firstServer == .me ? .me : .opponent1
        self.firstService = ServiceChoice(
            server: server, receiver: server == .me ? .opponent1 : .me)
    }

    /// Match en double. Le serveur et le receveur doivent être dans des camps opposés.
    public init(
        rules: ScoringRules = .threeByFifteen, doublesFirstService: ServiceChoice,
        id: UUID = UUID(),
        startedAt: Date = Date()
    ) {
        precondition(
            doublesFirstService.server.side != doublesFirstService.receiver.side,
            "Le serveur et le receveur doivent être dans des camps opposés")
        self.id = id
        self.startedAt = startedAt
        self.rules = rules
        self.format = .doubles
        self.firstService = doublesFirstService
    }

    /// Chaque échange avec son gagnant, son serveur et son heure (journal gardé pour les stats).
    public var rallyRecords: [RallyRecord] {
        // Rejoue le journal pas à pas pour connaître le serveur avant chaque échange.
        var replay = self
        replay.log = []
        var records: [RallyRecord] = []
        for entry in log {
            if case .rally(let winner) = entry.event, let server = replay.state.server {
                records.append(RallyRecord(winner: winner, server: server, at: entry.at))
            }
            replay.log.append(entry)
        }
        return records
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
        var announcement: Announcement?

        for event in events {
            // Une annonce ne concerne que l'échange qui vient d'être joué.
            announcement = nil
            switch event {
            case .serviceChoice(let choice):
                rotation = Rotation(choice, format: format)
                awaiting = nil
            case .rally(let side):
                game[side] += 1
                rotation?.rallyWon(by: side, newScore: game[side])
                // Premier camp du set à atteindre le score de pause (l'autre est encore en dessous).
                if let intervalAt = rules.intervalAt, game[side] == intervalAt,
                    game[side.opposite] < intervalAt
                {
                    let isDecidingGame = completedGames.count == 2 * (rules.gamesToWinMatch - 1)
                    announcement = isDecidingGame ? .intervalAndChangeOfEnds : .interval
                }
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
            awaitingServiceChoice: awaiting, positions: rotation?.positions(score: game) ?? [:],
            announcement: announcement, winner: winner)
    }

    /// Ignoré si le match est terminé ou si le service du set reste à choisir.
    public mutating func recordRally(wonBy side: Side, at date: Date = Date()) {
        let current = state
        guard !current.isOver, current.awaitingServiceChoice == nil else { return }
        log.append(LoggedEvent(event: .rally(wonBy: side), at: date))
    }

    /// Ignoré si aucun choix n'est attendu, ou si le choix ne respecte pas
    /// le camp attendu au service et un receveur adverse.
    public mutating func chooseService(_ choice: ServiceChoice, at date: Date = Date()) {
        guard let side = state.awaitingServiceChoice, choice.server.side == side,
            choice.receiver.side == side.opposite
        else { return }
        log.append(LoggedEvent(event: .serviceChoice(choice), at: date))
    }

    /// Retire le dernier événement du journal (un échange ou un choix de service).
    /// Sans effet sur un match sans événement.
    public mutating func undo() {
        _ = log.popLast()
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

    /// Qui occupe chaque case. En simple, chaque joueur se tient dans la case de service :
    /// le receveur est en diagonale, donc dans la case du même nom vue depuis son camp.
    func positions(score: GameScore) -> [Side: [ServiceCourt: Player]] {
        let (server, court, receiver) = service(score: score)
        if format == .singles {
            return [server.side: [court: server], receiver.side: [court: receiver]]
        }
        return rightCourt.mapValues { [.right: $0, .left: $0.teammate] }
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
