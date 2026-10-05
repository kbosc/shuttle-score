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

/// Bilan avec ou contre une personne, sur les matchs terminés où elle est nommée.
public struct PlayerRecord: Equatable, Sendable {
    public let name: String
    /// Matchs où elle était mon partenaire.
    public let with: WinLoss
    /// Matchs où elle était mon adversaire.
    public let against: WinLoss

    public init(name: String, with: WinLoss, against: WinLoss) {
        self.name = name
        self.with = with
        self.against = against
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
        for record in records {
            guard record.status == .finished, let winner = record.match.state.winner,
                let matchNames = names[record.match.id]
            else { continue }
            for (role, rawName) in matchNames where role != .me {
                guard let name = PlayerNames.normalized(rawName) else { continue }
                let key = PlayerNames.key(name)
                if spelling[key] == nil { spelling[key] = name }
                var tally =
                    (role.side == .me ? with[key] : against[key]) ?? WinLoss(wins: 0, losses: 0)
                if winner == .me { tally.wins += 1 } else { tally.losses += 1 }
                if role.side == .me { with[key] = tally } else { against[key] = tally }
            }
        }
        let empty = WinLoss(wins: 0, losses: 0)
        return spelling.map { key, name in
            PlayerRecord(name: name, with: with[key] ?? empty, against: against[key] ?? empty)
        }
        .sorted { lhs, rhs in
            let left = lhs.with.wins + lhs.with.losses + lhs.against.wins + lhs.against.losses
            let right = rhs.with.wins + rhs.with.losses + rhs.against.wins + rhs.against.losses
            return left != right
                ? left > right : lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
