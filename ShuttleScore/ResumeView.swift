import ShuttleCore
import SwiftUI

/// Au lancement : un match était en cours (plantage, app fermée). Le reprendre ou l'arrêter.
struct ResumeView: View {
    let match: Match
    let onResume: () -> Void
    let onStop: () -> Void

    var body: some View {
        let state = match.state
        VStack(spacing: 8) {
            Text("\(state.currentGame.me) – \(state.currentGame.opponent)")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
            Text(
                "En cours · \(match.format == .singles ? "Simple" : "Double") · "
                    + "Sets \(state.gamesWon(by: .me)) – \(state.gamesWon(by: .opponent))"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            Button("Reprendre", action: onResume)
                .accessibilityIdentifier("resume.continue")
            Button("Arrêter", role: .destructive, action: onStop)
                .accessibilityIdentifier("resume.stop")
        }
    }
}

#Preview {
    ResumeView(match: Match(firstServer: .me), onResume: {}, onStop: {})
}
