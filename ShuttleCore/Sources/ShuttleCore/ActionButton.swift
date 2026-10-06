import Observation

/// Ce que fait un appui sur le bouton Action de l'Ultra (voir SPEC.md, « Bouton Action »).
public enum ActionButtonEffect: Equatable, Sendable {
    /// Pas de match : l'app s'ouvre sur l'écran de démarrage.
    case openApp
    /// Pendant un match : point pour mon camp, comme un tap sur la moitié basse.
    case scorePointForMyTeam
    /// Match terminé, ou service du set à choisir : l'appui ne fait rien.
    case ignored

    public static func of(_ match: Match?) -> ActionButtonEffect {
        guard let state = match?.state else { return .openApp }
        return state.isOver || state.awaitingServiceChoice != nil ? .ignored : .scorePointForMyTeam
    }
}

/// Relais entre le bouton Action (une App Intent, hors des écrans) et l'écran de match.
/// Chaque appui incrémente `count` ; l'écran de match observe ce compteur.
@MainActor
@Observable
public final class ActionButtonPresses {
    public static let shared = ActionButtonPresses()

    public private(set) var count = 0

    public init() {}

    public func press() {
        count += 1
    }
}
