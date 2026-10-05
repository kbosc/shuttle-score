import ShuttleCore
import SwiftUI

/// Premier set d'un double : qui sert, en appliquant la convention Adv. 1 (voir SPEC.md,
/// « Joueurs »). Si mon camp sert, Adv. 1 est celui qui reçoit ; si les adversaires
/// servent, Adv. 1 est celui qui sert et il reste à dire qui reçoit chez nous.
struct FirstDoublesServiceView: View {
    let onStart: (ServiceChoice) -> Void
    let onBack: () -> Void

    @State private var opponentsServe = false

    var body: some View {
        List {
            Section {
                if opponentsServe {
                    ForEach([Player.me, .partner], id: \.self) { receiver in
                        Button(receiver.name(in: .doubles)) {
                            onStart(.firstDoublesService(opponentsServeTo: receiver))
                        }
                        .accessibilityIdentifier("setup.doubles.receiver.\(receiver.identifier)")
                    }
                } else {
                    ForEach([Player.me, .partner], id: \.self) { server in
                        Button(server.name(in: .doubles)) {
                            onStart(.firstDoublesService(myTeamServer: server))
                        }
                        .accessibilityIdentifier("setup.doubles.server.\(server.identifier)")
                    }
                    Button("Adversaires") { opponentsServe = true }
                        .accessibilityIdentifier("setup.doubles.server.opponents")
                }
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(opponentsServe ? "Qui reçoit chez nous ?" : "Qui sert ?")
                    // Rappel de la convention, en haut pour être lu sans faire défiler.
                    Text(opponentsServe ? "Adv. 1 = celui qui sert" : "Adv. 1 = celui qui reçoit")
                        .font(.caption2)
                        .foregroundStyle(Color.serving)
                        .accessibilityIdentifier("setup.doubles.hint")
                }
            }

            Button("Retour") {
                if opponentsServe { opponentsServe = false } else { onBack() }
            }
        }
    }
}

#Preview {
    FirstDoublesServiceView(onStart: { _ in }, onBack: {})
}
