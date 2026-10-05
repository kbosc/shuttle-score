import Foundation

public enum MatchStatus: String, Codable, Sendable {
    case inProgress
    case finished
    case interrupted
}

/// Un match tel qu'il est sauvegardé : le match lui-même et son statut.
public struct MatchRecord: Sendable {
    public let match: Match
    public let status: MatchStatus

    public init(match: Match, status: MatchStatus) {
        self.match = match
        self.status = status
    }
}

/// Où les matchs sont sauvegardés (SwiftData dans l'app, en mémoire dans les tests).
@MainActor
public protocol MatchStore: AnyObject {
    /// Crée ou remplace l'enregistrement du match (même `match.id`).
    func save(_ record: MatchRecord) throws
    func delete(matchID: UUID) throws
    /// Le match en cours le plus récent, s'il y en a un.
    func latestInProgress() throws -> MatchRecord?
}

/// Décide quoi sauvegarder et quand. Une erreur de sauvegarde n'empêche jamais de jouer.
@MainActor
public final class MatchRecorder {
    private let store: any MatchStore

    public init(store: any MatchStore) {
        self.store = store
    }

    /// À appeler après chaque changement du match (point, annulation, choix du service).
    public func matchChanged(_ match: Match) {
        record(match, as: match.state.isOver ? .finished : .inProgress)
    }

    /// Le match est arrêté avant sa fin (bouton Arrêter, ou reprise refusée).
    public func matchStopped(_ match: Match) {
        record(match, as: .interrupted)
    }

    /// Le match en cours à proposer à la reprise au lancement de l'app.
    public func resumableMatch() -> Match? {
        (try? store.latestInProgress())?.match
    }

    /// Un match n'est gardé qu'à partir de son premier événement, et jamais en 5 points.
    private func record(_ match: Match, as status: MatchStatus) {
        guard match.rules.isRecorded else { return }
        do {
            if match.events.isEmpty {
                try store.delete(matchID: match.id)
            } else {
                try store.save(MatchRecord(match: match, status: status))
            }
        } catch {
            // Sauvegarde ratée : le match continue, il ne sera simplement pas repris.
        }
    }
}
