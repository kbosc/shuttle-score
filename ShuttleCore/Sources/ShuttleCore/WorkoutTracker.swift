/// Une séance d'entraînement (HealthKit dans l'app, factice dans les tests).
@MainActor
public protocol WorkoutSession: AnyObject {
    /// Demande l'autorisation si besoin et démarre la séance. Lance une erreur si c'est impossible.
    func start() async throws
    func pause()
    func resume()
    /// Termine la séance : enregistrée dans Santé si `save`, jetée sinon.
    func end(save: Bool) async
    /// Reprend la séance laissée active par un plantage de l'app. `false` s'il n'y en a pas.
    func recover() async -> Bool
    /// Termine et enregistre une séance laissée active par un plantage de l'app, s'il y en a une.
    func endRecoveredSession() async
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

    /// « Reprendre » un match après un plantage : on récupère sa séance si elle est encore
    /// active, sinon on en démarre une nouvelle.
    public func matchResumed() async {
        guard status == .idle else { return }
        status = .starting
        if await session.recover() {
            status = .running
            return
        }
        status = .idle
        await matchStarted()
    }

    /// Au lancement de l'app, sans match à reprendre : une séance restée active
    /// (match terminé, 5 points, match sans point…) est terminée et enregistrée,
    /// pour ne jamais être reprise par le match suivant.
    public func appLaunched(withMatchToResume: Bool) async {
        guard !withMatchToResume, status == .idle else { return }
        await session.endRecoveredSession()
    }

    /// Au lancement, la reprise du match est refusée : la séance restée active
    /// depuis le plantage est terminée et enregistrée.
    public func resumeDeclined() async {
        guard status == .idle else { return }
        await session.endRecoveredSession()
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
