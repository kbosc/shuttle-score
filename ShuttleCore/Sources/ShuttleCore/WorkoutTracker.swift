/// Une séance d'entraînement (HealthKit dans l'app, factice dans les tests).
@MainActor
public protocol WorkoutSession: AnyObject {
    /// Demande l'autorisation si besoin et démarre la séance. Lance une erreur si c'est impossible.
    func start() async throws
    func pause()
    func resume()
    /// Termine la séance : enregistrée dans Santé si `save`, jetée sinon.
    func end(save: Bool) async
}

/// Décide quand démarrer, mettre en pause, reprendre et terminer la séance au fil du match.
/// Une séance indisponible (accès refusé, appareil sans HealthKit) n'empêche jamais de jouer.
@MainActor
public final class WorkoutTracker {
    public enum Status: Equatable, Sendable {
        case idle
        case starting
        case running
        case paused
        case unavailable
    }

    public private(set) var status: Status = .idle
    private let session: any WorkoutSession

    public init(session: any WorkoutSession) {
        self.session = session
    }

    /// Un match commence.
    public func matchStarted() async {
        guard status == .idle else { return }
        status = .starting
        do {
            try await session.start()
        } catch {
            if status == .starting { status = .unavailable }
            return
        }
        // Le match a été quitté pendant le démarrage : la séance ne sert plus à rien.
        guard status == .starting else {
            await session.end(save: false)
            return
        }
        status = .running
    }

    /// L'état du match a changé : pause quand il se termine, reprise si une annulation le rouvre.
    public func matchChanged(isOver: Bool) {
        switch (status, isOver) {
        case (.running, true):
            session.pause()
            status = .paused
        case (.paused, false):
            session.resume()
            status = .running
        default:
            break
        }
    }

    /// On quitte le match (nouveau match, ou retour au choix du premier service).
    /// La séance est enregistrée si au moins un point a été joué, jetée sinon.
    public func matchLeft(hadRallies: Bool) async {
        let wasActive = status == .running || status == .paused
        status = .idle
        if wasActive {
            await session.end(save: hadRallies)
        }
    }
}
