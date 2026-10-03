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

    var body: some View {
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
                        match = nil
                    },
                    onNewMatch: {
                        setupFormat = nil
                        match = nil
                    })
            }
        } else {
            SetupView(initialFormat: setupFormat) { match = $0 }
        }
    }
}
