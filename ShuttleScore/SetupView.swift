import ShuttleCore
import SwiftUI

/// Simple ou double ; en simple, 3×15 ou 5 points ; puis qui sert (et en double, qui reçoit).
struct SetupView: View {
    let onStart: (Match) -> Void
    @State private var format: MatchFormat?
    /// Règles du simple. Le double se joue toujours en 3×15.
    @State private var singlesRules: ScoringRules?

    init(
        initialFormat: MatchFormat? = nil, initialRules: ScoringRules? = nil,
        onStart: @escaping (Match) -> Void
    ) {
        self.onStart = onStart
        _format = State(initialValue: initialFormat)
        _singlesRules = State(initialValue: initialFormat == .singles ? initialRules : nil)
    }

    var body: some View {
        switch format {
        case nil:
            VStack(spacing: 8) {
                Button("Simple") { format = .singles }
                    .accessibilityIdentifier("setup.format.singles")
                Button("Double") { format = .doubles }
                    .accessibilityIdentifier("setup.format.doubles")
            }
        case .singles:
            if let rules = singlesRules {
                VStack(spacing: 8) {
                    Text("Qui sert en premier ?")
                        .font(.headline)
                    Button("Moi") { onStart(Match(rules: rules, firstServer: .me)) }
                        .accessibilityIdentifier("setup.firstServer.me")
                    Button("Adversaire") { onStart(Match(rules: rules, firstServer: .opponent)) }
                        .accessibilityIdentifier("setup.firstServer.opponent")
                    Button("Retour") { singlesRules = nil }
                        .accessibilityIdentifier("setup.back")
                }
            } else {
                VStack(spacing: 8) {
                    Button("3×15") { singlesRules = .threeByFifteen }
                        .accessibilityIdentifier("setup.rules.official")
                    // Petit match à 3 en attendant d'autres joueurs : jamais sauvegardé.
                    Button("5 points") { singlesRules = .fivePoints }
                        .accessibilityIdentifier("setup.rules.fivePoints")
                    Button("Retour") { format = nil }
                        .accessibilityIdentifier("setup.back")
                }
            }
        case .doubles:
            FirstDoublesServiceView(
                onStart: { onStart(Match(doublesFirstService: $0)) },
                onBack: { format = nil })
        }
    }
}

#Preview {
    SetupView { _ in }
}
