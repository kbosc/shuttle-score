import ShuttleCore
import SwiftUI

@main
struct ShuttleScoreApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Réglage du match, puis match. Rien n'est persisté : quitter l'app perd le match.
struct RootView: View {
    @State private var match: Match?
    /// Format à reprendre quand on annule avant le premier point (mauvais premier service).
    @State private var setupFormat: MatchFormat?
    /// Séance HealthKit du match ; factice pendant les tests UI.
    @State private var workout = WorkoutTracker(
        session: ProcessInfo.processInfo.arguments.contains("-UITests")
            ? NoWorkoutSession() : HealthKitWorkoutSession())

    var body: some View {
        content
            // Pause de la séance à la fin du match, reprise si une annulation le rouvre.
            .onChange(of: match?.state.isOver) { _, isOver in
                if let isOver { workout.matchChanged(isOver: isOver) }
            }
    }

    @ViewBuilder private var content: some View {
        if let current = match {
            let binding = Binding(get: { current }, set: { match = $0 })
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
                        leave(current)
                    },
                    onNewMatch: {
                        setupFormat = nil
                        leave(current)
                    })
            }
        } else {
            SetupView(initialFormat: setupFormat) { newMatch in
                match = newMatch
                Task { await workout.matchStarted() }
            }
        }
    }

    private func leave(_ current: Match) {
        match = nil
        Task { await workout.matchLeft(hadRallies: !current.events.isEmpty) }
    }
}
