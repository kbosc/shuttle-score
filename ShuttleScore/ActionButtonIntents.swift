import AppIntents
import ShuttleCore

/// Bouton Action de l'Ultra (voir SPEC.md, « Bouton Action »).
///
/// Dans Réglages → Bouton Action, ShuttleScore propose « Match de badminton ». Un appui lance
/// `StartMatchIntent`, qui ouvre l'app ; pendant une séance (donc pendant un match), watchOS
/// enchaîne ensuite sur l'intent renvoyé par `result(actionButtonIntent:)` : chaque appui
/// suivant exécute `ScorePointIntent`.

enum MatchStyle: String, AppEnum {
    case badminton

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Match" }
    static var caseDisplayRepresentations: [MatchStyle: DisplayRepresentation] {
        [.badminton: "Match de badminton"]
    }
}

struct StartMatchIntent: StartWorkoutIntent {
    static var title: LocalizedStringResource { "Démarrer un match" }
    static var suggestedWorkouts: [StartMatchIntent] { [StartMatchIntent(style: .badminton)] }

    // Annoté @Parameter : sinon Réglages ne propose que « ouvrir l'app ».
    @Parameter(title: "Match")
    var workoutStyle: MatchStyle

    var displayRepresentation: DisplayRepresentation { "Match de badminton" }

    init() {}

    /// Ouvre l'app (sur l'écran de démarrage hors match) ; les appuis suivants marquent.
    /// Cet intent est aussi celui du 1er appui d'un match démarré depuis l'écran (ou du
    /// 2e match de la soirée) : il transmet donc l'appui, que seul l'écran de match écoute.
    @MainActor
    func perform() async throws -> some IntentResult {
        ActionButtonPresses.shared.press()
        return .result(actionButtonIntent: ScorePointIntent())
    }
}

struct ScorePointIntent: AppIntent {
    static var title: LocalizedStringResource { "Point pour mon camp" }
    static var isDiscoverable: Bool { false }

    /// Transmet l'appui à l'écran de match, et reste l'action des appuis suivants.
    @MainActor
    func perform() async throws -> some IntentResult {
        ActionButtonPresses.shared.press()
        return .result(actionButtonIntent: ScorePointIntent())
    }
}
