import Foundation

/// Noms donnés après coup aux joueurs d'un match, sur l'iPhone (voir SPEC.md, « Noms après coup »).
public enum PlayerNames {
    /// Nom saisi, nettoyé : espaces retirés aux bords ; `nil` s'il est vide.
    public static func normalized(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Clé de comparaison : « Lucas » et « lucas » sont la même personne.
    public static func key(_ name: String) -> String {
        (normalized(name) ?? "").folding(options: .caseInsensitive, locale: nil)
    }

    /// Rôles qu'on peut nommer selon le format (« Moi » ne se nomme jamais).
    public static func nameableRoles(in format: MatchFormat) -> [Player] {
        switch format {
        case .singles: [.opponent1]
        case .doubles: [.partner, .opponent1, .opponent2]
        }
    }
}

/// Qui est Adv. 1, d'après le premier échange du match (convention de SPEC.md, « Joueurs »).
public enum Opponent1Convention: Equatable, Sendable {
    /// Mon camp a servi le premier échange : Adv. 1 l'a reçu.
    case receivedFirstServe
    /// Le camp adverse a servi le premier échange : Adv. 1 l'a servi.
    case servedFirst
}

extension Match {
    public var opponent1Convention: Opponent1Convention {
        firstService.server.side == .me ? .receivedFirstServe : .servedFirst
    }
}

/// Annuaire des noms déjà utilisés, pour les suggestions et l'orthographe de référence.
public struct PlayerDirectory: Sendable {
    /// Orthographe de référence de chaque personne : la première rencontrée.
    private let spellings: [String: String]

    /// `namesByMatch` : dans l'ordre de priorité de l'orthographe (le premier gagne).
    public init(_ namesByMatch: [[Player: String]]) {
        var spellings: [String: String] = [:]
        for names in namesByMatch {
            for role in Player.allCases {
                guard let name = names[role].flatMap(PlayerNames.normalized) else { continue }
                let key = PlayerNames.key(name)
                if spellings[key] == nil { spellings[key] = name }
            }
        }
        self.spellings = spellings
    }

    /// Noms connus commençant par `prefix` (casse ignorée), sans doublon, triés.
    public func suggestions(startingWith prefix: String) -> [String] {
        let start = PlayerNames.key(prefix)
        return spellings.filter { $0.key.hasPrefix(start) }.map(\.value)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Orthographe à enregistrer : celle déjà connue pour la même personne, sinon le nom
    /// nettoyé ; `nil` si le nom est vide.
    public func canonical(_ raw: String) -> String? {
        guard let name = PlayerNames.normalized(raw) else { return nil }
        return spellings[PlayerNames.key(name)] ?? name
    }
}

extension PlayerDirectory {
    /// Annuaire pour modifier les noms du match `editing` : il exclut ce match, pour qu'on
    /// puisse y corriger l'orthographe d'un nom (« lucas » → « Lucas »).
    /// `namesNewestFirst` : noms des matchs, du plus récent au plus ancien.
    public static func forEditing(
        _ editing: UUID, namesNewestFirst: [(matchID: UUID, names: [Player: String])]
    ) -> PlayerDirectory {
        PlayerDirectory(namesNewestFirst.filter { $0.matchID != editing }.map(\.names))
    }
}

/// Noms d'un match prêts à être enregistrés, ou la raison du refus.
public enum NamingResult: Equatable, Sendable {
    case valid([Player: String])
    /// La même personne apparaît à deux rôles du match.
    case duplicate(name: String)
}

extension PlayerDirectory {
    /// Prépare les noms saisis pour un match : nettoyés, orthographe de référence, rôles
    /// non nommables ignorés, doublons refusés.
    public func naming(_ raw: [Player: String], in format: MatchFormat) -> NamingResult {
        var names: [Player: String] = [:]
        var seen: Set<String> = []
        for role in PlayerNames.nameableRoles(in: format) {
            guard let name = raw[role].flatMap(canonical) else { continue }
            guard seen.insert(PlayerNames.key(name)).inserted else {
                return .duplicate(name: name)
            }
            names[role] = name
        }
        return .valid(names)
    }
}

/// Points de mon camp au service et à la réception sur un ensemble de matchs.
public struct PointSplit: Equatable, Sendable {
    public var serve: PointRate
    public var receive: PointRate

    public init(serve: PointRate, receive: PointRate) {
        self.serve = serve
        self.receive = receive
    }

    public static let none = PointSplit(
        serve: PointRate(won: 0, played: 0), receive: PointRate(won: 0, played: 0))
}

/// Bilan avec ou contre une personne : victoires et défaites sur les matchs terminés,
/// points sur les matchs terminés et interrompus où elle est nommée.
public struct PlayerRecord: Equatable, Sendable {
    public let name: String
    /// Matchs où elle était mon partenaire.
    public let with: WinLoss
    /// Matchs où elle était mon adversaire.
    public let against: WinLoss
    /// Points de mon camp quand elle était mon partenaire.
    public let withPoints: PointSplit
    /// Points de mon camp quand elle était mon adversaire.
    public let againstPoints: PointSplit

    public init(
        name: String, with: WinLoss, against: WinLoss, withPoints: PointSplit = .none,
        againstPoints: PointSplit = .none
    ) {
        self.name = name
        self.with = with
        self.against = against
        self.withPoints = withPoints
        self.againstPoints = againstPoints
    }
}

extension MatchStats {
    /// Bilan par personne, du plus de matchs au moins (puis par nom).
    public static func byPlayer(_ records: [MatchRecord], names: [UUID: [Player: String]])
        -> [PlayerRecord]
    {
        var spelling: [String: String] = [:]
        var with: [String: WinLoss] = [:]
        var against: [String: WinLoss] = [:]
        var withPoints: [String: PointSplit] = [:]
        var againstPoints: [String: PointSplit] = [:]
        for record in records {
            guard let matchNames = names[record.match.id] else { continue }
            // Victoires et défaites : matchs terminés ; points : terminés et interrompus.
            let winner = record.status == .finished ? record.match.state.winner : nil
            let points = PointSplit(record.match)
            for (role, rawName) in matchNames where role != .me {
                guard let name = PlayerNames.normalized(rawName) else { continue }
                let key = PlayerNames.key(name)
                if spelling[key] == nil { spelling[key] = name }
                let isPartner = role.side == .me
                if isPartner {
                    withPoints[key, default: .none].add(points)
                } else {
                    againstPoints[key, default: .none].add(points)
                }
                guard let winner else { continue }
                var tally = (isPartner ? with[key] : against[key]) ?? WinLoss(wins: 0, losses: 0)
                if winner == .me { tally.wins += 1 } else { tally.losses += 1 }
                if isPartner { with[key] = tally } else { against[key] = tally }
            }
        }
        let empty = WinLoss(wins: 0, losses: 0)
        return spelling.map { key, name in
            PlayerRecord(
                name: name, with: with[key] ?? empty, against: against[key] ?? empty,
                withPoints: withPoints[key] ?? .none, againstPoints: againstPoints[key] ?? .none)
        }
        // Pas d'entrée sans match terminé ni point joué.
        .filter { $0.finishedMatches > 0 || $0.pointsPlayed > 0 }
        .sorted { lhs, rhs in
            lhs.finishedMatches != rhs.finishedMatches
                ? lhs.finishedMatches > rhs.finishedMatches
                : lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

extension PlayerRecord {
    fileprivate var finishedMatches: Int {
        with.wins + with.losses + against.wins + against.losses
    }

    fileprivate var pointsPlayed: Int {
        withPoints.serve.played + withPoints.receive.played + againstPoints.serve.played
            + againstPoints.receive.played
    }
}

extension PointSplit {
    /// Points de mon camp dans un match, d'après le serveur de chaque échange.
    init(_ match: Match) {
        self = .none
        for rally in match.rallyRecords {
            let won = rally.winner == .me
            if rally.server.side == .me {
                serve.played += 1
                if won { serve.won += 1 }
            } else {
                receive.played += 1
                if won { receive.won += 1 }
            }
        }
    }

    mutating func add(_ other: PointSplit) {
        serve.won += other.serve.won
        serve.played += other.serve.played
        receive.won += other.receive.won
        receive.played += other.receive.played
    }
}
