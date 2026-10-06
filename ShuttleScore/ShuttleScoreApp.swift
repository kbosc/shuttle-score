import ShuttleCore
import ShuttleStore
import SwiftUI

@main
struct ShuttleScoreApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Reprise éventuelle, réglage du match, puis match. Chaque changement du match est sauvegardé.
struct RootView: View {
    @State private var match: Match?
    /// Match en cours retrouvé au lancement, en attente de la décision « reprendre / arrêter ».
    @State private var pendingResume: Match?
    /// Format à reprendre quand on annule avant le premier point (mauvais premier service).
    @State private var setupFormat: MatchFormat?
    @State private var setupRules: ScoringRules?
    @State private var recorder: MatchRecorder
    /// Séance HealthKit du match ; factice pendant les tests UI.
    @State private var workout = WorkoutTracker(
        session: ProcessInfo.processInfo.arguments.contains("-UITests")
            ? NoWorkoutSession() : HealthKitWorkoutSession())

    init() {
        // Les tests UI n'envoient rien à l'iPhone.
        let sync: (any MatchSync)? =
            ProcessInfo.processInfo.arguments.contains("-UITests") ? nil : WatchConnectivitySync()
        let recorder = MatchRecorder(store: Self.makeStore(), sync: sync)
        _recorder = State(initialValue: recorder)
        _pendingResume = State(initialValue: recorder.resumableMatch())
    }

    var body: some View {
        content
            .overlay(alignment: .topLeading) {
                // Tests UI seulement : simule un appui sur le bouton Action, que le
                // simulateur ne permet pas d'attribuer à l'app.
                if ProcessInfo.processInfo.arguments.contains("-UITests") {
                    Button("Bouton Action") { ActionButtonPresses.shared.press() }
                        .frame(width: 30, height: 30)
                        .opacity(0.02)
                        .accessibilityIdentifier("debug.actionButton")
                }
            }
            // Au lancement : une séance orpheline (pas de match à reprendre) est terminée.
            .task { await workout.appLaunched(withMatchToResume: pendingResume != nil) }
            // Pause de la séance à la fin du match, reprise si une annulation le rouvre.
            .onChange(of: match?.state.isOver) { _, isOver in
                if let isOver { workout.matchChanged(isOver: isOver) }
            }
    }

    @ViewBuilder private var content: some View {
        if let resumable = pendingResume {
            ResumeView(
                match: resumable,
                onResume: {
                    pendingResume = nil
                    match = resumable
                    Task { await workout.matchResumed() }
                },
                onStop: {
                    pendingResume = nil
                    recorder.matchStopped(resumable)
                    Task { await workout.resumeDeclined() }
                })
        } else if let current = match {
            // Toute modification du match (point, annulation, choix du service) est sauvegardée.
            let binding = Binding(
                get: { current },
                set: {
                    match = $0
                    recorder.matchChanged($0)
                })
            if let side = current.state.awaitingServiceChoice {
                // En double, au début de chaque set à partir du 2e.
                ServiceChoiceView(
                    title: "Set \(current.state.completedGames.count + 1)",
                    servers: Player.players(of: side, in: .doubles),
                    onChoose: { binding.wrappedValue.chooseService($0) },
                    onUndo: { binding.wrappedValue.undo() })
            } else {
                MatchView(
                    match: binding,
                    onUndoFirstService: {
                        setupFormat = current.format
                        setupRules = current.rules
                        leave(current)
                    },
                    onStop: {
                        recorder.matchStopped(current)
                        setupFormat = nil
                        setupRules = nil
                        leave(current)
                    },
                    onNewMatch: {
                        setupFormat = nil
                        setupRules = nil
                        leave(current)
                    })
            }
        } else {
            SetupView(initialFormat: setupFormat, initialRules: setupRules) { newMatch in
                match = newMatch
                Task { await workout.matchStarted() }
            }
        }
    }

    private func leave(_ current: Match) {
        match = nil
        Task { await workout.matchLeft(hadRallies: !current.events.isEmpty) }
    }

    /// Stockage SwiftData de l'app. `-ResetStore` (tests UI) part d'un stockage vide.
    /// Si le stockage est inutilisable, on joue quand même, sans rien sauvegarder.
    private static func makeStore() -> any MatchStore {
        do {
            let store = try SwiftDataMatchStore()
            if ProcessInfo.processInfo.arguments.contains("-ResetStore") {
                try store.deleteAll()
            }
            return store
        } catch {
            return NoMatchStore()
        }
    }
}

/// Stockage de secours quand SwiftData est inutilisable : rien n'est gardé.
@MainActor
private final class NoMatchStore: MatchStore {
    func save(_ record: MatchRecord) throws {}
    func delete(matchID: UUID) throws {}
    func latestInProgress() throws -> MatchRecord? { nil }
}
