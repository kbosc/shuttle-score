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

/// Choix du premier serveur, puis match. Rien n'est persisté : quitter l'app perd le match.
struct RootView: View {
    @State private var match: Match?

    var body: some View {
        if let current = match {
            MatchView(
                match: Binding(get: { current }, set: { match = $0 }),
                onNewMatch: { match = nil })
        } else {
            SetupView { firstServer in match = Match(firstServer: firstServer) }
        }
    }
}
