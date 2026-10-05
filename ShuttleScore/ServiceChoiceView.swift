import ShuttleCore
import SwiftUI

/// Choix du serveur puis du receveur au début d'un set de double, à partir du 2e set
/// (le premier set passe par `FirstDoublesServiceView`).
struct ServiceChoiceView: View {
    let title: String
    /// Joueurs autorisés à servir : le camp gagnant du set précédent.
    let servers: [Player]
    let onChoose: (ServiceChoice) -> Void
    /// Revenir à l'écran précédent (réglage du match).
    var onBack: (() -> Void)?
    /// Annuler le dernier point du set précédent (un tap raté a pu terminer le set).
    var onUndo: (() -> Void)?

    @State private var server: Player?

    var body: some View {
        List {
            Section {
                if let server {
                    ForEach(Player.players(of: server.side.opposite, in: .doubles), id: \.self) {
                        receiver in
                        Button(receiver.name(in: .doubles)) {
                            onChoose(ServiceChoice(server: server, receiver: receiver))
                        }
                        .accessibilityIdentifier("choice.receiver.\(receiver.identifier)")
                    }
                } else {
                    ForEach(servers, id: \.self) { player in
                        Button(player.name(in: .doubles)) { server = player }
                            .accessibilityIdentifier("choice.server.\(player.identifier)")
                    }
                }
            } header: {
                Text("\(title) · \(server == nil ? "qui sert ?" : "qui reçoit ?")")
            }

            if server != nil {
                Button("Changer le serveur") { server = nil }
            } else if let onBack {
                Button("Retour", action: onBack)
            }
            if let onUndo {
                Button(
                    "Annuler le dernier point", systemImage: "arrow.uturn.backward", action: onUndo
                )
                .accessibilityIdentifier("choice.undo")
            }
        }
    }
}

#Preview {
    ServiceChoiceView(title: "Set 2", servers: [.me, .partner], onChoose: { _ in }, onUndo: {})
}
