import Foundation

/// Message envoyé de la montre à l'iPhone. Encodé en JSON pour passer par WatchConnectivity.
public enum SyncMessage: Codable, Equatable, Sendable {
    /// Crée ou remplace le match côté iPhone (même `match.id`).
    case upsert(MatchRecord)
    /// Le match n'existe plus sur la montre (tous ses points annulés).
    case delete(matchID: UUID)

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decoded(from data: Data) throws -> SyncMessage {
        try JSONDecoder().decode(SyncMessage.self, from: data)
    }
}

/// Côté iPhone : applique les messages reçus de la montre au stockage.
/// Un message illisible ou une erreur de stockage est ignoré : la synchro n'est pas critique.
@MainActor
public final class MatchSyncReceiver {
    private let store: any MatchStore

    public init(store: any MatchStore) {
        self.store = store
    }

    public func receive(_ data: Data) {
        guard let message = try? SyncMessage.decoded(from: data) else { return }
        switch message {
        case .upsert(let record):
            try? store.save(record)
        case .delete(let matchID):
            try? store.delete(matchID: matchID)
        }
    }
}

/// Ce que l'historique affiche d'un match.
public struct MatchSummary: Equatable, Sendable {
    public enum Result: Equatable, Sendable {
        case won
        case lost
        case interrupted
    }

    public let startedAt: Date
    public let format: MatchFormat
    /// Score de chaque set joué, y compris le set entamé d'un match interrompu.
    public let games: [GameScore]
    public let result: Result

    public init(_ record: MatchRecord) {
        let state = record.match.state
        startedAt = record.match.startedAt
        format = record.match.format
        // Le set entamé d'un match interrompu compte, pas un set pas encore commencé.
        let current = state.currentGame
        games = state.completedGames + (current.me + current.opponent > 0 ? [current] : [])
        result =
            switch (record.status, state.winner) {
            case (.finished, .me): .won
            case (.finished, .opponent): .lost
            default: .interrupted
            }
    }
}
