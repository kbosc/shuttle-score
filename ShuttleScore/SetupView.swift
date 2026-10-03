import ShuttleCore
import SwiftUI

/// Simple ou double, puis qui sert (et en double, qui reçoit).
struct SetupView: View {
    let onStart: (Match) -> Void
    @State private var format: MatchFormat?

    init(initialFormat: MatchFormat? = nil, onStart: @escaping (Match) -> Void) {
        self.onStart = onStart
        _format = State(initialValue: initialFormat)
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
            VStack(spacing: 8) {
                Text("Qui sert en premier ?")
                    .font(.headline)
                Button("Moi") { onStart(Match(firstServer: .me)) }
                    .accessibilityIdentifier("setup.firstServer.me")
                Button("Adversaire") { onStart(Match(firstServer: .opponent)) }
                    .accessibilityIdentifier("setup.firstServer.opponent")
                Button("Retour") { format = nil }
                    .accessibilityIdentifier("setup.back")
            }
        case .doubles:
            ServiceChoiceView(
                title: "Set 1", servers: Player.allCases,
                onChoose: { onStart(Match(doublesFirstService: $0)) },
                onBack: { format = nil })
        }
    }
}

#Preview {
    SetupView { _ in }
}
